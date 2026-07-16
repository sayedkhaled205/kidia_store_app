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
			'woocommerce_blocks_loaded',
			array( $this, 'register_store_api_data' )
		);
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
