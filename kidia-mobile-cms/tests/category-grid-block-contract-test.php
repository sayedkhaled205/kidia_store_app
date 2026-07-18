<?php
/** Category Grid API contract test. */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_textarea_field( $value ): string { return sanitize_text_field( $value ); }
function sanitize_hex_color( $value ): string { return preg_match( '/^#[0-9a-fA-F]{6}$/', (string) $value ) ? strtoupper( (string) $value ) : ''; }
function esc_url_raw( $value ): string { return filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : ''; }
function absint( $value ): int { return abs( (int) $value ); }
function wp_parse_args( $args, $defaults = array() ): array { return array_merge( (array) $defaults, (array) $args ); }
function wp_generate_uuid4(): string { return '00000000-0000-4000-8000-000000000001'; }
function taxonomy_exists( string $taxonomy ): bool { return 'product_cat' === $taxonomy; }
function is_wp_error( $value ): bool { return false; }
function wp_specialchars_decode( string $value, int $flags = ENT_QUOTES ): string { return html_entity_decode( $value, $flags ); }
function get_term_meta( int $term_id, string $key, bool $single = false ): int { unset( $key, $single ); return $term_id + 100; }
function wp_get_attachment_image_url( int $attachment_id, string $size ): string { unset( $size ); return 'https://example.com/category-' . $attachment_id . '.jpg'; }
function wp_parse_url( string $url, int $component = -1 ) { return parse_url( $url, $component ); }
function get_terms( array $args ): array {
	// Prove that legacy hide-empty elements fall back to visible categories.
	if ( ! empty( $args['hide_empty'] ) ) {
		return array();
	}
	return array( new WP_Term( 16, 'Kids &amp; Toys' ) );
}

final class WP_Term {
	public function __construct( public int $term_id, public string $name ) {}
}

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-block.php';
require dirname( __DIR__ ) . '/includes/blocks/class-kidia-mobile-category-grid-block.php';

$block = new Kidia_Mobile_Category_Grid_Block();
$api = $block->build_api_block(
	array(
		'id' => 'categories_home',
		'enabled' => true,
		'settings' => array( 'hide_empty' => true, 'parent_id' => 0 ),
	)
);

assert( is_array( $api ) );
assert( 'category_grid' === $api['type'] );
assert( 1 === count( $api['data']['items'] ) );
assert( 16 === $api['data']['items'][0]['id'] );
assert( 'Kids & Toys' === $api['data']['items'][0]['name'] );
assert( 'https://example.com/category-116.jpg' === $api['data']['items'][0]['image_url'] );
assert( 'category' === $api['data']['items'][0]['action']['type'] );
assert( '16' === $api['data']['items'][0]['action']['value'] );

echo "category-grid-block-contract-test: ok\n";
