<?php
/**
 * Native customer authentication security contract, isolated from WordPress.
 *
 * Run: php -d extension=openssl connectors/woocommerce/tests/native-auth-contract-test.php
 * Set MOBISHOP_CONNECTOR_TEST_ROOT to exercise a packaged connector source tree.
 * All keys, credentials, identities and option stores below are temporary fixtures.
 */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'DAY_IN_SECONDS', 86400 );
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';

$GLOBALS['native_routes'] = array();
$GLOBALS['native_hooks'] = array();
$GLOBALS['native_options'] = array();
$GLOBALS['native_transients'] = array();
$GLOBALS['native_meta'] = array();
$GLOBALS['native_http'] = array();
$GLOBALS['native_auth_calls'] = array();
$GLOBALS['native_issued'] = array();
$GLOBALS['native_created'] = array();
$GLOBALS['native_checks'] = 0;
$GLOBALS['native_https'] = true;
$GLOBALS['native_users'] = array(
    7 => array( 'login' => 'customer-seven', 'email' => 'customer@gmail.com', 'password' => 'password-seven', 'name' => 'Customer Seven', 'roles' => array( 'customer' ) ),
    8 => array( 'login' => 'store-manager', 'email' => 'manager@gmail.com', 'password' => 'password-manager', 'name' => 'Store Manager', 'roles' => array( 'customer', 'shop_manager' ), 'allcaps' => array( 'manage_woocommerce' => true ) ),
    9 => array( 'login' => 'customer-nine', 'email' => 'other@gmail.com', 'password' => 'password-nine', 'name' => 'Customer Nine', 'roles' => array( 'customer' ) ),
    10 => array( 'login' => 'user-editor', 'email' => 'editor@gmail.com', 'password' => 'password-editor', 'name' => 'User Editor', 'roles' => array( 'customer' ), 'allcaps' => array( 'edit_users' => true ) ),
    11 => array( 'login' => 'other-phone', 'email' => 'different@gmail.com', 'password' => 'password-eleven', 'name' => 'Different Phone', 'roles' => array( 'customer' ) ),
    12 => array( 'login' => 'shipping-only', 'email' => 'shipping@gmail.com', 'password' => 'password-twelve', 'name' => 'Shipping Phone', 'roles' => array( 'customer' ) ),
);
$GLOBALS['native_meta'] = array(
    7 => array( 'kidia_login_phone' => '+201012345678', 'billing_phone' => '01012345678' ),
    8 => array( 'kidia_login_phone' => '+201012345678' ),
    9 => array( 'kidia_login_phone' => '+201012345678' ),
    10 => array( 'kidia_login_phone' => '+201012345678' ),
    11 => array( 'kidia_login_phone' => '+201112345678' ),
    12 => array( 'kidia_login_phone' => '+201112345678', 'billing_phone' => '+201012345678' ),
);

class WP_REST_Server {
    public const READABLE = 'GET';
    public const CREATABLE = 'POST';
}
class WP_REST_Request {
    private array $params;
    public function __construct( array $params = array() ) { $this->params = $params; }
    public function get_param( $name ) { return $this->params[$name] ?? null; }
    public function get_header( $name ) { return ''; }
    public function get_json_params() { return $this->params; }
    public function get_params() { return $this->params; }
}
class WP_REST_Response {
    public $data;
    public int $status;
    public array $headers = array();
    public function __construct( $data, $status = 200 ) { $this->data = $data; $this->status = $status; }
    public function header( $key, $value ) { $this->headers[$key] = $value; }
    public function get_data() { return $this->data; }
    public function set_data( $data ) { $this->data = $data; }
    public function get_status() { return $this->status; }
}
class WP_Error {
    private $code;
    private $message;
    private $data;
    public function __construct( $code, $message = '', $data = array() ) { $this->code = $code; $this->message = $message; $this->data = $data; }
    public function get_error_code() { return $this->code; }
    public function get_error_message() { return $this->message; }
    public function get_error_data() { return $this->data; }
}
class WP_User {
    public int $ID;
    public string $user_login;
    public string $user_email;
    public string $user_pass;
    public string $display_name;
    public string $user_registered = '2024-01-15 12:00:00';
    public array $roles;
    public array $allcaps;
    public function __construct( $id, $record = null ) {
        $record ??= $GLOBALS['native_users'][(int) $id] ?? array();
        $this->ID = (int) $id;
        $this->user_login = (string) ( $record['login'] ?? '' );
        $this->user_email = (string) ( $record['email'] ?? '' );
        $this->user_pass = (string) ( $record['password_hash'] ?? ( 'fixture-hash:' . (string) ( $record['password'] ?? '' ) ) );
        $this->display_name = (string) ( $record['name'] ?? '' );
        $this->roles = $record['roles'] ?? array();
        $this->allcaps = $record['allcaps'] ?? array();
    }
    public function exists() { return isset( $GLOBALS['native_users'][$this->ID] ); }
}

