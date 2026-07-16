<?php
/**
 * Makes third-party WooCommerce product brands available through Store API.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Product_Brand_Bridge {

	/** Register the Store API schema extension after WooCommerce Blocks loads. */
	public function register(): void {
		add_action(
			'rest_api_init',
			array( $this, 'register_routes' )
		);
		add_filter(
			'woocommerce_store_api_product_query',
			array( $this, 'filter_product_query' ),
			10,
			2
		);

		if ( did_action( 'woocommerce_blocks_loaded' ) > 0 ) {
			$this->register_store_api_data();
			return;
		}

		add_action(
			'woocommerce_blocks_loaded',
			array( $this, 'register_store_api_data' )
		);
	}

	/** Apply the app's brand ids to third-party brand taxonomies. */
	public function filter_product_query( array $query_args, $request ): array {
		$taxonomy = $this->get_brand_taxonomy();
		if ( '' === $taxonomy || ! $request instanceof WP_REST_Request ) {
			return $query_args;
		}

		$raw_ids = $request->get_param( 'brand' );
		$ids     = array_filter(
			array_map(
				'absint',
				preg_split( '/\s*,\s*/', is_array( $raw_ids ) ? implode( ',', $raw_ids ) : (string) $raw_ids )
			)
		);
		if ( empty( $ids ) ) {
			return $query_args;
		}

		$tax_query   = isset( $query_args['tax_query'] ) && is_array( $query_args['tax_query'] )
			? $query_args['tax_query']
			: array();
		$tax_query[] = array(
			'taxonomy' => $taxonomy,
			'field'    => 'term_id',
			'terms'    => array_values( array_unique( $ids ) ),
			'operator' => 'IN',
		);
		$query_args['tax_query'] = $tax_query;
		return $query_args;
	}

	/** Register the normalized public brand collection used by app filters. */
	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/brands',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_brands' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'page'       => array(
						'default'           => 1,
						'sanitize_callback' => 'absint',
					),
					'per_page'   => array(
						'default'           => 100,
						'sanitize_callback' => 'absint',
					),
					'search'     => array(
						'default'           => '',
						'sanitize_callback' => 'sanitize_text_field',
					),
					'hide_empty' => array(
						'default'           => true,
						'sanitize_callback' => 'rest_sanitize_boolean',
					),
				),
			)
		);
	}

	/** Return brands independently from whichever brand plugin owns them. */
	public function get_brands( WP_REST_Request $request ) {
		$taxonomy = $this->get_brand_taxonomy();
		if ( '' === $taxonomy ) {
			return new WP_Error(
				'woo_mobile_brands_unavailable',
				__( 'No supported product brand taxonomy is registered.', 'kidia-mobile-cms' ),
				array( 'status' => 501 )
			);
		}

		$page       = max( 1, absint( $request->get_param( 'page' ) ) );
		$per_page   = max( 1, min( 100, absint( $request->get_param( 'per_page' ) ) ) );
		$search     = sanitize_text_field( (string) $request->get_param( 'search' ) );
		$hide_empty = rest_sanitize_boolean( $request->get_param( 'hide_empty' ) );
		$args       = array(
			'taxonomy'   => $taxonomy,
			'hide_empty' => $hide_empty,
			'number'     => $per_page,
			'offset'     => ( $page - 1 ) * $per_page,
			'orderby'    => 'name',
			'order'      => 'ASC',
		);
		if ( '' !== $search ) {
			$args['search'] = $search;
		}

		$terms = get_terms( $args );
		if ( is_wp_error( $terms ) ) {
			return $terms;
		}

		$count_args = array(
			'hide_empty' => $hide_empty,
		);
		if ( '' !== $search ) {
			$count_args['search'] = $search;
		}
		$total = wp_count_terms( $taxonomy, $count_args );
		$total = is_wp_error( $total ) ? count( $terms ) : absint( $total );

		$response = rest_ensure_response(
			array_values(
				array_map(
					function ( WP_Term $term ): array {
						return array(
							'id'    => $term->term_id,
							'name'  => $term->name,
							'slug'  => $term->slug,
							'count' => $term->count,
							'image' => array(
								'src' => $this->get_brand_image_url( $term->term_id ),
							),
						);
					},
					$terms
				)
			)
		);
		$response->header( 'X-WP-Total', (string) $total );
		$response->header( 'X-WP-TotalPages', (string) (int) ceil( $total / $per_page ) );
		return $response;
	}

	/** Register namespaced product data with WooCommerce's public API. */
	public function register_store_api_data(): void {
		if ( ! function_exists( 'woocommerce_store_api_register_endpoint_data' ) ||
			! class_exists( '\\Automattic\\WooCommerce\\StoreApi\\Schemas\\V1\\ProductSchema' ) ) {
			return;
		}


		woocommerce_store_api_register_endpoint_data(
			array(
				'endpoint'        => \Automattic\WooCommerce\StoreApi\Schemas\V1\ProductSchema::IDENTIFIER,
				'namespace'       => 'woo_mobile_cms',
				'data_callback'   => array( $this, 'get_product_brand_data' ),
				'schema_callback' => array( $this, 'get_product_brand_schema' ),
				'schema_type'     => ARRAY_A,
			)
		);
	}

	/** Return normalized brands for a Store API product response. */
	public function get_product_brand_data( $product ): array {
		if ( ! $product instanceof WC_Product ) {
			return array( 'brands' => array() );
		}

		$taxonomy = $this->get_brand_taxonomy();
		if ( '' === $taxonomy ) {
			return array( 'brands' => array() );
		}

		$terms = get_the_terms( $product->get_id(), $taxonomy );
		if ( is_wp_error( $terms ) || empty( $terms ) ) {
			return array( 'brands' => array() );
		}

		return array(
			'brands' => array_values( array_map(
				function ( WP_Term $term ) use ( $taxonomy ): array {
					$link = get_term_link( $term, $taxonomy );
					return array(
						'id'        => $term->term_id,
						'name'      => $term->name,
						'slug'      => $term->slug,
						'link'      => is_wp_error( $link ) ? '' : $link,
						'image_url' => $this->get_brand_image_url( $term->term_id ),
					);
				},
				$terms )
			)
		);
	}

	/** Describe the namespaced brand payload for Store API validation. */
	public function get_product_brand_schema(): array {
		return array(
			'brands' => array(
				'description' => __( 'Normalized product brands.', 'kidia-mobile-cms' ),
				'type'        => 'array',
				'readonly'    => true,
				'items'       => array(
					'type'       => 'object',
					'properties' => array(
						'id'        => array( 'type' => 'integer' ),
						'name'      => array( 'type' => 'string' ),
						'slug'      => array( 'type' => 'string' ),
						'link'      => array( 'type' => 'string' ),
						'image_url' => array( 'type' => 'string' ),
					),
				),
			),
		);
	}

	/** Find a supported registered product-brand taxonomy. */
	private function get_brand_taxonomy(): string {
		foreach ( array( 'product_brand', 'pwb-brand', 'yith_product_brand' ) as $taxonomy ) {
			if ( taxonomy_exists( $taxonomy ) ) {
				return $taxonomy;
			}
		}

		return '';
	}

	/** Resolve common brand-logo term metadata to an attachment URL. */
	private function get_brand_image_url( int $term_id ): string {
		foreach ( array( 'thumbnail_id', 'pwb_brand_image', 'brand_image_id' ) as $key ) {
			$attachment_id = absint( get_term_meta( $term_id, $key, true ) );
			if ( $attachment_id > 0 ) {
				$url = wp_get_attachment_image_url( $attachment_id, 'woocommerce_thumbnail' );
				if ( is_string( $url ) && '' !== $url ) {
					return $url;
				}
			}
		}

		return '';
	}
}
