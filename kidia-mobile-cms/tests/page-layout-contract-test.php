<?php
/** Catalog, product, wishlist and account page-builder contract test. */
declare( strict_types=1 );
define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_page_options'] = array();
$GLOBALS['kidia_page_routes'] = array();

class WP_REST_Server { public const READABLE = 'GET'; }
class WP_REST_Request {
	public function __construct( private array $params ) {}
	public function get_param( string $key ) { return $this->params[ $key ] ?? null; }
}
class WP_REST_Response {
	public array $headers = array();
	public function __construct( public $data ) {}
	public function header( string $name, string $value ): void { $this->headers[ $name ] = $value; }
}
class WP_Error {
	public function __construct( public string $code, public string $message, public array $data = array() ) {}
}

function __( string $value, string $domain = '' ): string { unset( $domain ); return $value; }
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_hex_color( $value ) { return preg_match( '/^#[0-9a-f]{6}$/i', (string) $value ) ? (string) $value : null; }
function esc_url_raw( $value ): string { return filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : ''; }
function get_option( string $name, $default = false ) { return $GLOBALS['kidia_page_options'][ $name ] ?? $default; }
function update_option( string $name, $value, bool $autoload = false ): bool { unset( $autoload ); $GLOBALS['kidia_page_options'][ $name ] = $value; return true; }
function add_action( string $hook, $callback ): void { unset( $hook, $callback ); }
function register_rest_route( string $namespace, string $route, array $definition ): void { $GLOBALS['kidia_page_routes'][ $namespace . $route ] = $definition; }
function rest_ensure_response( $value ): WP_REST_Response { return new WP_REST_Response( $value ); }
function kidia_page_assert( bool $condition, string $message ): void { if ( ! $condition ) throw new RuntimeException( $message ); }

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-page-layout-store.php';
require dirname( __DIR__ ) . '/api/class-page-layout-endpoint.php';

$store = new Kidia_Mobile_Page_Layout_Store();
$expected = array(
	'catalog' => array( 'filter_bar', 'product_grid' ),
	'product' => array( 'image_gallery', 'purchase_bar', 'reviews' ),
	'wishlist' => array( 'wishlist_grid', 'empty_state' ),
	'account' => array( 'account_summary', 'account_menu', 'logout_button' ),
);
foreach ( $expected as $page => $required ) {
	$layout = $store->get_layout( $page );
	kidia_page_assert( true === $layout['header']['locked'] && true === $layout['footer']['locked'], "$page chrome must be locked." );
	$ids = array_column( $layout['elements'], 'id' );
	foreach ( $required as $id ) {
		kidia_page_assert( in_array( $id, $ids, true ), "$page must expose $id." );
	}
	$submitted = array(
		'header' => array( 'enabled' => '1', 'settings' => array( 'title' => strtoupper( $page ) ) ),
		'elements' => array_reverse( $layout['elements'] ),
		'footer' => array( 'settings' => array( 'height' => 80 ) ),
	);
	$saved = $store->save_layout( $page, $submitted );
	kidia_page_assert( strtoupper( $page ) === $saved['header']['settings']['title'], "$page header settings must save." );
	kidia_page_assert( false === $saved['footer']['enabled'], "$page footer must support Hide without removal." );
	kidia_page_assert( 80.0 === $saved['footer']['settings']['height'], "$page footer controls must save." );
	kidia_page_assert( end( $ids ) === $saved['elements'][0]['id'], "$page element order must save." );
}

$endpoint = new Kidia_Mobile_CMS_Page_Layout_Endpoint();
$endpoint->register_routes();
kidia_page_assert( isset( $GLOBALS['kidia_page_routes']['woo-mobile/v1/page-layout/(?P<page>[a-z-]+)'] ), 'The public page-layout route must register.' );
$response = $endpoint->get_layout( new WP_REST_Request( array( 'page' => 'catalog', 'locale' => 'ar' ) ) );
kidia_page_assert( $response instanceof WP_REST_Response, 'A supported page must return a REST response.' );
kidia_page_assert( 'no-store, no-cache, must-revalidate, max-age=0' === $response->headers['Cache-Control'], 'Page layouts must never be served stale.' );
kidia_page_assert( 'ar' === $response->data['locale'], 'The requested locale must be returned.' );
kidia_page_assert( $endpoint->get_layout( new WP_REST_Request( array( 'page' => 'unknown' ) ) ) instanceof WP_Error, 'Unknown page builders must return 404 errors.' );

fwrite( STDOUT, "Page-layout contract test passed for catalog, product, wishlist and account.\n" );