function __( $text, $domain = '' ) { return $text; }
function __return_true() { return true; }
function is_wp_error( $value ) { return $value instanceof WP_Error; }
function add_action( $hook, $callback, $priority = 10, $accepted = 1 ) { $GLOBALS['native_hooks'][$hook][] = $callback; }
function add_filter( $hook, $callback, $priority = 10, $accepted = 1 ) {}
function apply_filters( $hook, $value, ...$args ) { return $value; }
function do_action( $hook, ...$args ) { foreach ( $GLOBALS['native_hooks'][$hook] ?? array() as $callback ) $callback( ...$args ); }
function register_rest_route( $namespace, $route, $definition ) { $GLOBALS['native_routes'][$namespace . $route] = $definition; }
function wp_is_using_https() { return $GLOBALS['native_https']; }
function is_ssl() { return $GLOBALS['native_https']; }
function home_url( $path = '' ) { return 'https://shop.example.test/' . ltrim( $path, '/' ); }
function wp_parse_url( $url, $component = -1 ) { return parse_url( $url, $component ); }
function sanitize_text_field( $value ) { return trim( strip_tags( (string) $value ) ); }
function sanitize_email( $value ) { return strtolower( filter_var( (string) $value, FILTER_SANITIZE_EMAIL ) ); }
function sanitize_key( $value ) { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_user( $value, $strict = false ) { return preg_replace( '/[^A-Za-z0-9_.@\-]/', '', (string) $value ); }
function is_email( $value ) { return false !== filter_var( (string) $value, FILTER_VALIDATE_EMAIL ); }
function absint( $value ) { return abs( (int) $value ); }
function wp_strip_all_tags( $value ) { return strip_tags( (string) $value ); }
function wp_unslash( $value ) { return $value; }
function wp_json_encode( $value, $flags = 0 ) { return json_encode( $value, $flags ); }
function wp_salt( $scheme = 'auth' ) { return 'native-contract-test-salt-' . $scheme; }
function wp_hash( $value, $scheme = 'auth', $algorithm = 'md5' ) { return hash_hmac( $algorithm, $value, wp_salt( $scheme ) ); }
function wp_generate_password( $length = 12, $special = true, $extra = false ) { return substr( bin2hex( random_bytes( $length ) ), 0, $length ); }
function mysql2date( $format, $date, $translate = true ) { return date( $format, strtotime( $date ) ); }
function get_option( $key, $default = false ) { return $GLOBALS['native_options'][$key] ?? $default; }
function add_option( $key, $value = '', $deprecated = '', $autoload = null ) {
    if ( array_key_exists( $key, $GLOBALS['native_options'] ) ) return false;
    $GLOBALS['native_options'][$key] = $value;
    return true;
}
function update_option( $key, $value, $autoload = null ) { $GLOBALS['native_options'][$key] = $value; return true; }
function delete_option( $key ) { unset( $GLOBALS['native_options'][$key] ); return true; }
function get_transient( $key ) {
    $row = $GLOBALS['native_transients'][$key] ?? null;
    if ( ! is_array( $row ) || ( $row['expires'] && $row['expires'] <= time() ) ) return false;
    return $row['value'];
}
function set_transient( $key, $value, $ttl = 0 ) { $GLOBALS['native_transients'][$key] = array( 'value' => $value, 'expires' => $ttl ? time() + $ttl : 0 ); return true; }
function delete_transient( $key ) { unset( $GLOBALS['native_transients'][$key] ); return true; }
function maybe_serialize( $value ) { return is_array( $value ) || is_object( $value ) ? serialize( $value ) : $value; }
function wp_cache_delete( $key, $group = '' ) {}
function wp_schedule_single_event( $timestamp, $hook, $args = array() ) { return true; }
function get_user_meta( $id, $key = '', $single = false ) { $value = $GLOBALS['native_meta'][(int) $id][$key] ?? null; return $value === null ? ( $single ? '' : array() ) : $value; }
function update_user_meta( $id, $key, $value ) { $GLOBALS['native_meta'][(int) $id][$key] = $value; return true; }
function delete_user_meta( $id, $key, $value = '' ) { unset( $GLOBALS['native_meta'][(int) $id][$key] ); return true; }
function get_userdata( $id ) { return get_user_by( 'id', $id ); }
function get_user_by( $field, $value ) {
    foreach ( $GLOBALS['native_users'] as $id => $record ) {
        if ( ( in_array( $field, array( 'id', 'ID' ), true ) && $id === (int) $value )
            || ( $field === 'email' && strcasecmp( $record['email'], (string) $value ) === 0 )
            || ( $field === 'login' && $record['login'] === $value ) ) return new WP_User( $id, $record );
    }
    return false;
}
function email_exists( $email ) { $user = get_user_by( 'email', $email ); return $user ? $user->ID : false; }
function username_exists( $login ) { $user = get_user_by( 'login', $login ); return $user ? $user->ID : false; }
function native_meta_matches( $id, $query ) {
    if ( isset( $query['key'] ) ) {
        $value = get_user_meta( $id, $query['key'], true );
        if ( ( $query['compare'] ?? '=' ) === 'REGEXP' ) return preg_match( '~' . $query['value'] . '~uD', (string) $value ) === 1;
        return ( $query['compare'] ?? '=' ) === 'IN' ? in_array( $value, (array) $query['value'], true ) : $value === $query['value'];
    }
    $results = array();
    foreach ( $query as $key => $clause ) if ( $key !== 'relation' && is_array( $clause ) ) $results[] = native_meta_matches( $id, $clause );
    return strtoupper( $query['relation'] ?? 'AND' ) === 'OR' ? in_array( true, $results, true ) : ! in_array( false, $results, true );
}
function get_users( $args = array() ) {
    $result = array();
    foreach ( $GLOBALS['native_users'] as $id => $record ) {
        if ( isset( $args['include'] ) && ! in_array( $id, $args['include'], true ) ) continue;
        if ( isset( $args['meta_query'] ) && ! native_meta_matches( $id, $args['meta_query'] ) ) continue;
        if ( isset( $args['meta_key'] ) && get_user_meta( $id, $args['meta_key'], true ) !== ( $args['meta_value'] ?? '' ) ) continue;
        $result[] = ( $args['fields'] ?? '' ) === 'ID' ? $id : new WP_User( $id, $record );
    }
    return ! empty( $args['number'] ) && $args['number'] > 0 ? array_slice( $result, 0, (int) $args['number'] ) : $result;
}
function user_can( $user, $capability ) {
    throw new RuntimeException( 'Native customer role checks must not recurse through user_can().' );
}
function wp_check_password( $password, $hash, $user_id = '' ) { return hash_equals( 'fixture-hash:' . $password, $hash ) || hash_equals( 'fixture-rehashed:' . $password, $hash ); }
function wp_authenticate( $login, $password ) {
    $GLOBALS['native_auth_calls'][] = $login;
    $user = get_user_by( 'login', $login ) ?: get_user_by( 'email', $login );
    if ( ! $user || ! wp_check_password( $password, $user->user_pass, $user->ID ) ) return new WP_Error( 'invalid', 'Invalid credentials.', array( 'status' => 403 ) );
    if ( isset( $GLOBALS['native_after_authenticate_hook'] ) ) {
        $hook = $GLOBALS['native_after_authenticate_hook'];
        unset( $GLOBALS['native_after_authenticate_hook'] );
        $hook( $user );
    }
    return isset( $GLOBALS['native_auth_override'] ) ? get_user_by( 'id', $GLOBALS['native_auth_override'] ) : $user;
}
function wp_insert_user( $data ) {
    if ( username_exists( $data['user_login'] ?? '' ) || ( ! empty( $data['user_email'] ) && email_exists( $data['user_email'] ) ) ) return new WP_Error( 'existing_user', 'Account already exists.' );
    if ( isset( $GLOBALS['native_before_insert_hook'] ) ) {
        $hook = $GLOBALS['native_before_insert_hook'];
        unset( $GLOBALS['native_before_insert_hook'] );
        $hook();
    }
    $id = max( array_keys( $GLOBALS['native_users'] ) ) + 1;
    $GLOBALS['native_users'][$id] = array( 'login' => (string) $data['user_login'], 'email' => (string) ( $data['user_email'] ?? '' ), 'password' => (string) ( $data['user_pass'] ?? '' ), 'name' => (string) ( $data['display_name'] ?? '' ), 'roles' => array( $data['role'] ?? 'customer' ) );
    $GLOBALS['native_created'][] = $id;
    return $id;
}
function wc_create_new_customer( $email, $username = '', $password = '', $args = array() ) {
    return wp_insert_user( array_merge( array( 'user_login' => $username ?: $email, 'user_email' => $email, 'user_pass' => $password, 'role' => 'customer' ), $args ) );
}
function wp_update_user( $data ) {
    $id = (int) $data['ID'];
    if ( ! isset( $GLOBALS['native_users'][$id] ) ) return new WP_Error( 'unknown_user' );
    foreach ( array( 'display_name' => 'name', 'user_email' => 'email', 'user_pass' => 'password' ) as $wp => $fixture ) if ( isset( $data[$wp] ) ) $GLOBALS['native_users'][$id][$fixture] = $data[$wp];
    return $id;
}
function wp_remote_get( $url, $args = array() ) {
    $GLOBALS['native_http'][] = array( 'url' => $url, 'args' => $args );
    if ( ! in_array( $url, array( 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com', 'https://www.googleapis.com/oauth2/v1/certs' ), true ) ) throw new RuntimeException( 'Untrusted signing key URL: ' . $url );
    return array( 'response' => array( 'code' => 200 ), 'headers' => array( 'cache-control' => 'public,max-age=3600' ), 'body' => json_encode( array( 'fixture-kid' => $GLOBALS['native_public_key'] ) ) );
}
function wp_remote_retrieve_response_code( $response ) { return $response['response']['code']; }
function wp_remote_retrieve_body( $response ) { return $response['body']; }
function wp_remote_retrieve_header( $response, $key ) { return $response['headers'][$key] ?? ''; }

$wpdb = new class {
    public $options = 'wp_options';
    public $prefix = 'wp_';
    public $race = false;
    public function prepare( $sql, ...$args ) { return array( $sql, $args ); }
    public function query( $prepared ) {
        if ( $this->race ) { $this->race = false; return 0; }
        list( $sql, $args ) = $prepared;
        if ( str_starts_with( ltrim( $sql ), 'DELETE' ) ) {
            list( $key, $old ) = $args;
            if ( ! array_key_exists( $key, $GLOBALS['native_options'] ) || maybe_serialize( $GLOBALS['native_options'][$key] ) !== $old ) return 0;
            unset( $GLOBALS['native_options'][$key] );
            return 1;
        }
        if ( str_starts_with( ltrim( $sql ), 'UPDATE' ) ) {
            list( $next, $key, $old ) = $args;
            if ( ! array_key_exists( $key, $GLOBALS['native_options'] ) || maybe_serialize( $GLOBALS['native_options'][$key] ) !== $old ) return 0;
            $GLOBALS['native_options'][$key] = unserialize( $next );
            return 1;
        }
        throw new RuntimeException( 'Unexpected SQL in isolated auth test.' );
    }
};
class Native_Test_Google_Provider {
    public array $links = array( 'google-seven' => 7, 'google-manager' => 8 );
    public bool $enabled = true;
    public function isEnabled() { return $this->enabled; }
    public function getUserIDByProviderIdentifier( $subject ) { return $this->links[$subject] ?? false; }
    public function linkUserToProviderIdentifier( $id, $subject ) {
        if ( isset( $GLOBALS['native_google_link_hook'] ) ) {
            $hook = $GLOBALS['native_google_link_hook'];
            unset( $GLOBALS['native_google_link_hook'] );
            $hook( $id, $subject );
        }
        $this->links[$subject] = (int) $id;
        return true;
    }
    public function getDbID() { return 'google'; }
}
class NextendSocialLogin { public static $providers = array(); }
NextendSocialLogin::$providers['google'] = new Native_Test_Google_Provider();

function native_assert( $condition, $label ) {
    if ( ! $condition ) throw new RuntimeException( $label );
    $GLOBALS['native_checks']++;
}
function native_data( $result, $label ) {
    native_assert( $result instanceof WP_REST_Response, $label . ' returns a response' . ( is_wp_error( $result ) ? ': ' . $result->get_error_code() : '' ) );
    return $result->data;
}
function native_rejected( $result, $label ) { native_assert( is_wp_error( $result ), $label ); }
function native_clear_rate() { $GLOBALS['native_transients'] = array(); }
function native_request( array $params ) { return new WP_REST_Request( $params ); }
function native_b64( $value ) { return rtrim( strtr( base64_encode( $value ), '+/', '-_' ), '=' ); }
function native_jwt( array $claims, array $header = array() ) {
    $header = array_merge( array( 'alg' => 'RS256', 'kid' => 'fixture-kid', 'typ' => 'JWT' ), $header );
    $input = native_b64( json_encode( $header ) ) . '.' . native_b64( json_encode( $claims ) );
    if ( ! openssl_sign( $input, $signature, $GLOBALS['native_private_key'], OPENSSL_ALGO_SHA256 ) ) throw new RuntimeException( 'Cannot sign temporary JWT.' );
    return $input . '.' . native_b64( $signature );
}
function native_phone_claims( $phone = '+201012345678' ) {
    return array( 'aud' => 'test-project', 'iss' => 'https://securetoken.google.com/test-project', 'sub' => 'fixture-firebase-user', 'exp' => time() + 3600, 'iat' => time(), 'auth_time' => time(), 'phone_number' => $phone, 'firebase' => array( 'sign_in_provider' => 'phone' ) );
}
function native_google_claims( $subject = 'google-seven' ) {
    return array( 'aud' => 'web.apps.googleusercontent.com', 'azp' => 'android.apps.googleusercontent.com', 'iss' => 'https://accounts.google.com', 'sub' => $subject, 'exp' => time() + 3600, 'iat' => time(), 'email' => 'customer@gmail.com', 'email_verified' => true, 'name' => 'Verified Google Customer' );
}
function native_ticket_options() { return array_filter( $GLOBALS['native_options'], static fn( $value, $key ) => str_starts_with( $key, '_mobishop_native_auth_' ), ARRAY_FILTER_USE_BOTH ); }
function native_lock_key( $identity ) { return '_mobishop_native_auth_' . hash_hmac( 'sha256', 'lock:' . $identity, wp_salt( 'auth' ) ); }
function native_phone( $endpoint, $verifier, $phone = '+201012345678', $overrides = array() ) {
    native_clear_rate();
    return $endpoint->phone_verify( native_request( array_merge( array( 'phone' => $phone, 'id_token' => native_jwt( native_phone_claims( $phone ) ), 'verifier' => $verifier ), $overrides ) ) );
}
function native_select( $endpoint, $ticket, $verifier, $account ) { return $endpoint->select( native_request( array( 'ticket' => $ticket, 'verifier' => $verifier, 'account_id' => $account ) ) ); }

if ( ! extension_loaded( 'openssl' ) ) throw new RuntimeException( 'Enable the OpenSSL PHP extension to run real-signature native authentication tests.' );
$key_options = array( 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA );
$bundled_config = dirname( PHP_BINARY ) . '/extras/ssl/openssl.cnf';
if ( is_file( $bundled_config ) ) $key_options['config'] = $bundled_config;
$GLOBALS['native_private_key'] = openssl_pkey_new( $key_options );
if ( ! $GLOBALS['native_private_key'] ) throw new RuntimeException( 'Cannot create temporary RSA key.' );
$GLOBALS['native_public_key'] = openssl_pkey_get_details( $GLOBALS['native_private_key'] )['key'];
$GLOBALS['native_options']['mobishop_native_auth_settings'] = array(
    'phone_enabled' => true,
    'phone_country_code' => '20',
    'require_phone' => true,
    'registration_enabled' => true,
    'firebase_project_id' => 'test-project',
    'firebase' => array( 'android' => array( 'apiKey' => 'public-fixture-api-key', 'appId' => '1:123456789:android:abcdef123456', 'projectId' => 'test-project', 'messagingSenderId' => '123456789', 'private_key' => 'must-not-leak-firebase-secret' ) ),
    'google_enabled' => true,
    'google' => array( 'server_client_id' => 'web.apps.googleusercontent.com', 'android_client_ids' => array( 'android.apps.googleusercontent.com' ), 'ios_client_id' => 'ios.apps.googleusercontent.com', 'client_secret' => 'must-not-leak-google-secret' ),
    'private_key' => 'must-not-leak-root-secret',
);

require_once rtrim( getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: dirname( __DIR__ ) . '/source', '/\\' ) . '/api/class-native-customer-auth-endpoint.php';
$endpoint = new MobiShop_Native_Customer_Auth_Endpoint(
    function ( $user ) {
        $GLOBALS['native_issued'][] = $user->ID;
        return new WP_REST_Response( array( 'user_id' => $user->ID, 'token' => 'fixture-issued-token-' . count( $GLOBALS['native_issued'] ), 'session_scope' => 'fixture-scope' ) );
    },
    static fn( $user ) => $user instanceof WP_User && ! in_array( 'shop_manager', $user->roles, true ) && ! in_array( 'administrator', $user->roles, true ) && empty( $user->allcaps['manage_options'] ) && empty( $user->allcaps['manage_woocommerce'] )
);
$endpoint->register();
do_action( 'rest_api_init' );
foreach ( array( 'config' => 'GET', 'identify' => 'POST', 'password' => 'POST', 'phone/verify' => 'POST', 'select' => 'POST', 'google' => 'POST', 'register' => 'POST' ) as $route => $verb ) {
    $definition = $GLOBALS['native_routes']['mobishop/v1/auth/native/' . $route] ?? null;
    native_assert( is_array( $definition ) && $definition['methods'] === $verb, 'Native ' . $route . ' route is published with its intended method' );
}
$config_response = $endpoint->config( native_request( array( 'platform' => 'android' ) ) );
$config = native_data( $config_response, 'Config' );
native_assert( ! str_contains( json_encode( $config ), 'must-not-leak' ), 'Configuration contains only public SDK values' );
native_assert( str_contains( $config_response->headers['Cache-Control'] ?? '', 'no-store' ), 'Native configuration is not cached' );
native_assert( $config['methods']['phone_otp'] && $config['methods']['google'], 'Configured native providers are available' );
$settings_snapshot = $GLOBALS['native_options']['mobishop_native_auth_settings'];
$GLOBALS['native_options']['mobishop_native_auth_settings']['firebase']['ios'] = array( 'apiKey' => 'fixture-ios-api', 'appId' => '1:123:ios:fixture', 'projectId' => 'test-project', 'messagingSenderId' => '123', 'iosBundleId' => 'app.fixture.native' );
$ios_pending = native_data( $endpoint->config( native_request( array( 'platform' => 'ios' ) ) ), 'Pending iOS phone configuration' );
native_assert( ! $ios_pending['methods']['phone_otp'] && $ios_pending['firebase'] === null, 'Native iOS SDK options alone do not advertise unverified secondary-app phone authentication' );
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_phone_native_ready'] = true;
$ios_ready = native_data( $endpoint->config( native_request( array( 'platform' => 'ios' ) ) ), 'Verified iOS phone configuration' );
native_assert( $ios_ready['methods']['phone_otp'], 'iOS phone requires its independent explicit readiness attestation' );
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings_snapshot;
$GLOBALS['native_options']['mobishop_native_auth_settings']['firebase']['android']['projectId'] = 'another-project';
$misconfigured = native_data( $endpoint->config( native_request( array( 'platform' => 'android' ) ) ), 'Mismatched Firebase configuration' );
native_assert( ! $misconfigured['methods']['phone_otp'] && $misconfigured['firebase'] === null, 'A mismatched SDK project cannot advertise usable phone authentication' );
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings_snapshot;
$GLOBALS['native_https'] = false;
$insecure = native_data( $endpoint->config( native_request( array( 'platform' => 'android' ) ) ), 'Insecure configuration' );
native_assert( ! $insecure['enabled'] && ! $insecure['methods']['phone_otp'] && ! $insecure['methods']['google'], 'Insecure origin disables native authentication' );
native_rejected( $endpoint->password( native_request( array( 'identifier' => 'customer@gmail.com', 'password' => 'password-seven', 'verifier' => str_repeat( 'a', 64 ) ) ) ), 'Credentials are rejected without HTTPS' );
$GLOBALS['native_https'] = true;
$verifier = str_repeat( 'a', 64 );
foreach ( array( '01012345678', 'customer@gmail.com', 'unknown@gmail.com' ) as $identifier ) {
    $data = native_data( $endpoint->identify( native_request( array( 'identifier' => $identifier ) ) ), 'Identify' );
    $serialized = json_encode( $data );
    native_assert( ! isset( $data['accounts'] ) && ! isset( $data['user'] ) && ! isset( $data['ticket'] ) && ! str_contains( $serialized, 'Customer Seven' ) && ! str_contains( $serialized, 'Customer Nine' ), 'Identify does not reveal account lists or issue identity proof' );
}

// A real signed proof selects eligible login identities only, never shipping-only matches.
$proof = native_data( native_phone( $endpoint, $verifier ), 'Verified phone' );
native_assert( $proof['status'] === 'select_account', 'A verified shared phone asks for account selection' );
$account_ids = array_map( static fn( $account ) => $account['id'], $proof['accounts'] );
sort( $account_ids );
native_assert( $account_ids === array( 7, 9 ), 'Picker excludes privileged accounts and a conflicting established phone identity' );
$ticket = $proof['ticket'];
$stored = serialize( native_ticket_options() );
native_assert( ! str_contains( $stored, $ticket ) && ! str_contains( $stored, $verifier ), 'Only ticket and verifier hashes are persisted' );
$issued_before = count( $GLOBALS['native_issued'] );
foreach ( array( str_repeat( 'b', 64 ), str_repeat( 'a', 63 ), str_repeat( 'a', 65 ), str_repeat( 'A', 64 ), str_repeat( 'g', 64 ), str_repeat( 'a', 64 ) . "\n" ) as $bad_verifier ) native_rejected( native_select( $endpoint, $ticket, $bad_verifier, 7 ), 'Wrong or malformed ticket binding is rejected' );
native_rejected( native_select( $endpoint, $ticket . "\n", $verifier, 7 ), 'Ticket syntax rejects a trailing newline' );
native_rejected( native_select( $endpoint, $ticket, $verifier, 11 ), 'Proof cannot select another phone account' );
native_rejected( native_select( $endpoint, $ticket, $verifier, 8 ), 'Proof cannot select a privileged account' );
$wpdb->race = true;
native_rejected( native_select( $endpoint, $ticket, $verifier, 7 ), 'Losing a concurrent ticket consumption cannot authenticate' );
native_assert( count( $GLOBALS['native_issued'] ) === $issued_before, 'Invalid and raced selections issue no sessions' );
$selected = native_data( native_select( $endpoint, $ticket, $verifier, 7 ), 'Selected account' );
native_assert( $selected['status'] === 'authenticated' && $selected['user_id'] === 7, 'Selected eligible customer receives the existing session response' );
native_rejected( native_select( $endpoint, $ticket, $verifier, 7 ), 'Consumed selection ticket cannot be replayed' );
native_assert( count( $GLOBALS['native_issued'] ) === $issued_before + 1, 'One ticket issues exactly one session' );

// Existing metadata may store international digits without a leading plus.
$canonical_phone = $GLOBALS['native_meta'][7]['kidia_login_phone'];
$GLOBALS['native_meta'][7]['kidia_login_phone'] = '201012345678';
$legacy_phone = native_data( native_phone( $endpoint, $verifier ), 'International phone metadata without plus' );
native_assert( $legacy_phone['status'] === 'select_account' && in_array( 7, array_column( $legacy_phone['accounts'], 'id' ), true ), 'Legacy international digits match the canonical verified phone without duplicating its country code' );
$legacy_selected = native_data( native_select( $endpoint, $legacy_phone['ticket'], $verifier, 7 ), 'Selected legacy international phone identity' );
native_assert( $legacy_selected['user_id'] === 7, 'Selection revalidates the same legacy phone format' );
$GLOBALS['native_meta'][7]['kidia_login_phone'] = $canonical_phone;

// Claim changes are still signed by the fixture key; only claim validation rejects them.
$claim_mutations = array(
    'wrong audience' => array( 'aud' => 'attacker-project' ),
    'wrong issuer' => array( 'iss' => 'https://securetoken.google.com/attacker-project' ),
    'expired proof' => array( 'exp' => time() - 1 ),
    'future issue time' => array( 'iat' => time() + 3600 ),
    'stale authentication' => array( 'auth_time' => time() - 601 ),
    'future authentication' => array( 'auth_time' => time() + 3600 ),
    'wrong phone' => array( 'phone_number' => '+201112345678' ),
    'wrong provider' => array( 'firebase' => array( 'sign_in_provider' => 'password' ) ),
    'empty subject' => array( 'sub' => '' ),
    'overlong subject' => array( 'sub' => str_repeat( 'x', 129 ) ),
    'string expiry' => array( 'exp' => (string) ( time() + 3600 ) ),
);
foreach ( $claim_mutations as $label => $changes ) {
    $before = count( native_ticket_options() );
    native_rejected( native_phone( $endpoint, $verifier, '+201012345678', array( 'id_token' => native_jwt( array_merge( native_phone_claims(), $changes ) ), 'project_id' => 'attacker-project' ) ), 'Reject Firebase ' . $label );
    native_assert( count( native_ticket_options() ) === $before, 'Invalid ' . $label . ' creates no ticket' );
}
foreach ( array( array( 'alg' => 'HS256' ), array( 'alg' => 'none' ), array( 'kid' => 'unknown-key' ) ) as $header ) native_rejected( native_phone( $endpoint, $verifier, '+201012345678', array( 'id_token' => native_jwt( native_phone_claims(), $header ) ) ), 'Reject untrusted token algorithm or key identifier' );
$damaged = native_jwt( native_phone_claims() );
$parts = explode( '.', $damaged );
$parts[2][0] = $parts[2][0] === 'A' ? 'B' : 'A';
native_rejected( native_phone( $endpoint, $verifier, '+201012345678', array( 'id_token' => implode( '.', $parts ) ) ), 'Reject a cryptographically invalid signature' );
native_rejected( native_phone( $endpoint, $verifier, '+201012345678', array( 'id_token' => str_repeat( 'x', 13000 ) ) ), 'Reject an oversized proof' );
native_rejected( native_phone( $endpoint, $verifier . "\n" ), 'Direct proof binding rejects a trailing newline' );
native_rejected( native_phone( $endpoint, $verifier, '+201012345678', array( 'id_token' => native_jwt( native_phone_claims() ) . "\n" ) ), 'Encoded signature rejects trailing data' );

// A blocked or overflowing existing identity must never become a new-registration proof.
$tickets_before = count( native_ticket_options() );
$manager_phone = $GLOBALS['native_meta'][8]['kidia_login_phone'];
$GLOBALS['native_meta'][8]['kidia_login_phone'] = '+201500000001';
native_rejected( native_phone( $endpoint, $verifier, '+201500000001' ), 'Privileged-only phone fails closed instead of offering registration' );
native_rejected( $endpoint->password( native_request( array( 'identifier' => '+201500000001', 'password' => 'password-manager', 'verifier' => $verifier ) ) ), 'Privileged-only phone password fails closed' );
$GLOBALS['native_meta'][8]['kidia_login_phone'] = $manager_phone;
$shipping_phone = $GLOBALS['native_meta'][12]['billing_phone'];
$GLOBALS['native_meta'][12]['billing_phone'] = '+201500000002';
native_rejected( native_phone( $endpoint, $verifier, '+201500000002' ), 'Shipping-only match cannot become a duplicate registration identity' );
$GLOBALS['native_meta'][12]['billing_phone'] = $shipping_phone;
for ( $id = 1000; $id < 1051; $id++ ) {
    $GLOBALS['native_users'][$id] = array( 'login' => 'overflow-' . $id, 'email' => 'overflow-' . $id . '@gmail.com', 'password' => 'overflow-password', 'name' => 'Overflow Customer', 'roles' => array( 'customer' ) );
    $GLOBALS['native_meta'][$id] = array( 'kidia_login_phone' => '+201500000003' );
}
native_rejected( native_phone( $endpoint, $verifier, '+201500000003' ), 'More than fifty matches cannot expose a partial picker or offer registration' );
native_rejected( $endpoint->password( native_request( array( 'identifier' => '+201500000003', 'password' => 'overflow-password', 'verifier' => $verifier ) ) ), 'Excessive password candidate set fails closed' );
for ( $id = 1000; $id < 1051; $id++ ) unset( $GLOBALS['native_users'][$id], $GLOBALS['native_meta'][$id] );
native_assert( count( native_ticket_options() ) === $tickets_before, 'Blocked phone identities create no proof ticket' );

// Eligibility is checked again after the proof ticket has been created.
$proof = native_data( native_phone( $endpoint, $verifier ), 'Role recheck proof' );
$GLOBALS['native_users'][7]['allcaps']['edit_users'] = true;
native_rejected( native_select( $endpoint, $proof['ticket'], $verifier, 7 ), 'Role elevation after proof is rejected at selection' );
unset( $GLOBALS['native_users'][7]['allcaps']['edit_users'] );
$GLOBALS['native_meta'][7]['kidia_login_phone'] = '+201112345678';
native_rejected( native_select( $endpoint, $proof['ticket'], $verifier, 7 ), 'Phone identity changed after proof is rejected' );
$GLOBALS['native_meta'][7]['kidia_login_phone'] = '+201012345678';
foreach ( native_ticket_options() as $key => $row ) $GLOBALS['native_options'][$key]['expires'] = time() - 1;
native_rejected( native_select( $endpoint, $proof['ticket'], $verifier, 7 ), 'Expired ticket cannot authenticate' );

// A password proves only the exact account whose password and provider hooks pass.
native_clear_rate();
$password = native_data( $endpoint->password( native_request( array( 'identifier' => '01012345678', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Phone password' );
native_assert( $password['status'] === 'authenticated' && $password['user_id'] === 7 && ! isset( $password['accounts'] ), 'Password for one shared-phone account does not prove other accounts' );
$GLOBALS['native_auth_override'] = 9;
native_rejected( $endpoint->password( native_request( array( 'identifier' => '01012345678', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Authentication filter cannot substitute another account for a matched password' );
unset( $GLOBALS['native_auth_override'] );
native_rejected( $endpoint->password( native_request( array( 'identifier' => '01012345678', 'password' => 'wrong-password', 'verifier' => $verifier ) ) ), 'Wrong password cannot reveal accounts' );
foreach ( array( 'manager@gmail.com' => 'password-manager', 'editor@gmail.com' => 'password-editor' ) as $email => $password ) native_rejected( $endpoint->password( native_request( array( 'identifier' => $email, 'password' => $password, 'verifier' => $verifier ) ) ), 'Privileged password account is denied' );
$GLOBALS['native_users'][9]['password'] = 'password-seven';
native_clear_rate();
$shared_password = native_data( $endpoint->password( native_request( array( 'identifier' => '01012345678', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Password matching two accounts' );
native_assert( $shared_password['status'] === 'select_account' && count( $shared_password['accounts'] ) === 2, 'Only accounts whose own password matched enter the password picker' );
$GLOBALS['native_users'][7]['password'] = 'changed-after-proof';
$issued_before = count( $GLOBALS['native_issued'] );
native_rejected( native_select( $endpoint, $shared_password['ticket'], $verifier, 7 ), 'Changing a password revokes a pending password-selection proof' );
native_assert( count( $GLOBALS['native_issued'] ) === $issued_before, 'Revoked password proof cannot issue a session' );
$still_valid = native_data( native_select( $endpoint, $shared_password['ticket'], $verifier, 9 ), 'Unchanged password proof' );
native_assert( $still_valid['user_id'] === 9, 'An unchanged matched account can consume the selection proof' );
$GLOBALS['native_users'][7]['password'] = 'password-seven';
$GLOBALS['native_users'][9]['password'] = 'password-nine';

// WordPress may upgrade the stored password hash while returning its earlier WP_User object.
$GLOBALS['native_users'][9]['password'] = 'password-seven';
$GLOBALS['native_after_authenticate_hook'] = function ( $authenticated_user ) {
    $GLOBALS['native_users'][$authenticated_user->ID]['password_hash'] = 'fixture-rehashed:' . $GLOBALS['native_users'][$authenticated_user->ID]['password'];
};
native_clear_rate();
$rehash_picker = native_data( $endpoint->password( native_request( array( 'identifier' => '01012345678', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Password proof after a transparent stored-hash upgrade' );
native_assert( $rehash_picker['status'] === 'select_account' && get_user_by( 'id', 7 )->user_pass === 'fixture-rehashed:password-seven', 'Successful authentication upgrades the stored hash while creating the shared-phone picker' );
$rehash_selected = native_data( native_select( $endpoint, $rehash_picker['ticket'], $verifier, 7 ), 'Selection after a transparent stored-hash upgrade' );
native_assert( $rehash_selected['user_id'] === 7 && $rehash_selected['status'] === 'authenticated', 'The picker binds the refreshed stored hash and does not mistake its upgrade for a later password change' );
unset( $GLOBALS['native_users'][7]['password_hash'] );
$GLOBALS['native_users'][9]['password'] = 'password-nine';

// Google identifies by the existing provider subject, not a caller-supplied email.
native_clear_rate();
$google = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims(), array( 'email' => 'changed@gmail.com' ) ) ), 'verifier' => $verifier, 'user_id' => 9 ) ) ), 'Linked Google' );
native_assert( $google['status'] === 'authenticated' && $google['user_id'] === 7, 'Linked Google subject retains the established customer despite a changed email' );
$cached_google = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims(), array( 'iat' => time() - 1800, 'exp' => time() + 1800 ) ) ), 'verifier' => $verifier ) ) ), 'Unexpired cached Google proof' );
native_assert( $cached_google['status'] === 'authenticated' && $cached_google['user_id'] === 7, 'An unexpired Google SDK token is not rejected after ten minutes' );
$cert_key = 'mobishop_native_certs_' . hash( 'sha256', 'https://www.googleapis.com/oauth2/v1/certs' );
set_transient( $cert_key, array( 'previous-kid' => $GLOBALS['native_public_key'] ), 300 );
unset( $GLOBALS['native_transients'][$cert_key . '_refresh'] );
$requests_before_rotation = count( $GLOBALS['native_http'] );
native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( native_google_claims() ), 'verifier' => $verifier ) ) ), 'Rotated Google signing key' );
native_assert( count( $GLOBALS['native_http'] ) === $requests_before_rotation + 1, 'Unknown cached key refreshes trusted issuer certificates once' );
foreach ( array( 'unknown-one', 'unknown-two' ) as $kid ) native_rejected( $endpoint->google( native_request( array( 'id_token' => native_jwt( native_google_claims(), array( 'kid' => $kid ) ), 'verifier' => $verifier ) ) ), 'Unknown rotated keys still fail verification' );
native_assert( count( $GLOBALS['native_http'] ) === $requests_before_rotation + 1, 'Unknown key IDs cannot trigger unbounded certificate refreshes' );
foreach ( array( 'aud' => 'attacker.apps.googleusercontent.com', 'azp' => 'attacker.apps.googleusercontent.com', 'iss' => 'https://attacker.example', 'exp' => time() - 1, 'iat' => time() + 120 ) as $claim => $value ) {
    native_clear_rate();
    native_rejected( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims(), array( $claim => $value ) ) ), 'verifier' => $verifier ) ) ), 'Reject invalid Google ' . $claim );
}
native_clear_rate();
native_rejected( $endpoint->google( native_request( array( 'id_token' => native_jwt( native_google_claims( 'google-manager' ) ), 'verifier' => $verifier ) ) ), 'Linked privileged Google account is denied' );
native_clear_rate();
native_rejected( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'unlinked-external' ), array( 'email' => 'unverified@external.example', 'email_verified' => false ) ) ), 'verifier' => $verifier ) ) ), 'Unlinked Google identity cannot establish an unverified email' );
native_clear_rate();
native_rejected( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'unlinked-external' ), array( 'email' => 'verified@external.example', 'email_verified' => true ) ) ), 'verifier' => $verifier ) ) ), 'Unlinked third-party Google email needs additional account proof even when email_verified is true' );

