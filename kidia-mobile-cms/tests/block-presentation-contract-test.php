<?php
/** Shared block presentation contract test. */
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

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-block.php';

final class Presentation_Test_Block extends Kidia_Mobile_Block {
	public function get_type(): string { return 'presentation_test'; }
	public function get_label(): string { return 'Presentation test'; }
	public function get_default_settings(): array { return array( 'label' => 'Default' ); }
	public function sanitize_settings( array $settings ): array { return array( 'label' => sanitize_text_field( $settings['label'] ?? '' ) ); }
	public function build_api_data( array $settings ): ?array { return array( 'label' => $settings['label'] ); }
	public function render_settings( int $index, array $settings ): void { unset( $index, $settings ); }
}

$block = new Presentation_Test_Block();
$instance = $block->normalize_instance(
	array(
		'id' => 'test_1', 'enabled' => true,
		'settings' => array(
			'label' => 'Hello', 'margin_top' => 12, 'margin_bottom' => 18,
			'margin_horizontal' => 9, 'padding_vertical' => 7,
			'padding_horizontal' => 11, 'block_background' => '#abcdef',
			'block_radius' => 22, 'content_scale' => 110,
		),
	),
	1
);
$api = $block->build_api_block( $instance );

assert( 'Hello' === $api['data']['label'] );
assert( '#ABCDEF' === $instance['settings']['block_background'] );
assert( 12 === $api['data']['presentation']['margin_top'] );
assert( 18 === $api['data']['presentation']['margin_bottom'] );
assert( 9 === $api['data']['presentation']['margin_horizontal'] );
assert( 7 === $api['data']['presentation']['padding_vertical'] );
assert( 11 === $api['data']['presentation']['padding_horizontal'] );
assert( '#ABCDEF' === $api['data']['presentation']['background_color'] );
assert( 22 === $api['data']['presentation']['block_radius'] );
assert( 110 === $api['data']['presentation']['content_scale'] );
echo "block-presentation-contract-test: ok\n";
