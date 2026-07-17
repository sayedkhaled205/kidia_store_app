<?php
/**
 * Secure customer authentication for the native mobile app.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Customer_Auth_Endpoint {

	private const SESSION_META_KEY = '_kidia_mobile_customer_sessions_v1';
	private const TOKEN_PREFIX     = 'kma1';
	private const MAX_SESSIONS     = 5;
	private const SOCIAL_TTL       = 600;
	private const SOCIAL_CODE_TTL  = 180;
	private const SOCIAL_SCHEME    = 'kidia-store-app';

	/** Register REST routes and Store API customer authentication. */
	public function register(): void {
		add_action(
			'rest_api_init',
			array( $this, 'register_routes' )
		);
		add_filter(
			'determine_current_user',
			array( $this, 'determine_current_user' ),
			20
		);
		add_action(
			'nsl_login',
			array( $this, 'capture_social_login' ),
			10,
			2
		);
	}

	/** Register the progressive email/password customer flow. */
	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/auth/identify',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'identify' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'email' => $this->email_argument(),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/login',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'login' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'email'    => $this->email_argument(),
					'password' => $this->password_argument(),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/register',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'register_customer' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'email'    => $this->email_argument(),
					'password' => $this->password_argument(),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/social/start',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'social_start' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'provider' => $this->social_provider_argument(),
					'state'    => $this->social_secret_argument(),
					'verifier' => $this->social_secret_argument(),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/social/callback',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'social_callback' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'request_id' => $this->social_secret_argument(),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/social/exchange',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'social_exchange' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'code'     => $this->social_secret_argument(),
					'state'    => $this->social_secret_argument(),
					'verifier' => $this->social_secret_argument(),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/me',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'current_customer' ),
				'permission_callback' => array( $this, 'authenticate_route' ),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/auth/logout',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'logout' ),
				'permission_callback' => array( $this, 'authenticate_route' ),
			)
		);
	}

	/** Return whether the next screen should sign in or create a password. */
	public function identify( WP_REST_Request $request ) {
		$secure = $this->require_https();
		if ( is_wp_error( $secure ) ) {
			return $secure;
		}

		$email   = $this->request_email( $request );
		$limited = $this->rate_limit( 'identify-ip', '', 60, 10 * MINUTE_IN_SECONDS );
		if ( is_wp_error( $limited ) ) {
			return $limited;
		}
		$limited = $this->rate_limit( 'identify-email', $email, 8, 10 * MINUTE_IN_SECONDS );
		if ( is_wp_error( $limited ) ) {
			return $limited;
		}

		return $this->no_store_response(
			array(
				'email' => $email,
				'next'  => email_exists( $email ) ? 'password' : 'create_password',
			)
		);
	}

	/** Authenticate an existing WooCommerce customer and issue an opaque token. */
	public function login( WP_REST_Request $request ) {
		$secure = $this->require_https();
		if ( is_wp_error( $secure ) ) {
			return $secure;
		}

		$email   = $this->request_email( $request );
		$limited = $this->rate_limit( 'login', $email, 10, 15 * MINUTE_IN_SECONDS );
		if ( is_wp_error( $limited ) ) {
			return $limited;
		}

		$user = wp_authenticate(
			$email,
			(string) $request->get_param( 'password' )
		);
		if ( is_wp_error( $user ) || ! $user instanceof WP_User || ! $this->is_allowed_customer( $user ) ) {
			return new WP_Error(
				'woo_mobile_auth_invalid_credentials',
				__( 'The email address or password is incorrect.', 'kidia-mobile-cms' ),
				array( 'status' => 401 )
			);
		}

		return $this->issue_session_response( $user );
	}

	/** Create the same WooCommerce customer account used by the website. */
	public function register_customer( WP_REST_Request $request ) {
		$secure = $this->require_https();
		if ( is_wp_error( $secure ) ) {
			return $secure;
		}

		$email    = $this->request_email( $request );
		$password = (string) $request->get_param( 'password' );
		$limited  = $this->rate_limit( 'register', $email, 5, HOUR_IN_SECONDS );
		if ( is_wp_error( $limited ) ) {
			return $limited;
		}

		if ( email_exists( $email ) ) {
			return new WP_Error(
				'woo_mobile_auth_account_exists',
				__( 'An account already exists for this email address.', 'kidia-mobile-cms' ),
				array( 'status' => 409 )
			);
		}
		if ( strlen( $password ) < 8 || strlen( $password ) > 4096 ) {
			return new WP_Error(
				'woo_mobile_auth_weak_password',
				__( 'Use a password containing at least 8 characters.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}
		if ( ! function_exists( 'wc_create_new_customer' ) ) {
			return new WP_Error(
				'woo_mobile_auth_woocommerce_unavailable',
				__( 'WooCommerce customer registration is unavailable.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$user_id = wc_create_new_customer( $email, '', $password );
		if ( is_wp_error( $user_id ) ) {
			$status = 'registration-error-email-exists' === $user_id->get_error_code() ? 409 : 400;
			return new WP_Error(
				'woo_mobile_auth_registration_failed',
				wp_strip_all_tags( $user_id->get_error_message() ),
				array( 'status' => $status )
			);
		}

		$user = get_user_by( 'id', (int) $user_id );
		if ( ! $user instanceof WP_User || ! $this->is_allowed_customer( $user ) ) {
			return new WP_Error(
				'woo_mobile_auth_registration_failed',
				__( 'The customer account could not be loaded.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}

		return $this->issue_session_response( $user );
	}

	/** Start the website's Nextend Google or Facebook flow. */
	public function social_start( WP_REST_Request $request ) {
		$secure = $this->require_https();
		if ( is_wp_error( $secure ) ) {
			return $secure;
		}

		$provider = sanitize_key( (string) $request->get_param( 'provider' ) );
		$state    = trim( (string) $request->get_param( 'state' ) );
		$verifier = trim( (string) $request->get_param( 'verifier' ) );
		$limited  = $this->rate_limit( 'social-start', $provider, 20, 10 * MINUTE_IN_SECONDS );
		if ( is_wp_error( $limited ) ) {
			return $limited;
		}

		$request_id = $this->random_secret( 32 );
		if ( '' === $request_id ) {
			return new WP_Error(
				'woo_mobile_auth_social_start_failed',
				__( 'A secure social sign-in request could not be created.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}

		$callback_url = add_query_arg(
			'request_id',
			$request_id,
			rest_url( 'woo-mobile/v1/auth/social/callback' )
		);
		$authorize_url = $this->render_social_authorize_url(
			$provider,
			$callback_url,
			$request_id
		);
		if ( is_wp_error( $authorize_url ) ) {
			return $authorize_url;
		}

		set_transient(
			$this->social_key( 'request', $request_id ),
			array(
				'provider'      => $provider,
				'state'         => $state,
				'state_hash'    => $this->social_secret_hash( $state ),
				'verifier_hash' => $this->social_secret_hash( $verifier ),
				'created'       => time(),
			),
			self::SOCIAL_TTL
		);

		return $this->no_store_response(
			array(
				'authorize_url' => $authorize_url,
				'expires_in'    => self::SOCIAL_TTL,
			)
		);
	}

	/** Capture the authenticated WordPress user before Nextend redirects. */
	public function capture_social_login( $user_id, $provider = null ): void {
		if ( ! class_exists( 'NextendSocialLogin', false ) || ! is_callable( array( 'NextendSocialLogin', 'getTrackerData' ) ) ) {
			return;
		}

		$tracker = (string) NextendSocialLogin::getTrackerData();
		if ( ! preg_match( '/^woo-mobile:([A-Za-z0-9_-]{43,128})$/', $tracker, $matches ) ) {
			return;
		}

		$request_id = $matches[1];
		$request_key = $this->social_key( 'request', $request_id );
		$pending     = get_transient( $request_key );
		$user        = get_user_by( 'id', (int) $user_id );
		if ( ! is_array( $pending ) || ! $user instanceof WP_User || ! $this->is_allowed_customer( $user ) ) {
			return;
		}
		$provider_id = is_object( $provider ) && is_callable( array( $provider, 'getId' ) )
			? sanitize_key( (string) $provider->getId() )
			: ( is_string( $provider ) ? sanitize_key( $provider ) : '' );
		if ( '' !== $provider_id && $provider_id !== (string) ( $pending['provider'] ?? '' ) ) {
			return;
		}
		if ( isset( $pending['code'] ) && $this->is_social_secret( (string) $pending['code'] ) ) {
			return;
		}

		$code = $this->random_secret( 32 );
		if ( '' === $code ) {
			return;
		}

		set_transient(
			$this->social_key( 'code', $code ),
			array(
				'user_id'       => $user->ID,
				'request_id'    => $request_id,
				'state_hash'    => (string) ( $pending['state_hash'] ?? '' ),
				'verifier_hash' => (string) ( $pending['verifier_hash'] ?? '' ),
			),
			self::SOCIAL_CODE_TTL
		);
		$pending['code']    = $code;
		$pending['user_id'] = $user->ID;
		set_transient( $request_key, $pending, self::SOCIAL_CODE_TTL );
	}

	/** Redirect the completed browser flow back to the installed mobile app. */
	public function social_callback( WP_REST_Request $request ) {
		$secure = $this->require_https();
		if ( is_wp_error( $secure ) ) {
			return $secure;
		}

		$request_id = trim( (string) $request->get_param( 'request_id' ) );
		$pending    = get_transient( $this->social_key( 'request', $request_id ) );
		$code       = is_array( $pending ) ? (string) ( $pending['code'] ?? '' ) : '';
		$state      = is_array( $pending ) ? (string) ( $pending['state'] ?? '' ) : '';
		if ( ! $this->is_social_secret( $code ) || ! $this->is_social_secret( $state ) ) {
			return new WP_Error(
				'woo_mobile_auth_social_not_completed',
				__( 'Social sign-in was not completed or has expired.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}

		$app_url = sprintf(
			'%s://auth/social-callback?code=%s&state=%s',
			self::SOCIAL_SCHEME,
			rawurlencode( $code ),
			rawurlencode( $state )
		);
		$response = new WP_REST_Response( null, 302 );
		$response->header( 'Location', $app_url );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		$response->header( 'Referrer-Policy', 'no-referrer' );
		return $response;
	}

	/** Exchange the one-time browser handoff for a normal mobile session. */
	public function social_exchange( WP_REST_Request $request ) {
		$secure = $this->require_https();
		if ( is_wp_error( $secure ) ) {
			return $secure;
		}

		$code     = trim( (string) $request->get_param( 'code' ) );
		$state    = trim( (string) $request->get_param( 'state' ) );
		$verifier = trim( (string) $request->get_param( 'verifier' ) );
		$limited  = $this->rate_limit( 'social-exchange', substr( $code, 0, 16 ), 15, 10 * MINUTE_IN_SECONDS );
		if ( is_wp_error( $limited ) ) {
			return $limited;
		}

		$code_key = $this->social_key( 'code', $code );
		$handoff  = get_transient( $code_key );
		if ( ! is_array( $handoff ) ||
			! hash_equals( (string) ( $handoff['state_hash'] ?? '' ), $this->social_secret_hash( $state ) ) ||
			! hash_equals( (string) ( $handoff['verifier_hash'] ?? '' ), $this->social_secret_hash( $verifier ) ) ) {
			return new WP_Error(
				'woo_mobile_auth_social_invalid_handoff',
				__( 'The social sign-in request is invalid or expired.', 'kidia-mobile-cms' ),
				array( 'status' => 401 )
			);
		}

		$user = get_user_by( 'id', (int) ( $handoff['user_id'] ?? 0 ) );
		if ( ! $user instanceof WP_User || ! $this->is_allowed_customer( $user ) ) {
			return $this->unauthorized_error();
		}

		delete_transient( $code_key );
		$request_id = (string) ( $handoff['request_id'] ?? '' );
		if ( $this->is_social_secret( $request_id ) ) {
			delete_transient( $this->social_key( 'request', $request_id ) );
		}
		return $this->issue_session_response( $user );
	}

	/** Return the profile attached to a valid mobile session. */
	public function current_customer( WP_REST_Request $request ) {
		$user = $this->user_from_request( $request );
		if ( ! $user instanceof WP_User ) {
			return $this->unauthorized_error();
		}

		return $this->no_store_response(
			array( 'user' => $this->customer_payload( $user ) )
		);
	}

	/** Revoke only the mobile session used for this request. */
	public function logout( WP_REST_Request $request ) {
		$user  = $this->user_from_request( $request );
		$token = $this->token_from_request( $request );
		if ( ! $user instanceof WP_User || '' === $token ) {
			return $this->unauthorized_error();
		}

		$target   = $this->token_hash( $token );
		$sessions = array_values(
			array_filter(
				$this->sessions_for( $user->ID ),
				static fn( array $session ): bool => ! hash_equals( $target, (string) $session['hash'] )
			)
		);
		update_user_meta( $user->ID, self::SESSION_META_KEY, $sessions );

		return $this->no_store_response( array( 'success' => true ) );
	}

	/** Permission callback for token-protected mobile endpoints. */
	public function authenticate_route( WP_REST_Request $request ) {
		return $this->user_from_request( $request ) instanceof WP_User
			? true
			: $this->unauthorized_error();
	}

	/**
	 * Authenticate mobile tokens only for customer-facing REST namespaces.
	 *
	 * This lets Woo Store API associate checkout orders with the customer while
	 * never turning the token into a wp-admin or arbitrary REST credential.
	 *
	 * @param int|false $user_id Previously authenticated user id.
	 * @return int|false
	 */
	public function determine_current_user( $user_id ) {
		if ( ! empty( $user_id ) || ! defined( 'REST_REQUEST' ) || ! REST_REQUEST || ! $this->is_mobile_rest_request() ) {
			return $user_id;
		}

		$token = $this->token_from_server();
		$user  = $this->user_for_token( $token );
		return $user instanceof WP_User ? $user->ID : $user_id;
	}

	/** Issue a random, revocable, expiring customer session. */
	private function issue_session_response( WP_User $user ) {
		try {
			$secret = bin2hex( random_bytes( 32 ) );
		} catch ( Throwable $error ) {
			return new WP_Error(
				'woo_mobile_auth_session_failed',
				__( 'A secure customer session could not be created.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}

		$token    = self::TOKEN_PREFIX . '.' . $user->ID . '.' . $secret;
		$now      = time();
		$lifetime = (int) apply_filters(
			'kidia_mobile_auth_session_lifetime',
			30 * DAY_IN_SECONDS,
			$user
		);
		$lifetime = max( HOUR_IN_SECONDS, min( 90 * DAY_IN_SECONDS, $lifetime ) );
		$expires  = $now + $lifetime;
		$sessions = $this->sessions_for( $user->ID );
		$sessions = array_values(
			array_filter(
				$sessions,
				static fn( array $session ): bool => (int) $session['expires'] > $now
			)
		);
		$sessions = array_slice( $sessions, -( self::MAX_SESSIONS - 1 ) );
		$sessions[] = array(
			'hash'    => $this->token_hash( $token ),
			'created' => $now,
			'expires' => $expires,
		);
		update_user_meta( $user->ID, self::SESSION_META_KEY, $sessions );

		return $this->no_store_response(
			array(
				'token'      => $token,
				'expires_at' => gmdate( 'c', $expires ),
				'user'       => $this->customer_payload( $user ),
			)
		);
	}

	/** Resolve and validate a token without storing the raw value. */
	private function user_for_token( string $token ): ?WP_User {
		if ( ! preg_match( '/^' . self::TOKEN_PREFIX . '\.([1-9][0-9]*)\.([a-f0-9]{64})$/', $token, $matches ) ) {
			return null;
		}
		$user_id  = (int) $matches[1];
		$target   = $this->token_hash( $token );
		$now      = time();
		$sessions = $this->sessions_for( $user_id );
		$valid    = array();
		$matched  = false;

		foreach ( $sessions as $session ) {
			if ( (int) $session['expires'] <= $now ) {
				continue;
			}
			$valid[] = $session;
			if ( hash_equals( (string) $session['hash'], $target ) ) {
				$matched = true;
			}
		}
		if ( count( $valid ) !== count( $sessions ) ) {
			update_user_meta( $user_id, self::SESSION_META_KEY, array_values( $valid ) );
		}
		if ( ! $matched ) {
			return null;
		}

		$user = get_user_by( 'id', $user_id );
		return $user instanceof WP_User && $this->is_allowed_customer( $user )
			? $user
			: null;
	}

	/** Return normalized, non-expired session metadata. */
	private function sessions_for( int $user_id ): array {
		$stored   = get_user_meta( $user_id, self::SESSION_META_KEY, true );
		$sessions = array();
		if ( ! is_array( $stored ) ) {
			return $sessions;
		}
		foreach ( $stored as $session ) {
			if ( ! is_array( $session ) ) {
				continue;
			}
			$hash    = isset( $session['hash'] ) ? (string) $session['hash'] : '';
			$created = isset( $session['created'] ) ? (int) $session['created'] : 0;
			$expires = isset( $session['expires'] ) ? (int) $session['expires'] : 0;
			if ( ! preg_match( '/^[a-f0-9]{64}$/', $hash ) || $created <= 0 || $expires <= $created ) {
				continue;
			}
			$sessions[] = array(
				'hash'    => $hash,
				'created' => $created,
				'expires' => $expires,
			);
		}
		return array_slice( $sessions, -self::MAX_SESSIONS );
	}

	/** Keep elevated WordPress accounts out of the customer token surface. */
	private function is_allowed_customer( WP_User $user ): bool {
		// Do not call user_can() while determine_current_user is resolving a
		// mobile token. Capability filters installed by another plugin may ask
		// for the current user again, recursively re-entering this method until
		// PHP-FPM is exhausted and Nginx returns 502. WP_User has already loaded
		// its roles and primitive capabilities, so they are safe to inspect
		// directly here.
		$roles   = array_map( 'sanitize_key', (array) $user->roles );
		$allcaps = is_array( $user->allcaps ?? null ) ? $user->allcaps : array();
		if ( in_array( 'administrator', $roles, true ) ||
			in_array( 'shop_manager', $roles, true ) ||
			! empty( $allcaps['manage_options'] ) ||
			! empty( $allcaps['manage_woocommerce'] ) ) {
			return false;
		}
		$allowed_roles = (array) apply_filters(
			'kidia_mobile_auth_allowed_roles',
			array( 'customer', 'subscriber' ),
			$user
		);
		return ! empty( array_intersect( array_map( 'sanitize_key', $allowed_roles ), $roles ) );
	}

	/** Small customer profile used by the account header and future pages. */
	private function customer_payload( WP_User $user ): array {
		return array(
			'id'           => $user->ID,
			'email'        => sanitize_email( $user->user_email ),
			'display_name' => sanitize_text_field( $user->display_name ),
			'first_name'   => sanitize_text_field( (string) get_user_meta( $user->ID, 'first_name', true ) ),
			'last_name'    => sanitize_text_field( (string) get_user_meta( $user->ID, 'last_name', true ) ),
		);
	}

	/** Rate limit public auth actions without persisting raw emails or IPs. */
	private function rate_limit( string $action, string $identifier, int $limit, int $window ) {
		$address = isset( $_SERVER['REMOTE_ADDR'] )
			? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) )
			: 'unknown';
		$scope = $action . '|' . $address . '|' . strtolower( trim( $identifier ) );
		$key   = 'kidia_auth_' . substr(
			hash_hmac( 'sha256', $scope, wp_salt( 'auth' ) ),
			0,
			40
		);
		$count = (int) get_transient( $key );
		if ( $count >= $limit ) {
			return new WP_Error(
				'woo_mobile_auth_rate_limited',
				__( 'Too many attempts. Please wait and try again.', 'kidia-mobile-cms' ),
				array( 'status' => 429 )
			);
		}
		set_transient( $key, $count + 1, $window );
		return true;
	}

	/** Extract the token from a REST request. */
	private function token_from_request( WP_REST_Request $request ): string {
		$token = trim( (string) $request->get_header( 'x-kidia-session' ) );
		if ( '' !== $token ) {
			return $this->normalize_token( $token );
		}
		$authorization = trim( (string) $request->get_header( 'authorization' ) );
		return preg_match( '/^Bearer\s+(.+)$/i', $authorization, $matches )
			? $this->normalize_token( $matches[1] )
			: '';
	}

	/** Extract the same header before the REST request object is constructed. */
	private function token_from_server(): string {
		$token = isset( $_SERVER['HTTP_X_KIDIA_SESSION'] )
			? wp_unslash( $_SERVER['HTTP_X_KIDIA_SESSION'] )
			: '';
		if ( '' !== trim( (string) $token ) ) {
			return $this->normalize_token( (string) $token );
		}
		$authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
		$authorization = wp_unslash( (string) $authorization );
		return preg_match( '/^Bearer\s+(.+)$/i', trim( $authorization ), $matches )
			? $this->normalize_token( $matches[1] )
			: '';
	}

	private function normalize_token( string $token ): string {
		$token = trim( $token );
		return strlen( $token ) <= 512 && ! preg_match( '/[\x00-\x1F\x7F]/', $token )
			? $token
			: '';
	}

	private function user_from_request( WP_REST_Request $request ): ?WP_User {
		return $this->user_for_token( $this->token_from_request( $request ) );
	}

	private function token_hash( string $token ): string {
		return hash_hmac( 'sha256', $token, wp_salt( 'auth' ) );
	}

	/** Limit automatic authentication to the plugin and Store API routes. */
	private function is_mobile_rest_request(): bool {
		$route = isset( $GLOBALS['wp']->query_vars['rest_route'] )
			? (string) $GLOBALS['wp']->query_vars['rest_route']
			: '';
		if ( str_starts_with( $route, '/wc/store/' ) || str_starts_with( $route, '/woo-mobile/v1/' ) ) {
			return true;
		}
		$uri = isset( $_SERVER['REQUEST_URI'] )
			? (string) wp_unslash( $_SERVER['REQUEST_URI'] )
			: '';
		return str_contains( $uri, '/wp-json/wc/store/' ) || str_contains( $uri, '/wp-json/woo-mobile/v1/' );
	}

	/** Render Nextend's own provider URL so its configured website app is reused. */
	private function render_social_authorize_url( string $provider, string $callback_url, string $request_id ) {
		if ( ! in_array( $provider, array( 'google', 'facebook' ), true ) || ! shortcode_exists( 'nextend_social_login' ) ) {
			return new WP_Error(
				'woo_mobile_auth_social_unavailable',
				__( 'Google or Facebook sign-in is not available on this store.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$shortcode = sprintf(
			'[nextend_social_login provider="%s" redirect="%s" trackerdata="woo-mobile:%s"]',
			$provider,
			esc_url_raw( $callback_url ),
			$request_id
		);
		$html = do_shortcode( $shortcode );
		if ( ! preg_match( '/<a\b[^>]*\bhref=(["\'])(.*?)\1/i', $html, $matches ) ) {
			return new WP_Error(
				'woo_mobile_auth_social_unavailable',
				__( 'The selected social sign-in provider is not enabled.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$authorize_url = html_entity_decode( $matches[2], ENT_QUOTES | ENT_HTML5, 'UTF-8' );
		if ( str_starts_with( $authorize_url, '/' ) ) {
			$authorize_url = home_url( $authorize_url );
		}
		$target = wp_parse_url( $authorize_url );
		$home   = wp_parse_url( home_url( '/' ) );
		if ( ! is_array( $target ) || ! is_array( $home ) || ! $this->same_origin_parts( $target, $home ) ) {
			return new WP_Error(
				'woo_mobile_auth_social_invalid_url',
				__( 'The social sign-in provider returned an unsafe URL.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}

		$query = array();
		parse_str( (string) ( $target['query'] ?? '' ), $query );
		if ( $provider !== sanitize_key( (string) ( $query['loginSocial'] ?? '' ) ) ) {
			return new WP_Error(
				'woo_mobile_auth_social_invalid_url',
				__( 'The social sign-in provider returned an invalid URL.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}
		return $authorize_url;
	}

	private function same_origin_parts( array $left, array $right ): bool {
		$left_scheme  = strtolower( (string) ( $left['scheme'] ?? '' ) );
		$right_scheme = strtolower( (string) ( $right['scheme'] ?? '' ) );
		$left_host    = strtolower( (string) ( $left['host'] ?? '' ) );
		$right_host   = strtolower( (string) ( $right['host'] ?? '' ) );
		$left_port    = isset( $left['port'] ) ? (int) $left['port'] : ( 'https' === $left_scheme ? 443 : 80 );
		$right_port   = isset( $right['port'] ) ? (int) $right['port'] : ( 'https' === $right_scheme ? 443 : 80 );
		return 'https' === $left_scheme &&
			$left_scheme === $right_scheme &&
			'' !== $left_host &&
			$left_host === $right_host &&
			$left_port === $right_port;
	}

	private function random_secret( int $byte_length ): string {
		try {
			return rtrim( strtr( base64_encode( random_bytes( $byte_length ) ), '+/', '-_' ), '=' );
		} catch ( Throwable $error ) {
			return '';
		}
	}

	private function is_social_secret( string $value ): bool {
		return 1 === preg_match( '/^[A-Za-z0-9_-]{43,128}$/', $value );
	}

	private function social_secret_hash( string $value ): string {
		return hash_hmac( 'sha256', $value, wp_salt( 'auth' ) );
	}

	private function social_key( string $type, string $value ): string {
		return 'kidia_auth_social_' . sanitize_key( $type ) . '_' . substr(
			hash_hmac( 'sha256', $value, wp_salt( 'auth' ) ),
			0,
			40
		);
	}

	private function request_email( WP_REST_Request $request ): string {
		return strtolower( sanitize_email( (string) $request->get_param( 'email' ) ) );
	}

	private function email_argument(): array {
		return array(
			'required'          => true,
			'type'              => 'string',
			'sanitize_callback' => 'sanitize_email',
			'validate_callback' => static fn( $value ): bool => (bool) is_email( $value ),
		);
	}

	private function password_argument(): array {
		return array(
			'required'          => true,
			'type'              => 'string',
			'validate_callback' => static fn( $value ): bool => is_string( $value ) && strlen( $value ) >= 1 && strlen( $value ) <= 4096,
		);
	}

	private function social_provider_argument(): array {
		return array(
			'required'          => true,
			'type'              => 'string',
			'sanitize_callback' => 'sanitize_key',
			'validate_callback' => static fn( $value ): bool => in_array( sanitize_key( (string) $value ), array( 'google', 'facebook' ), true ),
		);
	}

	private function social_secret_argument(): array {
		return array(
			'required'          => true,
			'type'              => 'string',
			'validate_callback' => static fn( $value ): bool => is_string( $value ) && 1 === preg_match( '/^[A-Za-z0-9_-]{43,128}$/', $value ),
		);
	}

	private function require_https() {
		if ( function_exists( 'wp_is_using_https' ) && wp_is_using_https() ) {
			return true;
		}
		return new WP_Error(
			'woo_mobile_auth_https_required',
			__( 'Customer authentication requires HTTPS.', 'kidia-mobile-cms' ),
			array( 'status' => 503 )
		);
	}

	private function unauthorized_error(): WP_Error {
		return new WP_Error(
			'woo_mobile_auth_unauthorized',
			__( 'The customer session is missing or expired.', 'kidia-mobile-cms' ),
			array( 'status' => 401 )
		);
	}

	private function no_store_response( array $data, int $status = 200 ): WP_REST_Response {
		$response = new WP_REST_Response( $data, $status );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}
}