// Competing Google subjects cannot link the same customer while a lease is held.
native_clear_rate();
$google_user_lock = native_lock_key( 'google-link:user:11' );
$GLOBALS['native_options'][$google_user_lock] = array( 'owner' => 'expired-owner', 'expires' => time() - 1 );
$next_owner = array( 'owner' => 'later-owner', 'expires' => time() + 300 );
$GLOBALS['native_google_link_hook'] = function () use ( $endpoint, $verifier, $google_user_lock, $next_owner ) {
    $GLOBALS['native_overlapping_link'] = $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'competing-google-subject' ), array( 'email' => 'different@gmail.com' ) ) ), 'verifier' => $verifier ) ) );
    // Simulate a new owner after an expired lease was replaced before the first worker returned.
    $GLOBALS['native_options'][$google_user_lock] = $next_owner;
};
$linked = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'new-google-eleven' ), array( 'email' => 'different@gmail.com' ) ) ), 'verifier' => $verifier ) ) ), 'Recovered Google linking lease' );
native_assert( $linked['user_id'] === 11, 'An expired linking lease is recoverable' );
native_rejected( $GLOBALS['native_overlapping_link'], 'Overlapping Google linking for the same user is rejected' );
native_assert( ! isset( NextendSocialLogin::$providers['google']->links['competing-google-subject'] ), 'Rejected competing link creates no provider mapping' );
native_assert( $GLOBALS['native_options'][$google_user_lock] === $next_owner, 'An old worker cannot release a newer owner lease' );
do_action( 'mobishop_native_auth_cleanup', $google_user_lock );
native_assert( ( $GLOBALS['native_options'][$google_user_lock] ?? null ) === $next_owner, 'Delayed cleanup from an old lease cannot remove a current lease' );
$GLOBALS['native_options'][$google_user_lock]['expires'] = time() - 1;
do_action( 'mobishop_native_auth_cleanup', $google_user_lock );
native_assert( ! isset( $GLOBALS['native_options'][$google_user_lock] ), 'Cleanup removes the current lease after it expires' );

