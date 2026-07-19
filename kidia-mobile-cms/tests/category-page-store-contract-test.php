<?php
/** Category element schema and legacy migration contract test. */
declare( strict_types=1 );
define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_category_option'] = array(
	11 => array( 'order' => 1, 'hidden' => false, 'image_id' => 0, 'image_size' => 68, 'image_shape' => 'rounded' ),
	22 => array( 'order' => 0, 'hidden' => true, 'image_id' => 44, 'image_size' => 92, 'image_shape' => 'circle', 'font_size' => 20 ),
);

function absint( $value ): int { return abs( (int) $value ); }
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_hex_color( $value ) { return preg_match( '/^#[0-9a-f]{6}$/i', (string) $value ) ? strtoupper( (string) $value ) : null; }
function get_option( string $name, $default = false ) { return $GLOBALS['kidia_category_option'] ?? $default; }
function update_option( string $name, $value, bool $autoload = false ): bool { unset( $name, $autoload ); $GLOBALS['kidia_category_option'] = $value; return true; }
function kidia_category_assert( bool $condition, string $message ): void { if ( ! $condition ) { throw new RuntimeException( $message ); } }

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-category-page-store.php';

$store = new Kidia_Mobile_Category_Page_Store();
$migrated = $store->get_settings();
kidia_category_assert( true === $migrated['enabled'], 'Legacy category pages must remain visible.' );
kidia_category_assert( array( 11, 22 ) === array_keys( $migrated['categories'] ), 'Legacy term rows must migrate without loss.' );
kidia_category_assert( 92 === $migrated['general']['image_size'] && 'circle' === $migrated['general']['image_shape'], 'The first displayed legacy row must seed the one General Settings block.' );
kidia_category_assert( ! array_key_exists( 'image_size', $migrated['categories'][22] ), 'Per-term rows must only retain app overrides.' );

$saved = $store->save_settings(
	array(
		'enabled' => '1',
		'general' => array( 'image_size' => 120, 'image_shape' => 'square', 'font_size' => 30 ),
		'categories' => array( 22 => array( 'order' => 0, 'hidden' => false, 'image_id' => 55, 'name' => 'App name' ) ),
	)
);
kidia_category_assert( 2 === $saved['version'], 'The Category element must save the current schema version.' );
kidia_category_assert( 'App name' === $saved['categories'][22]['name'], 'The app-only display name must save.' );
kidia_category_assert( array( 'order', 'hidden', 'image_id', 'name' ) === array_keys( $saved['categories'][22] ), 'Each category must only save order, visibility, image and name.' );
$layouts = array( 'default', 'visual_grid', 'circular_grid', 'compact_grid', 'sidebar' );
foreach ( $layouts as $layout ) {
	$saved_layout = $store->save_settings( array( 'enabled' => '1', 'general' => array( 'category_layout' => $layout, 'grid_columns' => 4, 'card_radius' => 21, 'card_gap' => 13, 'show_arrow' => '0' ) ) );
	kidia_category_assert( $layout === $saved_layout['general']['category_layout'], "$layout must save as a category layout." );
	kidia_category_assert( 4 === $saved_layout['general']['grid_columns'] && 21 === $saved_layout['general']['card_radius'] && 13 === $saved_layout['general']['card_gap'], "$layout must retain shared card settings." );
	kidia_category_assert( false === $saved_layout['general']['show_arrow'], "$layout must retain the shared arrow visibility setting." );
}
kidia_category_assert( 120 === $saved['general']['image_size'] && 30 === $saved['general']['font_size'], 'General Settings must save once for the whole element.' );

fwrite( STDOUT, "Category-page store migration and one-element schema passed.\n" );
