<?php
/** Ordered WooCommerce category page REST endpoint. */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Category_Page_Endpoint {
	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/category-page',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_categories' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'page'     => array( 'type' => 'integer', 'default' => 1, 'minimum' => 1 ),
					'per_page' => array( 'type' => 'integer', 'default' => 100, 'minimum' => 1, 'maximum' => 100 ),
				),
			)
		);
	}

	public function get_categories( WP_REST_Request $request ): WP_REST_Response {
		$terms = taxonomy_exists( 'product_cat' )
			? get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => true ) )
			: array();
		if ( is_wp_error( $terms ) ) {
			return new WP_REST_Response( array(), 200 );
		}

		$page_settings = ( new Kidia_Mobile_Category_Page_Store() )->get_settings();
		$settings      = $page_settings['categories'];
		$general       = $page_settings['general'];
		if ( empty( $page_settings['enabled'] ) ) {
			$response = new WP_REST_Response( array(), 200 );
			$response->header( 'X-WP-Total', '0' );
			$response->header( 'X-WP-TotalPages', '0' );
			$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
			$response->header( 'Pragma', 'no-cache' );
			return $response;
		}
		$by_parent = array();
		foreach ( $terms as $term ) {
			$by_parent[ (int) $term->parent ][] = $term;
		}
		foreach ( $by_parent as &$siblings ) {
			usort( $siblings, static function ( $left, $right ) use ( $settings ): int {
				$left_order  = isset( $settings[ $left->term_id ]['order'] ) ? (int) $settings[ $left->term_id ]['order'] : PHP_INT_MAX;
				$right_order = isset( $settings[ $right->term_id ]['order'] ) ? (int) $settings[ $right->term_id ]['order'] : PHP_INT_MAX;
				return $left_order === $right_order ? strcasecmp( $left->name, $right->name ) : $left_order <=> $right_order;
			} );
		}
		unset( $siblings );

		$ordered = array();
		$append  = function ( int $parent, bool $ancestor_hidden = false ) use ( &$append, &$ordered, $by_parent, $settings, $general ): void {
			foreach ( $by_parent[ $parent ] ?? array() as $term ) {
				$setting = is_array( $settings[ $term->term_id ] ?? null ) ? $settings[ $term->term_id ] : array();
				$hidden  = $ancestor_hidden || ! empty( $setting['hidden'] );
				if ( ! $hidden ) {
					$ordered[] = $this->format_term( $term, $setting, $general );
				}
				$append( (int) $term->term_id, $hidden );
			}
		};
		$append( 0 );

		$page       = max( 1, (int) $request->get_param( 'page' ) );
		$per_page   = min( 100, max( 1, (int) $request->get_param( 'per_page' ) ) );
		$total      = count( $ordered );
		$total_page = 0 === $total ? 0 : (int) ceil( $total / $per_page );
		$response   = new WP_REST_Response( array_slice( $ordered, ( $page - 1 ) * $per_page, $per_page ), 200 );
		$response->header( 'X-WP-Total', (string) $total );
		$response->header( 'X-WP-TotalPages', (string) $total_page );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}

	private function format_term( WP_Term $term, array $setting, array $general ): array {
		$image_id = absint( $setting['image_id'] ?? 0 );
		if ( 0 === $image_id ) {
			$image_id = absint( get_term_meta( $term->term_id, 'thumbnail_id', true ) );
		}
		$image = null;
		if ( $image_id ) {
			$source    = wp_get_attachment_image_url( $image_id, 'full' );
			$thumbnail = wp_get_attachment_image_url( $image_id, 'thumbnail' );
			if ( $source ) {
				$image = array( 'id' => $image_id, 'src' => $source, 'thumbnail' => $thumbnail ?: $source, 'alt' => get_post_meta( $image_id, '_wp_attachment_image_alt', true ) );
			}
		}
		$link = get_term_link( $term );
		return array(
			'id'          => (int) $term->term_id,
			'name'        => '' !== trim( (string) ( $setting['name'] ?? '' ) ) ? sanitize_text_field( (string) $setting['name'] ) : $term->name,
			'slug'        => $term->slug,
			'parent'      => (int) $term->parent,
			'description' => $term->description,
			'count'       => (int) $term->count,
			'image'       => $image,
			'permalink'   => is_wp_error( $link ) ? '' : $link,
			'presentation' => array(
				'category_layout'  => $general['category_layout'],
				'grid_columns'     => $general['grid_columns'],
				'card_radius'      => $general['card_radius'],
				'card_gap'         => $general['card_gap'],
				'margin_top'       => $general['margin_top'],
				'margin_bottom'    => $general['margin_bottom'],
				'page_background_color' => $general['page_background_color'],
				'card_style'       => $general['card_style'],
				'card_background_color' => $general['card_background_color'],
				'card_shadow_color' => $general['card_shadow_color'],
				'card_shadow_strength' => $general['card_shadow_strength'],
				'card_shadow_blur' => $general['card_shadow_blur'],
				'card_shadow_offset_y' => $general['card_shadow_offset_y'],
				'show_arrow'       => $general['show_arrow'],
				'image_size'       => $general['image_size'],
				'image_shape'      => $general['image_shape'],
				'image_radius'     => $general['image_radius'],
				'image_fit'        => $general['image_fit'],
				'image_effect'     => $general['image_effect'],
				'image_scale'      => $general['image_scale'],
				'image_position'   => $general['image_position'],
				'border_width'     => $general['border_width'],
				'border_color'     => $general['border_color'],
				'background_color' => $general['background_color'],
				'image_text_gap'   => $general['image_text_gap'],
				'font_size'        => $general['font_size'],
				'font_color'       => $general['font_color'],
				'font_weight'      => $general['font_weight'],
				'text_align'       => $general['text_align'],
				'text_max_lines'   => $general['text_max_lines'],
				'line_height'      => $general['line_height'],
			),
		);
	}
}