// Two independent proofs may link Google only to the customer explicitly selected by phone.
native_clear_rate();
$email_before_link = get_user_by( 'id', 9 )->user_email;
$google_start = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'google-phone-link' ), array( 'email' => 'new-google-identity@gmail.com' ) ) ), 'verifier' => $verifier ) ) ), 'Unlinked Google proof' );
native_assert( $google_start['status'] === 'registration_required' && ! isset( NextendSocialLogin::$providers['google']->links['google-phone-link'] ), 'Google proof alone does not link an arbitrary existing customer' );
native_rejected( native_phone( $endpoint, str_repeat( 'b', 64 ), '+201012345678', array( 'ticket' => $google_start['ticket'] ) ), 'Phone proof cannot adopt a Google ticket from another attempt' );
$combined = native_data( native_phone( $endpoint, $verifier, '+201012345678', array( 'ticket' => $google_start['ticket'] ) ), 'Combined Google and phone proof' );
native_assert( $combined['status'] === 'select_account' && ! isset( NextendSocialLogin::$providers['google']->links['google-phone-link'] ), 'Shared-phone proof still waits for explicit account selection before linking' );
native_rejected( native_phone( $endpoint, $verifier, '+201012345678', array( 'ticket' => $google_start['ticket'] ) ), 'Prior Google registration ticket cannot be consumed twice' );
$combined_selected = native_data( native_select( $endpoint, $combined['ticket'], $verifier, 9 ), 'Explicit combined-proof account selection' );
native_assert( $combined_selected['user_id'] === 9 && NextendSocialLogin::$providers['google']->links['google-phone-link'] === 9, 'Selected phone customer receives the verified Google subject' );
native_assert( get_user_by( 'id', 9 )->user_email === $email_before_link, 'Linking retains the existing customer email and identity' );
$conflict_start = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'google-conflicting-link' ), array( 'email' => 'conflicting-google-identity@gmail.com' ) ) ), 'verifier' => $verifier ) ) ), 'Separate Google proof before a subject conflict' );
$conflict_picker = native_data( native_phone( $endpoint, $verifier, '+201012345678', array( 'ticket' => $conflict_start['ticket'] ) ), 'Combined proof before a subject conflict' );
NextendSocialLogin::$providers['google']->links['google-conflicting-link'] = 11;
$issued_before = count( $GLOBALS['native_issued'] );
native_rejected( native_select( $endpoint, $conflict_picker['ticket'], $verifier, 9 ), 'Subject linked elsewhere after proof cannot be moved to the selected customer' );
native_assert( NextendSocialLogin::$providers['google']->links['google-conflicting-link'] === 11 && count( $GLOBALS['native_issued'] ) === $issued_before, 'Conflicting subject remains on its existing account and issues no session' );

