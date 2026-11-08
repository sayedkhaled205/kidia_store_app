<?php
/** Native customer authentication. Provider credentials are verified on the server. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Native_Customer_Auth_Endpoint {

	private const PREFIX = '_mobishop_native_auth_';
	private const TTL = 300;
	private const FIREBASE_CERTS = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
	private const GOOGLE_CERTS = 'https://www.googleapis.com/oauth2/v1/certs';
	private const FACEBOOK_GRAPH_DEBUG_TOKEN = 'https://graph.facebook.com/debug_token';
	private const FACEBOOK_GRAPH_ME = 'https://graph.facebook.com/me';
	private const FACEBOOK_OIDC_ISSUER = 'https://www.facebook.com';
	private const FACEBOOK_OIDC_JWKS = 'https://www.facebook.com/.well-known/oauth/openid/jwks/';
	private $issue;
	private $allowed;
	private $trusted_website_phone_project;
	private $shopping_profile;

	public function __construct( callable $issue, callable $allowed, ?string $trusted_website_phone_project = null, ?callable $shopping_profile = null ) {
		$this->issue = $issue;
		$this->shopping_profile = $shopping_profile;
		$this->allowed = $allowed;
		$this->trusted_website_phone_project = $trusted_website_phone_project;
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
		foreach ( array( 'config' => 'config', 'identify' => 'identify', 'password' => 'password', 'phone/verify' => 'phone_verify', 'phone/enroll' => 'phone_enroll', 'phone/confirm' => 'phone_confirm', 'select' => 'select', 'google' => 'google', 'apple' => 'apple', 'facebook/challenge' => 'facebook_challenge', 'facebook' => 'facebook', 'register' => 'register_customer' ) as $route => $method ) {
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
		$apple = $platform === 'ios' && ! empty( $s['apple_enabled'] ) && ! empty( $s['ios_apple_native_ready'] )
			&& function_exists( 'openssl_verify' ) && preg_match( '/^[a-z][a-z0-9-]{3,62}$/', $project )
			&& ( $f['projectId'] ?? '' ) === $project && ! empty( $f['apiKey'] ) && ! empty( $f['messagingSenderId'] )
			&& ! empty( $f['iosBundleId'] ) && strpos( (string) ( $f['appId'] ?? '' ), ':ios:' ) !== false;
		$fb = $this->facebook_app( $request );
		$facebook_ready = $platform === 'ios' ? ! empty( $s['ios_facebook_native_ready'] ) : ! empty( $s['android_facebook_native_ready'] );
		$facebook_native = $enabled && ! empty( $s['facebook_native_enabled'] ) && $facebook_ready && $fb !== null && function_exists( 'openssl_verify' );
		// New-account contact enrollment remains available without an operational SMS provider.
		// It records an unverified number; it cannot authenticate an existing account.
		$registration = $enabled && $this->registration_enabled();
		return array(
			'version' => 1, 'enabled' => $enabled,
			'privacy_policy_url' => function_exists( 'get_privacy_policy_url' ) ? esc_url_raw( get_privacy_policy_url(), array( 'https' ) ) : '',
			'password_reset_url' => $this->password_reset_url(),
			'supports_unverified_phone_enrollment' => $registration,
			'supports_expected_phone_google' => $enabled && $google,
			'phone_country_code' => preg_replace( '/\D/', '', (string) ( $s['phone_country_code'] ?? '' ) ),
			'methods' => array( 'password' => $enabled, 'email_password' => $enabled, 'phone_password' => $enabled,
				'phone_otp' => $enabled && (bool) $phone, 'google' => $enabled && $google, 'apple' => $enabled && $apple,
				'facebook' => $enabled && class_exists( 'MobiShop_Website_Auth_Endpoint' ) && ( new MobiShop_Website_Auth_Endpoint( $this->issue, $this->allowed ) )->facebook_enabled(),
				'facebook_native' => $facebook_native,
				'registration' => $registration, 'email_registration' => $registration ),
			'firebase' => $enabled && ( $phone || $apple ) ? $f : null,
			'google' => $enabled && $google ? array( 'server_client_id' => $client, 'ios_client_id' => $platform === 'ios' ? $g['ios_client_id'] : null ) : null,
			'facebook' => $facebook_native ? array( 'app_id' => $fb['app_id'], 'client_token' => $fb['client_token'] ) : null,
		);
	}

	private function password_reset_url(): string {
		$url = '';
		if ( class_exists( 'Kidia_Store_Custom_Login_Page_V020' ) ) {
			$page = Kidia_Store_Custom_Login_Page_V020::instance()->get_page_id();
			if ( $page > 0 && get_permalink( $page ) ) $url = add_query_arg( 'kidia_stage', 'forgot', get_permalink( $page ) );
		}
		if ( ! $url && function_exists( 'wc_get_page_id' ) && function_exists( 'wc_get_endpoint_url' ) ) {
			$page = wc_get_page_id( 'myaccount' );
			// Avoid filtered guest account URLs that point to a custom login page.
			if ( $page > 0 && get_permalink( $page ) ) $url = wc_get_endpoint_url( 'lost-password', '', get_permalink( $page ) );
		}
		if ( ! $url && function_exists( 'wp_lostpassword_url' ) ) $url = wp_lostpassword_url();
		return $url && function_exists( 'esc_url_raw' ) ? esc_url_raw( $url, array( 'https' ) ) : '';
	}

	/** Nextend's server credentials are authoritative; native settings may only confirm, never silently diverge from, them. */
	private function facebook_provider() {
		$provider = class_exists( 'NextendSocialLogin' ) ? ( NextendSocialLogin::$providers['facebook'] ?? null ) : null;
		return is_object( $provider ) && method_exists( $provider, 'isEnabled' ) && method_exists( $provider, 'getUserIDByProviderIdentifier' )
			&& method_exists( $provider, 'linkUserToProviderIdentifier' ) && method_exists( $provider, 'removeConnectionByUserID' ) && method_exists( $provider, 'getDbID' )
			&& isset( $provider->settings ) && is_object( $provider->settings ) && method_exists( $provider->settings, 'get' ) ? $provider : null;
	}

	private function facebook_app( WP_REST_Request $request ): ?array {
		$provider = $this->facebook_provider();
		if ( ! $provider || ! $provider->isEnabled() ) return null;
		$nextend_app_id = $provider->settings->get( 'appid' );
		$nextend_secret = $provider->settings->get( 'secret' );
		if ( ! is_string( $nextend_app_id ) || ! preg_match( '/^[1-9][0-9]{0,63}$/D', $nextend_app_id )
			|| ! is_string( $nextend_secret ) || $nextend_secret === '' || strlen( $nextend_secret ) > 512 || preg_match( '/[\x00-\x20\x7f]/', $nextend_secret ) ) return null;
		$f = is_array( $this->settings()['facebook'] ?? null ) ? $this->settings()['facebook'] : array();
		$app_id = $f['app_id'] ?? '';
		// Disagreement between configured native settings and the verified Nextend app is rejected, never silently overridden.
		if ( ! is_string( $app_id ) || ( $app_id !== '' && $app_id !== $nextend_app_id ) ) return null;
		$app_secret = $f['app_secret'] ?? '';
		if ( ! is_string( $app_secret ) || ( $app_secret !== '' && ! hash_equals( $nextend_secret, $app_secret ) ) ) return null;
		$client_token = $f['client_token'] ?? '';
		if ( ! is_string( $client_token ) || ! preg_match( '/^[A-Za-z0-9_-]{1,512}$/D', $client_token ) ) return null;
		return array( 'app_id' => $nextend_app_id, 'app_secret' => $app_secret !== '' ? $app_secret : $nextend_secret, 'client_token' => $client_token );
	}

	private function client_id( $value ): bool {
		return is_string( $value ) && (bool) preg_match( '/^[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$/', $value );
	}

	public function config( WP_REST_Request $request ) {
		return $this->response( $this->capabilities( $request ) );
	}

	/** Choose sign-in or enrollment without exposing account details or issuing proof. */
	public function identify( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'identify', 60 ) ) return $error;
		$identity = $this->identity( (string) $request->get_param( 'identifier' ) );
		if ( ! $identity ) return $this->error( 'invalid_identifier', 400 );
		$c = $this->capabilities( $request );
		$requires_email_registration = false;
		if ( $identity['kind'] === 'phone' ) {
			$methods = array( 'password' );
			$users = $this->phone_users( $identity['identifier'], true );
			if ( is_wp_error( $users ) && $request->get_param( 'supports_email_password_recovery' ) === true ) {
				// A conflicting or protected identity must use its original email proof.
				$methods = array( 'email_password' );
			} elseif ( $c['methods']['phone_otp'] ) {
				// New customers have no password yet. Existing accounts retain password recovery if SMS fails.
				$methods = $users === array() ? array( 'phone_otp' ) : array( 'password', 'phone_otp' );
			} elseif ( $users === array() && $c['methods']['email_registration'] && $request->get_param( 'supports_phone_registration_recovery' ) === true ) {
				// A deleted/new phone has no password. Use the existing email enrollment when SMS is unavailable.
				$methods = array( 'email_password' );
				$requires_email_registration = true;
			}
		} else {
			// Unknown emails alone may be offered password creation; existing emails keep the login flow.
			$methods = $c['methods']['email_registration'] && ! email_exists( $identity['identifier'] ) ? array( 'create_password' ) : array( 'password' );
		}
		return $this->response( $identity + array( 'methods' => $methods, 'requires_email_registration' => $requires_email_registration ) );
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
			if ( $this->can_shop_as_owner( $user ) && strtolower( $user->user_email ) === $identity['identifier'] ) return $this->owner_session( $user, 'password' );
			if ( $user instanceof WP_User && $this->eligible( $user ) && strtolower( $user->user_email ) === $identity['identifier'] ) $matched[] = $user;
		} else {
			$candidates = $this->phone_users( $identity['identifier'], true );
			if ( is_wp_error( $candidates ) ) return $this->error( 'invalid_credentials', 401 );
			// Bound password hashing work; excessive ambiguous records require OTP.
			if ( count( $candidates ) > 20 ) return $this->error( 'invalid_credentials', 401 );
			foreach ( $candidates as $user ) {
				if ( ! wp_check_password( $password, $user->user_pass, $user->ID ) ) continue;
				$verified = wp_authenticate( $user->user_login, $password );
				if ( $verified instanceof WP_User && $verified->ID === $user->ID ) {
					$verified = get_user_by( 'id', $verified->ID );
					if ( $this->eligible( $verified ) && $this->user_phone( $verified, $identity['identifier'], true ) === $identity['identifier'] ) $matched[] = $verified;
				}
			}
		}
		if ( ! $matched ) {
			// A still-unknown email may only start enrollment: no account, password storage, or session here.
			if ( $identity['kind'] === 'email' && ! email_exists( $identity['identifier'] ) && $this->capabilities( $request )['methods']['email_registration'] ) {
				return $this->registration_ticket( array( 'kind' => 'email_registration', 'email' => $identity['identifier'] ), $request );
			}
			return $this->error( 'invalid_credentials', 401 );
		}
		// Password proof is scoped to the accounts whose own password matched.
		$versions = array();
		foreach ( $matched as $user ) $versions[ $user->ID ] = $this->hash( $user->user_pass );
		return $this->complete_proof( $matched, array( 'kind' => 'password', 'identity' => $identity, 'password_versions' => $versions ), $request );
	}

	/** Prepare an OTP attempt without asserting possession of the contact number. */
	public function phone_enroll( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'phone_enroll', 20 ) ) return $error;
		$phone = $this->phone( (string) $request->get_param( 'phone' ) );
		if ( ! $phone || ! $this->verifier( $request ) ) return $this->error( 'invalid_identifier', 400 );
		$prior = (string) $request->get_param( 'ticket' );
		$proof = array( 'kind' => 'phone_registration' );
		if ( $prior !== '' ) {
			$row = $this->read_ticket( $prior, $request );
			if ( ! $row || $row['purpose'] !== 'register' ) return $this->error( 'invalid_ticket', 401 );
			$proof = $row['proof'];
		}
		$users = $this->phone_users( $phone, true );
		if ( is_wp_error( $users ) ) return $users;
		if ( $users ) return $this->error( 'existing_phone', 409 );
		// Never relax account-completion proof for an existing account.
		if ( ! empty( $proof['user_id'] ) ) return $this->error( 'phone_proof_required', 403 );
		if ( ! $this->registration_enabled() ) return $this->error( 'registration_disabled', 403 );
		if ( $prior !== '' && ! $this->consume( $prior, $row ) ) return $this->error( 'invalid_ticket', 401 );
		unset( $proof['phone'], $proof['unverified_phone'] );
		$proof['attempted_phone'] = $phone;
		return $this->registration_ticket( $proof, $request );
	}

	/** A repeated contact number is not an authentication proof. */
	public function phone_confirm( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'phone_confirm', 10 ) ) return $error;
		$ticket = (string) $request->get_param( 'ticket' );
		$row = $this->read_ticket( $ticket, $request );
		if ( ! $row || $row['purpose'] !== 'register' ) return $this->error( 'invalid_ticket', 401 );
		$proof = $row['proof'];
		$phone = $this->phone( (string) $request->get_param( 'phone' ) );
		if ( ! $phone || ! empty( $proof['user_id'] ) || ( $proof['attempted_phone'] ?? '' ) !== $phone ) return $this->error( 'phone_mismatch', 400 );
		$users = $this->phone_users( $phone, true );
		if ( is_wp_error( $users ) ) return $users;
		if ( $users ) return $this->error( 'existing_phone', 409 );
		if ( ! $this->consume( $ticket, $row ) ) return $this->error( 'invalid_ticket', 401 );
		unset( $proof['attempted_phone'] );
		$proof['unverified_phone'] = $phone;
		return $this->registration_ticket( $proof, $request );
	}

	/** Cookie-authenticated website completion; never exposed as a REST route. */
	public function website_contact( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'website_contact', 20 ) ) return $error;
		$id = get_current_user_id();
		$user = get_user_by( 'id', $id );
		if ( ! $id || ! $this->eligible( $user ) || ! wp_verify_nonce( (string) $request->get_param( 'nonce' ), 'mobishop_website_auth' )
			|| ! get_user_meta( $id, 'kidia_phone_setup_required', true ) || ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 403 );
		$phone = $this->phone( (string) $request->get_param( 'phone' ) );
		if ( ! $phone ) return $this->error( 'invalid_identifier', 400 );
		$mode = (string) $request->get_param( 'mode' );
		$session = $this->hash( wp_get_session_token() );
		$ticket = (string) $request->get_param( 'ticket' );
		if ( $mode !== 'prepare' ) {
			$row = $this->read_ticket( $ticket, $request );
			if ( ! $row || $row['purpose'] !== 'website_contact' || ( $row['proof']['user_id'] ?? 0 ) !== $id
				|| ( $row['proof']['phone'] ?? '' ) !== $phone || ! hash_equals( $row['proof']['session'], $session ) ) return $this->error( 'invalid_ticket', 401 );
		}
		$locks = $this->lock( array( 'register:phone:' . $phone, 'register:user_id:' . $id ) );
		if ( $locks === null ) return $this->error( 'retry', 409 );
		try {
			wp_cache_delete( $id, 'user_meta' );
			if ( ! get_user_meta( $id, 'kidia_phone_setup_required', true ) ) return $this->error( 'invalid_ticket', 401 );
			$users = $this->phone_users( $phone, true );
			if ( is_wp_error( $users ) ) return $users;
			foreach ( $users as $owner ) if ( $owner->ID !== $id ) return $this->error( 'existing_phone', 409 );
			if ( $mode === 'prepare' ) {
				$token = $this->ticket( 'website_contact', array( 'user_id' => $id, 'phone' => $phone, 'session' => $session ), $request );
				return is_wp_error( $token ) ? $token : $this->response( array( 'status' => 'contact_confirmation_required', 'ticket' => $token ) );
			}
			$verified = false;
			if ( $mode === 'verify' ) {
				$c = $this->capabilities( $request );
				$claims = $this->jwt( $request->get_param( 'id_token' ), self::FIREBASE_CERTS );
				$project = $request->get_param( 'client_channel' ) === 'website' && $this->trusted_website_phone_project !== null ? $this->trusted_website_phone_project : ( $c['firebase']['projectId'] ?? '' );
				$verified = $project !== '' && $claims && ( $claims['aud'] ?? null ) === $project
					&& ( $claims['iss'] ?? null ) === 'https://securetoken.google.com/' . $project && $this->fresh( $claims, true )
					&& ( $claims['phone_number'] ?? null ) === $phone && ( $claims['firebase']['sign_in_provider'] ?? null ) === 'phone';
				if ( ! $verified ) return $this->error( 'invalid_proof', 401 );
			} elseif ( $mode !== 'confirm' ) return $this->error( 'invalid_proof', 400 );
			$collected = (bool) get_user_meta( $id, 'kidia_profile_details_collected', true );
			$name = sanitize_text_field( (string) $request->get_param( 'name' ) );
			$password = $request->get_param( 'password' );
			if ( ! $collected && ( $name === '' || strlen( $name ) > 120 || ! is_string( $password ) || strlen( $password ) < 8 || strlen( $password ) > 4096
				|| ! is_string( $request->get_param( 'confirm_password' ) ) || ! hash_equals( $password, $request->get_param( 'confirm_password' ) ) ) ) return $this->error( 'invalid_profile', 400 );
			if ( ! $verified ) foreach ( $this->phone_keys() as $key ) if ( get_user_meta( $id, $key, true ) ) return $this->error( 'account_conflict', 409 );
			if ( ! $this->consume( $ticket, $row ) ) return $this->error( 'invalid_ticket', 401 );
			if ( ! $collected ) {
				$updated = wp_update_user( array( 'ID' => $id, 'display_name' => $name, 'first_name' => $name, 'user_pass' => $password ) );
				if ( is_wp_error( $updated ) ) return $this->error( 'registration_failed', 409 );
			}
			if ( $verified ) {
				update_user_meta( $id, 'kidia_login_phone', $phone );
				update_user_meta( $id, 'fme_billing_phone', $phone );
				if ( ! get_user_meta( $id, 'billing_phone', true ) ) update_user_meta( $id, 'billing_phone', $phone );
				delete_user_meta( $id, 'kidia_unverified_phone' );
			} else {
				// A repeated number is a contact, never an OTP identity or billing fallback.
				update_user_meta( $id, 'kidia_unverified_phone', $phone );
			}
			delete_user_meta( $id, 'kidia_phone_setup_required' );
			delete_user_meta( $id, 'kidia_profile_details_collected' );
			return call_user_func( $this->issue, get_user_by( 'id', $id ) );
		} finally { $this->unlock( $locks ); }
	}

	public function phone_verify( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'phone', 20 ) ) return $error;
		$c = $this->capabilities( $request );
		$website = $request->get_param( 'client_channel' ) === 'website' && $this->trusted_website_phone_project !== null;
		if ( $website ? $this->trusted_website_phone_project === '' : ! $c['methods']['phone_otp'] ) return $this->error( 'unavailable', 503 );
		$phone = $this->phone( (string) $request->get_param( 'phone' ) );
		if ( ! $phone || ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$claims = $this->jwt( $request->get_param( 'id_token' ), self::FIREBASE_CERTS );
		$project = $website ? $this->trusted_website_phone_project : $c['firebase']['projectId'];
		if ( ! $claims || ( $claims['aud'] ?? null ) !== $project || ( $claims['iss'] ?? null ) !== 'https://securetoken.google.com/' . $project
			|| ! $this->fresh( $claims, true ) || ( $claims['phone_number'] ?? null ) !== $phone
			|| ( $claims['firebase']['sign_in_provider'] ?? null ) !== 'phone' || strlen( $claims['sub'] ) > 128 ) return $this->error( 'invalid_proof', 401 );
		$users = $this->phone_users( $phone );
		if ( is_wp_error( $users ) ) return $users;
		$identity = array( 'project' => $project, 'uid' => $claims['sub'] );
		$proof = array( 'kind' => 'phone', 'phone' => $phone, 'phone_firebase_identity' => $identity );
		$prior = (string) $request->get_param( 'ticket' );
		if ( $prior !== '' ) {
			$row = $this->read_ticket( $prior, $request );
			if ( ! $row || $row['purpose'] !== 'register' || ! $this->consume( $prior, $row ) ) return $this->error( 'invalid_ticket', 401 );
			$proof = $row['proof'];
			unset( $proof['unverified_phone'], $proof['attempted_phone'] );
			$proof['phone'] = $phone;
			$proof['phone_firebase_identity'] = $identity;
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
				$proof['kind'] = ! empty( $proof['sub'] ) ? 'google_phone' : ( ! empty( $proof['facebook_subject'] ) ? 'facebook_phone' : 'phone' );
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
		$expected_input = $request->get_param( 'expected_phone' );
		$expected_phone = $expected_input === null ? null : $this->phone( (string) $expected_input );
		if ( $expected_input !== null && ! $expected_phone ) return $this->error( 'google_phone_mismatch', 403 );
		$proof = array( 'kind' => 'google', 'sub' => $claims['sub'], 'email' => $email,
			'authoritative' => (bool) preg_match( '/@(gmail|googlemail)\.com$/', $email ) || ( is_string( $claims['hd'] ?? null ) && $claims['hd'] !== '' ) );
		if ( $expected_phone !== null ) $proof['expected_phone'] = $expected_phone;
		$linked = $this->google_user( $proof['sub'] );
		if ( $linked ) {
			$user = get_user_by( 'id', $linked );
			if ( $this->can_shop_as_owner( $user ) && $expected_phone === null ) return $this->owner_session( $user, 'google' );
			if ( ! $this->eligible( $user ) ) return $this->error( 'invalid_credentials', 401, 'google_customer_policy' );
			if ( $expected_phone !== null && ! $this->google_matches_phone( $user, $expected_phone ) ) return $this->error( 'google_phone_mismatch', 403 );
			return $this->complete_proof( array( $user ), $proof, $request );
		}
		// Google is not authoritative for arbitrary third-party email accounts.
		if ( ! $proof['authoritative'] ) return $this->error( 'additional_proof_required', 403 );
		$user = get_user_by( 'email', $email );
		if ( $user ) {
			if ( $expected_phone !== null && ! $this->google_matches_phone( $user, $expected_phone ) ) return $this->error( 'google_phone_mismatch', 403 );
			if ( $this->can_shop_as_owner( $user ) && $expected_phone === null ) return $this->owner_session( $user, 'google' );
			if ( ! $this->eligible( $user ) || ! $this->link_google( $user->ID, $proof['sub'] ) ) return $this->error( 'account_conflict', 409 );
			return $this->complete_proof( array( $user ), $proof, $request );
		}
		if ( $expected_phone !== null ) return $this->error( 'google_phone_mismatch', 403 );
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

	/** Apple/Firebase subject is a separate identity, never a Google subject or an email match. */
	public function apple( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'apple', 20 ) ) return $error;
		$c = $this->capabilities( $request );
		if ( ! $c['methods']['apple'] ) return $this->error( 'unavailable', 503 );
		if ( ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$claims = $this->jwt( $request->get_param( 'id_token' ), self::FIREBASE_CERTS );
		$project = $c['firebase']['projectId'];
		$subjects = $claims['firebase']['identities']['apple.com'] ?? null;
		if ( ! $claims || ! $this->fresh( $claims, true ) || strlen( $claims['sub'] ) > 128
			|| ( $claims['aud'] ?? null ) !== $project || ( $claims['iss'] ?? null ) !== 'https://securetoken.google.com/' . $project
			|| ( $claims['firebase']['sign_in_provider'] ?? null ) !== 'apple.com'
			|| ! is_array( $subjects ) || count( $subjects ) !== 1 || ! is_string( $subjects[0] )
			|| ! preg_match( '/^[A-Za-z0-9._-]{1,255}$/D', $subjects[0] ) ) return $this->error( 'invalid_proof', 401 );
		$proof = array( 'kind' => 'apple', 'apple_subject' => $subjects[0], 'firebase_project' => $project, 'firebase_uid' => $claims['sub'] );
		$id = $this->apple_user( $proof );
		if ( $id ) {
			$user = get_user_by( 'id', $id );
			// Apple may recreate its Firebase UID before merchant erasure finishes.
			if ( $id > 0 && class_exists( 'MobiShop_Customer_Account_Deletion' ) && MobiShop_Customer_Account_Deletion::is_pending( $id ) ) return $this->error( 'account_deletion_pending', 409 );
			return $this->proof_allows( $user, $proof ) ? $this->complete_proof( array( $user ), $proof, $request ) : $this->error( 'invalid_credentials', 401 );
		}
		if ( ( $claims['email_verified'] ?? null ) !== true || ! is_string( $claims['email'] ?? null ) || ! is_email( $claims['email'] ) ) return $this->error( 'invalid_proof', 401 );
		$proof['email'] = strtolower( $claims['email'] );
		// A matching email alone must not transfer an existing merchant account.
		if ( email_exists( $proof['email'] ) ) return $this->error( 'additional_proof_required', 403 );
		return $this->registration_ticket( $proof, $request );
	}

	/**
	 * Read-only proof check for the authenticated deletion route, never a login route.
	 * The caller supplies its authenticated customer ID (not a request-body ID) and
	 * owns identity serialization. A true result does not confirm Apple revocation.
	 */
	public function validate_deletion_apple_proof( WP_REST_Request $request, int $captured_user_id ) {
		if ( $captured_user_id <= 0 ) return $this->error( 'invalid_proof', 401 );
		if ( ! class_exists( 'MobiShop_Customer_Identity_Links' ) ) return $this->error( 'unavailable', 503 );
		try {
			$c = $this->capabilities( $request );
			if ( ! $c['methods']['apple'] ) return $this->error( 'unavailable', 503 );
			$claims = $this->jwt( $request->get_param( 'id_token' ), self::FIREBASE_CERTS );
			$project = $c['firebase']['projectId'];
			$subjects = $claims['firebase']['identities']['apple.com'] ?? null;
			if ( ! $claims || ! $this->fresh( $claims, true ) || strlen( $claims['sub'] ) > 128
				|| ( $claims['aud'] ?? null ) !== $project || ( $claims['iss'] ?? null ) !== 'https://securetoken.google.com/' . $project
				|| ( $claims['firebase']['sign_in_provider'] ?? null ) !== 'apple.com'
				|| ! is_array( $subjects ) || array_keys( $subjects ) !== array( 0 )
				|| ! is_string( $subjects[0] ) || ! preg_match( '/^[A-Za-z0-9._-]{1,255}$/D', $subjects[0] ) ) {
				return $this->error( 'invalid_proof', 401 );
			}
			$user = get_user_by( 'id', $captured_user_id );
			if ( ! $this->eligible( $user ) ) return $this->error( 'invalid_proof', 401 );
			// Reject partial or duplicate bindings instead of trusting the first row.
			foreach ( array( '_mobishop_firebase_project' => $project, '_mobishop_firebase_uid' => $claims['sub'], '_mobishop_apple_subject' => $subjects[0] ) as $key => $expected ) {
				if ( get_user_meta( $captured_user_id, $key, false ) !== array( $expected ) ) return $this->error( 'invalid_proof', 401 );
			}
			$link = array( 'project' => $project, 'uid' => $claims['sub'], 'provider' => 'apple' );
			if ( MobiShop_Customer_Identity_Links::shared( $captured_user_id, $link ) !== false ) return $this->error( 'invalid_proof', 401 );
			return true;
		} catch ( Throwable $error ) {
			return $this->error( 'invalid_proof', 401 );
		}
	}

	private function apple_key( array $proof ): string {
		return hash( 'sha256', $proof['firebase_project'] . '|' . $proof['apple_subject'] );
	}
	private function apple_user( array $proof ): int {
		$ids = get_users( array( 'meta_key' => '_mobishop_apple_identity', 'meta_value' => $this->apple_key( $proof ), 'fields' => 'ID', 'number' => 2 ) );
		return count( $ids ) > 1 ? -1 : ( count( $ids ) === 1 ? (int) $ids[0] : 0 );
	}
	private function register_apple( array $row, string $ticket, WP_REST_Request $request ) {
		$p = $row['proof'];
		$c = $this->capabilities( $request );
		if ( ! $c['methods']['apple'] || ! $this->registration_enabled() || $c['firebase']['projectId'] !== $p['firebase_project'] ) return $this->error( 'registration_disabled', 403 );
		$name = sanitize_text_field( (string) $request->get_param( 'name' ) );
		if ( $name === '' || strlen( $name ) > 120 ) return $this->error( 'invalid_profile', 400 );
		$locks = $this->lock( array( 'apple-link:' . $this->apple_key( $p ), 'register:email:' . $p['email'] ) );
		if ( $locks === null ) return $this->error( 'retry', 409 );
		try {
			if ( $this->apple_user( $p ) || email_exists( $p['email'] ) ) return $this->error( 'account_conflict', 409 );
			if ( ! $this->consume( $ticket, $row ) ) return $this->error( 'invalid_ticket', 401 );
			$create = function () use ( $p, $name ) {
				$id = wp_insert_user( array( 'user_login' => 'mobile_' . bin2hex( random_bytes( 12 ) ), 'user_email' => $p['email'],
					'user_pass' => wp_generate_password( 64, true, true ), 'display_name' => $name, 'first_name' => $name, 'role' => 'customer' ) );
				if ( is_wp_error( $id ) ) return $this->error( 'registration_failed', 409 );
				update_user_meta( $id, '_mobishop_apple_identity', $this->apple_key( $p ) );
				update_user_meta( $id, '_mobishop_apple_subject', $p['apple_subject'] );
				update_user_meta( $id, '_mobishop_firebase_project', $p['firebase_project'] );
				update_user_meta( $id, '_mobishop_firebase_uid', $p['firebase_uid'] );
				update_user_meta( $id, '_mobishop_app_registered_at', gmdate( 'c' ) );
				// Apple proves the account; shipping contact details belong at checkout.
				delete_user_meta( $id, 'kidia_phone_setup_required' );
				$user = get_user_by( 'id', (int) $id );
				if ( ! $this->proof_allows( $user, $p ) || get_user_meta( $id, '_mobishop_apple_subject', true ) !== $p['apple_subject'] ) {
					// Only roll back the customer created above, still under both locks.
					// A partial identity write must not reserve this email forever.
					if ( ! function_exists( 'wp_delete_user' ) ) require_once ABSPATH . 'wp-admin/includes/user.php';
					wp_delete_user( (int) $id, 0 );
					return $this->error( 'registration_failed', 503 );
				}
				return $user;
			};
			try {
				if ( class_exists( 'MobiShop_Customer_Identity_Guard' ) ) {
					$user = MobiShop_Customer_Identity_Guard::new_identity( array( 'project' => $p['firebase_project'], 'uid' => $p['firebase_uid'] ), $create );
				} elseif ( defined( 'MOBISHOP_ACCOUNT_DELETION_ENABLED' ) && MOBISHOP_ACCOUNT_DELETION_ENABLED === true ) {
					return $this->error( 'identity_link_failed', 503 );
				} else { $user = $create(); }
			} catch ( Throwable $error ) { return $this->error( 'identity_link_failed', 503 ); }
			if ( is_wp_error( $user ) ) return $user;
			return $this->finish( $user, $p, $request );
		} finally { $this->unlock( $locks ); }
	}

	/** A server-random nonce bound to this platform/app is required before any provider proof is accepted. */
	public function facebook_challenge( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'facebook_challenge', 30 ) ) return $error;
		$platform = $this->platform( $request );
		$c = $this->capabilities( $request );
		if ( ! $c['methods']['facebook_native'] ) return $this->error( 'unavailable', 503 );
		if ( ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$fb = $this->facebook_app( $request );
		if ( ! $fb ) return $this->error( 'unavailable', 503 );
		$nonce = bin2hex( random_bytes( 32 ) );
		$ticket = $this->ticket( 'facebook_challenge', array( 'nonce' => $nonce, 'platform' => $platform, 'app_id' => $fb['app_id'] ), $request );
		if ( is_wp_error( $ticket ) ) return $ticket;
		return $this->response( array( 'ticket' => $ticket, 'nonce' => $nonce, 'expires_in' => self::TTL ) );
	}

	/** Classic Meta login or iOS Limited Login; the challenge ticket is consumed before either proof is trusted. */
	public function facebook( WP_REST_Request $request ) {
		if ( $error = $this->guard( 'facebook', 20 ) ) return $error;
		$platform = $this->platform( $request );
		$c = $this->capabilities( $request );
		if ( ! $c['methods']['facebook_native'] ) return $this->error( 'unavailable', 503 );
		if ( ! $this->verifier( $request ) ) return $this->error( 'invalid_proof', 401 );
		$fb = $this->facebook_app( $request );
		if ( ! $fb ) return $this->error( 'unavailable', 503 );
		$access_token = $request->get_param( 'access_token' );
		$id_token = $request->get_param( 'id_token' );
		$has_access = $access_token !== null;
		$has_id = $id_token !== null;
		// Exactly one proof kind is accepted; both present or both missing is rejected.
		if ( $has_access === $has_id ) return $this->error( 'invalid_proof', 400 );
		if ( $has_id && $platform !== 'ios' ) return $this->error( 'invalid_proof', 401 );
		$challenge = (string) $request->get_param( 'ticket' );
		$row = $this->read_ticket( $challenge, $request );
		if ( ! $row || $row['purpose'] !== 'facebook_challenge' || $row['proof']['platform'] !== $platform || $row['proof']['app_id'] !== $fb['app_id'] ) return $this->error( 'invalid_ticket', 401 );
		$nonce = (string) $row['proof']['nonce'];
		// A failed exchange after this point always requires a fresh challenge.
		if ( ! $this->consume( $challenge, $row ) ) return $this->error( 'invalid_ticket', 401 );
		$email = null;
		if ( $has_access ) {
			$profile = $this->facebook_classic_subject( $access_token, $fb );
			if ( ! $profile ) return $this->error( 'invalid_proof', 401 );
			$subject = $profile['subject'];
			$email = $profile['email'];
		} else {
			$subject = $this->facebook_limited_subject( $id_token, $fb, $nonce );
			if ( ! $subject ) return $this->error( 'invalid_proof', 401 );
		}
		$proof = array( 'kind' => 'facebook', 'facebook_subject' => $subject, 'facebook_app_id' => $fb['app_id'] );
		if ( is_string( $email ) && $email !== '' ) $proof['email'] = $email;
		$linked = $this->facebook_user( $subject, $fb['app_id'] );
		if ( $linked === -1 ) return $this->error( 'account_conflict', 409 );
		if ( $linked ) {
			$user = get_user_by( 'id', $linked );
			if ( $this->can_shop_as_owner( $user ) ) return $this->owner_session( $user, 'facebook' );
			return $this->proof_allows( $user, $proof ) ? $this->complete_proof( array( $user ), $proof, $request ) : $this->error( 'invalid_credentials', 401 );
		}
		// Facebook is never authoritative for an arbitrary existing email: no auto-link.
		return $this->registration_ticket( $proof, $request );
	}

	private function facebook_key( string $app_id, string $subject ): string {
		return hash( 'sha256', $app_id . '|' . $subject );
	}

	/** Corroborates the Nextend mapping with scoped local metadata; disagreement fails closed rather than guessing. */
	private function facebook_user( string $subject, string $app_id ): int {
		global $wpdb;
		$provider = $this->facebook_provider();
		if ( ! $provider || ! $provider->isEnabled() || $provider->settings->get( 'appid' ) !== $app_id ) return -1;
		// Nextend's single-row lookup hides duplicate legacy or concurrent website mappings.
		$rows = $wpdb->get_col( $wpdb->prepare( "SELECT ID FROM {$wpdb->prefix}social_users WHERE type=%s AND identifier=%s LIMIT 2", $provider->getDbID(), $subject ) );
		if ( ! is_array( $rows ) || count( $rows ) > 1 || $wpdb->last_error !== '' ) return -1;
		$remote = (int) $provider->getUserIDByProviderIdentifier( $subject );
		if ( $remote !== ( count( $rows ) === 1 ? (int) $rows[0] : 0 ) ) return -1;
		$ids = get_users( array( 'meta_key' => '_mobishop_facebook_identity', 'meta_value' => $this->facebook_key( $app_id, $subject ), 'fields' => 'ID', 'number' => 2 ) );
		if ( count( $ids ) > 1 ) return -1;
		$local = count( $ids ) === 1 ? (int) $ids[0] : 0;
		if ( $remote && $local && $remote !== $local ) return -1;
		$marker = $remote ? get_user_meta( $remote, '_mobishop_facebook_identity', true ) : '';
		if ( $marker && $marker !== $this->facebook_key( $app_id, $subject ) ) return -1;
		return $remote;
	}

	private function link_facebook( int $id, string $subject, string $app_id, bool $subject_locked = false ): bool {
		$identities = array( 'facebook-link:user:' . $app_id . ':' . $id );
		if ( ! $subject_locked ) $identities[] = 'facebook-link:sub:' . $app_id . ':' . $subject;
		$locks = $this->lock( $identities );
		if ( $locks === null ) return false;
		try {
			wp_cache_delete( $id, 'users' );
			wp_cache_delete( $id, 'user_meta' );
			if ( ! $this->eligible( get_user_by( 'id', $id ) ) ) return false;
			$existing = $this->facebook_user( $subject, $app_id );
			if ( $existing ) return $existing === $id;
			$old = get_user_meta( $id, '_mobishop_facebook_identity', true );
			if ( $old && $old !== $this->facebook_key( $app_id, $subject ) ) return false;
			$provider = $this->facebook_provider();
			if ( ! $provider || ! $provider->linkUserToProviderIdentifier( $id, $subject ) || $this->facebook_user( $subject, $app_id ) !== $id ) return false;
			update_user_meta( $id, '_mobishop_facebook_identity', $this->facebook_key( $app_id, $subject ) );
			update_user_meta( $id, '_mobishop_facebook_app_id', $app_id );
			return get_user_meta( $id, '_mobishop_facebook_identity', true ) === $this->facebook_key( $app_id, $subject )
				&& get_user_meta( $id, '_mobishop_facebook_app_id', true ) === $app_id && $this->facebook_user( $subject, $app_id ) === $id;
		} finally { $this->unlock( $locks ); }
	}

	/** Bounded nonempty token; only fixed trusted Graph URLs, server app credentials, and appsecret_proof are used. */
	private function facebook_classic_subject( $token, array $fb ): ?array {
		if ( ! is_string( $token ) || $token === '' || strlen( $token ) > 4096 || preg_match( '/[\x00-\x20\x7f]/', $token ) ) return null;
		$app_token = $fb['app_id'] . '|' . $fb['app_secret'];
		$debug_url = self::FACEBOOK_GRAPH_DEBUG_TOKEN . '?' . http_build_query( array( 'input_token' => $token ) );
		$response = wp_remote_get( $debug_url, array( 'headers' => array( 'Authorization' => 'Bearer ' . $app_token ), 'timeout' => 10, 'redirection' => 0, 'sslverify' => true, 'limit_response_size' => 65536 ) );
		if ( is_wp_error( $response ) || wp_remote_retrieve_response_code( $response ) !== 200 ) return null;
		$body = json_decode( wp_remote_retrieve_body( $response ), true );
		$data = is_array( $body ) ? ( $body['data'] ?? null ) : null;
		if ( ! is_array( $data ) || ( $data['is_valid'] ?? null ) !== true || ( $data['type'] ?? null ) !== 'USER' || ( $data['app_id'] ?? null ) !== $fb['app_id'] ) return null;
		$now = time();
		if ( ! is_int( $data['expires_at'] ?? null ) || $data['expires_at'] <= $now ) return null;
		if ( isset( $data['data_access_expires_at'] ) && ( ! is_int( $data['data_access_expires_at'] ) || $data['data_access_expires_at'] <= $now ) ) return null;
		$subject = $data['user_id'] ?? null;
		if ( ! is_string( $subject ) && ! is_int( $subject ) ) return null;
		$subject = (string) $subject;
		if ( $subject === '' || strlen( $subject ) > 64 || ! preg_match( '/^[1-9][0-9]*$/D', $subject ) ) return null;
		$proof = hash_hmac( 'sha256', $token, $fb['app_secret'] );
		$me_url = self::FACEBOOK_GRAPH_ME . '?' . http_build_query( array( 'fields' => 'id,email', 'appsecret_proof' => $proof ) );
		$me_response = wp_remote_get( $me_url, array( 'headers' => array( 'Authorization' => 'Bearer ' . $token ), 'timeout' => 10, 'redirection' => 0, 'sslverify' => true, 'limit_response_size' => 65536 ) );
		if ( is_wp_error( $me_response ) || wp_remote_retrieve_response_code( $me_response ) !== 200 ) return null;
		$me = json_decode( wp_remote_retrieve_body( $me_response ), true );
		if ( ! is_array( $me ) || ! isset( $me['id'] ) || (string) $me['id'] !== $subject ) return null;
		$email = is_string( $me['email'] ?? null ) && is_email( $me['email'] ) ? strtolower( $me['email'] ) : null;
		return array( 'subject' => $subject, 'email' => $email );
	}

	/** iOS Limited Login: a fixed-issuer RS256 JWT, never treated as a Graph access token. */
	private function facebook_limited_subject( $token, array $fb, string $nonce ): ?string {
		$claims = $this->facebook_jwt( $token );
		if ( ! $claims ) return null;
		$now = time();
		if ( ( $claims['iss'] ?? null ) !== self::FACEBOOK_OIDC_ISSUER || ( $claims['aud'] ?? null ) !== $fb['app_id'] ) return null;
		if ( ! is_int( $claims['exp'] ?? null ) || $claims['exp'] <= $now ) return null;
		if ( ! is_int( $claims['iat'] ?? null ) || $claims['iat'] > $now + 30 || $claims['iat'] < $now - 600 || $claims['iat'] >= $claims['exp'] ) return null;
		if ( isset( $claims['nbf'] ) && ( ! is_int( $claims['nbf'] ) || $claims['nbf'] > $now + 30 ) ) return null;
		if ( ! is_string( $claims['nonce'] ?? null ) || ! hash_equals( $nonce, $claims['nonce'] ) ) return null;
		$subject = $claims['sub'] ?? null;
		if ( ! is_string( $subject ) && ! is_int( $subject ) ) return null;
		$subject = (string) $subject;
		return $subject !== '' && strlen( $subject ) <= 64 && preg_match( '/^[1-9][0-9]*$/D', $subject ) ? $subject : null;
	}

	/** Independent RS256 verification against the fixed Meta OpenID JWKS; key material is JWK, not an x509 cert. */
	private function facebook_jwt( $token ): ?array {
		if ( ! is_string( $token ) || strlen( $token ) > 10000 ) return null;
		$parts = explode( '.', $token );
		if ( count( $parts ) !== 3 ) return null;
		$header = json_decode( (string) $this->decode( $parts[0] ), true );
		$claims = json_decode( (string) $this->decode( $parts[1] ), true );
		$sig = $this->decode( $parts[2] );
		if ( ! is_array( $header ) || ! is_array( $claims ) || $sig === false || ( $header['alg'] ?? null ) !== 'RS256'
			|| ! is_string( $header['kid'] ?? null ) || $header['kid'] === '' || strlen( $header['kid'] ) > 256 || ! empty( $header['crit'] ) || ! empty( $header['jku'] ) ) return null;
		$key = 'mobishop_native_facebook_certs';
		$certs = get_transient( $key );
		$refresh_key = $key . '_refresh';
		if ( ! is_array( $certs ) && get_transient( $refresh_key ) ) return null;
		if ( ! is_array( $certs ) || ( ! isset( $certs[ $header['kid'] ] ) && ! get_transient( $refresh_key ) ) ) {
			set_transient( $refresh_key, 1, 60 );
			$response = wp_remote_get( self::FACEBOOK_OIDC_JWKS, array( 'timeout' => 10, 'redirection' => 0, 'sslverify' => true, 'limit_response_size' => 65536 ) );
			if ( is_wp_error( $response ) || wp_remote_retrieve_response_code( $response ) !== 200 ) return null;
			$body = json_decode( wp_remote_retrieve_body( $response ), true );
			$keys = is_array( $body ) ? ( $body['keys'] ?? null ) : null;
			if ( ! is_array( $keys ) || count( $keys ) > 20 ) return null;
			$certs = array();
			$seen = array();
			foreach ( $keys as $jwk ) {
				if ( is_array( $jwk ) && is_string( $jwk['kid'] ?? null ) ) {
					if ( isset( $seen[ $jwk['kid'] ] ) ) return null;
					$seen[ $jwk['kid'] ] = true;
				}
				if ( ! is_array( $jwk ) || ( $jwk['kty'] ?? null ) !== 'RSA' || ( $jwk['use'] ?? 'sig' ) !== 'sig' || ( $jwk['alg'] ?? 'RS256' ) !== 'RS256'
					|| ( isset( $jwk['key_ops'] ) && ( ! is_array( $jwk['key_ops'] ) || ! in_array( 'verify', $jwk['key_ops'], true ) ) )
					|| ! is_string( $jwk['kid'] ?? null ) || $jwk['kid'] === '' || strlen( $jwk['kid'] ) > 256 || ! is_string( $jwk['n'] ?? null ) || ! is_string( $jwk['e'] ?? null ) ) continue;
				$pem = $this->rsa_jwk_to_pem( $jwk['n'], $jwk['e'] );
				if ( $pem !== null ) $certs[ $jwk['kid'] ] = $pem;
			}
			if ( ! $certs ) return null;
			set_transient( $key, $certs, 300 );
		}
		$cert = $certs[ $header['kid'] ] ?? null;
		if ( ! is_string( $cert ) || openssl_verify( $parts[0] . '.' . $parts[1], $sig, $cert, OPENSSL_ALGO_SHA256 ) !== 1 ) return null;
		return $claims;
	}

	/** Minimal RSA JWK (n, e) to a DER SubjectPublicKeyInfo PEM; no external dependency. */
	private function rsa_jwk_to_pem( string $n, string $e ): ?string {
		$modulus = $this->decode( $n );
		$exponent = $this->decode( $e );
		if ( $modulus === false || $exponent === false || strlen( $modulus ) < 256 || strlen( $modulus ) > 1024 || $exponent === '' || strlen( $exponent ) > 8 || !( ord( $exponent[strlen( $exponent ) - 1] ) & 1 ) ) return null;
		$sequence = $this->asn1_sequence( $this->asn1_integer( $modulus ) . $this->asn1_integer( $exponent ) );
		$algorithm = "\x30\x0d\x06\x09\x2a\x86\x48\x86\xf7\x0d\x01\x01\x01\x05\x00";
		$bit_string = "\x03" . $this->asn1_length( strlen( $sequence ) + 1 ) . "\x00" . $sequence;
		$spki = $this->asn1_sequence( $algorithm . $bit_string );
		return "-----BEGIN PUBLIC KEY-----\n" . chunk_split( base64_encode( $spki ), 64, "\n" ) . "-----END PUBLIC KEY-----\n";
	}

	private function asn1_integer( string $value ): string {
		if ( $value !== '' && ( ord( $value[0] ) & 0x80 ) ) $value = "\x00" . $value;
		return "\x02" . $this->asn1_length( strlen( $value ) ) . $value;
	}

	private function asn1_sequence( string $value ): string {
		return "\x30" . $this->asn1_length( strlen( $value ) ) . $value;
	}

	private function asn1_length( int $length ): string {
		if ( $length < 0x80 ) return chr( $length );
		$bytes = '';
		while ( $length > 0 ) { $bytes = chr( $length & 0xff ) . $bytes; $length >>= 8; }
		return chr( 0x80 | strlen( $bytes ) ) . $bytes;
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
		if ( class_exists( 'MobiShop_Customer_Account_Deletion' ) && MobiShop_Customer_Account_Deletion::is_pending( $user->ID ) ) return $this->error( 'account_deletion_pending', 409 );
		if ( in_array( $proof['kind'], array( 'facebook', 'facebook_phone' ), true )
			&& ( ! $this->capabilities( $request )['methods']['facebook_native'] || ! $this->proof_allows( $user, $proof ) ) ) return $this->error( 'invalid_proof', 401 );
		if ( ! empty( $proof['expected_phone'] ) && ! $this->google_matches_phone( $user, $proof['expected_phone'] ) ) return $this->error( 'google_phone_mismatch', 403 );
		if ( $proof['kind'] === 'google_phone' && $this->google_user( $proof['sub'] ) !== $user->ID && ! $this->link_google( $user->ID, $proof['sub'] ) ) return $this->error( 'account_conflict', 409 );
		if ( $proof['kind'] === 'facebook_phone' && $this->facebook_user( $proof['facebook_subject'], $proof['facebook_app_id'] ) !== $user->ID && ! $this->link_facebook( $user->ID, $proof['facebook_subject'], $proof['facebook_app_id'] ) ) return $this->error( 'account_conflict', 409 );
		if ( in_array( $proof['kind'], array( 'facebook', 'facebook_phone' ), true ) ) {
			wp_cache_delete( $user->ID, 'users' );
			wp_cache_delete( $user->ID, 'user_meta' );
			$user = get_user_by( 'id', $user->ID );
			if ( ! $this->proof_allows( $user, $proof ) || $this->facebook_user( $proof['facebook_subject'], $proof['facebook_app_id'] ) !== $user->ID ) return $this->error( 'invalid_proof', 401 );
		}
		if ( $proof['kind'] !== 'apple' && ! $this->ready( $user ) ) {
			$proof['user_id'] = (int) $user->ID;
			return $this->registration_ticket( $proof, $request );
		}
		// Only the selected, fully authenticated account receives this verified OTP identity.
		if ( ! $this->persist_phone_identity( $user->ID, $proof ) ) return $this->error( 'identity_link_failed', 503 );
		$result = call_user_func( $this->issue, $user );
		if ( $result instanceof WP_REST_Response ) {
			if ( $result->get_status() < 300 && $request->get_param( 'client_channel' ) !== 'website' ) {
				update_user_meta( $user->ID, '_mobishop_app_last_login_at', gmdate( 'c' ) );
				update_user_meta( $user->ID, '_mobishop_app_last_auth_method', sanitize_key( $proof['kind'] ) );
			}
			$result->set_data( array( 'status' => 'authenticated' ) + $result->get_data() );
			$result->header( 'Cache-Control', 'no-store, private' );
		}
		return $result;
	}

	/** Append-only per identity: concurrent different UIDs never replace each other or Apple metadata. */
	private function persist_phone_identity( int $user_id, array $proof ): bool {
		if ( ! isset( $proof['phone_firebase_identity'] ) ) return true;
		$identity = $proof['phone_firebase_identity'];
		if ( ! is_array( $identity ) || ! is_string( $identity['project'] ?? null ) || $identity['project'] === ''
			|| ! is_string( $identity['uid'] ?? null ) || $identity['uid'] === '' || strlen( $identity['uid'] ) > 128 ) return false;
		$key = '_mobishop_phone_firebase_identity_' . hash( 'sha256', $identity['project'] . '|' . $identity['uid'] );
		$value = array( 'project' => $identity['project'], 'uid' => $identity['uid'] );
		$write = static function () use ( $user_id, $key, $value ): bool {
			// WordPress returns false for an unchanged value too; read back the stored value.
			update_user_meta( $user_id, $key, $value );
			wp_cache_delete( $user_id, 'user_meta' );
			return get_user_meta( $user_id, $key, true ) === $value;
		};
		try {
			if ( class_exists( 'MobiShop_Customer_Identity_Guard' ) ) return MobiShop_Customer_Identity_Guard::writer( $user_id, $identity, $write, static function () use ( $user_id, $key, $value ): bool {
				wp_cache_delete( $user_id, 'user_meta' );
				return get_user_meta( $user_id, $key, false ) === array( $value );
			} );
			if ( defined( 'MOBISHOP_ACCOUNT_DELETION_ENABLED' ) && MOBISHOP_ACCOUNT_DELETION_ENABLED === true ) return false;
			return $write();
		} catch ( Throwable $error ) { return false; }
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
		$fields = $proof['kind'] === 'apple' ? array( 'name' ) : array( 'name', 'password' );
		// Email-originated registrations always require a verified phone, even if require_phone is globally off.
		if ( $proof['kind'] !== 'apple' && empty( $proof['phone'] ) && empty( $proof['unverified_phone'] ) ) $fields[] = 'phone';
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
		if ( $p['kind'] === 'apple' ) return $this->register_apple( $row, $ticket, $request );
		$is_facebook = in_array( $p['kind'], array( 'facebook', 'facebook_phone' ), true );
		if ( $is_facebook && ( ! $this->capabilities( $request )['methods']['facebook_native'] || ( $this->facebook_app( $request )['app_id'] ?? '' ) !== $p['facebook_app_id'] ) ) return $this->error( 'unavailable', 503 );
		$name = sanitize_text_field( (string) $request->get_param( 'name' ) );
		$password = $request->get_param( 'password' );
		$email = strtolower( trim( (string) $request->get_param( 'email' ) ) );
		if ( $name === '' || strlen( $name ) > 120 || ! is_string( $password ) || strlen( $password ) < 8 || strlen( $password ) > 4096
			|| ( $email !== '' && $email !== ( $p['email'] ?? '' ) ) ) return $this->error( 'invalid_profile', 400 );
		if ( empty( $p['phone'] ) && empty( $p['unverified_phone'] ) ) return $this->error( 'phone_proof_required', 403 );
		$user = ! empty( $p['user_id'] ) ? get_user_by( 'id', (int) $p['user_id'] ) : null;
		if ( ! empty( $p['user_id'] ) && ! $this->proof_allows( $user, $p ) ) return $this->error( 'invalid_proof', 401 );
		if ( ! $user && ! $this->registration_enabled() ) return $this->error( 'registration_disabled', 403 );
		// Serialize registrations for the verified identity, including parallel tickets.
		$identities = array();
		foreach ( array( 'phone', 'email', 'user_id' ) as $field ) if ( ! empty( $p[ $field ] ) ) $identities[] = 'register:' . $field . ':' . $p[ $field ];
		if ( ! empty( $p['unverified_phone'] ) ) $identities[] = 'register:phone:' . $p['unverified_phone'];
		if ( ! empty( $p['sub'] ) ) $identities[] = 'google-link:sub:' . $p['sub'];
		if ( $is_facebook ) $identities[] = 'facebook-link:sub:' . $p['facebook_app_id'] . ':' . $p['facebook_subject'];
		$locks = $this->lock( $identities );
		if ( $locks === null ) return $this->error( 'retry', 409 );
		try {
			if ( ! empty( $p['user_id'] ) ) {
				// Completion may have changed while this request acquired its identity leases.
				wp_cache_delete( (int) $p['user_id'], 'users' );
				wp_cache_delete( (int) $p['user_id'], 'user_meta' );
				$user = get_user_by( 'id', (int) $p['user_id'] );
				if ( ! $this->proof_allows( $user, $p ) || $this->ready( $user ) ) return $this->error( 'invalid_ticket', 401 );
			}
			if ( ! empty( $p['unverified_phone'] ) ) {
				if ( $user ) return $this->error( 'invalid_proof', 401 );
				$existing = $this->phone_users( $p['unverified_phone'], true );
				if ( is_wp_error( $existing ) ) return $existing;
				if ( $existing ) return $this->error( 'existing_phone', 409 );
			}
			if ( ! empty( $p['phone'] ) ) {
				$existing_users = $this->phone_users( $p['phone'] );
				if ( is_wp_error( $existing_users ) ) return $existing_users;
				$retains_phone = $user && $this->user_phone( $user, $p['phone'] ) === $p['phone'];
				foreach ( $existing_users as $existing ) if ( ! $user || ( $existing->ID !== $user->ID && ! $retains_phone ) ) return $this->error( 'account_conflict', 409 );
			}
			if ( ! $user && ! empty( $p['email'] ) && email_exists( $p['email'] ) ) return $this->error( 'account_conflict', 409 );
			if ( ! empty( $p['sub'] ) && $this->google_user( $p['sub'] ) && ( ! $user || $this->google_user( $p['sub'] ) !== $user->ID ) ) return $this->error( 'account_conflict', 409 );
			if ( $is_facebook ) {
				$linked = $this->facebook_user( $p['facebook_subject'], $p['facebook_app_id'] );
				if ( $linked && ( ! $user || $linked !== $user->ID ) ) return $this->error( 'account_conflict', 409 );
			}
			if ( ! $this->consume( $ticket, $row ) ) return $this->error( 'invalid_ticket', 401 );
			$is_new_account = ! $user;
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
			if ( $is_facebook && ! $this->link_facebook( $user->ID, $p['facebook_subject'], $p['facebook_app_id'], true ) ) {
				// This ID was created by this request under its subject/email/phone leases.
				if ( $is_new_account ) {
					$provider = $this->facebook_provider();
					if ( $provider ) $provider->removeConnectionByUserID( $user->ID );
					if ( ! function_exists( 'wp_delete_user' ) ) require_once ABSPATH . 'wp-admin/includes/user.php';
					wp_delete_user( $user->ID, 0 );
				}
				return $this->error( 'account_conflict', 409 );
			}
			if ( ! empty( $p['unverified_phone'] ) ) update_user_meta( $user->ID, 'kidia_unverified_phone', $p['unverified_phone'] );
			if ( ! empty( $p['phone'] ) ) {
				update_user_meta( $user->ID, 'kidia_login_phone', $p['phone'] );
				update_user_meta( $user->ID, 'fme_billing_phone', $p['phone'] );
				if ( ! get_user_meta( $user->ID, 'billing_phone', true ) ) update_user_meta( $user->ID, 'billing_phone', $p['phone'] );
			}
			if ( ! empty( $p['sub'] ) && ! $this->link_google( $user->ID, $p['sub'], true ) ) return $this->error( 'account_conflict', 409 );
			if ( $is_new_account && $request->get_param( 'client_channel' ) !== 'website' ) update_user_meta( $user->ID, '_mobishop_app_registered_at', gmdate( 'c' ) );
			delete_user_meta( $user->ID, 'kidia_phone_setup_required' );
			do_action( 'mobishop_native_auth_profile_completed', $user->ID, $p['kind'] );
			return $this->finish( get_user_by( 'id', $user->ID ), $p, $request );
		} finally {
			$this->unlock( $locks );
		}
	}

	/** Google proves this account; a contact claim cannot override a verified owner. */
	private function google_matches_phone( WP_User $user, string $phone ): bool {
		$owners = $this->phone_users( $phone );
		if ( is_wp_error( $owners ) ) return false;
		if ( $owners ) return in_array( (int) $user->ID, array_map( static fn( $owner ) => (int) $owner->ID, $owners ), true );
		return $this->user_phone( $user, $phone, true ) === $phone;
	}

	private function can_shop_as_owner( $user ): bool {
		return $this->shopping_profile !== null && MobiShop_Storefront_Admin::accepts( $user );
	}

	private function owner_session( WP_User $owner, string $method ) {
		$customer = ( $this->shopping_profile )( $owner );
		if ( is_wp_error( $customer ) ) return $customer;
		if ( ! $this->eligible( $customer ) || $customer->ID === $owner->ID ) return $this->error( 'invalid_credentials', 401 );
		$result = ( $this->issue )( $customer );
		if ( $result instanceof WP_REST_Response && $result->get_status() < 300 ) {
			$result->set_data( array( 'status' => 'authenticated' ) + $result->get_data() );
			update_user_meta( $customer->ID, '_mobishop_app_last_login_at', gmdate( 'c' ) );
			update_user_meta( $customer->ID, '_mobishop_app_last_auth_method', $method );
		}
		return $result;
	}

	private function eligible( $user ): bool {
		return $user instanceof WP_User && empty( $user->allcaps['edit_users'] ) && (bool) call_user_func( $this->allowed, $user );
	}

	private function proof_allows( $user, array $p ): bool {
		if ( ! $this->eligible( $user ) ) return false;
		if ( ! empty( $p['user_id'] ) && (int) $p['user_id'] !== $user->ID ) return false;
		if ( in_array( $p['kind'], array( 'facebook', 'facebook_phone' ), true ) ) {
			$linked = $this->facebook_user( $p['facebook_subject'], $p['facebook_app_id'] );
			if ( $p['kind'] === 'facebook' ) return $linked === $user->ID;
			if ( ! empty( $p['user_id'] ) && $linked !== $user->ID ) return false;
			return ( $linked === 0 || $linked === $user->ID ) && $this->user_phone( $user, $p['phone'] ) === $p['phone'];
		}
		if ( in_array( $p['kind'], array( 'phone', 'google_phone' ), true ) ) return $this->user_phone( $user, $p['phone'] ) === $p['phone'];
		if ( $p['kind'] === 'google' ) return $this->google_user( $p['sub'] ) === $user->ID;
		if ( $p['kind'] === 'apple' ) return $this->apple_user( $p ) === $user->ID
			&& get_user_meta( $user->ID, '_mobishop_firebase_project', true ) === $p['firebase_project']
			&& get_user_meta( $user->ID, '_mobishop_firebase_uid', true ) === $p['firebase_uid'];
		return in_array( (int) $user->ID, $p['ids'] ?? array(), true )
			&& hash_equals( (string) ( $p['password_versions'][ $user->ID ] ?? '' ), $this->hash( $user->user_pass ) )
			&& ( $p['identity']['kind'] === 'phone' ? $this->user_phone( $user, $p['identity']['identifier'], true ) === $p['identity']['identifier'] : strtolower( $user->user_email ) === $p['identity']['identifier'] );
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

	private function user_phone( WP_User $user, string $expected, bool $include_unverified = false ): string {
		// Contact-only accounts never gain an OTP identity from a later checkout.
		$contact = (string) get_user_meta( $user->ID, 'kidia_unverified_phone', true );
		// The first stored identity is authoritative: shipping metadata cannot override it.
		foreach ( array_merge( $this->phone_keys(), $include_unverified ? array( 'kidia_unverified_phone' ) : array() ) as $key ) {
			if ( in_array( $key, array( 'fme_billing_phone', 'billing_phone' ), true ) && $contact !== '' ) continue;
			$value = (string) get_user_meta( $user->ID, $key, true );
			if ( $value !== '' ) {
				// Older providers also store E.164 without the leading plus.
				if ( $this->phone_input( $value ) === ltrim( $expected, '+' ) ) return $expected;
				return $this->phone( $value );
			}
		}
		return '';
	}

	private function phone_users( string $phone, bool $include_unverified = false ) {
		$values = array( $phone, ltrim( $phone, '+' ), '00' . ltrim( $phone, '+' ) );
		$country = preg_replace( '/\D/', '', (string) ( $this->settings()['phone_country_code'] ?? '' ) );
		if ( $country && strpos( $phone, '+' . $country ) === 0 ) {
			$local = substr( $phone, strlen( $country ) + 1 );
			$values[] = $local; $values[] = '0' . $local;
		}
		$pattern = $this->phone_lookup_pattern( $values );
		$keys = array_merge( $this->phone_keys(), $include_unverified ? array( 'kidia_unverified_phone' ) : array() );
		$users = $this->phone_candidates( $keys, $pattern );
		if ( count( $users ) > 50 ) return $this->error( 'phone_account_conflict', 409 );
		if ( ! $include_unverified ) $users = array_values( array_filter( $users, fn( $user ) => ! get_user_meta( $user->ID, 'kidia_unverified_phone', true ) || $this->user_phone( $user, $phone ) !== '' ) );
		$eligible = array_values( array_filter( $users, fn( $user ) => $this->eligible( $user ) && $this->user_phone( $user, $phone, $include_unverified ) === $phone ) );
		return $users && ! $eligible ? $this->error( 'phone_account_conflict', 409 ) : $eligible;
	}

	/** Keep the 51-user limit and WordPress filters, without multiplying metadata joins. */
	private function phone_candidates( array $keys, string $pattern ): array {
		global $wpdb;
		$keys = array_values( array_unique( array_map( 'strval', $keys ) ) );
		if ( ! $keys ) return array();
		$spec = array( 'keys' => $keys, 'pattern' => $pattern );
		$placeholders = implode( ',', array_fill( 0, count( $keys ), '%s' ) );
		$predicate = $wpdb->prepare(
			"EXISTS (SELECT 1 FROM {$wpdb->usermeta} AS mobishop_phone_meta
			LEFT JOIN {$wpdb->usermeta} AS mobishop_contact_meta
			ON mobishop_contact_meta.user_id = mobishop_phone_meta.user_id AND mobishop_contact_meta.meta_key = 'kidia_unverified_phone'
			WHERE mobishop_phone_meta.user_id = {$wpdb->users}.ID
			AND mobishop_phone_meta.meta_key IN ($placeholders) AND mobishop_phone_meta.meta_value REGEXP %s
			AND (mobishop_phone_meta.meta_key NOT IN ('fme_billing_phone','billing_phone')
			OR mobishop_contact_meta.user_id IS NULL OR mobishop_contact_meta.meta_value = ''))",
			array_merge( $keys, array( $pattern ) )
		);
		$filter = static function( $query ) use ( $spec, $predicate ): void {
			if ( ( $query->query_vars['mobishop_native_phone_lookup'] ?? null ) === $spec ) {
				$query->query_where .= ' AND ' . $predicate;
			}
		};
		add_action( 'pre_user_query', $filter );
		try {
			return get_users( array( 'mobishop_native_phone_lookup' => $spec, 'number' => 51, 'orderby' => 'ID', 'order' => 'ASC' ) );
		} finally {
			remove_action( 'pre_user_query', $filter );
		}
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
		$ip = filter_var( wp_unslash( $_SERVER['REMOTE_ADDR'] ?? '' ), FILTER_VALIDATE_IP );
		// Both endpoint and shared IP budgets prevent switching identities to evade the limit.
		foreach ( array( $action => $limit, 'all' => 100 ) as $scope => $maximum ) {
			$key = 'mobishop_native_rate_' . $this->hash( $scope . ':' . ( $ip !== false ? $ip : 'unknown' ) );
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
