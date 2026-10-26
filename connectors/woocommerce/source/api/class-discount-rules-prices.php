<?php
/** FlyCart display prices for the mobile catalogue; cart pricing stays with WooCommerce. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Discount_Rules_Prices {

	public static function register(): void {
		add_filter( 'rest_post_dispatch', array( self::class, 'catalogue_response' ), 50, 3 );
		add_filter( 'rest_post_dispatch', array( self::class, 'cart_response' ), 50, 3 );
	}

	public static function available(): bool {
		return false !== has_filter( 'advanced_woo_discount_rules_get_product_discount_price' );
	}

	/** Returns a raw, quantity-one quote, including a legitimate zero price. */
	private static function quote( $product ): ?float {
		$value = apply_filters( 'advanced_woo_discount_rules_get_product_discount_price', false, $product, 1, 0 );
		return is_numeric( $value ) && is_finite( (float) $value ) && (float) $value >= 0
			? (float) $value : null;
	}

	private static function minor( $product, $amount, int $decimals, bool $display_tax ): string {
		if ( '' === $amount || null === $amount ) {
			return '';
		}
		if ( $display_tax ) {
			$price_function = 'incl' === get_option( 'woocommerce_tax_display_shop' )
				? 'wc_get_price_including_tax' : 'wc_get_price_excluding_tax';
			$amount = $price_function( $product, array( 'price' => $amount ) );
		}
		return (string) (int) round( (float) wc_format_decimal( $amount, $decimals ) * ( 10 ** $decimals ) );
	}

	/** Replaces display fields only. Never writes product data or modifies a cart item. */
	public static function prices( $product, array $prices, bool $display_tax = true ): array {
		if ( ! self::available() || ! $product || ! isset( $prices['currency_minor_unit'] ) ) {
			return $prices;
		}
		$decimals = max( 0, min( 8, (int) $prices['currency_minor_unit'] ) );
		$original = $prices;
		try {
			if ( $product->is_type( 'variable' ) ) {
				// FlyCart's parent quote uses its first child, not its cheapest child.
				// WooCommerce's visible price map preserves its visibility/stock rules.
				$visible = $product->get_variation_prices( false );
				$candidates = array();
				$changed = false;
				foreach ( array_keys( $visible['price'] ?? array() ) as $id ) {
					$child = wc_get_product( $id );
					if ( ! $child || ! $child->is_type( 'variation' ) || (int) $child->get_parent_id() !== (int) $product->get_id() ) {
						continue;
					}
					$quote = self::quote( $child );
					$changed = $changed || null !== $quote;
					$current = self::minor( $child, null === $quote ? $child->get_price() : $quote, $decimals, $display_tax );
					$regular = self::minor( $child, $child->get_regular_price(), $decimals, $display_tax );
					if ( '' !== $current ) {
						$candidates[] = array( 'price' => $current, 'regular' => $regular );
					}
				}
				if ( ! $changed || ! $candidates ) {
					return $prices;
				}
				usort( $candidates, static fn( $a, $b ) => (int) $a['price'] <=> (int) $b['price'] );
				$prices['price'] = $candidates[0]['price'];
				$prices['regular_price'] = $candidates[0]['regular'];
				$maximum = $candidates[ count( $candidates ) - 1 ]['price'];
				$prices['price_range'] = $maximum === $prices['price'] ? null : (object) array(
					'min_amount' => $prices['price'], 'max_amount' => $maximum,
				);
			} elseif ( $product->is_type( array( 'simple', 'variation', 'external' ) ) ) {
				$quote = self::quote( $product );
				if ( null === $quote ) {
					return $prices;
				}
				$prices['price'] = self::minor( $product, $quote, $decimals, $display_tax );
				$prices['regular_price'] = self::minor( $product, $product->get_regular_price(), $decimals, $display_tax );
			} else {
				return $prices;
			}
			// Do not clamp to a stored sale: FlyCart can be configured to use regular price.
			$prices['sale_price'] = $prices['price'];
			return $prices;
		} catch ( Throwable $error ) {
			// A third-party calculation failure must not break the catalogue.
			return $original;
		}
	}

	private static function item( array $item ): array {
		if ( empty( $item['id'] ) || ! isset( $item['prices'] ) || ! ( is_array( $item['prices'] ) || is_object( $item['prices'] ) ) ) {
			return $item;
		}
		$product = wc_get_product( (int) $item['id'] );
		$before = (array) $item['prices'];
		$after = self::prices( $product, $before );
		if ( $after !== $before ) {
			$item['prices'] = is_object( $item['prices'] ) ? (object) $after : $after;
			$item['on_sale'] = '' !== ( $after['regular_price'] ?? '' ) && (int) $after['price'] < (int) $after['regular_price'];
		}
		return $item;
	}

	public static function catalogue_response( $response, $server, $request ) {
		if ( ! self::available() || 'GET' !== $request->get_method() || 'mobile' !== strtolower( (string) $request->get_header( 'X-MobiShop-Channel' ) )
			|| ! preg_match( '#^/wc/store/v[0-9]+/products(?:/[0-9]+)?/?$#', $request->get_route() )
			|| ! ( $response instanceof WP_REST_Response ) || 200 !== $response->get_status() ) {
			return $response;
		}
		$data = $response->get_data();
		if ( ! is_array( $data ) ) {
			return $response;
		}
		if ( isset( $data['id'] ) ) {
			$data = self::item( $data );
		} else {
			foreach ( $data as &$item ) {
				if ( is_array( $item ) ) {
					$item = self::item( $item );
				}
			}
			unset( $item );
		}
		$response->set_data( $data );
		// Quotes can depend on dates, currency and customer context.
		$response->header( 'Cache-Control', 'no-store, private' );
		return $response;
	}

	/** Pro's website quantity lock is HTML-only; carry it into the native contract. */
	public static function cart_response( $response, $server, $request ) {
		if ( ! is_callable( array( '\\WDRPro\\App\\Rules\\BOGO', 'isFreeProduct' ) )
			|| ! preg_match( '#^/wc/store/v[0-9]+/cart(?:/[^/]+)?/?$#', $request->get_route() )
			|| ! ( $response instanceof WP_REST_Response ) || 200 !== $response->get_status()
			|| ! function_exists( 'WC' ) || ! WC()->cart ) {
			return $response;
		}
		$data = $response->get_data();
		if ( ! is_array( $data ) || ! isset( $data['items'] ) || ! is_array( $data['items'] ) ) {
			return $response;
		}
		foreach ( $data['items'] as &$item ) {
			if ( ! is_array( $item ) || empty( $item['key'] ) ) { continue; }
			$cart_item = WC()->cart->get_cart_item( $item['key'] );
			if ( $cart_item && \WDRPro\App\Rules\BOGO::isFreeProduct( $cart_item ) ) {
				$limits = (array) ( $item['quantity_limits'] ?? array() );
				$limits['editable'] = false;
				$item['quantity_limits'] = (object) $limits;
			}
		}
		unset( $item );
		$response->set_data( $data );
		return $response;
	}
}
MobiShop_Discount_Rules_Prices::register();