// A previously required account-completion step must survive every native entry point.
update_user_meta( 7, 'kidia_phone_setup_required', 'otp' );
$issued_before = count( $GLOBALS['native_issued'] );
native_clear_rate();
$pending_password = native_data( $endpoint->password( native_request( array( 'identifier' => 'customer@gmail.com', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Pending account password proof' );
native_assert( $pending_password['status'] === 'registration_required' && in_array( 'phone', $pending_password['fields'], true ), 'Password cannot bypass required phone completion' );
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $pending_password['ticket'], 'verifier' => $verifier, 'name' => 'Incomplete Customer', 'password' => 'replacement-password' ) ) ), 'Registration cannot clear a required phone step without phone proof' );
$pending_google = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( native_google_claims() ), 'verifier' => $verifier ) ) ), 'Pending Google account proof' );
native_assert( $pending_google['status'] === 'registration_required', 'Google cannot bypass required account completion' );
$pending_phone = native_data( native_phone( $endpoint, $verifier ), 'Pending phone account proof' );
$pending_selected = native_data( native_select( $endpoint, $pending_phone['ticket'], $verifier, 7 ), 'Pending selected account' );
native_assert( $pending_selected['status'] === 'registration_required' && count( $GLOBALS['native_issued'] ) === $issued_before, 'Selecting an incomplete account never issues a shopping session' );
native_assert( get_user_meta( 7, 'kidia_phone_setup_required', true ) === 'otp', 'Failed completion preserves the existing required-phone marker' );
delete_user_meta( 7, 'kidia_phone_setup_required' );

