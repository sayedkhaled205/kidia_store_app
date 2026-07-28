<?php
/**
 * Woo Mobile license activation and verification.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_License_Manager {

	private const API_BASE_URL       = 'https://api.woomobile.app/api/v1/licenses';
	private const BUILD_API_BASE_URL = 'https://api.woomobile.app/api/v1/builds';
	private const PUSH_API_BASE_URL  = 'https://api.woomobile.app/api/v1/push';
	private const STATE_OPTION       = 'kidia_mobile_license_state';
	private const INSTALLATION_OPTION = 'kidia_mobile_installation_id';
	private const CRON_HOOK          = 'kidia_mobile_verify_license';
	private const VERIFY_INTERVAL    = 3600;
	private const REQUEST_TIMEOUT    = 20;

	/**
	 * Register runtime hooks.
	 */
	public function register(): void {
		add_action( self::CRON_HOOK, array( $this, 'scheduled_verify' ) );

		$scheduled = wp_get_scheduled_event( self::CRON_HOOK );
		if ( $scheduled && 'hourly' !== $scheduled->schedule ) {
			wp_clear_scheduled_hook( self::CRON_HOOK );
			$scheduled = false;
		}

		if ( ! $scheduled ) {
			wp_schedule_event( time() + HOUR_IN_SECONDS, 'hourly', self::CRON_HOOK );
		}
	}

	/**
	 * Activate a license for this WordPress installation.
	 *
	 * @return true|WP_Error
	 */
	public function activate( string $license_key ) {
		$license_key = strtoupper( trim( $license_key ) );
		if ( '' === $license_key ) {
			return new WP_Error( 'license_key_required', __( 'Enter a license key.', 'kidia-mobile-cms' ) );
		}

		$nonce    = wp_generate_uuid4();
		$response = $this->request(
			'/activate',
			array(
				'license_key'     => $license_key,
				'installation_id' => $this->installation_id(),
				'site_url'        => home_url( '/' ),
				'plugin_version'  => KIDIA_MOBILE_CMS_VERSION,
				'nonce'           => $nonce,
			)
		);

		if ( is_wp_error( $response ) ) {
			return $response;
		}

		if ( empty( $response['activation_token'] ) || empty( $response['license_proof'] ) ) {
			return new WP_Error( 'invalid_license_response', __( 'The license server returned an incomplete response.', 'kidia-mobile-cms' ) );
		}

		$proof = $this->validate_proof( $response['license_proof'], $nonce );
		if ( is_wp_error( $proof ) ) {
			return $proof;
		}

		$this->save_state(
			array(
				'activation_token' => sanitize_text_field( (string) $response['activation_token'] ),
				'proof'            => $response['license_proof'],
				'payload'          => $proof,
				'last_verified_at' => time(),
				'last_error'       => '',
			)
		);

		return true;
	}

	/**
	 * Verify the currently stored activation.
	 *
	 * @return true|WP_Error
	 */
	public function verify( bool $force = false ) {
		$state = $this->state();
		$token = isset( $state['activation_token'] ) ? (string) $state['activation_token'] : '';
		if ( '' === $token ) {
			return new WP_Error( 'license_not_activated', __( 'No license is activated.', 'kidia-mobile-cms' ) );
		}

		$last_verified = absint( $state['last_verified_at'] ?? 0 );
		if ( ! $force && $last_verified > ( time() - self::VERIFY_INTERVAL ) ) {
			return true;
		}

		$nonce    = wp_generate_uuid4();
		$response = $this->request(
			'/verify',
			array(
				'nonce'          => $nonce,
				'plugin_version' => KIDIA_MOBILE_CMS_VERSION,
			),
			$token
		);

		if ( is_wp_error( $response ) ) {
			$state['last_error'] = $response->get_error_message();
			if ( in_array( $response->get_error_code(), array( 'license_inactive', 'license_expired', 'invalid_token', 'activation_inactive' ), true ) ) {
				$payload = is_array( $state['payload'] ?? null ) ? $state['payload'] : array();
				$license = is_array( $payload['license'] ?? null ) ? $payload['license'] : array();
				$license['status'] = 'inactive';
				$payload['license'] = $license;
				$state['payload'] = $payload;
				$state['last_verified_at'] = time();
			}
			$this->save_state( $state );
			return $response;
		}

		$proof = $this->validate_proof( $response['license_proof'] ?? array(), $nonce );
		if ( is_wp_error( $proof ) ) {
			$state['last_error'] = $proof->get_error_message();
			$this->save_state( $state );
			return $proof;
		}

		$state['proof']            = $response['license_proof'];
		$state['payload']          = $proof;
		$state['last_verified_at'] = time();
		$state['last_error']       = '';
		$this->save_state( $state );

		return true;
	}

	/**
	 * Current normalized license status for the UI and feature gates.
	 *
	 * @return array<string,mixed>
	 */
	public function status(): array {
		$state      = $this->state();
		$payload    = is_array( $state['payload'] ?? null ) ? $state['payload'] : array();
		$license    = is_array( $payload['license'] ?? null ) ? $payload['license'] : array();
		$entitlements = is_array( $license['entitlements'] ?? null ) ? $license['entitlements'] : array();
		$valid_until = isset( $payload['valid_until'] ) ? strtotime( (string) $payload['valid_until'] ) : false;
		$expires_at  = isset( $license['expires_at'] ) && null !== $license['expires_at']
			? strtotime( (string) $license['expires_at'] )
			: false;
		$active      = ! empty( $state['activation_token'] )
			&& 'active' === (string) ( $license['status'] ?? '' )
			&& false !== $valid_until
			&& $valid_until >= time()
			&& ( false === $expires_at || $expires_at >= time() );
		$payment_status = sanitize_key( (string) ( $entitlements['payment_status'] ?? 'paid' ) );
		$grace_ends_at  = ! empty( $entitlements['grace_ends_at'] )
			? strtotime( (string) $entitlements['grace_ends_at'] )
			: false;
		$grace_days_remaining = false === $grace_ends_at
			? 0
			: max( 0, (int) ceil( ( $grace_ends_at - time() ) / DAY_IN_SECONDS ) );

		return array(
			'active'           => $active,
			'status'           => $active ? 'active' : ( empty( $state['activation_token'] ) ? 'inactive' : 'verification_required' ),
			'plan'             => sanitize_key( (string) ( $license['plan'] ?? '' ) ),
			'expires_at'       => false === $expires_at ? null : $expires_at,
			'valid_until'      => false === $valid_until ? null : $valid_until,
			'last_verified_at' => absint( $state['last_verified_at'] ?? 0 ),
			'last_error'       => sanitize_text_field( (string) ( $state['last_error'] ?? '' ) ),
			'entitlements'     => $entitlements,
			'payment_status'   => $payment_status,
			'grace_ends_at'    => false === $grace_ends_at ? null : $grace_ends_at,
			'grace_days_remaining' => $grace_days_remaining,
			'signature_configured' => defined( 'KIDIA_MOBILE_LICENSE_PUBLIC_KEY' ) && '' !== (string) KIDIA_MOBILE_LICENSE_PUBLIC_KEY,
		);
	}

	public function is_active(): bool {
		return ! empty( $this->status()['active'] );
	}

	/**
	 * Sends an authenticated request to the WooMobile APK build service.
	 *
	 * The activation token never reaches the browser. Build requests reuse the
	 * same installation-bound authorization as license verification.
	 *
	 * @param string              $path   Build resource path, relative to /builds.
	 * @param string              $method HTTP method.
	 * @param array<string,mixed> $body   Optional JSON request body.
	 * @return array<string,mixed>|WP_Error
	 */
	public function build_service_request( string $path = '', string $method = 'GET', array $body = array() ) {
		$state = $this->state();
		$token = isset( $state['activation_token'] ) ? (string) $state['activation_token'] : '';
		if ( '' === $token || ! $this->is_active() ) {
			return new WP_Error( 'license_not_activated', __( 'Activate the website license before building the application.', 'kidia-mobile-cms' ) );
		}

		$path = '/' . ltrim( $path, '/' );
		if ( '/' !== $path && ! preg_match( '#^/[a-zA-Z0-9/_-]+$#', $path ) ) {
			return new WP_Error( 'invalid_build_path', __( 'The application build path is invalid.', 'kidia-mobile-cms' ) );
		}

		$method = strtoupper( $method );
		if ( ! in_array( $method, array( 'GET', 'POST' ), true ) ) {
			return new WP_Error( 'invalid_build_method', __( 'The application build request is invalid.', 'kidia-mobile-cms' ) );
		}

		$base_url = (string) apply_filters( 'kidia_mobile_build_api_base_url', self::BUILD_API_BASE_URL );
		$args     = array(
			'timeout' => 30,
			'method'  => $method,
			'headers' => array(
				'Accept'                   => 'application/json',
				'Content-Type'             => 'application/json',
				'Authorization'            => 'Bearer ' . $token,
				'X-WooMobile-Installation' => $this->installation_id(),
			),
		);
		if ( 'POST' === $method ) {
			$args['body'] = wp_json_encode( $body );
		}

		$response = wp_remote_request( untrailingslashit( $base_url ) . ( '/' === $path ? '' : $path ), $args );
		if ( is_wp_error( $response ) ) {
			return new WP_Error( 'build_service_unavailable', __( 'Could not contact the WooMobile build service. Please try again.', 'kidia-mobile-cms' ) );
		}

		$status = wp_remote_retrieve_response_code( $response );
		$data   = json_decode( wp_remote_retrieve_body( $response ), true );
		if ( $status < 200 || $status >= 300 || ! is_array( $data ) || ( isset( $data['ok'] ) && empty( $data['ok'] ) ) ) {
			$message = is_array( $data ) && isset( $data['error']['message'] )
				? sanitize_text_field( (string) $data['error']['message'] )
				: __( 'The WooMobile build service rejected the request.', 'kidia-mobile-cms' );
			$code = is_array( $data ) && isset( $data['error']['code'] )
				? sanitize_key( (string) $data['error']['code'] )
				: 'build_request_failed';
			return new WP_Error( $code ?: 'build_request_failed', $message );
		}

		return $data;
	}

	/**
	 * Sends an installation-bound request to the managed WooMobile Push service.
	 *
	 * Firebase credentials stay on the WooMobile platform. The WordPress plugin
	 * only sends a normalized notification and its selected device targets.
	 *
	 * @param string              $path   Push resource path, relative to /push.
	 * @param string              $method HTTP method.
	 * @param array<string,mixed> $body   Optional JSON request body.
	 * @return array<string,mixed>|WP_Error
	 */
	public function push_service_request( string $path = '', string $method = 'GET', array $body = array() ) {
		$state = $this->state();
		$token = isset( $state['activation_token'] ) ? (string) $state['activation_token'] : '';
		if ( '' === $token || ! $this->is_active() ) {
			return new WP_Error( 'license_not_activated', __( 'Activate the website license before using Push Notifications.', 'kidia-mobile-cms' ) );
		}

		$path = '/' . ltrim( $path, '/' );
		if ( '/' !== $path && ! preg_match( '#^/[a-zA-Z0-9/_-]+$#', $path ) ) {
			return new WP_Error( 'invalid_push_path', __( 'The Push Notifications request path is invalid.', 'kidia-mobile-cms' ) );
		}

		$method = strtoupper( $method );
		if ( ! in_array( $method, array( 'GET', 'POST' ), true ) ) {
			return new WP_Error( 'invalid_push_method', __( 'The Push Notifications request is invalid.', 'kidia-mobile-cms' ) );
		}

		$base_url = (string) apply_filters( 'kidia_mobile_push_api_base_url', self::PUSH_API_BASE_URL );
		$args     = array(
			'timeout' => 30,
			'method'  => $method,
			'headers' => array(
				'Accept'                   => 'application/json',
				'Content-Type'             => 'application/json',
				'Authorization'            => 'Bearer ' . $token,
				'X-WooMobile-Installation' => $this->installation_id(),
			),
		);
		if ( 'POST' === $method ) {
			$args['body'] = wp_json_encode( $body );
		}

		$response = wp_remote_request( untrailingslashit( $base_url ) . ( '/' === $path ? '' : $path ), $args );
		if ( is_wp_error( $response ) ) {
			return new WP_Error( 'push_service_unavailable', __( 'Could not contact the WooMobile Push service. Please try again.', 'kidia-mobile-cms' ) );
		}

		$status = wp_remote_retrieve_response_code( $response );
		$data   = json_decode( wp_remote_retrieve_body( $response ), true );
		if ( $status < 200 || $status >= 300 || ! is_array( $data ) || ( isset( $data['ok'] ) && empty( $data['ok'] ) ) ) {
			$message = is_array( $data ) && isset( $data['error']['message'] )
				? sanitize_text_field( (string) $data['error']['message'] )
				: __( 'The WooMobile Push service rejected the request.', 'kidia-mobile-cms' );
			$code = is_array( $data ) && isset( $data['error']['code'] )
				? sanitize_key( (string) $data['error']['code'] )
				: 'push_request_failed';
			return new WP_Error( $code ?: 'push_request_failed', $message );
		}

		return $data;
	}

	public function scheduled_verify(): void {
		$this->verify( true );
	}

	public static function deactivate_cron(): void {
		wp_clear_scheduled_hook( self::CRON_HOOK );
	}

	private function installation_id(): string {
		$id = (string) get_option( self::INSTALLATION_OPTION, '' );
		if ( '' === $id ) {
			$id = wp_generate_uuid4();
			add_option( self::INSTALLATION_OPTION, $id, '', false );
		}
		return $id;
	}

	/**
	 * @return array<string,mixed>
	 */
	private function state(): array {
		$state = get_option( self::STATE_OPTION, array() );
		return is_array( $state ) ? $state : array();
	}

	/**
	 * @param array<string,mixed> $state State to persist.
	 */
	private function save_state( array $state ): void {
		update_option( self::STATE_OPTION, $state, false );
	}

	/**
	 * @param array<string,mixed> $body Request body.
	 * @return array<string,mixed>|WP_Error
	 */
	private function request( string $path, array $body, string $token = '' ) {
		$headers = array(
			'Accept'       => 'application/json',
			'Content-Type' => 'application/json',
		);
		if ( '' !== $token ) {
			$headers['Authorization']             = 'Bearer ' . $token;
			$headers['X-WooMobile-Installation'] = $this->installation_id();
		}

		$response = wp_remote_post(
			self::API_BASE_URL . $path,
			array(
				'timeout' => self::REQUEST_TIMEOUT,
				'headers' => $headers,
				'body'    => wp_json_encode( $body ),
			)
		);
		if ( is_wp_error( $response ) ) {
			return new WP_Error( 'license_connection_failed', __( 'Could not contact the license server. Your last verified state remains available during the grace period.', 'kidia-mobile-cms' ) );
		}

		$status = wp_remote_retrieve_response_code( $response );
		$data   = json_decode( wp_remote_retrieve_body( $response ), true );
		if ( $status < 200 || $status >= 300 || ! is_array( $data ) || empty( $data['ok'] ) ) {
			$message = is_array( $data ) && isset( $data['error']['message'] )
				? sanitize_text_field( (string) $data['error']['message'] )
				: __( 'The license request was rejected.', 'kidia-mobile-cms' );
			$code = is_array( $data ) && isset( $data['error']['code'] )
				? sanitize_key( (string) $data['error']['code'] )
				: 'license_request_failed';
			return new WP_Error( $code ?: 'license_request_failed', $message );
		}

		return $data;
	}

	/**
	 * Decode and validate a signed license proof.
	 *
	 * The production public key is supplied via KIDIA_MOBILE_LICENSE_PUBLIC_KEY.
	 * Until it is configured, HTTPS and payload identity checks remain enforced.
	 *
	 * @param mixed  $proof Signed proof.
	 * @return array<string,mixed>|WP_Error
	 */
	private function validate_proof( $proof, string $nonce ) {
		if ( ! is_array( $proof ) || 'Ed25519' !== ( $proof['algorithm'] ?? '' ) ) {
			return new WP_Error( 'invalid_license_proof', __( 'The license proof is invalid.', 'kidia-mobile-cms' ) );
		}

		$payload_encoded = (string) ( $proof['payload'] ?? '' );
		$payload_json    = $this->base64_url_decode( $payload_encoded );
		$payload         = false === $payload_json ? null : json_decode( $payload_json, true );
		if ( ! is_array( $payload ) || ! hash_equals( $nonce, (string) ( $payload['nonce'] ?? '' ) ) ) {
			return new WP_Error( 'invalid_license_nonce', __( 'The license proof did not match this request.', 'kidia-mobile-cms' ) );
		}

		$activation = is_array( $payload['activation'] ?? null ) ? $payload['activation'] : array();
		if ( ! hash_equals( $this->installation_id(), (string) ( $activation['installation_id'] ?? '' ) ) ) {
			return new WP_Error( 'invalid_license_installation', __( 'The license proof belongs to another installation.', 'kidia-mobile-cms' ) );
		}

		$public_key = defined( 'KIDIA_MOBILE_LICENSE_PUBLIC_KEY' )
			? (string) KIDIA_MOBILE_LICENSE_PUBLIC_KEY
			: '';
		if ( '' !== $public_key ) {
			if ( ! function_exists( 'sodium_crypto_sign_verify_detached' ) ) {
				return new WP_Error( 'sodium_required', __( 'The Sodium PHP extension is required to verify the license signature.', 'kidia-mobile-cms' ) );
			}
			$signature = $this->base64_url_decode( (string) ( $proof['signature'] ?? '' ) );
			$key       = base64_decode( $public_key, true );
			if ( false === $signature || false === $key || ! sodium_crypto_sign_verify_detached( $signature, $payload_encoded, $key ) ) {
				return new WP_Error( 'invalid_license_signature', __( 'The license signature could not be verified.', 'kidia-mobile-cms' ) );
			}
		}

		return $payload;
	}

	/**
	 * @return string|false
	 */
	private function base64_url_decode( string $value ) {
		$padding = strlen( $value ) % 4;
		if ( 0 !== $padding ) {
			$value .= str_repeat( '=', 4 - $padding );
		}
		return base64_decode( strtr( $value, '-_', '+/' ), true );
	}
}
