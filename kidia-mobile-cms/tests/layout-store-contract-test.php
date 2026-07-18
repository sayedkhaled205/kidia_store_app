<?php
/**
 * Layout Store contract test with lightweight WordPress stubs.
 *
 * Run with: php kidia-mobile-cms/tests/layout-store-contract-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_test_options'] = array();

function sanitize_key( $value ): string {
	$value = strtolower( (string) $value );
	return preg_replace( '/[^a-z0-9_\-]/', '', $value ) ?: '';
}

function sanitize_text_field( $value ): string {
	return trim( strip_tags( (string) $value ) );
}

function sanitize_textarea_field( $value ): string {
	return sanitize_text_field( $value );
}

function esc_url_raw( $value ): string {
	return filter_var( (string) $value, FILTER_VALIDATE_URL )
		? (string) $value
		: '';
}

function absint( $value ): int {
	return abs( (int) $value );
}

function wp_parse_args( $args, $defaults = array() ): array {
	return array_merge( (array) $defaults, (array) $args );
}

function get_option( string $name, $default = false ) {
	return array_key_exists( $name, $GLOBALS['kidia_test_options'] )
		? $GLOBALS['kidia_test_options'][ $name ]
		: $default;
}

function update_option( string $name, $value, bool $autoload = false ): bool {
	unset( $autoload );
	$GLOBALS['kidia_test_options'][ $name ] = $value;
	return true;
}

function current_time( string $type, bool $gmt = false ): string {
	unset( $type, $gmt );
	return '2026-07-16 00:00:00';
}

final class Kidia_Mobile_Block_Registry {
	public static function exists( string $type ): bool {
		return in_array(
			$type,
			array(
				'app_header', 'hero_slider', 'image_banner', 'product_carousel',
				'brand_carousel', 'category_grid', 'product_grid', 'section_header',
				'promo_strip', 'coupon_banner', 'countdown', 'video_banner',
				'text_block', 'divider', 'spacer',
			),
			true
		);
	}

	public static function defaults( string $type ): array {
		unset( $type );
		return array(
			'items'       => array(),
			'auto_play'   => true,
			'interval_ms' => 4500,
		);
	}

	public static function generate_id( string $type ): string {
		return $type . '_generated';
	}

	public static function create( string $type, int $order ): array {
		return array(
			'id'       => $type . '_' . $order,
			'type'     => $type,
			'enabled'  => true,
			'order'    => $order,
			'settings' => self::defaults( $type ),
		);
	}

	public static function get( string $type ): array {
		return array( 'label' => ucwords( str_replace( '_', ' ', $type ) ) );
	}
}

function kidia_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-layout-store.php';

$source_settings = array(
	'items'       => array(
		array(
			'id'         => 'slide_1',
			'image_url'  => 'https://example.com/hero.jpg',
			'title'      => 'Original title',
			'action_type'=> 'category',
			'action_value'=> '12',
		),
	),
	'auto_play'   => false,
	'interval_ms' => 7000,
);

$GLOBALS['kidia_test_options']['kidia_mobile_hero_sliders'] = array(
	'broken legacy record',
	(object) array( 'id' => 'legacy_object' ),
	array(
		'id'       => 'hero_original',
		'name'     => 'Original',
		'status'   => 'draft',
		'enabled'  => true,
		'settings' => $source_settings,
	),
);

$store   = new Kidia_Mobile_Layout_Store();
$runtime = $store->get_runtime_layout();

kidia_assert(
	1 === count( $runtime ) && 'hero_original' === $runtime[0]['library_id'],
	'Runtime reconciliation must read existing Library items.'
);
kidia_assert(
	! array_key_exists( 'kidia_mobile_home_layout_v3', $GLOBALS['kidia_test_options'] ),
	'Runtime reconciliation must not write WordPress options.'
);

$layout = $store->get_layout();

kidia_assert(
	1 === count( $layout ) && 'hero_original' === $layout[0]['library_id'],
	'First reconciliation must use existing Library items instead of hiding them until refresh.'
);
kidia_assert( 1 === count( $layout ), 'The saved Library reference must hydrate.' );
kidia_assert( 'draft' === $layout[0]['status'], 'Hydration must preserve Draft status.' );
kidia_assert(
	'Original title' === $layout[0]['settings']['items'][0]['title'],
	'Hydration must use canonical Library settings.'
);

$store->save_layout(
	array(
		array(
			'id'         => 'hero_original',
			'library_id' => 'hero_original',
			'type'       => 'hero_slider',
			'name'       => 'Renamed in Builder',
			'enabled'    => true,
			'status'     => 'published',
		),
		array(
			'id'                => 'hero_copy',
			'library_id'        => 'hero_copy',
			'source_library_id' => 'hero_original',
			'create_intent'     => true,
			'type'              => 'hero_slider',
			'name'              => 'Original Copy',
			'enabled'           => true,
			'status'            => 'published',
		),
	)
);

$items = get_option( 'kidia_mobile_hero_sliders', array() );

kidia_assert( 2 === count( $items ), 'Duplicate must create a second Library item.' );
kidia_assert( 'draft' === $items[0]['status'], 'Builder must not publish an existing Draft.' );
kidia_assert(
	$source_settings === $items[0]['settings'],
	'Builder save must not rewrite canonical settings.'
);
kidia_assert( 'draft' === $items[1]['status'], 'A duplicate must start as Draft.' );
kidia_assert(
	'Original title' === $items[1]['settings']['items'][0]['title'],
	'Duplicate must copy the source settings.'
);

$store->save_layout(
	array(
		array(
			'id'         => 'hero_copy',
			'library_id' => 'hero_copy',
			'type'       => 'hero_slider',
			'name'       => 'Original Copy',
			'enabled'    => true,
			'status'     => 'draft',
		),
	)
);

$items = get_option( 'kidia_mobile_hero_sliders', array() );
kidia_assert( 2 === count( $items ), 'Removing from Builder must preserve the reusable Library record.' );

$layout = $store->get_layout();
kidia_assert( 1 === count( $layout ), 'A removed Library item must stay excluded from this Home Layout.' );
kidia_assert( 'hero_copy' === $layout[0]['library_id'], 'The retained reference must stay synchronized.' );

$store->save_layout(
	array(
		array(
			'id'         => 'hero_copy',
			'library_id' => 'hero_copy',
			'type'       => 'hero_slider',
			'name'       => 'Original Copy',
			'enabled'    => true,
			'status'     => 'draft',
		),
		array(
			'id'         => 'hero_original',
			'library_id' => 'hero_original',
			'type'       => 'hero_slider',
			'name'       => 'Original',
			'enabled'    => true,
			'status'     => 'draft',
		),
	)
);

kidia_assert( 2 === count( $store->get_layout() ), 'Adding an existing item must clear its exclusion.' );

$GLOBALS['kidia_test_options']['kidia_mobile_hero_sliders'] = array_values(
	array_filter(
		get_option( 'kidia_mobile_hero_sliders', array() ),
		static function ( array $item ): bool {
			return 'hero_original' !== ( $item['id'] ?? '' );
		}
	)
);

$store->save_layout(
	array(
		array(
			'id'         => 'hero_copy',
			'library_id' => 'hero_copy',
			'type'       => 'hero_slider',
			'name'       => 'Original Copy',
			'enabled'    => true,
			'status'     => 'draft',
		),
		array(
			'id'         => 'hero_original',
			'library_id' => 'hero_original',
			'type'       => 'hero_slider',
			'name'       => 'Deleted in Library',
			'enabled'    => true,
			'status'     => 'published',
		),
	)
);

$items = get_option( 'kidia_mobile_hero_sliders', array() );
kidia_assert( 1 === count( $items ), 'A stale Builder tab must not recreate a deleted Library item.' );
kidia_assert( 1 === count( $store->get_layout() ), 'A stale deleted reference must be removed from layout.' );

$store->save_layout(
	array(
		array(
			'id'            => 'hero_new',
			'library_id'    => 'hero_new',
			'create_intent' => true,
			'type'          => 'hero_slider',
			'name'          => 'New Hero',
			'enabled'       => true,
			'status'        => 'published',
		),
	)
);

$items = get_option( 'kidia_mobile_hero_sliders', array() );
$new_item = array_values(
	array_filter(
		$items,
		static function ( array $item ): bool {
			return 'hero_new' === ( $item['id'] ?? '' );
		}
	)
)[0] ?? null;

kidia_assert( is_array( $new_item ), 'An explicit create intent must create a Library item.' );
kidia_assert( 'draft' === $new_item['status'], 'Every Builder-created Library item must start as Draft.' );

// Prove that every Home Builder element survives the exact create/save/reload
// round trip used by a newly configured store.
$GLOBALS['kidia_test_options'] = array();
$all_types = array(
	'app_header', 'hero_slider', 'image_banner', 'product_carousel',
	'brand_carousel', 'category_grid', 'product_grid', 'section_header',
	'promo_strip', 'coupon_banner', 'countdown', 'video_banner',
	'text_block', 'divider', 'spacer',
);
$submitted = array();

foreach ( $all_types as $index => $type ) {
	$submitted[] = array(
		'id'            => $type . '_roundtrip',
		'library_id'    => $type . '_roundtrip',
		'create_intent' => '1',
		'type'          => $type,
		'name'          => 'Test ' . $type,
		'enabled'       => '1',
		'order'         => $index + 1,
		'status'        => 'draft',
	);
}

$browser_payload = json_encode( $submitted );
$decoded_payload = Kidia_Mobile_Layout_Store::decode_submission( $browser_payload );
kidia_assert(
	count( $submitted ) === count( $decoded_payload ),
	'The browser JSON payload must reach WordPress with every element intact.'
);

$store = new Kidia_Mobile_Layout_Store();
$store->save_layout( $decoded_payload );
$reloaded = $store->get_layout();

kidia_assert(
	count( $all_types ) === count( $reloaded ),
	'Every Home Builder element must remain present after Save Home Layout and reload.'
);

foreach ( $all_types as $index => $type ) {
	kidia_assert(
		$type === ( $reloaded[ $index ]['type'] ?? '' ),
		'Home Builder element order/type mismatch after reload: ' . $type
	);
	kidia_assert(
		$type . '_roundtrip' === ( $reloaded[ $index ]['library_id'] ?? '' ),
		'Home Builder Library reference was not persisted: ' . $type
	);
}

fwrite( STDOUT, "Browser payload and Layout Store test passed for all 15 Home Builder elements.\n" );
