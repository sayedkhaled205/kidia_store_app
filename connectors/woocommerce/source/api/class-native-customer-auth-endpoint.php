<?php
/** Native customer authentication. Provider credentials are verified on the server. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Native_Customer_Auth_Endpoint {

	private const PREFIX = '_mobishop_native_auth_';
	private const TTL = 300;
	private const FIREBASE_CERTS = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
	private const GOOGLE_CERTS = 'https://www.googleapis.com/oauth2/v1/certs';
	private $issue;
	private $allowed;

	public function __construct( callable $issue, callable $allowed ) {
		$this->issue = $issue;
		$this->allowed = $allowed;
	}

	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'routes' ) );
		add_action( 'mobishop_native_auth_cleanup', function ( $key ) {
			if ( ! is_string( $key ) || ! preg_match( '/^' . self::PREFIX . '[a-f0-9]{64}$/', $key ) ) return;
			$row = get_option( $key );
			if ( is_array( $row ) && (int) ( $row['expires'] ?? 0 ) <= time() ) $this->consume_key( $key, $row );
		} );
	}

	public function routes(): void {
		foreach ( array( 'config' => 'config', 'identify' => 'identify', 'password' => 'password', 'phone/verify' => 'phone_verify', 'select' => 'select', 'google' => 'google', 'register' => 'register_customer' ) as $route => $method ) {
			register_rest_route( 'mobishop/v1', '/auth/native/' . $route, array(
				'methods' => $route === 'config' ? 'GET' : 'POST',
				'callback' => array( $this, $method ), 'permission_callback' => '__return_true',
			) );
		}
	}

	/** Only operator-verified native SDK settings enable a provider. Website keys alone are insufficient. */
	private function settings(): array {
		$value = apply_filters( 'mobishop_native_auth_settings', get_option( 'mobishop_native_auth_settings', array() ) );
		return is_array( $value ) ? $value : array();
	}

	private function platform( WP_REST_Request $request ): string {
		return $request->get_param( 'platform' ) === 'ios' ? 'ios' : 'android';
	}

	private function capabilities( WP_REST_Request $request ): array {
		$s = $this->settings();
		$platform = $this->platform( $request );
		$f = $s['firebase'][ $platform ] ?? array();
		$f = is_array( $f ) ? array_intersect_key( $f, array_flip( array( 'apiKey', 'appId', 'projectId', 'messagingSenderId', 'storageBucket', 'iosBundleId', 'authDomain' ) ) ) : array();
		foreach ( $f as $key => $value ) if ( ! is_string( $value ) || strlen( $value ) > 512 ) unset( $f[ $key ] );
		$project = (string) ( $s['firebase_project_id'] ?? '' );
		$phone = ! empty( $s['phone_enabled'] ) && preg_match( '/^[a-z][a-z0-9-]{3,62}$/', $project )
			&& ( $f['projectId'] ?? '' ) === $project && ! empty( $f['apiKey'] ) && ! empty( $f['messagingSenderId'] )
			&& strpos( (string) ( $f['appId'] ?? '' ), ':' . $platform . ':' ) !== false
			&& ( $platform !== 'ios' || ( ! empty( $f['iosBundleId'] ) && ! empty( $s['ios_phone_native_ready'] ) ) );
		$g = is_array( $s['google'] ?? null ) ? $s['google'] : array();
		$client = (string) ( $g['server_client_id'] ?? '' );
		$native = $platform === 'ios' ? array( $g['ios_client_id'] ?? '' ) : (array) ( $g['android_client_ids'] ?? array() );
		$google = ! empty( $s['google_enabled'] ) && $this->client_id( $client ) && count( array_filter( $native, array( $this, 'client_id' ) ) ) > 0;
		$enabled = wp_is_using_https();
		$phone = $phone && function_exists( 'openssl_verify' );
		$google = $google && function_exists( 'openssl_verify' );
		return array(
			'version' => 1, 'enabled' => $enabled,
			'phone_country_code' => preg_replace( '/\D/', '', (string) ( $s['phone_country_code'] ?? '' ) ),
			'methods' => array( 'password' => $enabled, 'email_password' => $enabled, 'phone_password' => $enabled,
				'phone_otp' => $enabled && (bool) $phone, 'google' => $enabled && $google,
				'registration' => $enabled && $this->registration_enabled() && ( $phone || ( $google && ! $this->requires_phone() ) ) ),
			'firebase' => $enabled && $phone ? $f : null,
			'google' => $enabled && $google ? array( 'server_client_id' => $client, 'ios_client_id' => $platform === 'ios' ? $g['ios_client_id'] : null ) : null,
		);
	}

	private function client_id( $value ): bool {
		return is_string( $value ) && (bool) preg_match( '/^[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$/', $value );
	}

	public function config( WP_REST_Request $request ) {
		return $this->response( $this->capabilities( $request ) );
	}

	/** This step deliberately answers identically for existing and unknown identities. */
	public function identify( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'identify', 60 ) ) return $error;
		$identity = $this->identity( (string) $request->get_param( 'identifier' ) );
		if ( ! $identity ) return $this->error( 'invalid_identifier', 400 );
		$c = $this->capabilities( $request );
		$methods = array( 'password' );
		if ( $identity['kind'] === 'phone' && $c['methods']['phone_otp'] ) $methods[] = 'phone_otp';
		return $this->response( $identity + array( 'methods' => $methods ) );
	}

	public function password( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'password', 15 ) ) return $error;
		$identity = $this->identity( (string) $request->get_param( 'identifier' ) );
		$password = $request->get_param( 'password' );
		if ( ! $identity || ! $this->verifier( $request ) || ! is_string( $password ) || $password === '' || strlen( $password ) > 4096 ) return $this->error( 'invalid_credentials', 401 );
		$matched = array();
		if ( $identity['kind'] === 'email' ) {
			$user = wp_authenticate( $identity['identifier'], $password );
			// Authentication may upgrade the stored password hash or alter account policy.
			if ( $user instanceof WP_User ) $user = get_user_by( 'id', $user->ID );
			if ( $user instanceof WP_User && $this->eligible( $user ) && strtolower( $user->user_email ) === $identity['identifier'] ) $matched[] = $user;
		} else {
			$candidates = $this->phone_users( $identity['identifier'] );
			if ( is_wp_error( $candidates ) ) return $this->error( 'invalid_credentials', 401 );
			// Bound password hashing work; excessive ambiguous records require OTP.
			if ( count( $candidates ) > 20 ) return $this->error( 'invalid_credentials', 401 );
			foreach ( $candidates as $user ) {
				if ( ! wp_check_password( $password, $user->user_pass, $user->ID ) ) continue;
				$verified = wp_authenticate( $user->user_login, $password );
				if ( $verified instanceof WP_User && $verified->ID === $user->ID ) {
					$verified = get_user_by( 'id', $verified->ID );
					if ( $this->eligible( $verified ) && $this->user_phone( $verified, $identity['identifier'] ) === $identity['identifier'] ) $matched[] = $verified;
				}
			}
		}
		if ( ! $matched ) return $this->error( 'invalid_credentials', 401 );
		// Password proof is scoped to the accounts whose own password matched.
		$versions = array();
		foreach ( $matched as $user ) $versions[ $user->ID ] = $this->hash( $user->user_pass );
		return $this->complete_proof( $matched, array( 'kind' => 'password', 'identity' => $identity, 'password_versions' => $versions ), $request );
	}

	public function phone_verify( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'phone', 20 ) ) return $error;
		$c = $this->capabilities( $request );
		if ( ! $c['methods']['phone_otp'] ) return $this->error( 'unavailable', 503 );
		$phone = $this->phone( (string) $request->get_param( 'phone' ) );
		if ( ! $phone || ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$claims = $this->jwt( $request->get_param( 'id_token' ), self::FIREBASE_CERTS );
		$project = $c['firebase']['projectId'];
		if ( ! $claims || ( $claims['aud'] ?? null ) !== $project || ( $claims['iss'] ?? null ) !== 'https://securetoken.google.com/' . $project
			|| ! $this->fresh( $claims, true ) || ( $claims['phone_number'] ?? null ) !== $phone
			|| ( $claims['firebase']['sign_in_provider'] ?? null ) !== 'phone' || strlen( $claims['sub'] ) > 128 ) return $this->error( 'invalid_proof', 401 );
		$proof = array( 'kind' => 'phone', 'phone' => $phone );
		$prior = (string) $request->get_param( 'ticket' );
		if ( $prior !== '' ) {
			$row = $this->read_ticket( $prior, $request );
			if ( ! $row || $row['purpose'] !== 'register' || ! $this->consume( $prior, $row ) ) return $this->error( 'invalid_ticket', 401 );
			$proof = $row['proof'];
			$proof['phone'] = $phone;
			// Existing account completion cannot silently merge another account's phone.
			$users = $this->phone_users( $phone );
			if ( is_wp_error( $users ) ) return $users;
			if ( ! empty( $proof['user_id'] ) ) {
				$target = get_user_by( 'id', (int) $proof['user_id'] );
				if ( ! $this->proof_allows( $target, $proof ) ) return $this->error( 'invalid_proof', 401 );
				$retains_phone = $this->user_phone( $target, $phone ) === $phone;
				foreach ( $users as $user ) if ( $user->ID !== $target->ID && ! $retains_phone ) return $this->error( 'account_conflict', 409 );
			} elseif ( $users ) {
				// Two independent proofs permit linking the selected account, without moving its email or orders.
				$proof['kind'] = ! empty( $proof['sub'] ) ? 'google_phone' : 'phone';
				return $this->complete_proof( $users, $proof, $request );
			}
			return $this->registration_ticket( $proof, $request );
		}
		$users = $this->phone_users( $phone );
		return is_wp_error( $users ) ? $users : $this->complete_proof( $users, $proof, $request );
	}

	public function google( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'google', 20 ) ) return $error;
		$c = $this->capabilities( $request );
		if ( ! $c['methods']['google'] ) return $this->error( 'unavailable', 503 );
		if ( ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$claims = $this->jwt( $request->get_param( 'id_token' ), self::GOOGLE_CERTS );
		$g = $this->settings()['google'];
		$authorized = $this->platform( $request ) === 'ios' ? array( $g['ios_client_id'] ?? '' ) : (array) ( $g['android_client_ids'] ?? array() );
		$authorized[] = $g['server_client_id'];
		if ( ! $claims ) return $this->error( 'invalid_proof', 401, 'google_signature' );
		if ( ! $this->fresh( $claims, false ) ) return $this->error( 'invalid_proof', 401, 'google_time' );
		if ( ( $claims['aud'] ?? null ) !== $g['server_client_id'] ) return $this->error( 'invalid_proof', 401, 'google_audience' );
		if ( ! in_array( $claims['iss'] ?? null, array( 'accounts.google.com', 'https://accounts.google.com' ), true ) ) return $this->error( 'invalid_proof', 401, 'google_issuer' );
		if ( isset( $claims['azp'] ) && ! in_array( $claims['azp'], $authorized, true ) ) return $this->error( 'invalid_proof', 401, 'google_presenter' );
		if ( ( $claims['email_verified'] ?? null ) !== true || ! is_string( $claims['email'] ?? null ) || ! is_email( $claims['email'] ) ) return $this->error( 'invalid_proof', 401, 'google_email' );
		$email = strtolower( $claims['email'] );
		$proof = array( 'kind' => 'google', 'sub' => $claims['sub'], 'email' => $email,
			'authoritative' => (bool) preg_match( '/@(gmail|googlemail)\.com$/', $email ) || ( is_string( $claims['hd'] ?? null ) && $claims['hd'] !== '' ) );
		$linked = $this->google_user( $proof['sub'] );
		if ( $linked ) {
			$user = get_user_by( 'id', $linked );
			if ( ! $this->eligible( $user ) ) return $this->error( 'invalid_credentials', 401, 'google_customer_policy' );
			return $this->complete_proof( array( $user ), $proof, $request );
		}
		// Google is not authoritative for arbitrary third-party email accounts.
		if ( ! $proof['authoritative'] ) return $this->error( 'additional_proof_required', 403 );
		$user = get_user_by( 'email', $email );
		if ( $user ) {
			if ( ! $this->eligible( $user ) || ! $this->link_google( $user->ID, $proof['sub'] ) ) return $this->error( 'account_conflict', 409 );
			return $this->complete_proof( array( $user ), $proof, $request );
		}
		return $this->registration_ticket( $proof, $request );
	}

	public function select( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'select', 30 ) ) return $error;
		$ticket = (string) $request->get_param( 'ticket' );
		$row = $this->read_ticket( $ticket, $request );
		$id = (int) $request->get_param( 'account_id' );
		if ( ! $row || $row['purpose'] !== 'select' || ! in_array( $id, $row['ids'], true ) ) return $this->error( 'invalid_ticket', 401 );
		$user = get_user_by( 'id', $id );
		if ( ! $this->proof_allows( $user, $row['proof'] ) || ! $this->consume( $ticket, $row ) ) return $this->error( 'invalid_ticket', 401 );
		return $this->finish( $user, $row['proof'], $request );
	}

	private function complete_proof( array $users, array $proof, WP_REST_Request $request ) {
		if ( count( $users ) > 50 ) return $this->error( 'account_conflict', 409 );
		if ( ! $users ) return $this->registration_ticket( $proof, $request );
		$proof['ids'] = array_map( static fn( $user ) => (int) $user->ID, $users );
		if ( count( $users ) === 1 ) return $this->finish( $users[0], $proof, $request );
		$ticket = $this->ticket( 'select', $proof, $request, $proof['ids'] );
		if ( is_wp_error( $ticket ) ) return $ticket;
		return $this->response( array( 'status' => 'select_account', 'ticket' => $ticket, 'expires_in' => self::TTL,
			'accounts' => array_map( function ( $user ) {
				$email = explode( '@', (string) $user->user_email, 2 );
				return array( 'id' => (int) $user->ID, 'name' => sanitize_text_field( $user->display_name ),
					'email_hint' => count( $email ) === 2 ? substr( $email[0], 0, 1 ) . '***@' . $email[1] : '' );
			}, $users ) ) );
	}

	private function finish( WP_User $user, array $proof, WP_REST_Request $request ) {
		if ( ! $this->eligible( $user ) ) return $this->error( 'invalid_credentials', 401 );
		if ( $proof['kind'] === 'google_phone' && $this->google_user( $proof['sub'] ) !== $user->ID && ! $this->link_google( $user->ID, $proof['sub'] ) ) return $this->error( 'account_conflict', 409 );
		if ( ! $this->ready( $user ) ) {
			$proof['user_id'] = (int) $user->ID;
			return $this->registration_ticket( $proof, $request );
		}
		$result = call_user_func( $this->issue, $user );
		if ( $result instanceof WP_REST_Response ) {
			$result->set_data( array( 'status' => 'authenticated' ) + $result->get_data() );
			$result->header( 'Cache-Control', 'no-store, private' );
		}
		return $result;
	}

	private function ready( WP_User $user ): bool {
		$ready = apply_filters( 'mobishop_auth_customer_ready', ! get_user_meta( $user->ID, 'kidia_phone_setup_required', true ), $user );
		return (bool) apply_filters( 'mobishop_native_auth_customer_ready', $ready, $user );
	}

	private function registration_enabled(): bool {
		$s = $this->settings();
		return (bool) ( $s['registration_enabled'] ?? ( get_option( 'woocommerce_enable_myaccount_registration', 'no' ) === 'yes' ) );
	}

	private function requires_phone(): bool {
		$s = $this->settings();
		return (bool) apply_filters( 'mobishop_native_auth_requires_phone', $s['require_phone'] ?? class_exists( 'Kidia_Firebase_OTP_265' ) );
	}

	private function registration_ticket( array $proof, WP_REST_Request $request ) {
		if ( empty( $proof['user_id'] ) && ! $this->registration_enabled() ) return $this->error( 'registration_disabled', 403 );
		if ( $proof['kind'] === 'password' && empty( $proof['user_id'] ) ) return $this->error( 'invalid_proof', 401 );
		$fields = array( 'name', 'password' );
		if ( $this->requires_phone() && empty( $proof['phone'] ) ) $fields[] = 'phone';
		$ticket = $this->ticket( 'register', $proof, $request );
		if ( is_wp_error( $ticket ) ) return $ticket;
		return $this->response( array( 'status' => 'registration_required', 'ticket' => $ticket, 'expires_in' => self::TTL, 'fields' => $fields ) );
	}

	public function register_customer( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'register', 10 ) ) return $error;
		$ticket = (string) $request->get_param( 'ticket' );
		$row = $this->read_ticket( $ticket, $request );
		if ( ! $row || $row['purpose'] !== 'register' ) return $this->error( 'invalid_ticket', 401 );
		$p = $row['proof'];
		$name = sanitize_text_field( (string) $request->get_param( 'name' ) );
		$password = $request->get_param( 'password' );
		$email = strtolower( trim( (string) $request->get_param( 'email' ) ) );
		if ( $name === '' || strlen( $name ) > 120 || ! is_string( $password ) || strlen( $password ) < 8 || strlen( $password ) > 4096
			|| ( $email !== '' && $email !== ( $p['email'] ?? '' ) ) ) return $this->error( 'invalid_profile', 400 );
		if ( $this->requires_phone() && empty( $p['phone'] ) ) return $this->error( 'phone_proof_required', 403 );
		$user = ! empty( $p['user_id'] ) ? get_user_by( 'id', (int) $p['user_id'] ) : null;
		if ( ! empty( $p['user_id'] ) && ! $this->proof_allows( $user, $p ) ) return $this->error( 'invalid_proof', 401 );
		if ( ! $user && ! $this->registration_enabled() ) return $this->error( 'registration_disabled', 403 );
		// Serialize registrations for the verified identity, including parallel tickets.
		$identities = array();
		foreach ( array( 'phone', 'email', 'user_id' ) as $field ) if ( ! empty( $p[ $field ] ) ) $identities[] = 'register:' . $field . ':' . $p[ $field ];
		if ( ! empty( $p['sub'] ) ) $identities[] = 'google-link:sub:' . $p['sub'];
		$locks = $this->lock( $identities );
		if ( $locks === null ) return $this->error( 'retry', 409 );
		try {
			if ( ! empty( $p['phone'] ) ) {
				$existing_users = $this->phone_users( $p['phone'] );
				if ( is_wp_error( $existing_users ) ) return $existing_users;
				$retains_phone = $user && $this->user_phone( $user, $p['phone'] ) === $p['phone'];
				foreach ( $existing_users as $existing ) if ( ! $user || ( $existing->ID !== $user->ID && ! $retains_phone ) ) return $this->error( 'account_conflict', 409 );
			}
			if ( ! $user && ! empty( $p['email'] ) && email_exists( $p['email'] ) ) return $this->error( 'account_conflict', 409 );
			if ( ! empty( $p['sub'] ) && $this->google_user( $p['sub'] ) && ( ! $user || $this->google_user( $p['sub'] ) !== $user->ID ) ) return $this->error( 'account_conflict', 409 );
			if ( ! $this->consume( $ticket, $row ) ) return $this->error( 'invalid_ticket', 401 );
			if ( ! $user ) {
				$id = wp_insert_user( array( 'user_login' => 'mobile_' . bin2hex( random_bytes( 12 ) ),
					'user_email' => $p['email'] ?? '', 'user_pass' => $password, 'display_name' => $name, 'first_name' => $name, 'role' => 'customer' ) );
				if ( is_wp_error( $id ) ) return $this->error( 'registration_failed', 409 );
				$user = get_user_by( 'id', (int) $id );
			} else {
				$id = wp_update_user( array( 'ID' => $user->ID, 'display_name' => $name, 'first_name' => $name, 'user_pass' => $password ) );
				if ( is_wp_error( $id ) ) return $this->error( 'registration_failed', 409 );
			}
			if ( ! $this->eligible( $user ) ) return $this->error( 'invalid_credentials', 401 );
			if ( ! empty( $p['phone'] ) ) {
				update_user_meta( $user->ID, 'kidia_login_phone', $p['phone'] );
				update_user_meta( $user->ID, 'fme_billing_phone', $p['phone'] );
				if ( ! get_user_meta( $user->ID, 'billing_phone', true ) ) update_user_meta( $user->ID, 'billing_phone', $p['phone'] );
			}
			if ( ! empty( $p['sub'] ) && ! $this->link_google( $user->ID, $p['sub'], true ) ) return $this->error( 'account_conflict', 409 );
			delete_user_meta( $user->ID, 'kidia_phone_setup_required' );
			do_action( 'mobishop_native_auth_profile_completed', $user->ID, $p['kind'] );
			return $this->finish( get_user_by( 'id', $user->ID ), $p, $request );
		} finally {
			$this->unlock( $locks );
		}
	}

	private function eligible( $user ): bool {
		return $user instanceof WP_User && empty( $user->allcaps['edit_users'] ) && (bool) call_user_func( $this->allowed, $user );
	}

	private function proof_allows( $user, array $p ): bool {
		if ( ! $this->eligible( $user ) ) return false;
		if ( ! empty( $p['user_id'] ) && (int) $p['user_id'] !== $user->ID ) return false;
		if ( in_array( $p['kind'], array( 'phone', 'google_phone' ), true ) ) return $this->user_phone( $user, $p['phone'] ) === $p['phone'];
		if ( $p['kind'] === 'google' ) return $this->google_user( $p['sub'] ) === $user->ID;
		return in_array( (int) $user->ID, $p['ids'] ?? array(), true )
			&& hash_equals( (string) ( $p['password_versions'][ $user->ID ] ?? '' ), $this->hash( $user->user_pass ) )
			&& ( $p['identity']['kind'] === 'phone' ? $this->user_phone( $user, $p['identity']['identifier'] ) === $p['identity']['identifier'] : strtolower( $user->user_email ) === $p['identity']['identifier'] );
	}

	private function identity( string $value ): ?array {
		$value = trim( $value );
		if ( strlen( $value ) > 254 ) return null;
		if ( is_email( $value ) ) return array( 'identifier' => strtolower( $value ), 'kind' => 'email' );
		$phone = $this->phone( $value );
		return $phone ? array( 'identifier' => $phone, 'kind' => 'phone' ) : null;
	}

	private function phone( string $value ): string {
		$value = $this->phone_input( $value );
		if ( strpos( $value, '00' ) === 0 ) $value = '+' . substr( $value, 2 );
		$country = preg_replace( '/\D/', '', (string) ( $this->settings()['phone_country_code'] ?? '' ) );
		if ( $country && strpos( $value, '+' ) !== 0 ) $value = '+' . $country . ltrim( $value, '0' );
		return preg_match( '/^\+[1-9][0-9]{7,14}$/D', $value ) ? $value : '';
	}

	private function phone_input( string $value ): string {
		$value = strtr( trim( $value ), array_combine( preg_split( '//u', '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', -1, PREG_SPLIT_NO_EMPTY ), str_split( '01234567890123456789' ) ) );
		return (string) preg_replace( '/[\s().-]/u', '', $value );
	}

	private function phone_keys(): array {
		return (array) apply_filters( 'mobishop_native_auth_phone_meta_keys', array( 'kidia_login_phone', 'fme_billing_phone', 'billing_phone' ) );
	}

	private function user_phone( WP_User $user, string $expected ): string {
		// The first stored identity is authoritative: shipping metadata cannot override it.
		foreach ( $this->phone_keys() as $key ) {
			$value = (string) get_user_meta( $user->ID, $key, true );
			if ( $value !== '' ) {
				// Older providers also store E.164 without the leading plus.
				if ( $this->phone_input( $value ) === ltrim( $expected, '+' ) ) return $expected;
				return $this->phone( $value );
			}
		}
		return '';
	}

	private function phone_users( string $phone ) {
		$values = array( $phone, ltrim( $phone, '+' ), '00' . ltrim( $phone, '+' ) );
		$country = preg_replace( '/\D/', '', (string) ( $this->settings()['phone_country_code'] ?? '' ) );
		if ( $country && strpos( $phone, '+' . $country ) === 0 ) {
			$local = substr( $phone, strlen( $country ) + 1 );
			$values[] = $local; $values[] = '0' . $local;
		}
		$query = array( 'relation' => 'OR' );
		$pattern = $this->phone_lookup_pattern( $values );
		foreach ( $this->phone_keys() as $key ) $query[] = array( 'key' => $key, 'value' => $pattern, 'compare' => 'REGEXP' );
		// Bound the candidate set in SQL. No full user-table scan in PHP or partial picker.
		$users = get_users( array( 'meta_query' => $query, 'number' => 51, 'orderby' => 'ID', 'order' => 'ASC' ) );
		if ( count( $users ) > 50 ) return $this->error( 'account_conflict', 409 );
		$eligible = array_values( array_filter( $users, fn( $user ) => $this->eligible( $user ) && $this->user_phone( $user, $phone ) === $phone ) );
		return $users && ! $eligible ? $this->error( 'account_conflict', 409 ) : $eligible;
	}

	/** Match only known canonical variants plus the formatting accepted by phone_input(). */
	private function phone_lookup_pattern( array $values ): string {
		// Whole-character alternatives also work on older MySQL byte-oriented REGEXP engines.
		$digits = array( '(0|٠|۰)', '(1|١|۱)', '(2|٢|۲)', '(3|٣|۳)', '(4|٤|۴)', '(5|٥|۵)', '(6|٦|۶)', '(7|٧|۷)', '(8|٨|۸)', '(9|٩|۹)' );
		$separator = '[[:space:]().-]*';
		$patterns = array();
		foreach ( array_unique( $values ) as $value ) {
			$parts = array();
			foreach ( str_split( $value ) as $digit ) $parts[] = $digit === '+' ? '[+]' : $digits[ (int) $digit ];
			$patterns[] = implode( $separator, $parts );
		}
		return '^' . $separator . '(' . implode( '|', $patterns ) . ')' . $separator . '$';
	}

	private function google_provider() {
		$provider = class_exists( 'NextendSocialLogin' ) ? ( NextendSocialLogin::$providers['google'] ?? null ) : null;
		return is_object( $provider ) && method_exists( $provider, 'getUserIDByProviderIdentifier' ) && method_exists( $provider, 'linkUserToProviderIdentifier' ) ? $provider : null;
	}

	private function google_user( string $sub ): int {
		$provider = $this->google_provider();
		$id = $provider ? (int) $provider->getUserIDByProviderIdentifier( $sub ) : 0;
		if ( $id ) return $id;
		$ids = get_users( array( 'meta_key' => '_mobishop_google_subject', 'meta_value' => $sub, 'fields' => 'ID', 'number' => 2 ) );
		return count( $ids ) > 1 ? -1 : ( count( $ids ) === 1 ? (int) $ids[0] : 0 );
	}

	private function link_google( int $id, string $sub, bool $subject_locked = false ): bool {
		$identities = array( 'google-link:user:' . $id );
		if ( ! $subject_locked ) $identities[] = 'google-link:sub:' . $sub;
		$locks = $this->lock( $identities );
		if ( $locks === null ) return false;
		try {
			$existing = $this->google_user( $sub );
			if ( $existing ) return $existing === $id;
			$old = get_user_meta( $id, '_mobishop_google_subject', true );
			if ( $old && $old !== $sub ) return false;
			$provider = $this->google_provider();
			if ( $provider && ( ! $provider->linkUserToProviderIdentifier( $id, $sub ) || (int) $provider->getUserIDByProviderIdentifier( $sub ) !== $id ) ) return false;
			update_user_meta( $id, '_mobishop_google_subject', $sub );
			return $this->google_user( $sub ) === $id;
		} finally { $this->unlock( $locks ); }
	}

	private function jwt( $token, string $url ): ?array {
		if ( ! is_string( $token ) || strlen( $token ) > 10000 ) return null;
		$parts = explode( '.', $token );
		if ( count( $parts ) !== 3 ) return null;
		$header = json_decode( (string) $this->decode( $parts[0] ), true );
		$claims = json_decode( (string) $this->decode( $parts[1] ), true );
		$sig = $this->decode( $parts[2] );
		if ( ! is_array( $header ) || ! is_array( $claims ) || $sig === false || ( $header['alg'] ?? null ) !== 'RS256'
			|| ! is_string( $header['kid'] ?? null ) || strlen( $header['kid'] ) > 256 || ! empty( $header['crit'] ) ) return null;
		$key = 'mobishop_native_certs_' . hash( 'sha256', $url );
		$certs = get_transient( $key );
		// Refresh once on an unknown key after provider rotation. Bound refreshes
		// per issuer so random key IDs cannot force an outbound request per login.
		$refresh_key = $key . '_refresh';
		if ( ! is_array( $certs ) || ( ! isset( $certs[ $header['kid'] ] ) && ! get_transient( $refresh_key ) ) ) {
			set_transient( $refresh_key, 1, 60 );
			$response = wp_remote_get( $url, array( 'timeout' => 10, 'redirection' => 0, 'sslverify' => true, 'limit_response_size' => 65536 ) );
			if ( is_wp_error( $response ) || wp_remote_retrieve_response_code( $response ) !== 200 ) return null;
			$certs = json_decode( wp_remote_retrieve_body( $response ), true );
			if ( ! is_array( $certs ) || count( $certs ) > 20 ) return null;
			set_transient( $key, $certs, 300 );
		}
		$cert = $certs[ $header['kid'] ] ?? null;
		if ( ! is_string( $cert ) || openssl_verify( $parts[0] . '.' . $parts[1], $sig, $cert, OPENSSL_ALGO_SHA256 ) !== 1 ) return null;
		return $claims;
	}

	private function decode( string $value ) {
		if ( ! preg_match( '/^[A-Za-z0-9_-]+$/D', $value ) ) return false;
		return base64_decode( strtr( $value, '-_', '+/' ), true );
	}

	private function fresh( array $claims, bool $phone ): bool {
		$now = time();
		if ( ! is_string( $claims['sub'] ?? null ) || $claims['sub'] === '' || strlen( $claims['sub'] ) > 255
			|| ! is_int( $claims['exp'] ?? null ) || $claims['exp'] <= $now
			|| ! is_int( $claims['iat'] ?? null ) || $claims['iat'] > $now + ( $phone ? 0 : 30 ) || $claims['iat'] <= 0 || $claims['iat'] >= $claims['exp']
			// Google SDKs may reuse an unexpired ID token. Its signed expiry,
			// audience and issuer govern validity; the OTP proof stays recent.
			|| ( $phone && $claims['iat'] < $now - 600 )
			|| ( isset( $claims['nbf'] ) && ( ! is_int( $claims['nbf'] ) || $claims['nbf'] > $now + 30 ) ) ) return false;
		return ! $phone || ( is_int( $claims['auth_time'] ?? null ) && $claims['auth_time'] <= $now && $claims['auth_time'] >= $now - 600 );
	}

	private function verifier( WP_REST_Request $request ): bool {
		return is_string( $request->get_param( 'verifier' ) ) && (bool) preg_match( '/^[a-f0-9]{64}$/D', $request->get_param( 'verifier' ) );
	}

	private function hash( string $value ): string { return hash_hmac( 'sha256', $value, wp_salt( 'auth' ) ); }

	private function ticket( string $purpose, array $proof, WP_REST_Request $request, array $ids = array() ) {
		if ( ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$ticket = bin2hex( random_bytes( 32 ) );
		$key = self::PREFIX . $this->hash( $ticket );
		$row = array( 'expires' => time() + self::TTL, 'binding' => $this->hash( $request->get_param( 'verifier' ) ), 'purpose' => $purpose, 'proof' => $proof, 'ids' => $ids );
		if ( ! add_option( $key, $row, '', false ) ) return $this->error( 'unavailable', 503 );
		wp_schedule_single_event( $row['expires'] + 60, 'mobishop_native_auth_cleanup', array( $key ) );
		return $ticket;
	}

	private function read_ticket( string $ticket, WP_REST_Request $request ): ?array {
		if ( ! preg_match( '/^[a-f0-9]{64}$/D', $ticket ) || ! $this->verifier( $request ) ) return null;
		$row = get_option( self::PREFIX . $this->hash( $ticket ) );
		return is_array( $row ) && (int) $row['expires'] > time() && hash_equals( $row['binding'], $this->hash( $request->get_param( 'verifier' ) ) ) ? $row : null;
	}

	/** Delete only this exact ticket version: concurrent redemption has one winner. */
	private function consume( string $ticket, array $row ): bool {
		return $this->consume_key( self::PREFIX . $this->hash( $ticket ), $row );
	}

	private function consume_key( string $key, array $row ): bool {
		global $wpdb;
		$changed = $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", $key, maybe_serialize( $row ) ) ) === 1;
		wp_cache_delete( $key, 'options' );
		return $changed;
	}

	/** Short leases are removed after crashes; compare-and-delete cannot release a later owner's lease. */
	private function lock( array $identities ): ?array {
		$locks = array();
		sort( $identities );
		foreach ( array_unique( $identities ) as $identity ) {
			$key = self::PREFIX . $this->hash( 'lock:' . $identity );
			$row = array( 'owner' => bin2hex( random_bytes( 16 ) ), 'expires' => time() + self::TTL );
			$old = get_option( $key );
			if ( is_array( $old ) && (int) ( $old['expires'] ?? 0 ) <= time() ) $this->consume_key( $key, $old );
			if ( ! add_option( $key, $row, '', false ) ) { $this->unlock( $locks ); return null; }
			$locks[ $key ] = $row;
			wp_schedule_single_event( $row['expires'] + 60, 'mobishop_native_auth_cleanup', array( $key ) );
		}
		return $locks;
	}

	private function unlock( array $locks ): void {
		foreach ( $locks as $key => $row ) $this->consume_key( $key, $row );
	}

	private function guard( string $action, int $limit ) {
		if ( ! wp_is_using_https() ) return $this->error( 'https_required', 403 );
		// Both endpoint and shared IP budgets prevent switching identities to evade the limit.
		foreach ( array( $action => $limit, 'all' => 100 ) as $scope => $maximum ) {
			$key = 'mobishop_native_rate_' . $this->hash( $scope . ':' . (string) ( $_SERVER['REMOTE_ADDR'] ?? 'unknown' ) );
			$count = (int) get_transient( $key );
			if ( $count >= $maximum ) return $this->error( 'rate_limited', 429 );
			set_transient( $key, $count + 1, 600 );
		}
		return null;
	}

	private function response( array $data ) {
		$response = new WP_REST_Response( $data, 200 );
		$response->header( 'Cache-Control', 'no-store, private' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}

	private function error( string $code, int $status, string $reason = '' ) {
		if ( $reason !== '' ) {
			// Aggregate only fixed reason codes, never tokens or customer data.
			$key = 'mobishop_native_auth_diagnostics';
			$counts = get_transient( $key );
			if ( ! is_array( $counts ) ) $counts = array();
			$counts[ $reason ] = array( 'count' => min( 1000000, (int) ( $counts[ $reason ]['count'] ?? 0 ) + 1 ), 'last_at' => time() );
			set_transient( $key, $counts, HOUR_IN_SECONDS );
		}
		return new WP_Error( 'mobishop_native_' . $code, __( 'Sign-in could not be completed. Please try again.', 'mobi2app-connector' ), array( 'status' => $status ) );
	}
}
