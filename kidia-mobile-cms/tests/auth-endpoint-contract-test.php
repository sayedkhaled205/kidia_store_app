<?php
/**
 * Customer authentication endpoint contract test with WordPress stubs.
 *
 * Run with: php kidia-mobile-cms/tests/auth-endpoint-contract-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'DAY_IN_SECONDS', 86400 );

$_SERVER['REMOTE_ADDR'] = '127.0.0.1';

$GLOBALS['kidia_routes']     = array();
$GLOBALS['kidia_transients'] = array();
$GLOBALS['kidia_user_meta']  = array();
$GLOBALS['kidia_social_tracker'] = '';
$GLOBALS['kidia_users']      = array(
	7 => array(
		'email'        => 'customer@example.com',
		'password'     => 'correct-password',
		'display_name' => 'Test Customer',
		'roles'        => array( 'customer' ),
	),
);

class WP_REST_Server {
	public const READABLE  = 'GET';
	public const CREATABLE = 'POST';
}

class WP_REST_Request {
	private array $params;
	private array $headers;

	public function __construct( array $params = array(), array $headers = array() ) {
		$this->params  = $params;
		$this->headers = array_change_key_case( $headers, CASE_LOWER );
	}

	public function get_param( string $key ) {
		return $this->params[ $key ] ?? null;
	}

	public function get_header( string $key ): string {
		return (string) ( $this->headers[ strtolower( $key ) ] ?? '' );
	}
}

class WP_REST_Response {
	public $data;
	public int $status;
	public array $headers = array();

	public function __construct( $data, int $status = 200 ) {
		$this->data   = $data;
		$this->status = $status;
	}

	public function header( string $name, string $value ): void {
		$this->headers[ $name ] = $value;
	}
}

class NextendSocialLogin {
	public static string $tracker_data = '';

	public static function getTrackerData(): string {
		return self::$tracker_data;
	}
}

class WP_Error {
	private string $code;
	private string $message;
	private array $data;

	public function __construct( string $code, string $message, array $data = array() ) {
		$this->code    = $code;
		$this->message = $message;
		$this->data    = $data;
	}

	public function get_error_code(): string {
		return $this->code;
	}

	public function get_error_message(): string {
		return $this->message;
	}

	public function get_error_data(): array {
		return $this->data;
	}
}

class WP_User {
	public int $ID;
	public string $user_email;
	public string $display_name;
	public array $roles;

	public function __construct( int $id, array $record ) {
		$this->ID           = $id;
		$this->user_email   = (string) $record['email'];
		$this->display_name = (string) $record['display_name'];
		$this->roles        = (array) $record['roles'];
	}
}

function add_action( string $hook, $callback, int $priority = 10, int $accepted_args = 1 ): void {
	unset( $hook, $callback, $priority, $accepted_args );
}

function add_filter( string $hook, $callback, int $priority = 10 ): void {
	unset( $hook, $callback, $priority );
}

function register_rest_route( string $namespace, string $route, array $definition ): void {
	$GLOBALS['kidia_routes'][ $namespace . $route ] = $definition;
}

function __( string $text, string $domain = '' ): string {
	unset( $domain );
	return $text;
}

function is_wp_error( $value ): bool {
	return $value instanceof WP_Error;
}

function wp_is_using_https(): bool {
	return true;
}

function sanitize_email( $value ): string {
	return strtolower( filter_var( (string) $value, FILTER_SANITIZE_EMAIL ) );
}

function is_email( $value ): bool {
	return false !== filter_var( (string) $value, FILTER_VALIDATE_EMAIL );
}

function sanitize_text_field( $value ): string {
	return trim( strip_tags( (string) $value ) );
}

function sanitize_key( $value ): string {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: '';
}

function wp_strip_all_tags( $value ): string {
	return strip_tags( (string) $value );
}

function wp_unslash( $value ) {
	return $value;
}

function wp_salt( string $scheme = 'auth' ): string {
	return 'test-salt-' . $scheme;
}

function get_transient( string $key ) {
	return $GLOBALS['kidia_transients'][ $key ] ?? false;
}

function set_transient( string $key, $value, int $expiration ): bool {
	unset( $expiration );
	$GLOBALS['kidia_transients'][ $key ] = $value;
	return true;
}

function delete_transient( string $key ): bool {
	unset( $GLOBALS['kidia_transients'][ $key ] );
	return true;
}

function shortcode_exists( string $tag ): bool {
	return 'nextend_social_login' === $tag;
}

function esc_url_raw( string $url ): string {
	return $url;
}

function rest_url( string $path = '' ): string {
	return 'https://shop.example.com/wp-json/' . ltrim( $path, '/' );
}

function add_query_arg( string $key, string $value, string $url ): string {
	$separator = str_contains( $url, '?' ) ? '&' : '?';
	return $url . $separator . rawurlencode( $key ) . '=' . rawurlencode( $value );
}

function home_url( string $path = '' ): string {
	return 'https://shop.example.com/' . ltrim( $path, '/' );
}

function wp_parse_url( string $url ) {
	return parse_url( $url );
}

function do_shortcode( string $shortcode ): string {
	preg_match( '/provider="([^"]+)"/', $shortcode, $provider );
	preg_match( '/redirect="([^"]+)"/', $shortcode, $redirect );
	preg_match( '/trackerdata="([^"]+)"/', $shortcode, $tracker );
	$GLOBALS['kidia_social_tracker'] = html_entity_decode( (string) ( $tracker[1] ?? '' ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
	$query = http_build_query(
		array(
			'loginSocial' => (string) ( $provider[1] ?? '' ),
			'redirect'    => html_entity_decode( (string) ( $redirect[1] ?? '' ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ),
			'trackerdata' => $GLOBALS['kidia_social_tracker'],
		),
		'',
		'&',
		PHP_QUERY_RFC3986
	);
	return '<a href="https://shop.example.com/wp-login.php?' . htmlspecialchars( $query, ENT_QUOTES | ENT_HTML5, 'UTF-8' ) . '">Continue</a>';
}

function email_exists( string $email ) {
	foreach ( $GLOBALS['kidia_users'] as $id => $record ) {
		if ( $record['email'] === $email ) {
			return $id;
		}
	}
	return false;
}

function get_user_by( string $field, $value ) {
	if ( 'id' === $field ) {
		$id = (int) $value;
		return isset( $GLOBALS['kidia_users'][ $id ] )
			? new WP_User( $id, $GLOBALS['kidia_users'][ $id ] )
			: false;
	}
	return false;
}

function wp_authenticate( string $email, string $password ) {
	$id = email_exists( $email );
	if ( false === $id || $GLOBALS['kidia_users'][ $id ]['password'] !== $password ) {
		return new WP_Error( 'invalid', 'Invalid credentials.' );
	}
	return get_user_by( 'id', $id );
}

function wc_create_new_customer( string $email, string $username = '', string $password = '' ) {
	unset( $username );
	if ( email_exists( $email ) ) {
		return new WP_Error( 'registration-error-email-exists', 'Email exists.' );
	}
	$id = max( array_keys( $GLOBALS['kidia_users'] ) ) + 1;
	$GLOBALS['kidia_users'][ $id ] = array(
		'email'        => $email,
		'password'     => $password,
		'display_name' => $email,
		'roles'        => array( 'customer' ),
	);
	return $id;
}

function get_user_meta( int $user_id, string $key, bool $single = false ) {
	$value = $GLOBALS['kidia_user_meta'][ $user_id ][ $key ] ?? null;
	if ( null === $value ) {
		return $single ? '' : array();
	}
	return $value;
}

function update_user_meta( int $user_id, string $key, $value ): bool {
	$GLOBALS['kidia_user_meta'][ $user_id ][ $key ] = $value;
	return true;
}

function user_can( WP_User $user, string $capability ): bool {
	unset( $user, $capability );
	return false;
}

function apply_filters( string $hook, $value, ...$args ) {
	unset( $hook, $args );
	return $value;
}

function kidia_auth_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/api/class-customer-auth-endpoint.php';

$endpoint = new Kidia_Mobile_CMS_Customer_Auth_Endpoint();
$endpoint->register_routes();
kidia_auth_assert( 8 === count( $GLOBALS['kidia_routes'] ), 'All eight auth routes must be registered.' );

$existing = $endpoint->identify( new WP_REST_Request( array( 'email' => 'customer@example.com' ) ) );
kidia_auth_assert( $existing instanceof WP_REST_Response, 'Identify must return a REST response.' );
kidia_auth_assert( 'password' === $existing->data['next'], 'Existing email must request its password.' );
kidia_auth_assert( str_contains( $existing->headers['Cache-Control'], 'no-store' ), 'Auth responses must not be cached.' );

$new = $endpoint->identify( new WP_REST_Request( array( 'email' => 'new@example.com' ) ) );
kidia_auth_assert( 'create_password' === $new->data['next'], 'New email must request password creation.' );

$login = $endpoint->login(
	new WP_REST_Request(
		array(
			'email'    => 'customer@example.com',
			'password' => 'correct-password',
		)
	)
);
kidia_auth_assert( $login instanceof WP_REST_Response, 'Valid website credentials must create a mobile session.' );
$token = (string) $login->data['token'];
kidia_auth_assert( 1 === preg_match( '/^kma1\.7\.[a-f0-9]{64}$/', $token ), 'Session token format must be opaque and strong.' );
$stored_sessions = $GLOBALS['kidia_user_meta'][7]['_kidia_mobile_customer_sessions_v1'];
kidia_auth_assert( false === str_contains( serialize( $stored_sessions ), $token ), 'Only the session hash may be stored.' );

$profile = $endpoint->current_customer(
	new WP_REST_Request( array(), array( 'X-Kidia-Session' => $token ) )
);
kidia_auth_assert( 'customer@example.com' === $profile->data['user']['email'], 'The session must resolve the Woo customer.' );

$logout = $endpoint->logout(
	new WP_REST_Request( array(), array( 'X-Kidia-Session' => $token ) )
);
kidia_auth_assert( true === $logout->data['success'], 'Logout must report success.' );
$revoked = $endpoint->authenticate_route(
	new WP_REST_Request( array(), array( 'X-Kidia-Session' => $token ) )
);
kidia_auth_assert( $revoked instanceof WP_Error, 'A logged-out token must be rejected.' );

$registered = $endpoint->register_customer(
	new WP_REST_Request(
		array(
			'email'    => 'new@example.com',
			'password' => 'new-password',
		)
	)
);
kidia_auth_assert( $registered instanceof WP_REST_Response, 'A new email and password must create a Woo customer.' );
kidia_auth_assert( false !== email_exists( 'new@example.com' ), 'The new account must exist in the shared website user table.' );

$social_state    = str_repeat( 's', 64 );
$social_verifier = str_repeat( 'v', 64 );
$social_start    = $endpoint->social_start(
	new WP_REST_Request(
		array(
			'provider' => 'google',
			'state'    => $social_state,
			'verifier' => $social_verifier,
		)
	)
);
kidia_auth_assert( $social_start instanceof WP_REST_Response, 'Google sign-in must use the configured website provider.' );
kidia_auth_assert( str_contains( $social_start->data['authorize_url'], 'loginSocial=google' ), 'The website Google provider URL must be returned.' );
kidia_auth_assert( str_starts_with( $GLOBALS['kidia_social_tracker'], 'woo-mobile:' ), 'The social flow must include a mobile tracker.' );

NextendSocialLogin::$tracker_data = $GLOBALS['kidia_social_tracker'];
$endpoint->capture_social_login( 7, 'google' );
$request_id      = substr( NextendSocialLogin::$tracker_data, strlen( 'woo-mobile:' ) );
$social_callback = $endpoint->social_callback(
	new WP_REST_Request( array( 'request_id' => $request_id ) )
);
kidia_auth_assert( $social_callback instanceof WP_REST_Response, 'A completed social login must redirect to the app.' );
kidia_auth_assert( 302 === $social_callback->status, 'The social callback must return a redirect.' );
$app_callback = parse_url( $social_callback->headers['Location'] );
kidia_auth_assert( 'kidia-store-app' === ( $app_callback['scheme'] ?? '' ), 'The callback must target the registered app scheme.' );
parse_str( (string) ( $app_callback['query'] ?? '' ), $app_query );
kidia_auth_assert( $social_state === ( $app_query['state'] ?? '' ), 'The original social state must be returned unchanged.' );

$social_exchange = $endpoint->social_exchange(
	new WP_REST_Request(
		array(
			'code'     => (string) ( $app_query['code'] ?? '' ),
			'state'    => $social_state,
			'verifier' => $social_verifier,
		)
	)
);
kidia_auth_assert( $social_exchange instanceof WP_REST_Response, 'The one-time social handoff must create a mobile session.' );
kidia_auth_assert( 'customer@example.com' === $social_exchange->data['user']['email'], 'Social login must use the same Woo customer.' );

$reused_exchange = $endpoint->social_exchange(
	new WP_REST_Request(
		array(
			'code'     => (string) ( $app_query['code'] ?? '' ),
			'state'    => $social_state,
			'verifier' => $social_verifier,
		)
	)
);
kidia_auth_assert( $reused_exchange instanceof WP_Error, 'A social handoff code must be single-use.' );

fwrite( STDOUT, "Customer auth endpoint contract test passed.\n" );
