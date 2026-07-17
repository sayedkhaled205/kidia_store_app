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

		$variations       = array();
		$attribute_matrix = $this->get_parent_attribute_matrix( $product );
		foreach ( $product->get_children() as $variation_id ) {
			$variation = wc_get_product( $variation_id );
			if ( ! $variation instanceof WC_Product_Variation ) {
				continue;
			}

			$attributes = array();
			foreach ( $variation->get_attributes() as $taxonomy => $value ) {
				// Neither sanitize_key() nor sanitize_text_field() is safe here. The
				// latter removes percent-encoded octets, turning an Arabic taxonomy
				// such as pa_%d8... into the broken key `pa_`.
				$taxonomy = $this->normalize_taxonomy( $taxonomy );
				$value    = sanitize_title( (string) $value );
				$taxonomy = $this->resolve_attribute_taxonomy(
					$taxonomy,
					$value,
					$attribute_matrix
				);
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

	/**
	 * Build a value-to-taxonomy map from the parent variable product.
	 *
	 * Some legacy stores contain a non-Latin variation meta key that reaches
	 * WC_Product_Variation as only `pa_`. The parent still owns the complete
	 * taxonomy, so matching a unique option value restores the real key and
	 * prevents the app from rendering the same attribute twice.
	 */
	private function get_parent_attribute_matrix( WC_Product_Variable $product ): array {
		if ( ! is_callable( array( $product, 'get_variation_attributes' ) ) ) {
			return array();
		}

		$matrix = array();
		foreach ( $product->get_variation_attributes() as $taxonomy => $values ) {
			$taxonomy = $this->normalize_taxonomy( $taxonomy );
			if ( '' === $taxonomy || ! is_array( $values ) ) {
				continue;
			}
			$matrix[ $taxonomy ] = array_values(
				array_filter(
					array_map(
						static fn( $value ): string => sanitize_title( (string) $value ),
						$values
					)
				)
			);
		}
		return $matrix;
	}

	/** Preserve WooCommerce's percent-encoded non-Latin taxonomy slugs. */
	private function normalize_taxonomy( $taxonomy ): string {
		$taxonomy = trim( wp_strip_all_tags( (string) $taxonomy ) );
		if ( str_starts_with( $taxonomy, 'attribute_' ) ) {
			$taxonomy = substr( $taxonomy, strlen( 'attribute_' ) );
		}
		return sanitize_title( $taxonomy );
	}

	/** Restore only an unambiguous broken taxonomy; valid keys stay untouched. */
	private function resolve_attribute_taxonomy(
		string $taxonomy,
		string $value,
		array $attribute_matrix
	): string {
		if ( '' !== $taxonomy && 'pa_' !== $taxonomy && 'attribute_pa_' !== $taxonomy ) {
			return $taxonomy;
		}
		if ( '' === $value ) {
			return $taxonomy;
		}

		$matches = array();
		foreach ( $attribute_matrix as $candidate => $values ) {
			if ( in_array( $value, $values, true ) ) {
				$matches[] = $candidate;
			}
		}
		return 1 === count( $matches ) ? $matches[0] : $taxonomy;
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