// Existing shared-phone customers can complete their own profile without merging accounts.
$other_account_before = $GLOBALS['native_users'][9];
$other_meta_before = $GLOBALS['native_meta'][9];
$created_before_shared = count( $GLOBALS['native_created'] );
update_user_meta( 7, 'kidia_phone_setup_required', 'account' );
native_clear_rate();
$shared_profile_start = native_data( $endpoint->password( native_request( array( 'identifier' => 'customer@gmail.com', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Shared-phone account password proof' );
$shared_profile_phone = native_data( native_phone( $endpoint, $verifier, '+201012345678', array( 'ticket' => $shared_profile_start['ticket'] ) ), 'Preserved shared-phone account proof' );
$shared_profile_done = native_data( $endpoint->register_customer( native_request( array( 'ticket' => $shared_profile_phone['ticket'], 'verifier' => $verifier, 'name' => 'Completed Shared Customer', 'password' => 'password-seven' ) ) ), 'Shared-phone account profile completion' );
native_assert( $shared_profile_done['user_id'] === 7 && count( $GLOBALS['native_created'] ) === $created_before_shared, 'Password and OTP complete the original shared-phone customer without creating another account' );
native_assert( $GLOBALS['native_users'][9] === $other_account_before && $GLOBALS['native_meta'][9] === $other_meta_before, 'Completing one shared-phone profile preserves the other account and its provider links' );
native_assert( ! get_user_meta( 7, 'kidia_phone_setup_required', true ), 'Shared-phone completion clears the selected account marker' );
update_user_meta( 7, 'kidia_phone_setup_required', 'account' );
$direct_shared_proof = native_data( native_phone( $endpoint, $verifier ), 'Direct shared-phone profile proof' );
$direct_shared_selected = native_data( native_select( $endpoint, $direct_shared_proof['ticket'], $verifier, 7 ), 'Direct shared-phone profile selection' );
$direct_shared_done = native_data( $endpoint->register_customer( native_request( array( 'ticket' => $direct_shared_selected['ticket'], 'verifier' => $verifier, 'name' => 'Customer Seven', 'password' => 'password-seven' ) ) ), 'Direct shared-phone profile completion' );
native_assert( $direct_shared_done['user_id'] === 7 && get_user_meta( 7, 'kidia_login_phone', true ) === '+201012345678', 'OTP and explicit selection also complete an existing shared-phone account' );
update_user_meta( 7, 'kidia_phone_setup_required', 'otp' );
native_clear_rate();
$move_phone_start = native_data( $endpoint->password( native_request( array( 'identifier' => 'customer@gmail.com', 'password' => 'password-seven', 'verifier' => $verifier ) ) ), 'Existing identity before a conflicting phone change' );
native_rejected( native_phone( $endpoint, $verifier, '+201112345678', array( 'ticket' => $move_phone_start['ticket'] ) ), 'Completion still rejects changing to another established customer phone' );
native_assert( get_user_meta( 7, 'kidia_login_phone', true ) === '+201012345678', 'Rejected phone change preserves the original login identity' );
delete_user_meta( 7, 'kidia_phone_setup_required' );

// Registration requires a bound recent proof and cannot claim arbitrary email identity.
$unregistered_phone = '+201512345678';
$registration = native_data( native_phone( $endpoint, $verifier, $unregistered_phone ), 'Unknown verified phone' );
$parallel_registration = native_data( native_phone( $endpoint, $verifier, $unregistered_phone ), 'Separate proof for the same unknown phone' );
native_assert( $registration['status'] === 'registration_required', 'Unknown verified phone offers registration with a restricted ticket' );
$created_before = count( $GLOBALS['native_created'] );
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $registration['ticket'], 'verifier' => str_repeat( 'b', 64 ), 'name' => 'New Customer', 'password' => 'new-password' ) ) ), 'Registration rejects the wrong proof binding' );
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $registration['ticket'], 'verifier' => $verifier, 'name' => 'New Customer', 'password' => 'new-password', 'email' => 'customer@gmail.com' ) ) ), 'Phone proof cannot claim an existing arbitrary email identity' );
native_assert( count( $GLOBALS['native_created'] ) === $created_before, 'Rejected registration never creates a user' );
$wpdb->race = true;
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $registration['ticket'], 'verifier' => $verifier, 'name' => 'New Customer', 'password' => 'new-password' ) ) ), 'Losing a registration ticket race cannot create an account' );
native_assert( count( $GLOBALS['native_created'] ) === $created_before, 'Raced registration has no user side effect' );
$registration_lock = native_lock_key( 'register:phone:' . $unregistered_phone );
$GLOBALS['native_options'][$registration_lock] = array( 'owner' => 'other-register-worker', 'expires' => time() + 300 );
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $registration['ticket'], 'verifier' => $verifier, 'name' => 'New Customer', 'password' => 'new-password' ) ) ), 'Active identity registration lease prevents another creation' );
native_assert( count( $GLOBALS['native_created'] ) === $created_before, 'Blocked registration lease has no account side effect' );
$GLOBALS['native_options'][$registration_lock]['expires'] = time() - 1;
$registered = native_data( $endpoint->register_customer( native_request( array( 'ticket' => $registration['ticket'], 'verifier' => $verifier, 'name' => 'New Customer', 'password' => 'new-password', 'phone' => '+201112345678', 'user_id' => 7 ) ) ), 'Proof-bound registration' );
native_assert( $registered['status'] === 'authenticated' && count( $GLOBALS['native_created'] ) === $created_before + 1, 'Verified registration creates exactly one customer' );
$new_id = $registered['user_id'];
native_assert( get_user_meta( $new_id, 'kidia_login_phone', true ) === $unregistered_phone && get_user_by( 'id', $new_id )->user_email === '', 'Registration identity comes from proof, not request phone or email' );
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $registration['ticket'], 'verifier' => $verifier, 'name' => 'Replay', 'password' => 'new-password' ) ) ), 'Registration ticket cannot be replayed' );
native_rejected( $endpoint->register_customer( native_request( array( 'ticket' => $parallel_registration['ticket'], 'verifier' => $verifier, 'name' => 'Duplicate', 'password' => 'new-password' ) ) ), 'A separate earlier ticket cannot duplicate an identity that has since registered' );
native_assert( count( $GLOBALS['native_created'] ) === $created_before + 1, 'Concurrent identity proofs result in one registered customer' );

