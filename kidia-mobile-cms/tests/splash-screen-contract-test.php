<?php
declare( strict_types=1 );
define( 'ABSPATH', __DIR__ );
$GLOBALS['kidia_splash_routes'] = array();
class WP_REST_Server { public const READABLE = 'GET'; }
class WP_REST_Response { public array $headers = array(); public function __construct( public $data ) {} public function header( string $name, string $value ): void { $this->headers[ $name ] = $value; } }
function add_action( string $hook, $callback ): void { unset( $hook, $callback ); }
function register_rest_route( string $namespace, string $route, array $definition ): void { $GLOBALS['kidia_splash_routes'][ $namespace . $route ] = $definition; }
function rest_ensure_response( $data ): WP_REST_Response { return new WP_REST_Response( $data ); }
function __( string $value, string $domain = '' ): string { unset( $domain ); return $value; }
function get_bloginfo( string $field ): string { unset( $field ); return 'Kidia'; }
function get_option( string $name, $default = false ) { unset( $name ); return array( 'duration_ms' => 2500, 'image_url' => 'https://example.com/logo.png' ); }
require dirname( __DIR__ ) . '/api/class-splash-screen-endpoint.php';
$endpoint = new Kidia_Mobile_CMS_Splash_Screen_Endpoint();
$endpoint->register_routes();
if ( ! isset( $GLOBALS['kidia_splash_routes']['woo-mobile/v1/splash-screen'] ) ) { throw new RuntimeException( 'Splash route must register.' ); }
$response = $endpoint->get_settings();
if ( 2500 !== $response->data['duration_ms'] || 'Kidia' !== $response->data['store_name'] ) { throw new RuntimeException( 'Splash defaults and saved settings must merge.' ); }
if ( 'no-store, no-cache, must-revalidate, max-age=0' !== $response->headers['Cache-Control'] ) { throw new RuntimeException( 'Splash response must not be cached.' ); }
fwrite( STDOUT, "Splash-screen contract test passed.\n" );
