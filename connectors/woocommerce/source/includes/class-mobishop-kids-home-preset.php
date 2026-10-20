<?php
/** Kids & Baby Home sections shared by setup preview and theme installation. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Kids_Home_Preset {
	public static function apply( array $blocks, string $primary, string $secondary ): array {
		$path = __DIR__ . '/presets/kids-home-tail293.json';
		$tail = is_readable( $path ) ? json_decode( file_get_contents( $path ), true ) : null;
		if ( ! is_array( $tail ) || 8 !== count( $tail ) ) { return $blocks; }
		$prefix = array();
		foreach ( $blocks as $block ) {
			$prefix[] = $block;
			if ( 'hero_slider' === ( $block['type'] ?? '' ) ) { break; }
		}
		if ( empty( $prefix ) || 'hero_slider' !== ( end( $prefix )['type'] ?? '' ) ) { return $blocks; }
		$rewrite = static function ( $value ) use ( &$rewrite, $primary, $secondary ) {
			if ( is_array( $value ) ) { return array_map( $rewrite, $value ); }
			if ( ! is_string( $value ) ) { return $value; }
			if ( '#4ea999' === strtolower( $value ) ) { return $primary; }
			if ( '#256a77' === strtolower( $value ) ) { return $secondary; }
			return str_replace( 'http://staging.kidiastore.com/wp-content/plugins/mobishop/admin/assets/theme-previews/', MOBISHOP_URL . 'admin/assets/theme-previews/', $value );
		};
		$result = array_merge( $prefix, $rewrite( $tail ) );
		foreach ( $result as $index => &$block ) { $block['order'] = $index + 1; }
		unset( $block );
		return $result;
	}
}