// Existing password accounts finish registration only after an independent phone proof.
$completion_id = max( array_keys( $GLOBALS['native_users'] ) ) + 1;
$GLOBALS['native_users'][$completion_id] = array( 'login' => 'pending-profile', 'email' => 'pending-profile@gmail.com', 'password' => 'profile-password', 'name' => 'Incomplete Profile', 'roles' => array( 'customer' ) );
update_user_meta( $completion_id, 'kidia_phone_setup_required', 'otp' );
native_clear_rate();
$profile_start = native_data( $endpoint->password( native_request( array( 'identifier' => 'pending-profile@gmail.com', 'password' => 'profile-password', 'verifier' => $verifier ) ) ), 'Existing profile password proof' );
$profile_phone = native_data( native_phone( $endpoint, $verifier, '+201011111111', array( 'ticket' => $profile_start['ticket'] ) ), 'Existing profile phone proof' );
native_assert( $profile_phone['status'] === 'registration_required' && ! in_array( 'phone', $profile_phone['fields'], true ), 'Verified completion ticket no longer asks for phone proof' );
$created_before_profile = count( $GLOBALS['native_created'] );
$profile_done = native_data( $endpoint->register_customer( native_request( array( 'ticket' => $profile_phone['ticket'], 'verifier' => $verifier, 'name' => 'Completed Profile', 'password' => 'completed-password' ) ) ), 'Existing profile completion' );
native_assert( $profile_done['status'] === 'authenticated' && $profile_done['user_id'] === $completion_id && count( $GLOBALS['native_created'] ) === $created_before_profile, 'Completing an existing account preserves its identity and creates no duplicate' );
native_assert( get_user_meta( $completion_id, 'kidia_login_phone', true ) === '+201011111111' && ! get_user_meta( $completion_id, 'kidia_phone_setup_required', true ), 'Successful completion stores only the verified phone and clears its required marker' );
native_assert( wp_check_password( 'completed-password', get_user_by( 'id', $completion_id )->user_pass, $completion_id ), 'Completed profile receives the explicitly chosen password' );

