<?php
/** Shared category-page settings, migration and sanitization. */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Category_Page_Store {
	private const OPTION_NAME = 'kidia_mobile_category_page';
	private const VERSION     = 2;

	/** @return array<string,mixed> */
	public static function general_defaults(): array {
		return array(
			'image_size'       => 68,
			'image_shape'      => 'rounded',
			'image_radius'     => 18,
			'image_fit'        => 'contain',
			'image_effect'     => 'none',
			'image_scale'      => 100,
			'image_position'   => 'center',
			'border_width'     => 0,
			'border_color'     => '#DDE5E2',
			'background_color' => '#FFFFFF',
			'image_text_gap'   => 10,
			'font_size'        => 16,
			'font_color'       => '#1F2933',
			'font_weight'      => 800,
			'text_align'       => 'start',
			'text_max_lines'   => 2,
			'line_height'      => 125,
		);
	}

	/** @return array{version:int,enabled:bool,general:array<string,mixed>,categories:array<int,array<string,mixed>>} */
	public function get_settings(): array {
		$raw = get_option( self::OPTION_NAME, array() );
		return $this->normalize( is_array( $raw ) ? $raw : array() );
	}

	/** @param array<string,mixed> $submitted @return array<string,mixed> */
	public function save_settings( array $submitted ): array {
		$categories = array();
		foreach ( is_array( $submitted['categories'] ?? null ) ? $submitted['categories'] : array() as $term_id => $row ) {
			$id = absint( $term_id );
			if ( 0 === $id || ! is_array( $row ) ) {
				continue;
			}
			$categories[ $id ] = $this->sanitize_category( $row );
		}

		$clean = array(
			'version'    => self::VERSION,
			'enabled'    => ! empty( $submitted['enabled'] ),
			'general'    => self::sanitize_general( is_array( $submitted['general'] ?? null ) ? $submitted['general'] : array() ),
			'categories' => $categories,
		);
		update_option( self::OPTION_NAME, $clean, false );
		return $clean;
	}

	/** @param array<string,mixed> $raw @return array<string,mixed> */
	private function normalize( array $raw ): array {
		$is_current = isset( $raw['categories'] ) && is_array( $raw['categories'] );
		$rows       = $is_current ? $raw['categories'] : $this->legacy_rows( $raw );
		$general    = is_array( $raw['general'] ?? null ) ? $raw['general'] : $this->legacy_general( $raw );
		$categories = array();

		foreach ( $rows as $term_id => $row ) {
			$id = absint( $term_id );
			if ( 0 === $id || ! is_array( $row ) ) {
				continue;
			}
			$categories[ $id ] = $this->sanitize_category( $row );
		}

		return array(
			'version'    => self::VERSION,
			'enabled'    => $is_current ? ! empty( $raw['enabled'] ) : true,
			'general'    => self::sanitize_general( $general ),
			'categories' => $categories,
		);
	}

	/** @param array<string,mixed> $raw @return array<int,array<string,mixed>> */
	private function legacy_rows( array $raw ): array {
		$rows = array();
		foreach ( $raw as $term_id => $row ) {
			if ( is_numeric( $term_id ) && is_array( $row ) ) {
				$rows[ absint( $term_id ) ] = $row;
			}
		}
		return $rows;
	}

	/** @param array<string,mixed> $raw @return array<string,mixed> */
	private function legacy_general( array $raw ): array {
		$rows = $this->legacy_rows( $raw );
		if ( empty( $rows ) ) {
			return array();
		}
		uasort(
			$rows,
			static fn( array $left, array $right ): int => absint( $left['order'] ?? PHP_INT_MAX ) <=> absint( $right['order'] ?? PHP_INT_MAX )
		);
		$first = reset( $rows );
		return is_array( $first ) ? $first : array();
	}

	/** @param array<string,mixed> $row @return array<string,mixed> */
	private function sanitize_category( array $row ): array {
		return array(
			'order'    => max( 0, absint( $row['order'] ?? 0 ) ),
			'hidden'   => ! empty( $row['hidden'] ),
			'image_id' => absint( $row['image_id'] ?? 0 ),
			'name'     => sanitize_text_field( (string) ( $row['name'] ?? '' ) ),
		);
	}

	/** @param array<string,mixed> $settings @return array<string,mixed> */
	public static function sanitize_general( array $settings ): array {
		$defaults = self::general_defaults();
		return array(
			'image_size'       => min( 120, max( 32, absint( $settings['image_size'] ?? $defaults['image_size'] ) ) ),
			'image_shape'      => self::choice( $settings['image_shape'] ?? '', array( 'square', 'rounded', 'circle' ), $defaults['image_shape'] ),
			'image_radius'     => min( 50, max( 0, absint( $settings['image_radius'] ?? $defaults['image_radius'] ) ) ),
			'image_fit'        => self::choice( $settings['image_fit'] ?? '', array( 'contain', 'cover' ), $defaults['image_fit'] ),
			'image_effect'     => self::choice( $settings['image_effect'] ?? '', array( 'none', 'shadow', 'grayscale' ), $defaults['image_effect'] ),
			'image_scale'      => min( 150, max( 80, absint( $settings['image_scale'] ?? $defaults['image_scale'] ) ) ),
			'image_position'   => self::choice( $settings['image_position'] ?? '', array( 'center', 'top', 'bottom', 'left', 'right' ), $defaults['image_position'] ),
			'border_width'     => min( 8, max( 0, absint( $settings['border_width'] ?? $defaults['border_width'] ) ) ),
			'border_color'     => sanitize_hex_color( $settings['border_color'] ?? '' ) ?: $defaults['border_color'],
			'background_color' => sanitize_hex_color( $settings['background_color'] ?? '' ) ?: $defaults['background_color'],
			'image_text_gap'   => min( 40, max( 0, absint( $settings['image_text_gap'] ?? $defaults['image_text_gap'] ) ) ),
			'font_size'        => min( 30, max( 10, absint( $settings['font_size'] ?? $defaults['font_size'] ) ) ),
			'font_color'       => sanitize_hex_color( $settings['font_color'] ?? '' ) ?: $defaults['font_color'],
			'font_weight'      => in_array( absint( $settings['font_weight'] ?? $defaults['font_weight'] ), array( 400, 500, 600, 700, 800, 900 ), true ) ? absint( $settings['font_weight'] ?? $defaults['font_weight'] ) : $defaults['font_weight'],
			'text_align'       => self::choice( $settings['text_align'] ?? '', array( 'start', 'center', 'end' ), $defaults['text_align'] ),
			'text_max_lines'   => min( 3, max( 1, absint( $settings['text_max_lines'] ?? $defaults['text_max_lines'] ) ) ),
			'line_height'      => min( 200, max( 100, absint( $settings['line_height'] ?? $defaults['line_height'] ) ) ),
		);
	}

	/** @param mixed $value @param array<int,string> $allowed */
	private static function choice( $value, array $allowed, string $fallback ): string {
		$value = sanitize_key( (string) $value );
		return in_array( $value, $allowed, true ) ? $value : $fallback;
	}
}
