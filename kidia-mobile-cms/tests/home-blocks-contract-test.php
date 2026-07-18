<?php
/** Home block API contracts and App Header Builder regression test. */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_product_query'] = array();

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

function kidia_home_assert( bool $condition, string $message ): void {
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
function get_bloginfo( string $show ): string { unset( $show ); return 'Kidia Test Store'; }
function get_woocommerce_currency(): string { return 'EGP'; }
function get_woocommerce_currency_symbol( string $currency ): string { unset( $currency ); return 'EGP'; }
function wc_get_products( array $args ): array { $GLOBALS['kidia_product_query'] = $args; return array( new WC_Product() ); }
function wc_get_product_ids_on_sale(): array { return array( 42 ); }
function wp_get_attachment_image_url( int $attachment_id, string $size ): string {
	unset( $size );
	return 'https://example.com/media-' . $attachment_id . '.jpg';
}
function wc_placeholder_img_src( string $size ): string { unset( $size ); return 'https://example.com/placeholder.jpg'; }
function taxonomy_exists( string $taxonomy ): bool { return 'product_brand' === $taxonomy; }
function get_terms( array $args ): array {
	return 'product_brand' === ( $args['taxonomy'] ?? '' )
		? array( new WP_Term( 7, 'Kidia Brand', 'kidia-brand' ) )
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

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-app-header-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-coupon-banner-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-product-carousel-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-brand-carousel-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-section-header-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-promo-strip-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-quick-links-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-banner-grid-block.php';

// Regression: render_settings() used to fatal before the Builder footer and JS
// because App Header called a missing sanitize_http_url() base helper.
$header = new Kidia_Mobile_App_Header_Block();
ob_start();
$header->render_settings( 0, $header->get_default_settings() );
$header_markup = (string) ob_get_clean();
kidia_home_assert( str_contains( $header_markup, 'kidia-app-header-logo-url' ), 'App Header settings must render without a fatal error.' );
kidia_home_assert( str_contains( $header_markup, 'kidia-app-header-logo-preview' ), 'The App Header logo preview must open the shared media picker.' );
$header_api = $header->build_api_block(
	array( 'id' => 'header', 'enabled' => true, 'settings' => array( 'logo_url' => 'javascript:alert(1)' ) )
);
kidia_home_assert( 'Kidia Test Store' === $header_api['data']['title'], 'App Header must provide Flutter with a required title.' );
kidia_home_assert( '' === $header_api['data']['logo_url'], 'Unsafe App Header URLs must be rejected.' );
kidia_home_assert( '#FFFFFF' === $header_api['data']['background_color'], 'App Header must expose its configurable background.' );
kidia_home_assert( 'icon' === $header_api['data']['search_style'], 'App Header must expose its configurable search presentation.' );

$coupon = new Kidia_Mobile_Coupon_Banner_Block();
ob_start();
$coupon->render_settings( 1, $coupon->get_default_settings() );
$coupon_markup = (string) ob_get_clean();
kidia_home_assert( str_contains( $coupon_markup, 'kidia-select-media' ), 'Coupon Banner images must use the WordPress media picker.' );
kidia_home_assert( str_contains( $coupon_markup, 'kidia-media-preview' ), 'Coupon Banner images must render a clickable preview.' );

$carousel = new Kidia_Mobile_Product_Carousel_Block();
$carousel_api = $carousel->build_api_block(
	array(
		'id'       => 'products',
		'enabled'  => true,
		'settings' => array(
			'title'          => 'Latest',
			'subtitle'       => 'Fresh arrivals',
			'source'         => 'latest',
			'limit'          => 4,
			'show_view_all'  => true,
			'view_all_label' => 'See everything',
			'card_style'     => 'elevated',
			'show_name'      => true,
			'show_price'     => true,
			'show_rating'    => true,
		),
	)
);
kidia_home_assert( 1 === count( $carousel_api['data']['items'] ), 'Product Carousel must return Flutter product items, not query settings.' );
$product = $carousel_api['data']['items'][0];
kidia_home_assert( 42 === $product['id'] && '499' === $product['price'], 'Product Carousel must expose product identity and price.' );
kidia_home_assert( 'https://example.com/media-41.jpg' === $product['image_url'], 'Product Carousel must expose an absolute product image.' );
kidia_home_assert( 'EGP' === $product['currency_code'] && 'EGP' === $product['currency_symbol'], 'Product Carousel must expose the Flutter currency contract.' );
kidia_home_assert( 'product' === $product['action']['type'] && '42' === $product['action']['value'], 'Product cards must navigate to their product.' );
kidia_home_assert( 4.7 === $product['rating'] && 28 === $product['review_count'], 'Product cards must expose ratings when that presentation is enabled.' );
kidia_home_assert( 17 === $product['discount_percent'], 'Product cards must expose the calculated discount percentage.' );
kidia_home_assert( 'Fresh arrivals' === $carousel_api['data']['subtitle'], 'Product Carousel subtitles must reach Flutter.' );
kidia_home_assert( 'See everything' === $carousel_api['data']['view_all_label'], 'Product Carousel View All labels must reach Flutter.' );
kidia_home_assert( 'elevated' === $carousel_api['data']['card_style'] && true === $carousel_api['data']['show_rating'], 'Product Carousel card presentation settings must reach Flutter.' );
kidia_home_assert( 'collection' === $carousel_api['data']['view_all_action']['type'], 'Latest products must get an automatic View All collection action.' );

$brands = new Kidia_Mobile_Brand_Carousel_Block();
$brand_api = $brands->build_api_block(
	array( 'id' => 'brands', 'enabled' => true, 'settings' => $brands->get_default_settings() )
);
kidia_home_assert( 1 === count( $brand_api['data']['items'] ), 'Brand Carousel must query the active WooCommerce brand taxonomy.' );
kidia_home_assert( 'brand' === $brand_api['data']['items'][0]['action']['type'], 'Brand items must use the Flutter action object.' );
kidia_home_assert( 'https://example.com/media-77.jpg' === $brand_api['data']['items'][0]['logo_url'], 'Brand items must expose a valid logo.' );

$section = new Kidia_Mobile_Section_Header_Block();
kidia_home_assert( null === $section->build_api_data( $section->get_default_settings() ), 'An empty required Section Header title must be omitted.' );
$section_api = $section->build_api_data(
	array( 'title' => 'Offers', 'show_view_all' => true, 'view_all_label' => 'View all', 'action_type' => 'collection', 'action_value' => 'sale' )
);
kidia_home_assert( 'View all' === $section_api['action_label'], 'Section Header must use Flutter action_label.' );
kidia_home_assert( 'collection' === $section_api['action']['type'], 'Section Header action must use the Flutter action object.' );

$promo = new Kidia_Mobile_Promo_Strip_Block();
kidia_home_assert( null === $promo->build_api_data( $promo->get_default_settings() ), 'An empty required Promo Strip text must be omitted.' );
$promo_api = $promo->build_api_data(
	array( 'text' => 'Free shipping', 'action_type' => 'search', 'action_value' => 'new' )
);
kidia_home_assert( 'Free shipping' === $promo_api['text'], 'Promo Strip must expose its required text.' );
kidia_home_assert( 'search' === $promo_api['action']['type'], 'Promo Strip action settings must reach Flutter.' );

$quick_links = new Kidia_Mobile_Quick_Links_Block();
$quick_links_settings = array_merge(
	$quick_links->get_default_settings(),
	array(
		'title'       => 'Shop by age',
		'layout'      => 'grid',
		'image_shape' => 'circle',
		'columns'     => 5,
		'items'       => array(
			array(
				'image_url'    => 'https://example.com/baby.jpg',
				'label'        => 'Baby',
				'subtitle'     => '0-2 years',
				'action_type'  => 'category',
				'action_value' => '12',
			),
			array(
				'image_url' => 'javascript:alert(1)',
				'label'     => 'Unsafe',
			),
		),
	)
);
$quick_links_api = $quick_links->build_api_data( $quick_links_settings );
kidia_home_assert( is_array( $quick_links_api ) && 1 === count( $quick_links_api['items'] ), 'Quick Links must omit incomplete or unsafe shortcuts.' );
kidia_home_assert( 'grid' === $quick_links_api['layout'] && 5 === $quick_links_api['columns'], 'Quick Links layout settings must reach Flutter.' );
kidia_home_assert( 'category' === $quick_links_api['items'][0]['action']['type'], 'Quick Links must expose per-item navigation actions.' );
ob_start();
$quick_links->render_settings( 6, $quick_links_settings );
$quick_links_markup = (string) ob_get_clean();
kidia_home_assert( str_contains( $quick_links_markup, 'kidia-add-repeatable-item' ), 'Quick Links must provide a repeatable item editor.' );
kidia_home_assert( str_contains( $quick_links_markup, 'kidia-select-media' ), 'Quick Links images must use the WordPress media picker.' );

$banner_grid = new Kidia_Mobile_Banner_Grid_Block();
$banner_grid_settings = array_merge(
	$banner_grid->get_default_settings(),
	array(
		'title'         => 'Collections',
		'layout'        => 'featured',
		'aspect_ratio'  => 0.75,
		'image_fit'     => 'contain',
		'border_radius' => 12,
		'items'         => array(
			array(
				'image_url'    => 'https://example.com/summer.jpg',
				'title'        => 'Summer edit',
				'subtitle'     => 'New season',
				'button_label' => 'Shop now',
				'action_type'  => 'collection',
				'action_value' => 'summer',
			),
		),
	)
);
$banner_grid_api = $banner_grid->build_api_data( $banner_grid_settings );
kidia_home_assert( is_array( $banner_grid_api ) && 'featured' === $banner_grid_api['layout'], 'Banner Grid must expose its featured layout.' );
kidia_home_assert( 0.75 === $banner_grid_api['aspect_ratio'] && 'contain' === $banner_grid_api['image_fit'], 'Banner Grid image presentation settings must reach Flutter.' );
kidia_home_assert( 'Shop now' === $banner_grid_api['items'][0]['button_label'], 'Banner Grid overlays must expose their button label.' );
kidia_home_assert( 'summer' === $banner_grid_api['items'][0]['action']['value'], 'Banner Grid items must expose their own action.' );
ob_start();
$banner_grid->render_settings( 7, $banner_grid_settings );
$banner_grid_markup = (string) ob_get_clean();
kidia_home_assert( str_contains( $banner_grid_markup, 'kidia-add-repeatable-item' ), 'Banner Grid must provide a repeatable item editor.' );
kidia_home_assert( str_contains( $banner_grid_markup, 'kidia-select-media' ), 'Banner Grid images must use the WordPress media picker.' );

$builder_template = file_get_contents(
	dirname( __DIR__ ) . '/admin/templates/block-template.php'
);
kidia_home_assert( false !== $builder_template, 'Home Builder block template must be readable.' );
kidia_home_assert( str_contains( $builder_template, 'kidia-builder-essentials' ), 'Every block must render the compact essentials panel.' );
kidia_home_assert( str_contains( $builder_template, 'kidia-builder-settings-content' ), 'Every block must render settings inside the shared compact panel.' );

fwrite( STDOUT, "Home block API contracts and App Header Builder regression test passed.\n" );
