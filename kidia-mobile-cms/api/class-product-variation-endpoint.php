<?php
/**
 * Public, normalized variation matrix for the native mobile product page.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Product_Variation_Endpoint {

	/** Register the public read-only route. */
	public function register(): void {
		add_action(
			'rest_api_init',
			array( $this, 'register_routes' )
		);
	}

	/** Register routes. */
	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/products/(?P<id>\d+)/variations',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_variations' ),
				'permission_callback' => '__return_true',
				'args'                => array(
					'id' => array(
						'required'          => true,
						'type'              => 'integer',
						'sanitize_callback' => 'absint',
						'validate_callback' => static fn( $value ): bool => absint( $value ) > 0,
					),
				),
			)
		);
	}

	/** Return exact purchasability and attributes for every variation. */
	public function get_variations( WP_REST_Request $request ) {
		if ( ! function_exists( 'wc_get_product' ) ) {
			return new WP_Error(
				'woo_mobile_woocommerce_unavailable',
				__( 'WooCommerce is not available.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$product = wc_get_product( absint( $request['id'] ) );
		if ( ! $product instanceof WC_Product_Variable ) {
			return new WP_Error(
				'woo_mobile_product_not_variable',
				__( 'The requested product has no variations.', 'kidia-mobile-cms' ),
				array( 'status' => 404 )
			);
		}

		$variations = array();
		foreach ( $product->get_children() as $variation_id ) {
			$variation = wc_get_product( $variation_id );
			if ( ! $variation instanceof WC_Product_Variation ) {
				continue;
			}

			$attributes = array();
			foreach ( $variation->get_attributes() as $taxonomy => $value ) {
				// Do not run non-Latin taxonomies through sanitize_key(). Arabic
				// attribute slugs are percent encoded by WooCommerce; stripping the
				// percent signs turns them into an unresolvable pa_d8... duplicate.
				$taxonomy = sanitize_text_field( (string) $taxonomy );
				$value    = sanitize_title( (string) $value );
				if ( '' === $taxonomy || '' === $value ) {
					continue;
				}
				$attributes[] = array(
					'name'     => wc_attribute_label( $taxonomy, $product ),
					'taxonomy' => $taxonomy,
					'value'    => $value,
				);
			}

			$variations[] = array(
				'id'             => $variation->get_id(),
				'attributes'     => $attributes,
				'is_purchasable' => $variation->is_purchasable(),
				'is_in_stock'    => $variation->is_in_stock(),
				'prices'         => $this->get_prices( $variation ),
				'image'          => $this->get_image( $variation ),
			);
		}

		return rest_ensure_response( array_values( $variations ) );
	}

	/** Normalize prices to the minor-unit contract used by Store API. */
	private function get_prices( WC_Product_Variation $variation ): array {
		$currency = get_woocommerce_currency();
		$decimals = wc_get_price_decimals();

		return array(
			'currency_code'       => $currency,
			'currency_symbol'     => get_woocommerce_currency_symbol( $currency ),
			'currency_minor_unit' => $decimals,
			'currency_prefix'     => '',
			'currency_suffix'     => '',
			'price'               => $this->to_minor_units( $variation->get_price(), $decimals ),
			'regular_price'       => $this->to_minor_units( $variation->get_regular_price(), $decimals ),
			'sale_price'          => $this->to_minor_units( $variation->get_sale_price(), $decimals ),
		);
	}

	/** Convert a decimal WooCommerce amount into a safe integer string. */
	private function to_minor_units( $amount, int $decimals ): string {
		if ( '' === $amount || null === $amount ) {
			return '';
		}

		$factor = 10 ** max( 0, min( 8, $decimals ) );
		return (string) (int) round( (float) wc_format_decimal( $amount, $decimals ) * $factor );
	}

	/** Return the variation image in the same shape as Store API. */
	private function get_image( WC_Product_Variation $variation ): ?array {
		$image_id = $variation->get_image_id();
		if ( $image_id <= 0 ) {
			return null;
		}

		$source = wp_get_attachment_image_url( $image_id, 'full' );
		if ( ! is_string( $source ) || '' === $source ) {
			return null;
		}

		return array(
			'src'       => $source,
			'thumbnail' => (string) wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' ),
			'name'      => get_the_title( $image_id ),
			'alt'       => (string) get_post_meta( $image_id, '_wp_attachment_image_alt', true ),
		);
	}
}
