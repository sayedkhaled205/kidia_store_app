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
function wp_json_encode( $value ): string { return json_encode( $value, JSON_UNESCAPED_SLASHES ); }
function get_option( string $name, $default = false ) { return $GLOBALS['kidia_page_options'][ $name ] ?? $default; }
function update_option( string $name, $value, bool $autoload = false ): bool { unset( $autoload ); $GLOBALS['kidia_page_options'][ $name ] = $value; return true; }
function add_action( string $hook, $callback ): void { unset( $hook, $callback ); }
function register_rest_route( string $namespace, string $route, array $definition ): void { $GLOBALS['kidia_page_routes'][ $namespace . $route ] = $definition; }
function rest_ensure_response( $value ): WP_REST_Response { return new WP_REST_Response( $value ); }
function kidia_page_assert( bool $condition, string $message ): void { if ( ! $condition ) throw new RuntimeException( $message ); }

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-page-layout-store.php';
require dirname( __DIR__ ) . '/api/class-page-layout-endpoint.php';

$store = new Kidia_Mobile_Page_Layout_Store();
$product_default = $store->get_layout( 'product' );
kidia_page_assert( 'product_action' === $product_default['footer']['settings']['style'], 'Product Page must default to the product action footer.' );
$product_footer_columns = json_decode( $product_default['footer']['settings']['layout_json'], true )['rows'][0]['columns'];
kidia_page_assert( array( 'share', 'like', 'add_to_cart' ) === array_map( static fn( array $column ): string => $column['items'][0], $product_footer_columns ), 'Product footer must default to Share, Like and Add to bag.' );
$home_default = $store->get_layout( 'home' );
$home_rows = json_decode( $home_default['header']['settings']['layout_json'], true )['rows'];
kidia_page_assert( 2 === count( $home_rows ) && array( 'logo' ) === $home_rows[0]['columns'][0]['items'] && 100 === $home_rows[1]['columns'][0]['width'] && array( 'search_bar' ) === $home_rows[1]['columns'][0]['items'], 'Home header must default to the two-row percentage-column layout.' );
kidia_page_assert( 100 === $home_default['header']['settings']['search_width_percent'], 'Home search must default to the full available width.' );
kidia_page_assert( 8 === $home_default['header']['settings']['row_gap'], 'Home header rows must preserve the measured PatPat gap.' );
kidia_page_assert( 120 === $home_default['header']['settings']['height'] && 42 === $home_default['header']['settings']['logo_height'], 'Home header height and logo must use the PatPat proportions.' );
kidia_page_assert( 44 === $home_default['header']['settings']['search_height'] && 22 === $home_default['header']['settings']['search_radius'], 'Home search must use the PatPat height and pill radius.' );
$GLOBALS['kidia_page_options']['kidia_mobile_page_layout_home'] = array(
	'version' => 2,
	'header' => array( 'enabled' => true, 'settings' => array( 'height' => 64, 'layout_json' => wp_json_encode( array( 'rows' => array() ) ) ) ),
	'footer' => array( 'enabled' => true, 'settings' => array( 'horizontal_padding' => 0 ) ),
);
$migrated_home = $store->get_layout( 'home' );
kidia_page_assert( 64.0 === $migrated_home['header']['settings']['height'], 'Schema upgrades must preserve a saved header instead of replacing it.' );
kidia_page_assert( 0.0 === $migrated_home['footer']['settings']['side_spacing_percent'], 'Legacy footers must receive the full-width PatPat side-spacing default.' );
unset( $GLOBALS['kidia_page_options']['kidia_mobile_page_layout_home'] );
foreach ( array( 'cart_icon_variant', 'search_icon_variant', 'support_icon_variant' ) as $icon_setting ) {
	kidia_page_assert( array_key_exists( $icon_setting, $home_default['header']['settings'] ), "Header must expose $icon_setting." );
}
foreach ( array( 'home_icon_variant', 'wishlist_icon_variant', 'account_icon_variant' ) as $icon_setting ) {
	kidia_page_assert( array_key_exists( $icon_setting, $home_default['footer']['settings'] ), "Footer must expose $icon_setting." );
}
$catalog_default = $store->get_layout( 'catalog' );
$catalog_ids = array_column( $catalog_default['elements'], 'id' );
kidia_page_assert( ! in_array( 'pagination', $catalog_ids, true ), 'Pagination must be a Product Grid setting, not a separate element.' );
$catalog_grid = $catalog_default['elements'][ array_search( 'product_grid', $catalog_ids, true ) ];
kidia_page_assert( 'load_more' === $catalog_grid['settings']['pagination_mode'], 'Product Grid must expose pagination mode.' );
kidia_page_assert( 12 === $catalog_grid['settings']['products_per_page'], 'Product Grid must expose products per page.' );
$catalog_filter = $catalog_default['elements'][ array_search( 'filter_bar', $catalog_ids, true ) ];
foreach ( array( 'filter_price', 'filter_sale', 'filter_brand', 'filter_size', 'block_width', 'block_height', 'icon_size' ) as $filter_setting ) {
	kidia_page_assert( array_key_exists( $filter_setting, $catalog_filter['settings'] ), "Filter Bar must expose $filter_setting." );
}
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
	$submitted['header']['settings']['title'] = strtoupper( $page ) . ' SECOND';
	$submitted['elements'][0]['settings']['__second_save_probe'] = 'ignored';
	$second_saved = $store->save_layout( $page, $submitted );
	kidia_page_assert( strtoupper( $page ) . ' SECOND' === $second_saved['header']['settings']['title'], "$page must accept consecutive saves." );
}

