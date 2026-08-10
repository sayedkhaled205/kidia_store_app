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
			'minimum_confidence'       => 55,
			'maximum_recommendations'  => 60,
			'high_interest_min_views'  => 10,
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
		$cache_key = self::recommendation_cache_key( $from, $to, $source );
		$cached    = get_transient( $cache_key );
		if ( is_array( $cached ) ) {
			return $cached;
		}

		$summary = Kidia_Mobile_Analytics::summary( $from, $to, $source );
		$settings = self::automatic_profile( $summary );
		$events  = $summary['events'];
		$funnel  = is_array( $summary['funnel'] ?? null ) ? $summary['funnel'] : array();
		$commerce = is_array( $summary['commerce'] ?? null ) ? $summary['commerce'] : array();
		$views   = absint( $events['view_item']['count'] ?? 0 );
		$carts   = absint( $funnel['added_to_cart'] ?? 0 );
		$checks  = absint( $funnel['started_checkout'] ?? 0 );
		$buys    = absint( $funnel['purchased'] ?? 0 );
		$historical_orders = absint( $commerce['orders'] ?? 0 );
		$offers  = array();
		$rotation_segments = self::rotation_segments( $from, $to, $source );
		$rotation_labels   = array(
			'fast'   => __( 'Fast-moving products', 'mobishop' ),
			'medium' => __( 'Medium-moving products', 'mobishop' ),
			'slow'   => __( 'Slow-moving products', 'mobishop' ),
			'poor'   => __( 'Poor-performing products', 'mobishop' ),
		);
		foreach ( $rotation_segments as $segment => $products ) {
			foreach ( array_slice( $products, 0, 10 ) as $product_index => $product ) {
				$discount = 0.0;
				$scheme   = $segment . '_rotation';
				$title    = __( 'Protect demand without discounting', 'mobishop' );
				$risk     = 'low';
				$duration = 168;
				if ( 'medium' === $segment ) {
					$title    = __( 'Accelerate a medium-moving product', 'mobishop' );
					$discount = 5.0;
					$duration = 96;
				} elseif ( 'slow' === $segment ) {
					$title    = __( 'Move slow stock with a controlled offer', 'mobishop' );
					$discount = self::discount_for_slow_stock( $product, true );
					$risk     = 'medium';
					$duration = 72;
				} elseif ( 'poor' === $segment ) {
					$title    = __( 'Clear poor-performing stock safely', 'mobishop' );
					$discount = max( 12, self::discount_for_slow_stock( $product, false ) );
					$risk     = 'medium';
					$duration = 72;
				}
				$recommendation = self::offer(
					'rotation-' . $segment . '-' . absint( $product['id'] ?? 0 ),
					$scheme,
					$title,
					sprintf(
						__( '%1$s is classified as %2$s from its selected-period sales, stock, age and selling velocity.', 'mobishop' ),
						sanitize_text_field( (string) ( $product['name'] ?? '' ) ),
						$rotation_labels[ $segment ] ?? $segment
					),
					array(
						sprintf( __( '%d units sold in the selected period', 'mobishop' ), absint( $product['sales'] ?? 0 ) ),
						sprintf( __( 'Sales velocity: %.3f units/day', 'mobishop' ), (float) ( $product['velocity'] ?? 0 ) ),
						sprintf( __( '%d days in store', 'mobishop' ), absint( $product['age_days'] ?? 0 ) ),
						null === ( $product['stock'] ?? null )
							? __( 'Stock status: available (quantity is not managed)', 'mobishop' )
							: sprintf( __( '%d units currently available', 'mobishop' ), absint( $product['stock'] ) ),
					),
					min( 96, 64 + min( 28, absint( $product['sales'] ?? 0 ) * 2 ) ),
					$risk,
					'percent',
					$discount,
					$duration,
					'engaged',
					$source,
					array( absint( $product['id'] ?? 0 ) )
				);
				$recommendation['rotation_segment'] = $segment;
				$recommendation['rotation_label']   = $rotation_labels[ $segment ] ?? $segment;
				$offers[] = $recommendation;
				if ( 'fast' === $segment && $product_index < 5 ) {
					$fast_offer = self::offer(
						'rotation-fast-offer-' . absint( $product['id'] ?? 0 ),
						'fast_offer',
						__( 'Grow basket value with a short fast-product offer', 'mobishop' ),
						sprintf(
							__( '%1$s is already fast-moving, so this is a short low-discount basket-growth test rather than a clearance action.', 'mobishop' ),
							sanitize_text_field( (string) ( $product['name'] ?? '' ) )
						),
						array(
							sprintf( __( '%d units sold in the selected period', 'mobishop' ), absint( $product['sales'] ?? 0 ) ),
							sprintf( __( 'Sales velocity: %.3f units/day', 'mobishop' ), (float) ( $product['velocity'] ?? 0 ) ),
							__( 'The offer is intentionally limited to 3% and 48 hours to protect margin on proven demand.', 'mobishop' ),
						),
						min( 94, 68 + min( 24, absint( $product['sales'] ?? 0 ) ) ),
						'medium',
						'percent',
						3.0,
						48,
						'engaged',
						$source,
						array( absint( $product['id'] ?? 0 ) )
					);
					$fast_offer['rotation_segment'] = 'fast';
					$fast_offer['rotation_label']   = $rotation_labels['fast'];
					$offers[] = $fast_offer;
				}
			}
		}

		$purchases = array();
		foreach ( (array) ( $summary['tracked_top_purchases'] ?? array() ) as $row ) {
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
			$discount = self::discount_for_conversion_gap( $product_views, $product_buys, ! empty( $settings['protect_margin'] ) );
			$offers[] = self::offer(
				'high-interest-' . $product_id,
				'high_interest',
				__( 'Turn product interest into orders', 'mobishop' ),
				sprintf( __( '%1$s received %2$d views but only %3$d tracked purchases.', 'mobishop' ), $name, $product_views, $product_buys ),
				array(
					sprintf( __( '%d product views', 'mobishop' ), $product_views ),
					sprintf( __( '%d tracked purchases', 'mobishop' ), $product_buys ),
					__( 'A focused incentive can test whether price or hesitation is blocking checkout.', 'mobishop' ),
				),
				min( 92, 55 + min( 30, $product_views ) ),
				'medium',
				'percent',
				$discount,
				48,
				'engaged',
				$source,
				array( $product_id )
			);
		}

		$bundles = ! empty( $commerce['pairs'] ) ? array_slice( (array) $commerce['pairs'], 0, 8 ) : array();
		$product_order_counts = array();
		foreach ( (array) ( $commerce['products'] ?? array() ) as $product_row ) {
			$product_order_counts[ absint( $product_row['object_id'] ?? $product_row['id'] ?? 0 ) ] = absint( $product_row['order_count'] ?? 0 );
		}
		foreach ( $bundles as $bundle ) {
			$bundle_ids   = array_values( array_filter( array_map( 'absint', (array) ( $bundle['product_ids'] ?? array() ) ) ) );
			$bundle_names = array_values( array_map( 'sanitize_text_field', (array) ( $bundle['names'] ?? array() ) ) );
			$bundle_count = absint( $bundle['count'] ?? 0 );
			if ( count( $bundle_ids ) < 2 || count( $bundle_names ) < 2 || $bundle_count < 2 ) {
				continue;
			}
			$left_orders  = absint( $product_order_counts[ $bundle_ids[0] ] ?? 0 );
			$right_orders = absint( $product_order_counts[ $bundle_ids[1] ] ?? 0 );
			$support      = $historical_orders > 0 ? $bundle_count / $historical_orders : 0.0;
			$confidence   = min( $left_orders, $right_orders ) > 0 ? $bundle_count / min( $left_orders, $right_orders ) : 0.0;
			$lift         = $left_orders > 0 && $right_orders > 0 && $historical_orders > 0
				? ( $bundle_count * $historical_orders ) / ( $left_orders * $right_orders )
				: 0.0;
			if ( $lift < 1.2 || $confidence < .08 ) {
				continue;
			}
			$bundle_discount = self::discount_for_bundle( $bundle_count, $historical_orders, ! empty( $settings['protect_margin'] ) );
			$offers[] = self::offer(
				'bundle-' . implode( '-', $bundle_ids ),
				'bundle',
				__( 'Frequently bought together bundle', 'mobishop' ),
				sprintf( __( '%1$s and %2$s appeared together in %3$d paid orders.', 'mobishop' ), $bundle_names[0], $bundle_names[1], $bundle_count ),
				array(
					sprintf( __( '%d co-purchases', 'mobishop' ), $bundle_count ),
					sprintf( __( 'Support: %1$s%% · Confidence: %2$s%% · Lift: %3$s×', 'mobishop' ), round( 100 * $support, 2 ), round( 100 * $confidence, 1 ), round( $lift, 2 ) ),
					__( 'Lift above 1 means the relationship is stronger than random popularity; unrelated popular pairs are excluded.', 'mobishop' ),
				),
				min( 96, 58 + min( 20, $bundle_count * 2 ) + min( 18, (int) round( ( $lift - 1 ) * 10 ) ) ),
				'low',
				'percent',
				$bundle_discount,
				96,
				'all',
				$source,
				$bundle_ids
			);
		}

		if ( ! empty( $funnel['is_reliable'] ) && $carts >= 3 && $buys < $carts ) {
			$drop = round( 100 * max( 0, $carts - $buys ) / max( 1, $carts ), 1 );
			$offers[] = self::offer(
				'cart-recovery',
				'cart_recovery',
				__( 'Recover cart hesitation', 'mobishop' ),
				sprintf( __( '%1$d add-to-cart events produced %2$d purchases; the measured gap is %3$s%%.', 'mobishop' ), $carts, $buys, $drop ),
				array(
					sprintf( __( '%d add-to-cart events', 'mobishop' ), $carts ),
					sprintf( __( '%d purchases', 'mobishop' ), $buys ),
					__( 'Use a short expiry and send only to shoppers who left items behind.', 'mobishop' ),
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

		if ( ! empty( $funnel['is_reliable'] ) && $checks >= 2 && $buys < $checks ) {
			$offers[] = self::offer(
				'checkout-threshold',
				'free_shipping',
				__( 'Test a free-shipping threshold', 'mobishop' ),
				sprintf( __( '%1$d shoppers began checkout and %2$d completed a tracked purchase.', 'mobishop' ), $checks, $buys ),
				array(
					sprintf( __( '%d checkout starts', 'mobishop' ), $checks ),
					sprintf( __( '%d purchases', 'mobishop' ), $buys ),
					__( 'Set the threshold above current average order value to protect margin.', 'mobishop' ),
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

		if ( $historical_orders >= 3 && (float) ( $commerce['revenue'] ?? 0 ) > 0 ) {
			$aov       = (float) $commerce['revenue'] / $historical_orders;
			$threshold = ceil( $aov * 1.2 / 10 ) * 10;
			$offers[]  = self::offer(
				'aov-lift',
				'aov_lift',
				__( 'Lift average order value', 'mobishop' ),
				sprintf( __( 'Tracked average order value is %1$s. Test a reward above %2$s rather than discounting every order.', 'mobishop' ), wp_strip_all_tags( wc_price( $aov ) ), wp_strip_all_tags( wc_price( $threshold ) ) ),
				array(
					sprintf( __( '%d paid WooCommerce orders', 'mobishop' ), $historical_orders ),
					sprintf( __( 'Current AOV: %s', 'mobishop' ), wp_strip_all_tags( wc_price( $aov ) ) ),
					__( 'The threshold is intentionally above current AOV to encourage one more item.', 'mobishop' ),
				),
				min( 90, 60 + min( 25, $historical_orders ) ),
				'low',
				'fixed_cart',
				round( max( 1, $aov * ( ! empty( $settings['protect_margin'] ) ? .04 : .05 ) ), 2 ),
				72,
				'all',
				$source,
				array()
			);
		}

		$removed = absint( $events['remove_from_cart']['count'] ?? 0 );
		$tracked_cart_events = absint( $events['add_to_cart']['count'] ?? 0 );
		if ( $removed >= 3 && $removed >= max( 2, (int) floor( $tracked_cart_events * .25 ) ) ) {
			$offers[] = self::offer(
				'cart-removal-friction',
				'remove_friction',
				__( 'Investigate products removed from carts', 'mobishop' ),
				sprintf( __( '%1$d removal events were measured against %2$d add-to-cart events.', 'mobishop' ), $removed, $tracked_cart_events ),
				array(
					sprintf( __( '%d remove-from-cart events', 'mobishop' ), $removed ),
					__( 'Review unexpected shipping cost, variation clarity and stock messages before adding a discount.', 'mobishop' ),
					__( 'This is a funnel recommendation, not an automatically created offer.', 'mobishop' ),
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
				__( 'Simplify the registration decision', 'mobishop' ),
				sprintf( __( '%1$d visitors produced %2$d completed registrations in the selected period.', 'mobishop' ), absint( $summary['visitors'] ), $registrations ),
				array(
					sprintf( __( '%d measured visitors', 'mobishop' ), absint( $summary['visitors'] ) ),
					sprintf( __( '%d completed registrations', 'mobishop' ), $registrations ),
					__( 'Test fewer required fields and make guest checkout visible before offering a discount.', 'mobishop' ),
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
				__( 'Turn search demand into merchandising', 'mobishop' ),
				sprintf( __( 'Customers searched for “%1$s” %2$d times.', 'mobishop' ), sanitize_text_field( (string) $top_search['event_label'] ), absint( $top_search['event_count'] ) ),
				array(
					sprintf( __( '%d tracked searches', 'mobishop' ), absint( $top_search['event_count'] ) ),
					__( 'Feature matching products in navigation, categories or the home page.', 'mobishop' ),
					__( 'If no matching product exists, treat this as assortment demand rather than an offer.', 'mobishop' ),
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
				__( 'Promote the category customers already explore', 'mobishop' ),
				sprintf( __( '%1$s attracted %2$d category views.', 'mobishop' ), sanitize_text_field( (string) $top_category['event_label'] ), absint( $top_category['event_count'] ) ),
				array(
					sprintf( __( '%d category views', 'mobishop' ), absint( $top_category['event_count'] ) ),
					__( 'Move the category higher in navigation or create a focused collection.', 'mobishop' ),
					__( 'Pair it with complementary products only when order data supports the relationship.', 'mobishop' ),
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
				__( 'Schedule campaigns near peak activity', 'mobishop' ),
				sprintf( __( 'The busiest measured hour starts at %1$s with %2$d tracked actions.', 'mobishop' ), wp_date( get_option( 'time_format' ), mktime( $hour, 0 ) ), absint( $peak['event_count'] ) ),
				array(
					sprintf( __( '%d actions in the busiest hour', 'mobishop' ), absint( $peak['event_count'] ) ),
					__( 'Use this as a scheduling signal and compare it with a quieter-hour holdout.', 'mobishop' ),
					__( 'Timing alone does not justify a discount.', 'mobishop' ),
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
				__( 'Feature the most-viewed product', 'mobishop' ),
				sprintf( __( '%1$s is the most-viewed product with %2$d measured views.', 'mobishop' ), sanitize_text_field( (string) $top_viewed['event_label'] ), absint( $top_viewed['event_count'] ) ),
				array(
					sprintf( __( '%d measured views', 'mobishop' ), absint( $top_viewed['event_count'] ) ),
					__( 'Use a Popular now placement without discounting the product.', 'mobishop' ),
					__( 'Fallback safely to best sellers when visitor history is not available.', 'mobishop' ),
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
				__( 'Use a proven best-seller recommendation', 'mobishop' ),
				sprintf( __( '%1$s led the selected period with %2$d tracked purchases.', 'mobishop' ), sanitize_text_field( (string) $top_purchase['event_label'] ), absint( $top_purchase['event_count'] ) ),
				array(
					sprintf( __( '%d tracked purchases', 'mobishop' ), absint( $top_purchase['event_count'] ) ),
					__( 'Place it on Home or Category pages as social proof.', 'mobishop' ),
					__( 'Do not add a discount unless margin and funnel evidence justify one.', 'mobishop' ),
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
		foreach ( $offers as &$offer ) {
			$offer = self::add_expected_outcomes( $offer, $commerce, $from, $to );
		}
		unset( $offer );
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
		$offers = self::remove_discount_conflicts( $offers );
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
		$settings['high_interest_min_views'] = max( 10, min( 50, (int) ceil( max( 1, $visitors ) * .015 ) ) );
		$settings['slow_stock_min_age_days'] = $orders >= 100 ? 45 : 30;
		$settings['slow_stock_min_units'] = $catalog >= 1000 ? 8 : 3;
		$settings['minimum_confidence'] = $orders >= 50 || $visitors >= 500 ? 65 : 55;
		return $settings;
	}

	/**
	 * Classifies every currently available catalog product from real selected-period
	 * sales. The result is cached with the analytical snapshot so opening the page
	 * stays light and repeated filtering never scans the catalog again.
	 *
	 * @return array{fast:list<array<string,mixed>>,medium:list<array<string,mixed>>,slow:list<array<string,mixed>>,poor:list<array<string,mixed>>}
	 */
	public static function rotation_segments( int $from, int $to, string $source = 'all' ): array {
		$source    = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		$cache_key = self::rotation_cache_key( $from, $to, $source );
		$cached    = get_transient( $cache_key );
		if ( is_array( $cached ) ) {
			return array_merge( self::empty_rotation_segments(), $cached );
		}
		$segments = self::empty_rotation_segments();
		if ( ! function_exists( 'wc_get_products' ) || ! function_exists( 'wc_get_product' ) ) {
			return $segments;
		}

		$commerce   = Kidia_Mobile_Analytics::commerce_snapshot( $from, $to, $source );
		$sales_map  = is_array( $commerce['product_sales'] ?? null ) ? $commerce['product_sales'] : array();
		$period_days = max( 1, (int) ceil( max( DAY_IN_SECONDS, $to - $from ) / DAY_IN_SECONDS ) );
		$rows       = array();
		$velocities = array();
		$catalog_rows = is_array( $commerce['catalog_rows'] ?? null ) ? $commerce['catalog_rows'] : array();
		if ( empty( $catalog_rows ) ) {
			$product_ids = wc_get_products(
				array(
					'status'       => 'publish',
					'stock_status' => 'instock',
					'limit'        => -1,
					'return'       => 'ids',
					'orderby'      => 'ID',
					'order'        => 'ASC',
				)
			);
			foreach ( array_map( 'absint', (array) $product_ids ) as $product_id ) {
				$product = wc_get_product( $product_id );
				if ( ! $product instanceof WC_Product || ! $product->is_in_stock() ) {
					continue;
				}
				$created = $product->get_date_created();
				$catalog_rows[] = array(
					'id'       => $product_id,
					'name'     => $product->get_name(),
					'stock'    => $product->managing_stock() ? max( 0, (int) $product->get_stock_quantity() ) : null,
					'age_days' => $created ? max( 1, (int) floor( ( time() - $created->getTimestamp() ) / DAY_IN_SECONDS ) ) : 1,
				);
			}
		}
		foreach ( $catalog_rows as $catalog_row ) {
			$product_id = absint( $catalog_row['id'] ?? 0 );
			if ( $product_id <= 0 ) {
				continue;
			}
			$age     = max( 1, absint( $catalog_row['age_days'] ?? 1 ) );
			$sales   = absint( $sales_map[ $product_id ] ?? 0 );
			$days    = max( 1, min( $period_days, $age ) );
			$velocity = $sales / $days;
			if ( $sales > 0 ) {
				$velocities[] = $velocity;
			}
			$stock = array_key_exists( 'stock', $catalog_row ) && null !== $catalog_row['stock']
				? max( 0, (int) $catalog_row['stock'] )
				: null;
			$rows[] = array(
				'id'          => $product_id,
				'name'        => sanitize_text_field( (string) ( $catalog_row['name'] ?? '#' . $product_id ) ),
				'sales'       => $sales,
				'stock'       => $stock,
				'age_days'    => $age,
				'period_days' => $days,
				'velocity'    => round( $velocity, 4 ),
				'opportunity' => round( $age * max( 1, null === $stock ? 1 : $stock ) / max( 1, $sales + 1 ), 2 ),
			);
		}
		sort( $velocities, SORT_NUMERIC );
		$fast_threshold   = self::percentile( $velocities, .75 );
		$medium_threshold = self::percentile( $velocities, .40 );
		foreach ( $rows as $row ) {
			$sales    = absint( $row['sales'] ?? 0 );
			$velocity = (float) ( $row['velocity'] ?? 0 );
			$age      = absint( $row['age_days'] ?? 0 );
			if ( $sales > 0 && $velocity >= max( .0001, $fast_threshold ) ) {
				$segments['fast'][] = $row;
			} elseif ( $sales > 0 && $velocity >= max( .0001, $medium_threshold ) ) {
				$segments['medium'][] = $row;
			} elseif ( $sales > 0 || $age < 120 ) {
				$segments['slow'][] = $row;
			} else {
				$segments['poor'][] = $row;
			}
		}
		foreach ( $segments as $segment => &$segment_rows ) {
			usort(
				$segment_rows,
				in_array( $segment, array( 'fast', 'medium' ), true )
					? static fn( $left, $right ) => ( $right['sales'] <=> $left['sales'] ) ?: ( $right['velocity'] <=> $left['velocity'] )
					: static fn( $left, $right ) => $right['opportunity'] <=> $left['opportunity']
			);
		}
		unset( $segment_rows );
		set_transient( $cache_key, $segments, 10 * MINUTE_IN_SECONDS );
		return $segments;
	}

	/** Clears derived decisions after a fresh incremental store snapshot. */
	public static function clear_cache( int $from, int $to, string $source = 'all' ): void {
		delete_transient( self::recommendation_cache_key( $from, $to, $source ) );
		delete_transient( self::rotation_cache_key( $from, $to, $source ) );
	}

	private static function recommendation_cache_key( int $from, int $to, string $source ): string {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		return 'kidia_ai_offers_v6_' . md5( $from . '|' . $to . '|' . $source );
	}

	private static function rotation_cache_key( int $from, int $to, string $source ): string {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		return 'kidia_ai_rotation_v3_' . md5( $from . '|' . $to . '|' . $source );
	}

	/** @return array{fast:array,medium:array,slow:array,poor:array} */
	private static function empty_rotation_segments(): array {
		return array( 'fast' => array(), 'medium' => array(), 'slow' => array(), 'poor' => array() );
	}

	/** @param list<float|int> $sorted */
	private static function percentile( array $sorted, float $percentile ): float {
		$count = count( $sorted );
		if ( 0 === $count ) {
			return 0.0;
		}
		$index = max( 0, min( $count - 1, (int) floor( ( $count - 1 ) * $percentile ) ) );
		return (float) $sorted[ $index ];
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
				'label' => __( 'Personalized discovery', 'mobishop' ),
				'items' => array( 'Recommended for you', 'Recently viewed', 'Continue shopping', 'Buy again', 'First purchase', 'VIP', 'Win-back' ),
			),
			'relationships' => array(
				'label' => __( 'Product relationships', 'mobishop' ),
				'items' => array( 'Frequently bought together', 'Complementary products', 'Related products', 'Viewed this, viewed that', 'Viewed this, bought that', 'More like this', 'Visual similarity', 'Complete the look' ),
			),
			'merchandising' => array(
				'label' => __( 'Merchandising & demand', 'mobishop' ),
				'items' => array( 'Trending now', 'Best sellers', 'Most viewed', 'Most added to cart', 'High conversion', 'Search-demand merchandising', 'Category cross-sell', 'New launch' ),
			),
			'offers' => array(
				'label' => __( 'Offers & basket growth', 'mobishop' ),
				'items' => array( 'AOV lift', 'Free shipping threshold', 'BOGO', 'Quantity break', 'Cart recovery', 'Checkout rescue', 'Bundle discount', 'Personal coupon' ),
			),
			'inventory' => array(
				'label' => __( 'Inventory & timing', 'mobishop' ),
				'items' => array( 'Slow-stock rescue', 'Overstock clearance', 'Low-stock urgency', 'Restock priority', 'Seasonal clearance', 'Peak-time scheduling' ),
			),
			'funnel' => array(
				'label' => __( 'Funnel decisions', 'mobishop' ),
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
	private static function slow_stock_products( array $settings, array $commerce ): array {
		if ( ! function_exists( 'wc_get_products' ) ) {
			return array();
		}
		$period_sales = array();
		foreach ( (array) ( $commerce['products'] ?? array() ) as $row ) {
			$product_id = absint( $row['object_id'] ?? 0 );
			if ( $product_id > 0 ) {
				$period_sales[ $product_id ] = absint( $row['event_count'] ?? 0 );
			}
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
			$sales = absint( $period_sales[ $product->get_id() ] ?? 0 );
			$date  = $product->get_date_created();
			$age   = $date ? max( 1, (int) floor( ( time() - $date->getTimestamp() ) / DAY_IN_SECONDS ) ) : 1;
			if (
				$stock < absint( $settings['slow_stock_min_units'] )
				|| $age < absint( $settings['slow_stock_min_age_days'] )
				|| $sales > max( 10, $stock )
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

	private static function discount_for_conversion_gap( int $views, int $purchases, bool $protect_margin ): float {
		$conversion = $views > 0 ? 100 * $purchases / $views : 0.0;
		$discount   = $conversion <= 1 ? 12 : ( $conversion <= 3 ? 10 : 7 );
		return (float) ( $protect_margin ? min( 10, $discount ) : $discount );
	}

	/** @param array<string,mixed> $product */
	private static function discount_for_slow_stock( array $product, bool $protect_margin ): float {
		$age   = absint( $product['age_days'] ?? 0 );
		$stock = absint( $product['stock'] ?? 0 );
		$sales = absint( $product['sales'] ?? 0 );
		$discount = 8;
		if ( $age >= 180 || $stock >= max( 20, $sales * 8 ) ) {
			$discount = 15;
		} elseif ( $age >= 90 || $stock >= max( 12, $sales * 5 ) ) {
			$discount = 12;
		} elseif ( $age >= 60 ) {
			$discount = 10;
		}
		return (float) ( $protect_margin ? min( 12, $discount ) : $discount );
	}

	private static function discount_for_bundle( int $co_purchases, int $orders, bool $protect_margin ): float {
		$support = $orders > 0 ? 100 * $co_purchases / $orders : 0.0;
		$discount = $support >= 20 ? 6 : ( $support >= 10 ? 8 : 10 );
		return (float) ( $protect_margin ? min( 8, $discount ) : $discount );
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
			'fast_rotation'          => 'merchandising',
			'fast_offer'             => 'campaign',
			'medium_rotation'        => 'campaign',
			'slow_rotation'          => 'inventory',
			'poor_rotation'          => 'inventory',
		);
		$kind     = $kind_map[ $scheme ] ?? 'campaign';
		$is_offer = $discount_value > 0;
		$expected_outcomes = array(
			'campaign'      => __( 'Measure incremental purchases and revenue against the current baseline.', 'mobishop' ),
			'merchandising' => __( 'Improve product discovery, product-pair attachment and qualified product views.', 'mobishop' ),
			'inventory'     => __( 'Improve sell-through while limiting unnecessary margin loss.', 'mobishop' ),
			'funnel'        => __( 'Reduce the measured drop-off at the identified sales-funnel step.', 'mobishop' ),
			'timing'        => __( 'Improve campaign engagement by testing the strongest observed activity window.', 'mobishop' ),
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
			'fast_rotation'          => 'placement',
			'fast_offer'             => 'coupon',
			'medium_rotation'        => 'coupon',
			'slow_rotation'          => 'coupon',
			'poor_rotation'          => 'coupon',
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
			'fast_rotation' => 'home',
			'fast_offer'    => 'product',
			'medium_rotation' => 'product',
			'slow_rotation' => 'home',
			'poor_rotation' => 'home',
		);
		$recommended_placement = $placement_map[ $scheme ] ?? 'analytics';
		$products = self::product_snapshots( $product_ids );
		$product_ids = array_values( array_map( 'absint', array_column( $products, 'id' ) ) );
		$product_names = array_values(
			array_filter(
				array_map(
					static fn( array $product ): string => sanitize_text_field( (string) ( $product['name'] ?? '' ) ),
					$products
				)
			)
		);
		$target = empty( $product_names )
			? __( 'the measured audience', 'mobishop' )
			: implode( ' + ', array_slice( $product_names, 0, 3 ) );
		$discount_label = $discount_value > 0
			? ( 'percent' === $discount_type
				? sprintf( __( '%s%%', 'mobishop' ), wc_format_decimal( $discount_value ) )
				: wp_strip_all_tags( wc_price( $discount_value ) ) )
			: __( 'No discount', 'mobishop' );
		$decision = self::decision_sentence(
			$scheme,
			$target,
			$discount_label,
			$duration_hours,
			$recommended_placement
		);
		$metrics = array(
			array( 'label' => __( 'Recommended value', 'mobishop' ), 'value' => $discount_label ),
			array( 'label' => __( 'Duration', 'mobishop' ), 'value' => sprintf( __( '%d hours', 'mobishop' ), $duration_hours ) ),
			array( 'label' => __( 'Products', 'mobishop' ), 'value' => (string) count( $products ) ),
			array( 'label' => __( 'Confidence', 'mobishop' ), 'value' => $confidence . '%' ),
		);
		$success_metric = self::success_metric( $scheme );
		$guardrail = $discount_value > 0
			? __( 'Verify gross margin before publishing; stop the test if incremental gross profit falls.', 'mobishop' )
			: __( 'Compare the selected placement with the previous period or a holdout before keeping it.', 'mobishop' );
		$analysis_grade = $confidence >= 80 ? 'strong' : ( $confidence >= 65 ? 'good' : 'exploratory' );
		$rotation_segment = 'storewide';
		$rotation_label   = __( 'Store-wide decisions', 'mobishop' );
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
			'recommended_placement',
			'products',
			'decision',
			'metrics',
			'success_metric',
			'guardrail',
			'analysis_grade',
			'rotation_segment',
			'rotation_label'
		);
	}

	private static function decision_sentence(
		string $scheme,
		string $target,
		string $discount,
		int $duration_hours,
		string $placement
	): string {
		switch ( $scheme ) {
			case 'bundle':
				return sprintf(
					__( 'Publish a product-scoped bundle for %1$s with %2$s off for %3$d hours.', 'mobishop' ),
					$target,
					$discount,
					$duration_hours
				);
			case 'high_interest':
			case 'slow_stock':
			case 'fast_offer':
			case 'medium_rotation':
			case 'slow_rotation':
			case 'poor_rotation':
				return sprintf(
					__( 'Run a %1$s product-only offer on %2$s for %3$d hours.', 'mobishop' ),
					$discount,
					$target,
					$duration_hours
				);
			case 'cart_recovery':
				return sprintf(
					__( 'Send a %1$s recovery offer only to tracked abandoned carts, expiring after %2$d hours.', 'mobishop' ),
					$discount,
					$duration_hours
				);
			case 'aov_lift':
				return sprintf(
					__( 'Create a %1$s cart reward above the calculated order-value threshold for %2$d hours.', 'mobishop' ),
					$discount,
					$duration_hours
				);
			case 'popular':
			case 'best_seller':
			case 'fast_rotation':
				return sprintf(
					__( 'Place %1$s in the %2$s recommendations without discounting it.', 'mobishop' ),
					$target,
					$placement
				);
			case 'search_demand':
			case 'category_merchandising':
				return sprintf(
					__( 'Create a measured merchandising placement in %s; no discount is recommended yet.', 'mobishop' ),
					$placement
				);
			case 'peak_timing':
				return __( 'Schedule the next controlled campaign in the measured peak window without changing its price.', 'mobishop' );
			case 'remove_friction':
			case 'signup_friction':
				return __( 'Fix the measured funnel obstacle first; do not issue a discount until the next comparison period.', 'mobishop' );
			case 'free_shipping':
				return __( 'Test free shipping only above the calculated basket threshold and compare completed checkouts.', 'mobishop' );
			default:
				return sprintf(
					__( 'Apply the measured action to %1$s for %2$d hours and review the success metric.', 'mobishop' ),
					$target,
					$duration_hours
				);
		}
	}

	private static function success_metric( string $scheme ): string {
		$metrics = array(
			'high_interest'          => __( 'Product conversion rate and incremental gross profit', 'mobishop' ),
			'slow_stock'             => __( 'Sell-through rate and gross profit per unit', 'mobishop' ),
			'bundle'                 => __( 'Bundle attachment rate, order value and incremental gross profit', 'mobishop' ),
			'cart_recovery'          => __( 'Recovered carts, recovered revenue and coupon cost', 'mobishop' ),
			'free_shipping'          => __( 'Checkout completion rate and shipping cost per converted order', 'mobishop' ),
			'aov_lift'               => __( 'Average order value and gross profit per order', 'mobishop' ),
			'popular'                => __( 'Placement click-through and product conversion rate', 'mobishop' ),
			'best_seller'            => __( 'Placement click-through and product conversion rate', 'mobishop' ),
			'fast_rotation'          => __( 'Product conversion, stock cover and gross profit without discount cost', 'mobishop' ),
			'fast_offer'             => __( 'Incremental basket value, units and gross profit after the controlled discount', 'mobishop' ),
			'medium_rotation'        => __( 'Incremental units, product conversion and gross profit after discount', 'mobishop' ),
			'slow_rotation'          => __( 'Sell-through, stock cover and incremental gross profit', 'mobishop' ),
			'poor_rotation'          => __( 'Clearance sell-through, recovered cash and remaining stock', 'mobishop' ),
			'search_demand'          => __( 'Search exits, product clicks and purchases after search', 'mobishop' ),
			'category_merchandising' => __( 'Category click-through and revenue per visitor', 'mobishop' ),
			'peak_timing'            => __( 'Campaign conversion compared with a quieter-hour holdout', 'mobishop' ),
			'remove_friction'        => __( 'Remove-from-cart rate and checkout starts', 'mobishop' ),
			'signup_friction'        => __( 'Registration completion and guest checkout completion', 'mobishop' ),
		);
		return $metrics[ $scheme ] ?? __( 'Incremental purchases, revenue and gross profit', 'mobishop' );
	}

	/**
	 * @param list<int> $product_ids
	 * @return list<array<string,mixed>>
	 */
	private static function product_snapshots( array $product_ids ): array {
		if ( ! function_exists( 'wc_get_product' ) ) {
			return array();
		}
		$products = array();
		foreach ( array_slice( array_values( array_unique( array_filter( array_map( 'absint', $product_ids ) ) ) ), 0, 6 ) as $product_id ) {
			$product = wc_get_product( $product_id );
			if ( ! $product instanceof WC_Product || ! $product->is_in_stock() ) {
				continue;
			}
			$cost = (float) get_post_meta( $product_id, '_wc_cog_cost', true );
			if ( $cost <= 0 ) {
				$cost = (float) get_post_meta( $product_id, '_cost', true );
			}
			$products[] = array(
				'id'            => $product_id,
				'name'          => $product->get_name(),
				'price'         => max( 0, (float) $product->get_price() ),
				'regular_price' => max( 0, (float) $product->get_regular_price() ),
				'cost'          => max( 0, $cost ),
				'stock'         => $product->managing_stock() ? max( 0, (int) $product->get_stock_quantity() ) : null,
				'image_url'     => $product->get_image_id()
					? (string) wp_get_attachment_image_url( $product->get_image_id(), 'woocommerce_thumbnail' )
					: '',
			);
		}
		return $products;
	}

	/** Adds a transparent baseline/uplift forecast; profit requires real cost data. */
	private static function add_expected_outcomes( array $offer, array $commerce, int $from, int $to ): array {
		$product_ids = array_values( array_filter( array_map( 'absint', (array) ( $offer['product_ids'] ?? array() ) ) ) );
		if ( empty( $product_ids ) || (float) ( $offer['discount_value'] ?? 0 ) <= 0 ) {
			return $offer;
		}
		$sales = array();
		foreach ( (array) ( $commerce['products'] ?? array() ) as $row ) {
			$sales[ absint( $row['object_id'] ?? $row['id'] ?? 0 ) ] = absint( $row['event_count'] ?? 0 );
		}
		$days = max( 1, (int) ceil( max( DAY_IN_SECONDS, $to - $from ) / DAY_IN_SECONDS ) );
		$duration_days = max( 1 / 24, absint( $offer['duration_hours'] ?? 24 ) / 24 );
		$baseline_units = 0.0;
		$revenue = 0.0;
		$profit = 0.0;
		$has_cost = true;
		$discount = min( 100, max( 0, (float) ( $offer['discount_value'] ?? 0 ) ) ) / 100;
		$uplift = min( .55, .05 + $discount * 1.6 + max( 0, absint( $offer['confidence'] ?? 0 ) - 55 ) / 400 );
		foreach ( (array) ( $offer['products'] ?? array() ) as $product ) {
			$id = absint( $product['id'] ?? 0 );
			$units = (float) ( $sales[ $id ] ?? 0 ) * $duration_days / $days;
			$incremental_units = $units * $uplift;
			$price = max( 0, (float) ( $product['price'] ?? 0 ) ) * ( 1 - $discount );
			$cost = max( 0, (float) ( $product['cost'] ?? 0 ) );
			$baseline_units += $units;
			$revenue += $incremental_units * $price;
			if ( $cost > 0 ) {
				$profit += $incremental_units * max( 0, $price - $cost );
			} else {
				$has_cost = false;
			}
		}
		$offer['expected_baseline_units'] = round( $baseline_units, 2 );
		$offer['expected_incremental_revenue'] = round( $revenue, 2 );
		$offer['expected_incremental_profit'] = $has_cost ? round( $profit, 2 ) : null;
		$offer['metrics'][] = array( 'label' => __( 'Expected incremental revenue', 'mobishop' ), 'value' => wp_strip_all_tags( wc_price( $revenue ) ) );
		if ( $has_cost ) {
			$offer['metrics'][] = array( 'label' => __( 'Expected incremental profit', 'mobishop' ), 'value' => wp_strip_all_tags( wc_price( $profit ) ) );
		} else {
			$offer['evidence'][] = __( 'Profit forecast is withheld because product cost is not recorded in WooCommerce.', 'mobishop' );
		}
		return $offer;
	}

	/** Keeps the strongest discount decision per product so concurrent offers do not compete. */
	private static function remove_discount_conflicts( array $offers ): array {
		$claimed = array();
		$kept = array();
		foreach ( $offers as $offer ) {
			$ids = array_values( array_filter( array_map( 'absint', (array) ( $offer['product_ids'] ?? array() ) ) ) );
			$is_discount = (float) ( $offer['discount_value'] ?? 0 ) > 0;
			if ( $is_discount && array_intersect( $ids, array_keys( $claimed ) ) ) {
				continue;
			}
			$kept[] = $offer;
			if ( $is_discount ) {
				foreach ( $ids as $id ) {
					$claimed[ $id ] = true;
				}
			}
		}
		return $kept;
	}
}