// New Google registrations retain both server-verified identities through profile completion.
native_clear_rate();
$google_registration = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( array_merge( native_google_claims( 'brand-new-google' ), array( 'email' => 'brand-new-google@gmail.com' ) ) ), 'verifier' => $verifier ) ) ), 'New Google registration proof' );
$google_phone_registration = native_data( native_phone( $endpoint, $verifier, '+201022222222', array( 'ticket' => $google_registration['ticket'] ) ), 'New Google registration phone proof' );
$google_registered = native_data( $endpoint->register_customer( native_request( array( 'ticket' => $google_phone_registration['ticket'], 'verifier' => $verifier, 'name' => 'New Google Customer', 'password' => 'new-google-password', 'email' => 'brand-new-google@gmail.com' ) ) ), 'New Google profile registration' );
$google_id = $google_registered['user_id'];
native_assert( $google_registered['status'] === 'authenticated' && get_user_by( 'id', $google_id )->user_email === 'brand-new-google@gmail.com' && get_user_meta( $google_id, 'kidia_login_phone', true ) === '+201022222222', 'New Google customer stores the proven email and phone' );
native_assert( NextendSocialLogin::$providers['google']->links['brand-new-google'] === $google_id, 'Successful Google registration shares the provider mapping with the website' );

// Google linking and registration use the same subject lease across account creation.
native_clear_rate();
$race_claims = array_merge( native_google_claims( 'registration-link-race' ), array( 'email' => 'registration-race@gmail.com' ) );
$race_registration_start = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( $race_claims ), 'verifier' => $verifier ) ) ), 'Registration race Google proof' );
$race_registration_phone = native_data( native_phone( $endpoint, $verifier, '+201033333333', array( 'ticket' => $race_registration_start['ticket'] ) ), 'Registration race new phone proof' );
$race_link_start = native_data( $endpoint->google( native_request( array( 'id_token' => native_jwt( $race_claims ), 'verifier' => $verifier ) ) ), 'Competing link Google proof' );
$race_link_picker = native_data( native_phone( $endpoint, $verifier, '+201112345678', array( 'ticket' => $race_link_start['ticket'] ) ), 'Competing link existing phone proof' );
native_assert( in_array( 12, array_column( $race_link_picker['accounts'], 'id' ), true ), 'Competing fixture selects a customer without a prior Google mapping' );
$created_before_link_race = count( $GLOBALS['native_created'] );
$issued_before_link_race = count( $GLOBALS['native_issued'] );
$GLOBALS['native_before_insert_hook'] = function () use ( $endpoint, $verifier, $race_link_picker ) {
    $GLOBALS['native_subject_lock_during_insert'] = get_option( native_lock_key( 'google-link:sub:registration-link-race' ) );
    $GLOBALS['native_registration_link_race'] = native_select( $endpoint, $race_link_picker['ticket'], $verifier, 12 );
};
$race_registration_done = native_data( $endpoint->register_customer( native_request( array( 'ticket' => $race_registration_phone['ticket'], 'verifier' => $verifier, 'name' => 'Race-safe Customer', 'password' => 'race-safe-password' ) ) ), 'Registration with an overlapping Google link' );
native_assert( is_array( $GLOBALS['native_subject_lock_during_insert'] ), 'Registration owns the shared Google subject lease before account creation' );
native_rejected( $GLOBALS['native_registration_link_race'], 'Competing selected-account Google link cannot interrupt registration' );
native_assert( count( $GLOBALS['native_created'] ) === $created_before_link_race + 1 && count( $GLOBALS['native_issued'] ) === $issued_before_link_race + 1, 'The race produces exactly one new account and one session' );
native_assert( NextendSocialLogin::$providers['google']->links['registration-link-race'] === $race_registration_done['user_id'] && ! get_user_meta( 12, '_mobishop_google_subject', true ), 'Google remains linked to the completed registration and does not mutate the competing account' );

// Rate limiting happens before another password authentication attempt or identity write.
native_clear_rate();
for ( $attempt = 0; $attempt < 15; $attempt++ ) {
    $bad_login = $endpoint->password( native_request( array( 'identifier' => 'customer@gmail.com', 'password' => 'wrong-password', 'verifier' => $verifier ) ) );
    native_assert( is_wp_error( $bad_login ) && ( $bad_login->get_error_data()['status'] ?? 0 ) !== 429, 'Initial password attempts are evaluated within the IP budget' );
}
$calls_before = count( $GLOBALS['native_auth_calls'] );
$limited = $endpoint->password( native_request( array( 'identifier' => 'other@gmail.com', 'password' => 'password-nine', 'verifier' => $verifier ) ) );
native_assert( is_wp_error( $limited ) && ( $limited->get_error_data()['status'] ?? 0 ) === 429 && count( $GLOBALS['native_auth_calls'] ) === $calls_before, 'Changing email cannot evade the password IP budget or run authentication after the limit' );

// Legacy formatted numbers resolve to their existing account, never a duplicate signup.
native_clear_rate();
$formatted_id = 2001;
$GLOBALS['native_users'][$formatted_id] = array( 'login' => 'formatted-phone', 'email' => 'formatted@gmail.com', 'password' => 'formatted-password', 'name' => 'Formatted Phone', 'roles' => array( 'customer' ) );
$formatted_phone = '+201088888888';
foreach ( array( '010 8888 8888', '(010)8888-8888', '٠١٠ ٨٨٨٨ ٨٨٨٨', '۰۰۲۰ ۱۰ ۸۸۸۸ ۸۸۸۸', '+20 (10) 8888-8888', '20 10 8888 8888' ) as $formatted_value ) {
    $GLOBALS['native_meta'][$formatted_id] = array( 'billing_phone' => $formatted_value );
    $formatted_password = native_data( $endpoint->password( native_request( array( 'identifier' => $formatted_phone, 'password' => 'formatted-password', 'verifier' => $verifier ) ) ), 'Formatted legacy phone password' );
    native_assert( $formatted_password['status'] === 'authenticated' && $formatted_password['user_id'] === $formatted_id, 'Formatting does not hide the existing password account' );
    $formatted_otp = native_data( native_phone( $endpoint, $verifier, $formatted_phone ), 'Formatted legacy phone OTP' );
    native_assert( $formatted_otp['status'] === 'authenticated' && $formatted_otp['user_id'] === $formatted_id && ! isset( $formatted_otp['ticket'] ), 'Verified formatted phone uses the existing customer instead of offering duplicate registration' );
}
$GLOBALS['native_meta'][$formatted_id] = array( 'kidia_login_phone' => '+201099999999', 'billing_phone' => '010 8888 8888' );
native_rejected( native_phone( $endpoint, $verifier, $formatted_phone ), 'Formatted shipping metadata cannot override a different canonical login identity or create a duplicate signup' );
native_rejected( $endpoint->password( native_request( array( 'identifier' => $formatted_phone, 'password' => 'formatted-password', 'verifier' => $verifier ) ) ), 'Password cannot authenticate through formatted shipping metadata belonging to a different canonical identity' );
unset( $GLOBALS['native_users'][$formatted_id], $GLOBALS['native_meta'][$formatted_id] );

// HTTP calls stay fixed, do not follow redirects, and verify TLS.
foreach ( $GLOBALS['native_http'] as $call ) {
    native_assert( ( $call['args']['sslverify'] ?? true ) === true && ( $call['args']['redirection'] ?? -1 ) === 0, 'Trusted signing-key retrieval verifies TLS and follows no redirects' );
}
echo 'Native customer auth: ' . $GLOBALS['native_checks'] . ' contract/security checks passed.' . PHP_EOL;
