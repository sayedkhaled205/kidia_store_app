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
foreach ( Kidia_Mobile_Page_Layout_Store::pages() as $page_with_elements => $_page_label ) {
	foreach ( array( Kidia_Mobile_Page_Layout_Store::header_fields(), Kidia_Mobile_Page_Layout_Store::footer_fields() ) as $chrome_fields ) {
		$chrome_keys = array_column( $chrome_fields, 'key' );
		$chrome_labels = array_column( $chrome_fields, 'label', 'key' );
		foreach ( array( 'margin_top', 'margin_bottom', 'space_up', 'space_down', 'background_color' ) as $layout_key ) {
			kidia_page_assert( in_array( $layout_key, $chrome_keys, true ), "$page_with_elements fixed chrome must expose $layout_key." );
		}
		kidia_page_assert( 'Merge up' === $chrome_labels['margin_top'], "$page_with_elements fixed chrome must label margin_top as Merge up." );
		kidia_page_assert( 'Merge down' === $chrome_labels['margin_bottom'], "$page_with_elements fixed chrome must label margin_bottom as Merge down." );
	}
	foreach ( Kidia_Mobile_Page_Layout_Store::element_definitions( $page_with_elements ) as $definition ) {
		$field_keys = array_column( $definition['fields'], 'key' );
		$field_labels = array_column( $definition['fields'], 'label', 'key' );
		$element_name = $page_with_elements . '.' . $definition['id'];
		kidia_page_assert( in_array( 'background_color', $field_keys, true ), "$element_name must expose an element background setting." );
		kidia_page_assert( 1 === count( array_keys( $field_keys, 'background_color', true ) ), "$element_name must expose the element background exactly once." );
		foreach ( array( 'margin_top', 'margin_bottom', 'space_up', 'space_down' ) as $layout_key ) {
			kidia_page_assert( in_array( $layout_key, $field_keys, true ), "$element_name must expose $layout_key." );
			kidia_page_assert( 1 === count( array_keys( $field_keys, $layout_key, true ) ), "$element_name must expose $layout_key exactly once." );
		}
		kidia_page_assert( 'Merge up' === $field_labels['margin_top'], "$element_name must label margin_top as Merge up." );
		kidia_page_assert( 'Merge down' === $field_labels['margin_bottom'], "$element_name must label margin_bottom as Merge down." );
	}
}
$catalog_default = $store->get_layout( 'catalog' );
$catalog_ids = array_column( $catalog_default['elements'], 'id' );
$legacy_catalog = $catalog_default;
foreach ( $legacy_catalog['elements'] as &$legacy_element ) {
	unset( $legacy_element['settings']['space_up'], $legacy_element['settings']['space_down'] );
	$legacy_element['settings']['padding_vertical'] = 13;
}
unset( $legacy_element );
$GLOBALS['kidia_page_options']['kidia_mobile_page_layout_catalog'] = $legacy_catalog;
$migrated_catalog = $store->get_layout( 'catalog' );
foreach ( $migrated_catalog['elements'] as $migrated_element ) {
	kidia_page_assert( 13.0 === $migrated_element['settings']['space_up'] && 13.0 === $migrated_element['settings']['space_down'], 'Legacy vertical spacing must migrate without a visual reset.' );
}
unset( $GLOBALS['kidia_page_options']['kidia_mobile_page_layout_catalog'] );
$catalog_default = $store->get_layout( 'catalog' );
$catalog_ids = array_column( $catalog_default['elements'], 'id' );
$catalog_grid = $catalog_default['elements'][ array_search( 'product_grid', $catalog_ids, true ) ];
kidia_page_assert( true === $catalog_grid['settings']['quick_add_enabled'], 'Catalog Product Grid quick add must default to enabled.' );
kidia_page_assert( false === $catalog_grid['settings']['show_wishlist'], 'Catalog Product Grid wishlist must default to hidden.' );
kidia_page_assert( 'bottom_end' === $catalog_grid['settings']['quick_add_position'], 'Quick Add must default to the lower end corner.' );
kidia_page_assert( 'top_end' === $catalog_grid['settings']['product_wishlist_position'], 'Wishlist must default to the upper end corner.' );
$custom_catalog = $catalog_default;
$custom_catalog['elements'][ array_search( 'product_grid', $catalog_ids, true ) ]['settings'] = array_merge(
	$catalog_grid['settings'],
	array(
		'quick_add_icon_size' => 31,
		'quick_add_background_size' => 55,
		'quick_add_icon_color' => '#123456',
		'quick_add_position' => 'top_start',
		'product_wishlist_position' => 'bottom_start',
	)
);
$store->save_layout( 'catalog', $custom_catalog );
$saved_catalog = $store->get_layout( 'catalog' );
$saved_grid = $saved_catalog['elements'][ array_search( 'product_grid', array_column( $saved_catalog['elements'], 'id' ), true ) ];
kidia_page_assert( 31.0 === $saved_grid['settings']['quick_add_icon_size'], 'Saved Quick Add icon size must reach the public layout.' );
kidia_page_assert( 55.0 === $saved_grid['settings']['quick_add_background_size'], 'Saved Quick Add background size must reach the public layout.' );
kidia_page_assert( '#123456' === $saved_grid['settings']['quick_add_icon_color'], 'Saved Quick Add color must reach the public layout.' );
kidia_page_assert( 'top_start' === $saved_grid['settings']['quick_add_position'], 'Saved Quick Add position must reach the public layout.' );
kidia_page_assert( 'bottom_start' === $saved_grid['settings']['product_wishlist_position'], 'Saved wishlist position must reach the public layout.' );
unset( $GLOBALS['kidia_page_options']['kidia_mobile_page_layout_catalog'] );
$wishlist_default = $store->get_layout( 'wishlist' );
$wishlist_ids = array_column( $wishlist_default['elements'], 'id' );
$wishlist_grid = $wishlist_default['elements'][ array_search( 'wishlist_grid', $wishlist_ids, true ) ];
kidia_page_assert( true === $wishlist_grid['settings']['quick_add_enabled'], 'Wishlist Products quick add must default to enabled.' );
$product_default = $store->get_layout( 'product' );
$product_ids = array_column( $product_default['elements'], 'id' );
$product_summary = $product_default['elements'][ array_search( 'product_summary', $product_ids, true ) ];
kidia_page_assert( ! array_key_exists( 'quick_add_enabled', $product_summary['settings'] ), 'Product Information must not own the quick-add setting.' );
kidia_page_assert( 'product_action' === $product_default['footer']['settings']['style'], 'Product Page must default to the product action footer.' );
kidia_page_assert( 62 === $product_default['footer']['settings']['button_width_percent'], 'Product footer must expose the PatPat action width.' );
kidia_page_assert( 56 === $product_default['footer']['settings']['button_height'], 'Product footer must expose the PatPat action height.' );
foreach ( array( 'button_style', 'button_shape', 'button_border_color', 'button_border_width' ) as $button_setting ) {
	kidia_page_assert( array_key_exists( $button_setting, $product_default['footer']['settings'] ), "Product footer must expose $button_setting." );
}
$product_footer_columns = json_decode( $product_default['footer']['settings']['layout_json'], true )['rows'][0]['columns'];
kidia_page_assert( array( 'share', 'like', 'add_to_cart' ) === array_map( static fn( array $column ): string => $column['items'][0], $product_footer_columns ), 'Product footer must default to Share, Like and Add to bag.' );
$home_default = $store->get_layout( 'home' );
kidia_page_assert( 'Kidia' === $home_default['header']['settings']['logo_text'], 'Header logo must expose a text fallback.' );
kidia_page_assert( '#1F2933' === $home_default['header']['settings']['logo_text_color'], 'Header logo text must expose its own color.' );
$home_rows = json_decode( $home_default['header']['settings']['layout_json'], true )['rows'];
kidia_page_assert( 2 === count( $home_rows ) && array( 'logo' ) === $home_rows[0]['columns'][0]['items'] && 100 === $home_rows[1]['columns'][0]['width'] && array( 'search_bar' ) === $home_rows[1]['columns'][0]['items'], 'Home header must default to the two-row percentage-column layout.' );
kidia_page_assert( 100 === $home_default['header']['settings']['search_width_percent'], 'Home search must default to the full available width.' );
kidia_page_assert( 8 === $home_default['header']['settings']['row_gap'], 'Home header rows must preserve the measured compact-store gap.' );
kidia_page_assert( 120 === $home_default['header']['settings']['height'] && 42 === $home_default['header']['settings']['logo_height'], 'Home header height and logo must use the compact-store proportions.' );
kidia_page_assert( 44 === $home_default['header']['settings']['search_height'] && 22 === $home_default['header']['settings']['search_radius'], 'Home search must use the compact-store height and pill radius.' );
$compact_rows = json_decode( $home_default['header']['settings']['compact_layout_json'], true )['rows'];
kidia_page_assert( true === $home_default['header']['settings']['collapse_on_scroll'], 'Home header must allow the collapsed scroll header by default.' );
kidia_page_assert( array( 'search_bar' ) === $compact_rows[0]['columns'][0]['items'] && array( 'cart' ) === $compact_rows[0]['columns'][1]['items'], 'Collapsed header must have an independently stored Search + Cart layout.' );
kidia_page_assert( 'medium' === $home_default['header']['settings']['collapse_speed'], 'Collapsed header must default to medium transition speed.' );
kidia_page_assert( 'smooth_compact' === $home_default['header']['settings']['collapse_transition'], 'Home must default to the smooth compact Search + Cart transition.' );
kidia_page_assert( ! array_key_exists( 'scroll_up_header', $home_default['header']['settings'] ), 'The obsolete scroll-up header choice must not be exposed.' );
foreach ( array( 'collapse_transition', 'collapse_speed', 'compact_style', 'compact_background_color', 'compact_side_margin', 'compact_radius', 'compact_border_width', 'compact_border_color', 'compact_shadow' ) as $compact_setting ) {
	kidia_page_assert( array_key_exists( $compact_setting, $home_default['header']['settings'] ), "Collapsed header must expose $compact_setting." );
}
kidia_page_assert( false === $home_default['footer']['settings']['hide_on_scroll'], 'Footer auto-hide must remain optional by default.' );
$GLOBALS['kidia_page_options']['kidia_mobile_page_layout_home'] = array(
	'version' => 2,
	'header' => array( 'enabled' => true, 'settings' => array( 'height' => 64, 'layout_json' => wp_json_encode( array( 'rows' => array() ) ) ) ),
	'footer' => array( 'enabled' => true, 'settings' => array( 'horizontal_padding' => 0 ) ),
);
$migrated_home = $store->get_layout( 'home' );
kidia_page_assert( 64.0 === $migrated_home['header']['settings']['height'], 'Schema upgrades must preserve a saved header instead of replacing it.' );
kidia_page_assert( 0.0 === $migrated_home['footer']['settings']['side_spacing_percent'], 'Legacy footers must receive the full-width side-spacing default.' );
unset( $GLOBALS['kidia_page_options']['kidia_mobile_page_layout_home'] );
foreach ( array( 'cart_icon_variant', 'search_icon_variant', 'support_icon_variant' ) as $icon_setting ) {
	kidia_page_assert( array_key_exists( $icon_setting, $home_default['header']['settings'] ), "Header must expose $icon_setting." );
}
foreach ( array( 'show_cart_badge', 'cart_badge_shape', 'cart_badge_size', 'cart_badge_background', 'cart_badge_text_color' ) as $badge_setting ) {
	kidia_page_assert( array_key_exists( $badge_setting, $home_default['header']['settings'] ), "Cart Settings must expose $badge_setting." );
}
foreach ( array( 'home_icon_variant', 'wishlist_icon_variant', 'account_icon_variant' ) as $icon_setting ) {
	kidia_page_assert( array_key_exists( $icon_setting, $home_default['footer']['settings'] ), "Footer must expose $icon_setting." );
}
$catalog_default = $store->get_layout( 'catalog' );
$catalog_ids = array_column( $catalog_default['elements'], 'id' );
foreach ( $catalog_default['elements'] as $element ) {
	foreach ( array( 'margin_top', 'margin_bottom', 'padding_vertical', 'padding_horizontal', 'background_color' ) as $presentation_setting ) {
		kidia_page_assert( array_key_exists( $presentation_setting, $element['settings'] ), "Every page element must expose $presentation_setting." );
	}
}
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
	'product' => array( 'product_tabs', 'image_gallery', 'product_summary', 'variations', 'purchase_bar', 'description', 'reviews', 'related_products' ),
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
$product_layout = $store->get_layout( 'product' );
$product_ids = array_column( $product_layout['elements'], 'id' );
$product_gallery = $product_layout['elements'][ array_search( 'image_gallery', $product_ids, true ) ];
kidia_page_assert( true === $product_gallery['settings']['show_counter'], 'Product gallery must show its image counter by default.' );
kidia_page_assert( false === $product_gallery['settings']['show_thumbnails'], 'PatPat gallery must hide thumbnails by default.' );
kidia_page_assert( '#1D1D1D' === $product_layout['footer']['settings']['button_color'], 'Product action must use the PatPat black button.' );
kidia_page_assert( 'Add to bag' === $product_layout['footer']['settings']['add_to_cart_label'], 'Product action must use the requested label.' );

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