foreach ( array( 'home', 'category' ) as $page ) {
	$layout = $store->get_layout( $page );
	kidia_page_assert( true === $layout['header']['locked'] && true === $layout['footer']['locked'], "$page fixed chrome must exist." );
	$saved = $store->save_layout( $page, array( 'header' => array( 'enabled' => '1', 'settings' => array( 'title' => strtoupper( $page ) ) ), 'footer' => array( 'enabled' => '1' ) ) );
	kidia_page_assert( strtoupper( $page ) === $saved['header']['settings']['title'], "$page header settings must save." );
}
kidia_page_assert( $store->get_layout( 'home' )['header']['settings']['title'] !== $store->get_layout( 'category' )['header']['settings']['title'], 'Every page must keep independent header settings.' );

// Exercise every header/footer field through the complete save -> reload cycle.
$probe_settings = static function ( array $fields, bool $second ): array {
	$values = array();
	foreach ( $fields as $field ) {
		$key = $field['key'];
		switch ( $field['type'] ) {
			case 'checkbox': $values[ $key ] = $second ? '0' : '1'; break;
			case 'number': $values[ $key ] = $second ? (string) $field['min'] : (string) $field['max']; break;
			case 'color': $values[ $key ] = $second ? '#246B5A' : '#C84F6A'; break;
			case 'select': $options = array_keys( $field['options'] ); $values[ $key ] = (string) ( $second ? end( $options ) : reset( $options ) ); break;
			case 'json': $values[ $key ] = wp_json_encode( array( 'rows' => array( array( 'columns' => array( array( 'width' => $second ? 40 : 50, 'align' => 'left', 'items' => array( $second ? 'logo' : 'home' ) ), array( 'width' => $second ? 60 : 50, 'align' => 'right', 'items' => array( $second ? 'cart' : 'wishlist' ) ) ) ) ) ) ); break;
			case 'image': $values[ $key ] = $second ? 'https://example.com/logo-second.png' : 'https://example.com/logo-first.png'; break;
			default: $values[ $key ] = $second ? 'Second saved value' : 'First saved value';
		}
	}
	return $values;
};
foreach ( Kidia_Mobile_Page_Layout_Store::pages() as $page => $_label ) {
	$header_first = $probe_settings( Kidia_Mobile_Page_Layout_Store::header_fields(), false );
	$footer_first = $probe_settings( Kidia_Mobile_Page_Layout_Store::footer_fields(), false );
	$first = $store->save_layout( $page, array( 'header' => array( 'enabled' => '1', 'settings' => $header_first ), 'footer' => array( 'enabled' => '1', 'settings' => $footer_first ) ) );
	$reloaded_first = $store->get_layout( $page );
	foreach ( array( 'header', 'footer' ) as $part ) {
		foreach ( $first[ $part ]['settings'] as $key => $expected_value ) {
			kidia_page_assert( $expected_value === $reloaded_first[ $part ]['settings'][ $key ], "$page $part.$key must survive save and reload." );
		}
	}
	$header_second = $probe_settings( Kidia_Mobile_Page_Layout_Store::header_fields(), true );
	$footer_second = $probe_settings( Kidia_Mobile_Page_Layout_Store::footer_fields(), true );
	$second = $store->save_layout( $page, array( 'header' => array( 'enabled' => '1', 'settings' => $header_second ), 'footer' => array( 'enabled' => '1', 'settings' => $footer_second ) ) );
	$reloaded_second = $store->get_layout( $page );
	foreach ( array( 'header', 'footer' ) as $part ) {
		foreach ( $second[ $part ]['settings'] as $key => $expected_value ) {
			kidia_page_assert( $expected_value === $reloaded_second[ $part ]['settings'][ $key ], "$page $part.$key must survive a second consecutive save and reload." );
		}
	}
}

$endpoint = new Kidia_Mobile_CMS_Page_Layout_Endpoint();
$endpoint->register_routes();
kidia_page_assert( isset( $GLOBALS['kidia_page_routes']['woo-mobile/v1/page-layout/(?P<page>[a-z-]+)'] ), 'The public page-layout route must register.' );
$response = $endpoint->get_layout( new WP_REST_Request( array( 'page' => 'catalog', 'locale' => 'ar' ) ) );
kidia_page_assert( $response instanceof WP_REST_Response, 'A supported page must return a REST response.' );
kidia_page_assert( 'no-store, no-cache, must-revalidate, max-age=0' === $response->headers['Cache-Control'], 'Page layouts must never be served stale.' );
kidia_page_assert( 'ar' === $response->data['locale'], 'The requested locale must be returned.' );
kidia_page_assert( $endpoint->get_layout( new WP_REST_Request( array( 'page' => 'unknown' ) ) ) instanceof WP_Error, 'Unknown page builders must return 404 errors.' );

fwrite( STDOUT, "Page-layout contract test passed for all application pages.\n" );
