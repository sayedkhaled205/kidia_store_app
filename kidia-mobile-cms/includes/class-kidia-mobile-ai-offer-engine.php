<?php
/**
 * Explainable, store-local offer recommendations.
 *
 * The engine intentionally uses first-party WooCommerce and Kidia analytics
 * data. It does not send customer or order data to an external AI provider.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_AI_Offer_Engine {

	/**
	 * Automatic guardrails used by the evidence engine.
	 *
	 * These are derived by the plugin and are deliberately not owner setup
	 * fields. The owner reviews the resulting action, not the analysis recipe.
	 *
	 * @return array<string,int|bool>
	 */
	public static function settings(): array {
		return array(
			'minimum_confidence'       => 35,
			'maximum_recommendations'  => 24,
			'high_interest_min_views'  => 3,
			'low_conversion_percent'   => 8,
			'slow_stock_min_age_days'  => 30,
			'slow_stock_min_units'     => 5,
			'protect_margin'           => true,
		);
	}

	/**
	 * Builds decision-ready offer suggestions from the selected channel.
	 *
	 * @return list<array<string,mixed>>
	 */
	public static function recommendations( int $from, int $to, string $source = 'all' ): array {
		$source    = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		$cache_key = 'kidia_ai_offers_v2_' . md5( $from . '|' . $to . '|' . $source );
		$cached    = get_transient( $cache_key );
		if ( is_array( $cached ) ) {
			return $cached;
		}

		$summary = Kidia_Mobile_Analytics::summary( $from, $to, $source );
		$settings = self::automatic_profile( $summary );
		$events  = $summary['events'];
		$commerce = is_array( $summary['commerce'] ?? null ) ? $summary['commerce'] : array();
		$views   = absint( $events['view_item']['count'] ?? 0 );
		$carts   = absint( $events['add_to_cart']['count'] ?? 0 );
		$checks  = absint( $events['begin_checkout']['count'] ?? 0 );
		$buys    = absint( $events['purchase']['count'] ?? 0 );
		$offers  = array();

		$purchases = array();
		foreach ( $summary['top_purchases'] as $row ) {
			$purchases[ absint( $row['object_id'] ) ] = absint( $row['event_count'] );
		}
		foreach ( array_slice( $summary['top_products'], 0, 12 ) as $row ) {
			$product_id = absint( $row['object_id'] );
			$product_views = absint( $row['event_count'] );
			$product_buys  = absint( $purchases[ $product_id ] ?? 0 );
			$minimum_views = absint( $settings['high_interest_min_views'] );
			$low_rate      = (float) $settings['low_conversion_percent'] / 100;
			if ( $product_views < $minimum_views || $product_buys >= max( 2, (int) floor( $product_views * $low_rate ) ) ) {
				continue;
			}
			$name = sanitize_text_field( (string) $row['event_label'] );
			$offers[] = self::offer(
				'high-interest-' . $product_id,
				'high_interest',
				__( 'Turn product interest into orders', 'kidia-mobile-cms' ),
				sprintf( __( '%1$s received %2$d views but only %3$d tracked purchases.', 'kidia-mobile-cms' ), $name, $product_views, $product_buys ),
				array(
					sprintf( __( '%d product views', 'kidia-mobile-cms' ), $product_views ),
					sprintf( __( '%d tracked purchases', 'kidia-mobile-cms' ), $product_buys ),
					__( 'A focused incentive can test whether price or hesitation is blocking checkout.', 'kidia-mobile-cms' ),
				),
				min( 92, 55 + min( 30, $product_views ) ),
				'medium',
				'percent',
				! empty( $settings['protect_margin'] ) ? 8 : 10,
				48,
				'engaged',
				$source,
				array( $product_id )
			);
		}

		$slow_products = self::slow_stock_products( $settings );
		foreach ( array_slice( $slow_products, 0, 6 ) as $product ) {
			$offers[] = self::offer(
				'slow-stock-' . $product['id'],
				'slow_stock',
				__( 'Rescue slow-moving stock', 'kidia-mobile-cms' ),
				sprintf(
					__( '%1$s has %2$d units in stock, has been listed for %3$d days and sold %4$d units.', 'kidia-mobile-cms' ),
					$product['name'],
					$product['stock'],
					$product['age_days'],
					$product['sales']
				),
				array(
					sprintf( __( '%d days in store', 'kidia-mobile-cms' ), $product['age_days'] ),
					sprintf( __( '%d available units', 'kidia-mobile-cms' ), $product['stock'] ),
					sprintf( __( 'Sales velocity: %.2f units/day', 'kidia-mobile-cms' ), $product['velocity'] ),
				),
				78,
				'medium',
				'percent',
				! empty( $settings['protect_margin'] ) ? 12 : 15,
				72,
				'engaged',
				$source,
				array( $product['id'] )
			);
		}

		$bundles = ! empty( $commerce['pairs'] ) ? array_slice( (array) $commerce['pairs'], 0, 8 ) : array();
		if ( empty( $bundles ) ) {
			$fallback_bundle = self::frequent_pair( $from, $to, $source );
			$bundles = empty( $fallback_bundle )
				? array()
				: array(
					array(
						'product_ids' => $fallback_bundle['ids'],
						'names'       => $fallback_bundle['names'],
						'count'       => $fallback_bundle['count'],
					)
				);
		}
		foreach ( $bundles as $bundle ) {
			$bundle_ids   = array_values( array_filter( array_map( 'absint', (array) ( $bundle['product_ids'] ?? array() ) ) ) );
			$bundle_names = array_values( array_map( 'sanitize_text_field', (array) ( $bundle['names'] ?? array() ) ) );
			$bundle_count = absint( $bundle['count'] ?? 0 );
			if ( count( $bundle_ids ) < 2 || count( $bundle_names ) < 2 || $bundle_count < 2 ) {
				continue;
			}
			$offers[] = self::offer(
				'bundle-' . implode( '-', $bundle_ids ),
				'bundle',
				__( 'Frequently bought together bundle', 'kidia-mobile-cms' ),
				sprintf( __( '%1$s and %2$s appeared together in %3$d paid orders.', 'kidia-mobile-cms' ), $bundle_names[0], $bundle_names[1], $bundle_count ),
				array(
					sprintf( __( '%d co-purchases', 'kidia-mobile-cms' ), $bundle_count ),
					__( 'Bundle only the measured pair; do not discount unrelated products.', 'kidia-mobile-cms' ),
					__( 'Recommended as a limited product-scoped coupon.', 'kidia-mobile-cms' ),
				),
				min( 94, 58 + $bundle_count * 4 ),
				'low',
				'percent',
				! empty( $settings['protect_margin'] ) ? 8 : 10,
				96,
				'all',
				$source,
				$bundle_ids
			);
		}

		if ( $carts >= 3 && $buys < $carts ) {
			$drop = round( 100 * max( 0, $carts - $buys ) / max( 1, $carts ), 1 );
			$offers[] = self::offer(
				'cart-recovery',
				'cart_recovery',
				__( 'Recover cart hesitation', 'kidia-mobile-cms' ),
				sprintf( __( '%1$d add-to-cart events produced %2$d purchases; the measured gap is %3$s%%.', 'kidia-mobile-cms' ), $carts, $buys, $drop ),
				array(
					sprintf( __( '%d add-to-cart events', 'kidia-mobile-cms' ), $carts ),
					sprintf( __( '%d purchases', 'kidia-mobile-cms' ), $buys ),
					__( 'Use a short expiry and send only to shoppers who left items behind.', 'kidia-mobile-cms' ),
				),
				min( 90, 55 + $carts ),
				'low',
				'percent',
				! empty( $settings['protect_margin'] ) ? 5 : 8,
				24,
				'abandoned',
				$source,
				array()
			);
		}

		if ( $checks >= 2 && $buys < $checks ) {
			$offers[] = self::offer(
				'checkout-threshold',
				'free_shipping',
				__( 'Test a free-shipping threshold', 'kidia-mobile-cms' ),
				sprintf( __( '%1$d shoppers began checkout and %2$d completed a tracked purchase.', 'kidia-mobile-cms' ), $checks, $buys ),
				array(
					sprintf( __( '%d checkout starts', 'kidia-mobile-cms' ), $checks ),
					sprintf( __( '%d purchases', 'kidia-mobile-cms' ), $buys ),
					__( 'Set the threshold above current average order value to protect margin.', 'kidia-mobile-cms' ),
				),
				min( 86, 54 + $checks ),
				'medium',
				'fixed_cart',
				0,
				24,
				'checkout',
				$source,
				array()
			);
		}

		if ( $buys >= 3 && (float) ( $events['purchase']['value'] ?? 0 ) > 0 ) {
			$aov       = (float) $events['purchase']['value'] / $buys;
			$threshold = ceil( $aov * 1.2 / 10 ) * 10;
			$offers[]  = self::offer(
				'aov-lift',
				'aov_lift',
				__( 'Lift average order value', 'kidia-mobile-cms' ),
				sprintf( __( 'Tracked average order value is %1$s. Test a reward above %2$s rather than discounting every order.', 'kidia-mobile-cms' ), wp_strip_all_tags( wc_price( $aov ) ), wp_strip_all_tags( wc_price( $threshold ) ) ),
				array(
					sprintf( __( '%d tracked purchases', 'kidia-mobile-cms' ), $buys ),
					sprintf( __( 'Current AOV: %s', 'kidia-mobile-cms' ), wp_strip_all_tags( wc_price( $aov ) ) ),
					__( 'The threshold is intentionally above current AOV to encourage one more item.', 'kidia-mobile-cms' ),
				),
				min( 90, 60 + $buys ),
				'low',
				'fixed_cart',
				round( max( 1, $aov * ( ! empty( $settings['protect_margin'] ) ? .04 : .05 ) ), 2 ),
				72,
				'all',
				$source,
				array()
			);
		}

		if ( $views >= 10 && empty( $offers ) ) {
			$offers[] = self::offer(
				'viewed-category',
				'category',
				__( 'Category cross-sell test', 'kidia-mobile-cms' ),
				__( 'The store has measurable browsing interest but no single product signal is strong enough yet.', 'kidia-mobile-cms' ),
				array(
					sprintf( __( '%d tracked product views', 'kidia-mobile-cms' ), $views ),
					__( 'Start with a small audience and compare conversion against a holdout.', 'kidia-mobile-cms' ),
				),
				52,
				'medium',
				'percent',
				5,
				48,
				'engaged',
				$source,
				array()
			);
		}

		$removed = absint( $events['remove_from_cart']['count'] ?? 0 );
		if ( $removed >= 3 && $removed >= max( 2, (int) floor( $carts * .25 ) ) ) {
			$offers[] = self::offer(
				'cart-removal-friction',
				'remove_friction',
				__( 'Investigate products removed from carts', 'kidia-mobile-cms' ),
				sprintf( __( '%1$d removal events were measured against %2$d add-to-cart events.', 'kidia-mobile-cms' ), $removed, $carts ),
				array(
					sprintf( __( '%d remove-from-cart events', 'kidia-mobile-cms' ), $removed ),
					__( 'Review unexpected shipping cost, variation clarity and stock messages before adding a discount.', 'kidia-mobile-cms' ),
					__( 'This is a funnel recommendation, not an automatically created offer.', 'kidia-mobile-cms' ),
				),
				min( 88, 55 + $removed ),
				'low',
				'percent',
				0,
				48,
				'engaged',
				$source,
				array()
			);
		}

		$registrations = absint( $events['sign_up']['count'] ?? 0 );
		if ( absint( $summary['visitors'] ?? 0 ) >= 5 && $registrations < max( 1, (int) floor( absint( $summary['visitors'] ) * .1 ) ) ) {
			$offers[] = self::offer(
				'signup-friction',
				'signup_friction',
				__( 'Simplify the registration decision', 'kidia-mobile-cms' ),
				sprintf( __( '%1$d visitors produced %2$d completed registrations in the selected period.', 'kidia-mobile-cms' ), absint( $summary['visitors'] ), $registrations ),
				array(
					sprintf( __( '%d measured visitors', 'kidia-mobile-cms' ), absint( $summary['visitors'] ) ),
					sprintf( __( '%d completed registrations', 'kidia-mobile-cms' ), $registrations ),
					__( 'Test fewer required fields and make guest checkout visible before offering a discount.', 'kidia-mobile-cms' ),
				),
				72,
				'low',
				'percent',
				0,
				72,
				'guests',
				$source,
				array()
			);
		}

		$top_search = $summary['top_searches'][0] ?? null;
		if ( is_array( $top_search ) && absint( $top_search['event_count'] ?? 0 ) >= 2 ) {
			$offers[] = self::offer(
				'search-demand-' . sanitize_key( (string) ( $top_search['event_label'] ?? '' ) ),
				'search_demand',
				__( 'Turn search demand into merchandising', 'kidia-mobile-cms' ),
				sprintf( __( 'Customers searched for “%1$s” %2$d times.', 'kidia-mobile-cms' ), sanitize_text_field( (string) $top_search['event_label'] ), absint( $top_search['event_count'] ) ),
				array(
					sprintf( __( '%d tracked searches', 'kidia-mobile-cms' ), absint( $top_search['event_count'] ) ),
					__( 'Feature matching products in navigation, categories or the home page.', 'kidia-mobile-cms' ),
					__( 'If no matching product exists, treat this as assortment demand rather than an offer.', 'kidia-mobile-cms' ),
				),
				min( 86, 58 + absint( $top_search['event_count'] ) * 2 ),
				'low',
				'percent',
				0,
				96,
				'all',
				$source,
				array()
			);
		}

		$top_category = $summary['top_categories'][0] ?? null;
		if ( is_array( $top_category ) && absint( $top_category['event_count'] ?? 0 ) >= 3 ) {
			$offers[] = self::offer(
				'category-demand-' . absint( $top_category['object_id'] ?? 0 ),
				'category_merchandising',
				__( 'Promote the category customers already explore', 'kidia-mobile-cms' ),
				sprintf( __( '%1$s attracted %2$d category views.', 'kidia-mobile-cms' ), sanitize_text_field( (string) $top_category['event_label'] ), absint( $top_category['event_count'] ) ),
				array(
					sprintf( __( '%d category views', 'kidia-mobile-cms' ), absint( $top_category['event_count'] ) ),
					__( 'Move the category higher in navigation or create a focused collection.', 'kidia-mobile-cms' ),
					__( 'Pair it with complementary products only when order data supports the relationship.', 'kidia-mobile-cms' ),
				),
				min( 88, 60 + absint( $top_category['event_count'] ) ),
				'low',
				'percent',
				0,
				96,
				'engaged',
				$source,
				array()
			);
		}

		$peak = $summary['activity_hours'][0] ?? null;
		if ( is_array( $peak ) && absint( $peak['event_count'] ?? 0 ) >= 3 ) {
			$hour = absint( $peak['hour'] ?? 0 );
			$offers[] = self::offer(
				'peak-time-' . $hour,
				'peak_timing',
				__( 'Schedule campaigns near peak activity', 'kidia-mobile-cms' ),
				sprintf( __( 'The busiest measured hour starts at %1$s with %2$d tracked actions.', 'kidia-mobile-cms' ), wp_date( get_option( 'time_format' ), mktime( $hour, 0 ) ), absint( $peak['event_count'] ) ),
				array(
					sprintf( __( '%d actions in the busiest hour', 'kidia-mobile-cms' ), absint( $peak['event_count'] ) ),
					__( 'Use this as a scheduling signal and compare it with a quieter-hour holdout.', 'kidia-mobile-cms' ),
					__( 'Timing alone does not justify a discount.', 'kidia-mobile-cms' ),
				),
				min( 84, 55 + absint( $peak['event_count'] ) ),
				'low',
				'percent',
				0,
				24,
				'all',
				$source,
				array()
			);
		}

		$top_viewed = $summary['top_products'][0] ?? null;
		if ( is_array( $top_viewed ) && absint( $top_viewed['event_count'] ?? 0 ) >= 3 ) {
			$product_id = absint( $top_viewed['object_id'] ?? 0 );
			$offers[] = self::offer(
				'popular-' . $product_id,
				'popular',
				__( 'Feature the most-viewed product', 'kidia-mobile-cms' ),
				sprintf( __( '%1$s is the most-viewed product with %2$d measured views.', 'kidia-mobile-cms' ), sanitize_text_field( (string) $top_viewed['event_label'] ), absint( $top_viewed['event_count'] ) ),
				array(
					sprintf( __( '%d measured views', 'kidia-mobile-cms' ), absint( $top_viewed['event_count'] ) ),
					__( 'Use a Popular now placement without discounting the product.', 'kidia-mobile-cms' ),
					__( 'Fallback safely to best sellers when visitor history is not available.', 'kidia-mobile-cms' ),
				),
				min( 91, 60 + absint( $top_viewed['event_count'] ) ),
				'low',
				'percent',
				0,
				168,
				'all',
				$source,
				$product_id ? array( $product_id ) : array()
			);
		}

		foreach ( array_slice( (array) $summary['top_purchases'], 0, 6 ) as $top_purchase ) {
			if ( ! is_array( $top_purchase ) || absint( $top_purchase['event_count'] ?? 0 ) < 1 ) {
				continue;
			}
			$product_id = absint( $top_purchase['object_id'] ?? 0 );
			$offers[] = self::offer(
				'best-seller-' . $product_id,
				'best_seller',
				__( 'Use a proven best-seller recommendation', 'kidia-mobile-cms' ),
				sprintf( __( '%1$s led the selected period with %2$d tracked purchases.', 'kidia-mobile-cms' ), sanitize_text_field( (string) $top_purchase['event_label'] ), absint( $top_purchase['event_count'] ) ),
				array(
					sprintf( __( '%d tracked purchases', 'kidia-mobile-cms' ), absint( $top_purchase['event_count'] ) ),
					__( 'Place it on Home or Category pages as social proof.', 'kidia-mobile-cms' ),
					__( 'Do not add a discount unless margin and funnel evidence justify one.', 'kidia-mobile-cms' ),
				),
				min( 94, 65 + absint( $top_purchase['event_count'] ) * 2 ),
				'low',
				'percent',
				0,
				168,
				'all',
				$source,
				$product_id ? array( $product_id ) : array()
			);
		}

		$offers = array_values(
			array_filter(
				$offers,
				static fn( $offer ) => absint( $offer['confidence'] ?? 0 ) >= absint( $settings['minimum_confidence'] )
			)
		);
		usort(
			$offers,
			static function ( array $left, array $right ): int {
				$confidence = absint( $right['confidence'] ?? 0 ) <=> absint( $left['confidence'] ?? 0 );
				if ( 0 !== $confidence ) {
					return $confidence;
				}
				return count( (array) ( $right['product_ids'] ?? array() ) )
					<=> count( (array) ( $left['product_ids'] ?? array() ) );
			}
		);
		$offers = apply_filters( 'kidia_mobile_ai_offer_recommendations', $offers, $summary, $source, $from, $to );
		$offers = is_array( $offers )
			? array_values( array_slice( $offers, 0, absint( $settings['maximum_recommendations'] ) ) )
			: array();
		set_transient( $cache_key, $offers, 10 * MINUTE_IN_SECONDS );
		return $offers;
	}

	/**
	 * Calibrates evidence thresholds from current store volume. The store owner
	 * reviews the outcome, while the engine owns the analytical thresholds.
	 *
	 * @param array<string,mixed> $summary Current analytical snapshot.
	 * @return array<string,int|bool>
	 */
	private static function automatic_profile( array $summary ): array {
		$settings = self::settings();
		$visitors = absint( $summary['visitors'] ?? 0 );
		$orders   = absint( $summary['commerce']['orders'] ?? 0 );
		$catalog  = absint( $summary['commerce']['catalog_products'] ?? 0 );
		$settings['high_interest_min_views'] = max( 3, min( 25, (int) ceil( max( 1, $visitors ) * .01 ) ) );
		$settings['slow_stock_min_age_days'] = $orders >= 100 ? 45 : 30;
		$settings['slow_stock_min_units'] = $catalog >= 1000 ? 8 : 3;
		$settings['minimum_confidence'] = $orders >= 50 || $visitors >= 500 ? 45 : 35;
		return $settings;
	}

	/**
	 * Playbooks researched from leading commerce recommendation systems and
	 * grouped for a usable interface rather than an overlapping tag cloud.
	 *
	 * @return array<string,array{label:string,items:list<string>}>
	 */
	public static function playbook_groups(): array {
		return array(
			'personalization' => array(
				'label' => __( 'Personalized discovery', 'kidia-mobile-cms' ),
				'items' => array( 'Recommended for you', 'Recently viewed', 'Continue shopping', 'Buy again', 'First purchase', 'VIP', 'Win-back' ),
			),
			'relationships' => array(
				'label' => __( 'Product relationships', 'kidia-mobile-cms' ),
				'items' => array( 'Frequently bought together', 'Complementary products', 'Related products', 'Viewed this, viewed that', 'Viewed this, bought that', 'More like this', 'Visual similarity', 'Complete the look' ),
			),
			'merchandising' => array(
				'label' => __( 'Merchandising & demand', 'kidia-mobile-cms' ),
				'items' => array( 'Trending now', 'Best sellers', 'Most viewed', 'Most added to cart', 'High conversion', 'Search-demand merchandising', 'Category cross-sell', 'New launch' ),
			),
			'offers' => array(
				'label' => __( 'Offers & basket growth', 'kidia-mobile-cms' ),
				'items' => array( 'AOV lift', 'Free shipping threshold', 'BOGO', 'Quantity break', 'Cart recovery', 'Checkout rescue', 'Bundle discount', 'Personal coupon' ),
			),
			'inventory' => array(
				'label' => __( 'Inventory & timing', 'kidia-mobile-cms' ),
				'items' => array( 'Slow-stock rescue', 'Overstock clearance', 'Low-stock urgency', 'Restock priority', 'Seasonal clearance', 'Peak-time scheduling' ),
			),
			'funnel' => array(
				'label' => __( 'Funnel decisions', 'kidia-mobile-cms' ),
				'items' => array( 'High view / low purchase', 'Registration friction', 'Search with no results', 'Product removal friction', 'Checkout drop-off', 'Channel comparison' ),
			),
		);
	}

	/**
	 * More than one hundred documented inputs that the engine can progressively
	 * cover as the store collects events, inventory and order history.
	 *
	 * @return list<string>
	 */
	public static function signal_catalog(): array {
		$metrics = array(
			'views', 'unique_views', 'add_to_cart', 'remove_from_cart', 'checkout_start',
			'purchase', 'conversion_rate', 'cart_rate', 'checkout_rate', 'drop_off',
			'units_sold', 'gross_revenue', 'net_revenue', 'average_order_value', 'discount_rate',
			'refund_rate', 'cancel_rate', 'return_rate', 'stock', 'stock_days',
			'stock_age', 'sales_velocity', 'sell_through', 'margin_proxy', 'price',
			'price_change', 'coupon_use', 'repeat_purchase', 'new_customer', 'returning_customer',
		);
		$windows = array( 'today', '7d', '30d', '90d' );
		$signals = array();
		foreach ( $metrics as $metric ) {
			foreach ( $windows as $window ) {
				$signals[] = $metric . '_' . $window;
			}
		}
		foreach ( array( 'website', 'mobile', 'hour', 'weekday', 'category', 'product_pair', 'customer_value', 'recency', 'frequency', 'season' ) as $dimension ) {
			$signals[] = 'dimension_' . $dimension;
		}
		$signals = apply_filters( 'kidia_mobile_ai_offer_signals', $signals );
		return is_array( $signals ) ? array_values( array_unique( array_map( 'sanitize_key', $signals ) ) ) : array();
	}

	/** @return list<array<string,mixed>> */
	private static function slow_stock_products( array $settings ): array {
		if ( ! function_exists( 'wc_get_products' ) ) {
			return array();
		}
		$products = wc_get_products(
			array(
				'status'       => 'publish',
				'stock_status' => 'instock',
				'limit'        => 250,
				'orderby'      => 'date',
				'order'        => 'ASC',
			)
		);
		$rows = array();
		foreach ( $products as $product ) {
			if ( ! $product instanceof WC_Product ) {
				continue;
			}
			$stock = $product->managing_stock() ? max( 0, (int) $product->get_stock_quantity() ) : 0;
			$sales = max( 0, (int) $product->get_total_sales() );
			$date  = $product->get_date_created();
			$age   = $date ? max( 1, (int) floor( ( time() - $date->getTimestamp() ) / DAY_IN_SECONDS ) ) : 1;
			if (
				$stock < absint( $settings['slow_stock_min_units'] )
				|| $age < absint( $settings['slow_stock_min_age_days'] )
				|| $sales > max( 10, $stock * 2 )
			) {
				continue;
			}
			$rows[] = array(
				'id'       => $product->get_id(),
				'name'     => $product->get_name(),
				'stock'    => $stock,
				'sales'    => $sales,
				'age_days' => $age,
				'velocity' => round( $sales / $age, 2 ),
				'score'    => $stock * $age / max( 1, $sales + 1 ),
			);
		}
		usort( $rows, static fn( $left, $right ) => $right['score'] <=> $left['score'] );
		return $rows;
	}

	/** @return array<string,mixed> */
	private static function frequent_pair( int $from, int $to, string $source ): array {
		if ( ! function_exists( 'wc_get_orders' ) ) {
			return array();
		}
		$args = array(
			'limit'        => 500,
			'status'       => function_exists( 'wc_get_is_paid_statuses' ) ? wc_get_is_paid_statuses() : array( 'processing', 'completed' ),
			'date_created' => $from . '...' . $to,
			'return'       => 'objects',
		);
		if ( 'mobile' === $source ) {
			$args['meta_query'] = array( array( 'key' => '_kidia_order_source', 'value' => 'mobile' ) );
		} elseif ( 'website' === $source ) {
			$args['meta_query'] = array(
				'relation' => 'OR',
				array( 'key' => '_kidia_order_source', 'compare' => 'NOT EXISTS' ),
				array( 'key' => '_kidia_order_source', 'value' => 'website' ),
			);
		}
		$pairs = array();
		foreach ( wc_get_orders( $args ) as $order ) {
			$ids = array_values( array_unique( array_filter( array_map( static fn( $item ) => absint( $item->get_product_id() ), $order->get_items() ) ) ) );
			sort( $ids );
			for ( $i = 0; $i < count( $ids ); ++$i ) {
				for ( $j = $i + 1; $j < count( $ids ); ++$j ) {
					$key = $ids[ $i ] . ':' . $ids[ $j ];
					$pairs[ $key ] = ( $pairs[ $key ] ?? 0 ) + 1;
				}
			}
		}
		if ( empty( $pairs ) ) {
			return array();
		}
		arsort( $pairs );
		$key   = (string) array_key_first( $pairs );
		$count = absint( $pairs[ $key ] );
		if ( $count < 2 ) {
			return array();
		}
		$ids   = array_map( 'absint', explode( ':', $key ) );
		$names = array_map(
			static function ( int $id ): string {
				$product = wc_get_product( $id );
				return $product instanceof WC_Product ? $product->get_name() : '#' . $id;
			},
			$ids
		);
		return array( 'ids' => $ids, 'names' => $names, 'count' => $count );
	}

	/** @return array<string,mixed> */
	private static function offer(
		string $id,
		string $scheme,
		string $title,
		string $summary,
		array $evidence,
		int $confidence,
		string $risk,
		string $discount_type,
		float $discount_value,
		int $duration_hours,
		string $audience,
		string $source,
		array $product_ids
	): array {
		$kind_map = array(
			'high_interest'          => 'campaign',
			'slow_stock'             => 'inventory',
			'bundle'                 => 'merchandising',
			'cart_recovery'          => 'campaign',
			'free_shipping'          => 'funnel',
			'aov_lift'               => 'campaign',
			'category'               => 'merchandising',
			'remove_friction'        => 'funnel',
			'signup_friction'        => 'funnel',
			'search_demand'          => 'merchandising',
			'category_merchandising' => 'merchandising',
			'peak_timing'            => 'timing',
			'popular'                => 'merchandising',
			'best_seller'            => 'merchandising',
		);
		$kind     = $kind_map[ $scheme ] ?? 'campaign';
		$is_offer = $discount_value > 0;
		$expected_outcomes = array(
			'campaign'      => __( 'Measure incremental purchases and revenue against the current baseline.', 'kidia-mobile-cms' ),
			'merchandising' => __( 'Improve product discovery, product-pair attachment and qualified product views.', 'kidia-mobile-cms' ),
			'inventory'     => __( 'Improve sell-through while limiting unnecessary margin loss.', 'kidia-mobile-cms' ),
			'funnel'        => __( 'Reduce the measured drop-off at the identified sales-funnel step.', 'kidia-mobile-cms' ),
			'timing'        => __( 'Improve campaign engagement by testing the strongest observed activity window.', 'kidia-mobile-cms' ),
		);
		$expected_outcome = $expected_outcomes[ $kind ] ?? $expected_outcomes['campaign'];
		$implementation_map = array(
			'bundle'                 => 'bundle',
			'popular'                => 'placement',
			'best_seller'            => 'placement',
			'search_demand'          => 'merchandising',
			'category_merchandising' => 'merchandising',
			'remove_friction'        => 'store_action',
			'signup_friction'        => 'store_action',
			'peak_timing'            => 'schedule',
			'free_shipping'          => 'shipping_rule',
		);
		$implementation = $implementation_map[ $scheme ] ?? ( $is_offer ? 'coupon' : 'store_action' );
		$placement_map = array(
			'popular'       => 'home',
			'best_seller'   => 'home',
			'bundle'        => 'product',
			'high_interest' => 'product',
			'search_demand' => 'search',
			'category_merchandising' => 'category',
			'cart_recovery' => 'cart',
			'free_shipping' => 'checkout',
		);
		$recommended_placement = $placement_map[ $scheme ] ?? 'analytics';
		return compact(
			'id',
			'scheme',
			'title',
			'summary',
			'evidence',
			'confidence',
			'risk',
			'discount_type',
			'discount_value',
			'duration_hours',
			'audience',
			'source',
			'product_ids',
			'kind',
			'is_offer',
			'expected_outcome',
			'implementation',
			'recommended_placement'
		);
	}
}
