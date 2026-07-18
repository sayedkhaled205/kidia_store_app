<?php
/** Home Builder is the canonical source for complete element settings. */
declare( strict_types=1 );
define( 'ABSPATH', __DIR__ );
$GLOBALS['kidia_test_options'] = array();
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_textarea_field( $value ): string { return sanitize_text_field( $value ); }
function sanitize_hex_color( $value ) { return preg_match( '/^#[0-9a-f]{6}$/i', (string) $value ) ? (string) $value : null; }
function esc_url_raw( $value ): string { return filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : ''; }
function absint( $value ): int { return abs( (int) $value ); }
function wp_parse_args( $args, $defaults = array() ): array { return array_merge( (array) $defaults, (array) $args ); }
function get_option( string $name, $default = false ) { return array_key_exists( $name, $GLOBALS['kidia_test_options'] ) ? $GLOBALS['kidia_test_options'][ $name ] : $default; }
function update_option( string $name, $value, bool $autoload = false ): bool { unset( $autoload ); $GLOBALS['kidia_test_options'][ $name ] = $value; return true; }
function current_time( string $type, bool $gmt = false ): string { unset( $type, $gmt ); return '2026-07-18 00:00:00'; }

final class Kidia_Mobile_Block_Registry {
	private const TYPES = array( 'app_header', 'hero_slider', 'image_banner', 'product_carousel', 'brand_carousel', 'category_grid', 'product_grid', 'section_header', 'promo_strip', 'coupon_banner', 'countdown', 'video_banner', 'text_block', 'divider', 'spacer' );
	public static function exists( string $type ): bool { return in_array( $type, self::TYPES, true ); }
	public static function defaults( string $type ): array { unset( $type ); return array( 'title' => '', 'items' => array(), 'limit' => 8 ); }
	public static function generate_id( string $type ): string { return $type . '_generated'; }
	public static function create( string $type, int $order ): array { return array( 'id' => $type . '_' . $order, 'type' => $type, 'enabled' => true, 'order' => $order, 'settings' => self::defaults( $type ) ); }
	public static function get( string $type ): array { return array( 'label' => $type ); }
}
function kidia_assert( bool $condition, string $message ): void { if ( ! $condition ) throw new RuntimeException( $message ); }
require dirname( __DIR__ ) . '/includes/class-kidia-mobile-layout-store.php';

// Legacy references migrate once, but unplaced Library records are never
// injected into the Home Page.
$GLOBALS['kidia_test_options']['kidia_mobile_hero_sliders'] = array(
	array( 'id' => 'placed', 'name' => 'Placed', 'enabled' => true, 'status' => 'published', 'settings' => array( 'title' => 'Legacy title' ) ),
	array( 'id' => 'unplaced', 'name' => 'Old page item', 'enabled' => true, 'status' => 'published', 'settings' => array( 'title' => 'Must stay hidden' ) ),
);
$GLOBALS['kidia_test_options']['kidia_mobile_home_layout_v4'] = array(
	array( 'id' => 'placed', 'library_id' => 'placed', 'type' => 'hero_slider', 'name' => 'Placed', 'enabled' => true, 'status' => 'published', 'order' => 1 ),
);
$store = new Kidia_Mobile_Layout_Store();
$migrated = $store->get_layout();
kidia_assert( 1 === count( $migrated ), 'Legacy Library items not placed in Home Builder must stay hidden.' );
kidia_assert( 'Legacy title' === $migrated[0]['settings']['title'], 'A referenced legacy element must migrate its settings.' );

$submitted = array();
$types = array( 'app_header', 'hero_slider', 'image_banner', 'product_carousel', 'brand_carousel', 'category_grid', 'product_grid', 'section_header', 'promo_strip', 'coupon_banner', 'countdown', 'video_banner', 'text_block', 'divider', 'spacer' );
foreach ( $types as $index => $type ) {
	$submitted[] = array(
		'id' => $type . '_inline', 'library_id' => $type . '_inline', 'type' => $type,
		'name' => 'Inline ' . $type, 'enabled' => '1', 'status' => 'published', 'order' => $index + 1,
		'settings' => array( 'title' => 'Saved ' . $type, 'limit' => 12, 'items' => array( array( 'image_url' => 'https://example.com/' . $type . '.jpg' ) ) ),
	);
}
$decoded = Kidia_Mobile_Layout_Store::decode_submission( (string) json_encode( $submitted ) );
kidia_assert( count( $types ) === count( $decoded ), 'JSON submission must contain every inline element.' );
$store->save_layout( $decoded );
$reloaded = $store->get_layout();
kidia_assert( count( $types ) === count( $reloaded ), 'Every inline element must survive save/reload.' );
foreach ( $reloaded as $index => $block ) {
	kidia_assert( 'published' === $block['status'], 'Inline visibility must survive.' );
	kidia_assert( 'Saved ' . $types[ $index ] === $block['settings']['title'], 'Inline settings must be canonical after reload.' );
}
$runtime = $store->get_runtime_layout();
kidia_assert( count( $types ) === count( $runtime ), 'The mobile runtime must read the same complete Home Builder layout.' );
kidia_assert( isset( $GLOBALS['kidia_test_options']['kidia_mobile_home_layout_v5'][0]['settings'] ), 'The saved Home Layout must contain settings, not Library references only.' );
fwrite( STDOUT, "Inline Home Builder canonical-layout test passed for all 15 elements.\n" );
