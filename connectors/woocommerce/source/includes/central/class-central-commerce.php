<?php
defined('ABSPATH') || exit;
/** Read-only renderer for the authenticated central workspace; no local admin UI. */
final class MobiShop_Central_Commerce {
private const CAPABILITY = 'manage_woocommerce';
	public function store_data_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'mobishop' ) );
		}
		$store_tab    = isset( $_GET['store_tab'] ) ? sanitize_key( wp_unslash( $_GET['store_tab'] ) ) : 'products';
		$store_source = isset( $_GET['store_source'] ) ? sanitize_key( wp_unslash( $_GET['store_source'] ) ) : 'all';
		$store_source = in_array( $store_source, array( 'all', 'website', 'mobile' ), true ) ? $store_source : 'all';
		$allowed      = array( 'products', 'categories', 'discounts', 'customers', 'orders', 'reports', 'analytics', 'abandoned-carts' );
		$store_tab    = in_array( $store_tab, $allowed, true ) ? $store_tab : 'products';

		$date_default = 'abandoned-carts' === $store_tab
			? 'all_time'
			: ( in_array( $store_tab, array( 'reports', 'analytics' ), true )
				? 'today'
				: ( 'customers' === $store_tab ? 'all_time' : 'last_30_days' ) );
		$date_preset = isset( $_GET['date_preset'] ) ? sanitize_key( wp_unslash( $_GET['date_preset'] ) ) : $date_default;
		$date_range  = $this->store_data_date_range( $date_preset );
		$date_from   = $date_range['from'];
		$date_to     = $date_range['to'];
		$date_preset = $date_range['preset'];
		$previous_to = $date_from - 1;
		$previous_from = $previous_to - ( $date_to - $date_from );
		$store_reporting_ready = (bool) true;

		$product_page     = max( 1, absint( $_GET['product_page'] ?? 1 ) );
		$product_per_page = 20;
		$product_search   = isset( $_GET['product_search'] )
			? sanitize_text_field( wp_unslash( $_GET['product_search'] ) )
			: '';
		$product_visibility = isset( $_GET['product_visibility'] )
			? sanitize_key( wp_unslash( $_GET['product_visibility'] ) )
			: 'all';
		$product_visibility = in_array( $product_visibility, array( 'all', 'shown', 'hidden_mobile', 'hidden_website', 'hidden_both' ), true )
			? $product_visibility
			: 'all';
		$product_query    = null;
		$products         = array();
		$product_total    = 0;
		$product_pages    = 1;
		if ( 'products' === $store_tab && function_exists( 'wc_get_product' ) ) {
			$product_query_args = array(
				'post_type'              => 'product',
				'post_status'            => array( 'publish', 'draft', 'pending', 'private', 'future' ),
				'posts_per_page'         => $product_per_page,
				'paged'                  => $product_page,
				'orderby'                => 'date',
				'order'                  => 'DESC',
				'fields'                 => 'ids',
				'no_found_rows'          => false,
				'update_post_meta_cache' => true,
				'update_post_term_cache' => false,
			);
			if ( '' !== $product_search ) {
				$product_query_args['s'] = $product_search;
				$sku_product_id = function_exists( 'wc_get_product_id_by_sku' )
					? absint( wc_get_product_id_by_sku( $product_search ) )
					: 0;
				if ( $sku_product_id > 0 ) {
					unset( $product_query_args['s'] );
					$product_query_args['post__in'] = array( $sku_product_id );
				}
			}
			if ( 'hidden_mobile' === $product_visibility ) {
				$product_query_args['meta_query'] = array( array( 'key' => MobiShop_Product_Channel_Visibility::MOBILE_META, 'value' => 'yes' ) );
			} elseif ( 'hidden_website' === $product_visibility ) {
				$product_query_args['meta_query'] = array( array( 'key' => MobiShop_Product_Channel_Visibility::WEBSITE_META, 'value' => 'yes' ) );
			} elseif ( 'hidden_both' === $product_visibility ) {
				$product_query_args['meta_query'] = array(
					'relation' => 'AND',
					array( 'key' => MobiShop_Product_Channel_Visibility::MOBILE_META, 'value' => 'yes' ),
					array( 'key' => MobiShop_Product_Channel_Visibility::WEBSITE_META, 'value' => 'yes' ),
				);
			} elseif ( 'shown' === $product_visibility ) {
				$product_query_args['meta_query'] = array(
					'relation' => 'AND',
					array(
						'relation' => 'OR',
						array( 'key' => MobiShop_Product_Channel_Visibility::MOBILE_META, 'compare' => 'NOT EXISTS' ),
						array( 'key' => MobiShop_Product_Channel_Visibility::MOBILE_META, 'value' => 'yes', 'compare' => '!=' ),
					),
					array(
						'relation' => 'OR',
						array( 'key' => MobiShop_Product_Channel_Visibility::WEBSITE_META, 'compare' => 'NOT EXISTS' ),
						array( 'key' => MobiShop_Product_Channel_Visibility::WEBSITE_META, 'value' => 'yes', 'compare' => '!=' ),
					),
				);
			}
			$product_query = new WP_Query( $product_query_args );
			foreach ( $product_query->posts as $product_id ) {
				$product = wc_get_product( $product_id );
				if ( $product instanceof WC_Product ) {
					$products[] = $product;
				}
			}
			$product_total = absint( $product_query->found_posts );
			$product_pages = max( 1, absint( $product_query->max_num_pages ) );
		}
		$coupon_page   = max( 1, absint( $_GET['coupon_page'] ?? 1 ) );
		$coupon_search = isset( $_GET['coupon_search'] ) ? sanitize_text_field( wp_unslash( $_GET['coupon_search'] ) ) : '';
		$coupon_status = isset( $_GET['coupon_status'] ) ? sanitize_key( wp_unslash( $_GET['coupon_status'] ) ) : 'all';
		$coupon_type   = isset( $_GET['coupon_type'] ) ? sanitize_key( wp_unslash( $_GET['coupon_type'] ) ) : 'all';
		$coupon_scope  = isset( $_GET['coupon_scope'] ) ? sanitize_key( wp_unslash( $_GET['coupon_scope'] ) ) : 'all';
		$coupon_channel = isset( $_GET['coupon_channel'] ) ? sanitize_key( wp_unslash( $_GET['coupon_channel'] ) ) : 'any';
		$coupon_query  = null;
		$coupons       = array();
		$coupon_total  = 0;
		$coupon_pages  = 1;
		if ( 'discounts' === $store_tab ) {
			$coupon_args = array(
				'post_type'              => 'shop_coupon',
				'post_status'            => array( 'publish', 'draft', 'pending', 'private', 'future' ),
				'posts_per_page'         => 24,
				'paged'                  => $coupon_page,
				'orderby'                => 'date',
				'order'                  => 'DESC',
				'no_found_rows'          => false,
				'update_post_meta_cache' => true,
			);
			if ( '' !== $coupon_search ) {
				$coupon_args['s'] = $coupon_search;
			}
			if ( in_array( $coupon_status, array( 'draft', 'scheduled' ), true ) ) {
				$coupon_args['post_status'] = 'scheduled' === $coupon_status ? 'future' : 'draft';
			}
			$meta_query = array( 'relation' => 'AND' );
			$now        = time();
			if ( 'active' === $coupon_status ) {
				$coupon_args['post_status'] = 'publish';
				$meta_query[] = array(
					'relation' => 'OR',
					array( 'key' => '_date_expires', 'compare' => 'NOT EXISTS' ),
					array( 'key' => '_date_expires', 'value' => '', 'compare' => '=' ),
					array( 'key' => '_date_expires', 'value' => $now, 'compare' => '>=', 'type' => 'NUMERIC' ),
				);
			} elseif ( 'expired' === $coupon_status ) {
				$coupon_args['post_status'] = 'publish';
				$meta_query[] = array( 'key' => '_date_expires', 'value' => $now, 'compare' => '<', 'type' => 'NUMERIC' );
			}
			if ( in_array( $coupon_type, array( 'percent', 'fixed_cart', 'fixed_product' ), true ) ) {
				$meta_query[] = array( 'key' => '_discount_type', 'value' => $coupon_type );
			}
			if ( 'individual' === $coupon_scope ) {
				$meta_query[] = array( 'key' => '_individual_use', 'value' => 'yes' );
			} elseif ( 'product' === $coupon_scope ) {
				$meta_query[] = array( 'key' => '_product_ids', 'value' => '', 'compare' => '!=' );
			} elseif ( 'category' === $coupon_scope ) {
				$meta_query[] = array( 'key' => '_product_categories', 'value' => 'a:0:{}', 'compare' => '!=' );
			}
			if ( 'all' === $coupon_channel ) {
				$meta_query[] = array(
					'relation' => 'OR',
					array( 'key' => MobiShop_Coupon_Channel::META_KEY, 'compare' => 'NOT EXISTS' ),
					array( 'key' => MobiShop_Coupon_Channel::META_KEY, 'value' => 'all' ),
				);
			} elseif ( in_array( $coupon_channel, array( 'website', 'mobile' ), true ) ) {
				$meta_query[] = array( 'key' => MobiShop_Coupon_Channel::META_KEY, 'value' => $coupon_channel );
			}
			if ( count( $meta_query ) > 1 ) {
				$coupon_args['meta_query'] = $meta_query;
			}
			$coupon_query = new WP_Query( $coupon_args );
			$coupons      = $coupon_query->posts;
			$coupon_total = absint( $coupon_query->found_posts );
			$coupon_pages = max( 1, absint( $coupon_query->max_num_pages ) );
		}

		$category_terms = 'categories' === $store_tab && taxonomy_exists( 'product_cat' )
			? get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false, 'orderby' => 'name', 'order' => 'ASC' ) )
			: array();
		$parent_categories = array();
		$subcategory_groups = array();
		if ( ! is_wp_error( $category_terms ) ) {
			foreach ( $category_terms as $category ) {
				if ( 0 === (int) $category->parent ) {
					$parent_categories[] = $category;
					$subcategory_groups[ $category->term_id ] = array();
				}
			}
			foreach ( $category_terms as $category ) {
				if ( 0 !== (int) $category->parent ) {
					$root = $this->store_data_root_category( $category, $category_terms );
					$subcategory_groups[ $root ][] = $category;
				}
			}
		}

		$orders = array();
		if ( 'orders' === $store_tab && function_exists( 'wc_get_orders' ) ) {
			$order_args = array(
				'type'         => 'shop_order',
				'limit'        => 60,
				'orderby'      => 'date',
				'order'        => 'DESC',
				'date_created' => $date_from . '...' . $date_to,
			);
			$order_args = $this->store_data_order_source_args( $order_args, $store_source );
			$orders     = array_filter( wc_get_orders( $order_args ), static fn( $order ): bool => $order instanceof WC_Order );
		}

		$customer_page = max( 1, absint( $_GET['customer_page'] ?? 1 ) );
		$customer_args = array(
			'role__in'    => array( 'customer', 'subscriber' ),
			'number'      => 24,
			'paged'       => $customer_page,
			'orderby'     => 'registered',
			'order'       => 'DESC',
			'count_total' => true,
		);
		if ( 'all_time' !== $date_preset ) {
			$customer_args['date_query'] = array(
				array(
					'after'     => gmdate( 'Y-m-d H:i:s', $date_from ),
					'before'    => gmdate( 'Y-m-d H:i:s', $date_to ),
					'inclusive' => true,
				),
			);
		}
		if ( 'mobile' === $store_source ) {
			$customer_args['meta_query'] = array(
				'relation' => 'OR',
				array( 'key' => '_mobishop_customer', 'value' => '1' ),
				array( 'key' => '_mobishop_customer_sessions_v1', 'compare' => 'EXISTS' ),
			);
		}
		$customer_query = 'customers' === $store_tab ? new WP_User_Query( $customer_args ) : null;
		$customers      = $customer_query instanceof WP_User_Query ? $customer_query->get_results() : array();
		if ( ! empty( $customers ) ) {
			update_meta_cache( 'user', wp_list_pluck( $customers, 'ID' ) );
		}
		if ( 'website' === $store_source ) {
			$customers = array_values(
				array_filter(
					$customers,
					static fn( WP_User $customer ): bool => MobiShop_Analytics::customer_sources( $customer->ID )['website']
				)
			);
		}
		$customer_total = $customer_query instanceof WP_User_Query ? absint( $customer_query->get_total() ) : 0;
		$customer_pages = max( 1, (int) ceil( $customer_total / 24 ) );

		$reporting_snapshot = MobiShop_Analytics::empty_commerce_snapshot();
		$reporting_snapshot['all_orders'] = 0;
		$reporting_snapshot['status_counts'] = array();
		if ( $store_reporting_ready && in_array( $store_tab, array( 'reports', 'analytics' ), true ) ) {
			$reporting_snapshot = MobiShop_Analytics::reporting_snapshot( $date_from, $date_to, $store_source );
		}
		$order_revenue      = (float) ( $reporting_snapshot['revenue'] ?? 0 );
		$order_units        = absint( $reporting_snapshot['units'] ?? 0 );
		$order_average      = (float) ( $reporting_snapshot['average_order_value'] ?? 0 );
		$order_statuses  = is_array( $reporting_snapshot['status_counts'] ?? null )
			? $reporting_snapshot['status_counts']
			: array();
		$product_performance = array();
		foreach ( array_slice( (array) ( $reporting_snapshot['products'] ?? array() ), 0, 10 ) as $product_row ) {
			$product_id = absint( $product_row['object_id'] ?? 0 );
			$product_performance[ $product_id ] = array(
				'name'    => sanitize_text_field( (string) ( $product_row['event_label'] ?? '#' . $product_id ) ),
				'units'   => absint( $product_row['event_count'] ?? 0 ),
				'revenue' => max( 0, (float) ( $product_row['revenue'] ?? 0 ) ),
			);
		}

		$analytics = MobiShop_Analytics::empty_summary();
		$analytics_previous = MobiShop_Analytics::empty_summary();
		if ( 'analytics' === $store_tab && $store_reporting_ready ) {
			$previous_reporting = MobiShop_Analytics::reporting_snapshot( $previous_from, $previous_to, $store_source );
			$analytics = MobiShop_Analytics::summary( $date_from, $date_to, $store_source, true, $reporting_snapshot );
			$analytics_previous = MobiShop_Analytics::summary( $previous_from, $previous_to, $store_source, true, $previous_reporting );
		}
		$cart_view = isset( $_GET['cart_view'] ) ? sanitize_key( wp_unslash( $_GET['cart_view'] ) ) : 'abandoned';
		$cart_view = in_array( $cart_view, array( 'active', 'abandoned', 'recovered' ), true ) ? $cart_view : 'abandoned';
		$cart_per_page = absint( $_GET['cart_per_page'] ?? 20 );
		$cart_per_page = in_array( $cart_per_page, array( 20, 50, 100 ), true ) ? $cart_per_page : 20;
		$cart_page = max( 1, absint( $_GET['cart_page'] ?? 1 ) );
		$abandoned_summary = 'abandoned-carts' === $store_tab
			? MobiShop_Analytics::abandoned_summary( $date_from, $date_to, $store_source )
			: array();
		$abandoned_import_state = 'abandoned-carts' === $store_tab
			? MobiShop_Analytics::website_session_import_status()
			: array();
		$cart_total = absint( $abandoned_summary[ $cart_view ] ?? 0 );
		$cart_pages = max( 1, (int) ceil( $cart_total / $cart_per_page ) );
		$cart_page  = min( $cart_page, $cart_pages );
		$abandoned_carts = 'abandoned-carts' === $store_tab
			? MobiShop_Analytics::abandoned_carts(
				$date_from,
				$date_to,
				$store_source,
				$cart_per_page,
				( $cart_page - 1 ) * $cart_per_page,
				$cart_view
			)
			: array();
		$recovery_stats = 'abandoned-carts' === $store_tab ? MobiShop_Recovery_Campaigns::stats() : array();
		$recovery_campaigns = 'abandoned-carts' === $store_tab ? MobiShop_Recovery_Campaigns::recent( 50 ) : array();

		$category_count = taxonomy_exists( 'product_cat' )
			? wp_count_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false ) )
			: 0;
		$user_counts = count_users();
		$role_counts = is_array( $user_counts['avail_roles'] ?? null ) ? $user_counts['avail_roles'] : array();
		$post_counts = wp_count_posts( 'product' );
		$counts = array(
			'products'         => is_object( $post_counts ) ? absint( $post_counts->publish ?? 0 ) : 0,
			'categories'       => is_wp_error( $category_count ) ? 0 : absint( $category_count ),
			'discounts'        => is_object( wp_count_posts( 'shop_coupon' ) ) ? absint( wp_count_posts( 'shop_coupon' )->publish ?? 0 ) : count( $coupons ),
			'customers'        => absint( $role_counts['customer'] ?? 0 ) + absint( $role_counts['subscriber'] ?? 0 ),
			'orders'           => function_exists( 'wc_orders_count' ) ? MobiShop_Analytics::total_order_count() : count( $orders ),
			'abandoned-carts'  => MobiShop_Analytics::abandoned_count(),
		);
		require __DIR__ . '/store-data-view.php';
	}

	private function store_data_date_range( string $preset, ?array $request = null ): array {
		$allowed = array( 'all_time', 'today', 'yesterday', 'last_7_days', 'last_30_days', 'this_month', 'previous_month', 'last_year', 'custom' );
		$preset  = in_array( $preset, $allowed, true ) ? $preset : 'last_30_days';
		$zone    = wp_timezone();
		$today   = new DateTimeImmutable( 'today', $zone );
		$from    = $today->modify( '-29 days' );
		$to      = $today->modify( '+1 day -1 second' );

		switch ( $preset ) {
			case 'all_time':
				$from = ( new DateTimeImmutable( '@1' ) )->setTimezone( $zone );
				break;
			case 'today':
				$from = $today;
				break;
			case 'yesterday':
				$from = $today->modify( '-1 day' );
				$to   = $today->modify( '-1 second' );
				break;
			case 'last_7_days':
				$from = $today->modify( '-6 days' );
				break;
			case 'this_month':
				$from = $today->modify( 'first day of this month' );
				break;
			case 'previous_month':
				$from = $today->modify( 'first day of previous month' );
				$to   = $today->modify( 'first day of this month -1 second' );
				break;
			case 'last_year':
				$from = $today->modify( '-1 year +1 day' );
				break;
			case 'custom':
				$request     = null === $request ? $_GET : $request;
				$custom_from = isset( $request['date_from'] ) ? sanitize_text_field( wp_unslash( $request['date_from'] ) ) : '';
				$custom_to   = isset( $request['date_to'] ) ? sanitize_text_field( wp_unslash( $request['date_to'] ) ) : '';
				$parsed_from = DateTimeImmutable::createFromFormat( '!Y-m-d', $custom_from, $zone );
				$parsed_to   = DateTimeImmutable::createFromFormat( '!Y-m-d', $custom_to, $zone );
				if ( false !== $parsed_from && false !== $parsed_to && $parsed_to >= $parsed_from ) {
					$from = $parsed_from;
					$to   = $parsed_to->modify( '+1 day -1 second' );
				} else {
					$preset = 'last_30_days';
				}
				break;
		}

		return array( 'preset' => $preset, 'from' => $from->getTimestamp(), 'to' => $to->getTimestamp() );
	}

	private function store_data_order_source_args( array $args, string $source ): array {
		if ( 'mobile' === $source ) {
			$args['meta_query'] = array( array( 'key' => '_mobishop_order_source', 'value' => 'mobile' ) );
		} elseif ( 'website' === $source ) {
			$args['meta_query'] = array(
				'relation' => 'OR',
				array( 'key' => '_mobishop_order_source', 'compare' => 'NOT EXISTS' ),
				array( 'key' => '_mobishop_order_source', 'value' => 'website' ),
			);
		}
		return $args;
	}

	private function store_data_root_category( WP_Term $category, array $terms ): int {
		$parents = array();
		foreach ( $terms as $term ) {
			$parents[ $term->term_id ] = (int) $term->parent;
		}
		$root = (int) $category->parent;
		while ( isset( $parents[ $root ] ) && 0 !== $parents[ $root ] ) {
			$root = $parents[ $root ];
		}
		return $root;
	}

}
