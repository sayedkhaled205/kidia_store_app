<?php
/** Packaged connector: outline defaults, save/readback and API export. */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['mobishop_product_query'] = array();
class MobiShop_Setup_Wizard { public function identity(): array { return array( 'primary_color' => '#347A89' ); } }

class WP_Term {
	public function __construct(
		public int $term_id,
		public string $name,
		public string $slug = ''
	) {}
}

class WC_Product {
	public function get_id(): int { return 42; }
	public function get_name(): string { return 'Kids Outfit'; }
	public function get_image_id(): int { return 41; }
	public function get_price(): string { return '499'; }
	public function get_regular_price(): string { return '599'; }
	public function get_average_rating(): string { return '4.7'; }
	public function get_review_count(): int { return 28; }
	public function is_in_stock(): bool { return true; }
	public function is_on_sale(): bool { return true; }
}

function mobishop_home_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

function __( string $text, string $domain = '' ): string { unset( $domain ); return $text; }
function esc_attr( $value ): string { return htmlspecialchars( (string) $value, ENT_QUOTES | ENT_HTML5, 'UTF-8' ); }
function esc_html( $value ): string { return htmlspecialchars( (string) $value, ENT_QUOTES | ENT_HTML5, 'UTF-8' ); }
function esc_html__( string $text, string $domain = '' ): string { return esc_html( __( $text, $domain ) ); }
function esc_textarea( $value ): string { return htmlspecialchars( (string) $value, ENT_QUOTES | ENT_HTML5, 'UTF-8' ); }
function esc_url( $value ): string { return esc_url_raw( $value ); }
function esc_html_e( string $text, string $domain = '' ): void { echo htmlspecialchars( __( $text, $domain ), ENT_QUOTES | ENT_HTML5, 'UTF-8' ); }
function checked( $checked, $current = true ): void { if ( $checked === $current ) echo ' checked="checked"'; }
function selected( $selected, $current = true ): void { if ( $selected === $current ) echo ' selected="selected"'; }
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_textarea_field( $value ): string { return sanitize_text_field( $value ); }
function sanitize_hex_color( $value ): string { return preg_match( '/^#[0-9a-f]{6}$/i', (string) $value ) ? strtoupper( (string) $value ) : ''; }
function absint( $value ): int { return abs( (int) $value ); }
function wp_parse_args( $args, $defaults = array() ): array { return array_merge( (array) $defaults, (array) $args ); }
function wp_generate_uuid4(): string { return '00000000-0000-4000-8000-000000000001'; }
function wp_specialchars_decode( string $value, int $flags = ENT_QUOTES ): string { return html_entity_decode( $value, $flags ); }
function wp_parse_url( string $url, int $component = -1 ) { return parse_url( $url, $component ); }
function esc_url_raw( $value, ?array $protocols = null ): string {
	$url = filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : '';
	if ( '' === $url || null === $protocols ) {
		return $url;
	}
	return in_array( (string) parse_url( $url, PHP_URL_SCHEME ), $protocols, true ) ? $url : '';
}
function get_bloginfo( string $show ): string { unset( $show ); return 'MobiShop Test Store'; }
function get_woocommerce_currency(): string { return 'EGP'; }
function get_woocommerce_currency_symbol( string $currency ): string { unset( $currency ); return 'EGP'; }
function wc_get_products( array $args ): array { $GLOBALS['mobishop_product_query'] = $args; return array( new WC_Product() ); }
function wc_get_product_ids_on_sale(): array { return array( 42 ); }
function wp_get_attachment_image_url( int $attachment_id, string $size ): string {
	unset( $size );
	return 'https://example.com/media-' . $attachment_id . '.jpg';
}
function wc_placeholder_img_src( string $size ): string { unset( $size ); return 'https://example.com/placeholder.jpg'; }
function taxonomy_exists( string $taxonomy ): bool { return 'product_brand' === $taxonomy; }
function get_terms( array $args ): array {
	return 'product_brand' === ( $args['taxonomy'] ?? '' )
		? array( new WP_Term( 7, 'MobiShop Brand', 'mobishop-brand' ) )
		: array();
}
function get_term( int $term_id, string $taxonomy ) {
	return 'product_cat' === $taxonomy ? new WP_Term( $term_id, 'Category', 'category' ) : false;
}
function get_term_meta( int $term_id, string $key, bool $single = false ): int {
	unset( $term_id, $key, $single );
	return 77;
}
function is_wp_error( $value ): bool { return false; }


function get_option($key,$default=false) { return $GLOBALS['outline_options'][$key] ?? $default; }
function update_option($key,$value,$autoload=false) { $GLOBALS['outline_options'][$key]=$value; return true; }
function wp_json_encode($value) { return json_encode($value); }
function mobishop_page_assert($condition,$message) { mobishop_home_assert($condition,$message); }
$root=getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__).'/source';
require $root.'/includes/class-mobishop-block.php';
require $root.'/includes/class-mobishop-page-layout-store.php';
require $root.'/includes/blocks/class-mobishop-product-carousel-block.php';
require $root.'/includes/blocks/class-mobishop-product-grid-block.php';
$store = new MobiShop_Page_Layout_Store();
foreach ( array( 'catalog', 'wishlist' ) as $outline_page ) {
	$outline_layout = $store->get_layout( $outline_page );
	foreach ( $outline_layout['elements'] as &$outline_element ) {
		if ( ! in_array( $outline_element['type'], array( 'product_grid', 'wishlist_grid', 'product_carousel' ), true ) ) { continue; }
		mobishop_page_assert( '#347A89' === $outline_element['settings']['card_outline_color'], 'Product outlines must default to the merchant brand.' );
		$outline_element['settings']['card_outline_color'] = '#DC713A';
	}
	unset( $outline_element );
	$store->save_layout( $outline_page, $outline_layout );
	foreach ( $store->get_layout( $outline_page )['elements'] as $outline_element ) {
		if ( isset( $outline_element['settings']['card_outline_color'] ) ) {
			mobishop_page_assert( '#DC713A' === $outline_element['settings']['card_outline_color'], 'Custom outline must survive connector save and reload.' );
		}
	}
	unset( $GLOBALS['mobishop_page_options'][ 'mobishop_page_layout_' . $outline_page ] );
}
foreach ( array( new MobiShop_Product_Carousel_Block(), new MobiShop_Product_Grid_Block() ) as $outline_block ) {
	mobishop_home_assert( '#347A89' === $outline_block->get_default_settings()['card_outline_color'], 'Home product outlines must default to merchant brand.' );
	foreach ( array( '#DC713A', 'invalid' ) as $outline_value ) {
		$outline_settings = $outline_block->sanitize_settings( array_merge( $outline_block->get_default_settings(), array( 'card_outline_color' => $outline_value ) ) );
		$outline_expected = 'invalid' === $outline_value ? '#347A89' : $outline_value;
		mobishop_home_assert( $outline_expected === $outline_settings['card_outline_color'], 'Home outline color must be sanitized and retained.' );
		mobishop_home_assert( $outline_expected === $outline_block->build_api_data( $outline_settings )['card_outline_color'], 'Home product API must export outline color.' );
	}
}
fwrite(STDOUT,"Packaged connector outline contracts passed.\n");
