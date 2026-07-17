<?php
/**
 * Authenticated WooCommerce order history for the native mobile app.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Customer_Orders_Endpoint {

	private const MAX_PER_PAGE = 20;

	/** Register the customer-only order history route. */
	public function register(): void {
		add_action(
			'rest_api_init',
			array( $this, 'register_routes' )
		);
	}

	/** Register endpoint and strict pagination arguments. */
	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/customer/orders',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_orders' ),
				'permission_callback' => array( $this, 'authenticate_customer' ),
				'args'                => array(
					'page'     => array(
						'default'           => 1,
						'type'              => 'integer',
						'sanitize_callback' => 'absint',
						'validate_callback' => static fn( $value ): bool => absint( $value ) >= 1,
					),
					'per_page' => array(
						'default'           => self::MAX_PER_PAGE,
						'type'              => 'integer',
						'sanitize_callback' => 'absint',
						'validate_callback' => static fn( $value ): bool => absint( $value ) >= 1 && absint( $value ) <= self::MAX_PER_PAGE,
					),
				),
			)
		);

		register_rest_route(
			'woo-mobile/v1',
			'/customer/orders/(?P<id>\d+)/cancel',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'cancel_order' ),
				'permission_callback' => array( $this, 'authenticate_customer' ),
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

	/** Require the current user resolved by the mobile-session auth filter. */
	public function authenticate_customer( WP_REST_Request $request ) {
		unset( $request );
		return get_current_user_id() > 0
			? true
			: new WP_Error(
				'woo_mobile_auth_unauthorized',
				__( 'The customer session is missing or expired.', 'kidia-mobile-cms' ),
				array( 'status' => 401 )
			);
	}

	/** Return only orders owned by the authenticated WooCommerce customer. */
	public function get_orders( WP_REST_Request $request ) {
		$customer_id = get_current_user_id();
		if ( $customer_id <= 0 ) {
			return $this->unauthorized_error();
		}
		if ( ! function_exists( 'wc_get_orders' ) || ! function_exists( 'wc_price' ) ) {
			return new WP_Error(
				'woo_mobile_orders_woocommerce_unavailable',
				__( 'WooCommerce order history is unavailable.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$page     = max( 1, absint( $request->get_param( 'page' ) ?: 1 ) );
		$per_page = min(
			self::MAX_PER_PAGE,
			max( 1, absint( $request->get_param( 'per_page' ) ?: self::MAX_PER_PAGE ) )
		);
		$result = wc_get_orders(
			array(
				// Match the same customer query used by WooCommerce My Account.
				'customer'    => $customer_id,
				'limit'       => $per_page,
				'page'        => $page,
				'paginate'    => true,
				'orderby'     => 'date',
				'order'       => 'DESC',
				'return'      => 'objects',
			)
		);
		if ( ! is_object( $result ) || ! isset( $result->orders, $result->total, $result->max_num_pages ) || ! is_array( $result->orders ) ) {
			return new WP_Error(
				'woo_mobile_orders_invalid_result',
				__( 'WooCommerce returned invalid order history data.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}

		$orders = array();
		foreach ( $result->orders as $order ) {
			if ( ! is_object( $order ) || ! is_callable( array( $order, 'get_customer_id' ) ) ) {
				continue;
			}
			if ( (int) $order->get_customer_id() !== $customer_id ) {
				continue;
			}
			$orders[] = $this->order_payload( $order );
		}

		$response = new WP_REST_Response(
			array(
				'orders'      => $orders,
				'page'        => $page,
				'per_page'    => $per_page,
				'total'       => max( 0, (int) $result->total ),
				'total_pages' => max( 0, (int) $result->max_num_pages ),
			),
			200
		);
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		$response->header( 'X-WP-Total', (string) max( 0, (int) $result->total ) );
		$response->header( 'X-WP-TotalPages', (string) max( 0, (int) $result->max_num_pages ) );
		return $response;
	}

	/** Cancel an owned order only when WooCommerce exposes Cancel on My Account. */
	public function cancel_order( WP_REST_Request $request ) {
		$customer_id = get_current_user_id();
		if ( $customer_id <= 0 ) {
			return $this->unauthorized_error();
		}
		if ( ! function_exists( 'wc_get_order' ) ) {
			return new WP_Error(
				'woo_mobile_orders_woocommerce_unavailable',
				__( 'WooCommerce order history is unavailable.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$order = wc_get_order( absint( $request->get_param( 'id' ) ) );
		if ( ! is_object( $order ) ||
			! is_callable( array( $order, 'get_customer_id' ) ) ||
			(int) $order->get_customer_id() !== $customer_id ) {
			return new WP_Error(
				'woo_mobile_order_not_found',
				__( 'The requested order was not found.', 'kidia-mobile-cms' ),
				array( 'status' => 404 )
			);
		}
		if ( ! $this->can_cancel_order( $order ) ) {
			return new WP_Error(
				'woo_mobile_order_cannot_cancel',
				__( 'This order can no longer be cancelled.', 'kidia-mobile-cms' ),
				array( 'status' => 409 )
			);
		}
		if ( ! is_callable( array( $order, 'update_status' ) ) ) {
			return new WP_Error(
				'woo_mobile_order_cancel_unavailable',
				__( 'This order cannot be cancelled right now.', 'kidia-mobile-cms' ),
				array( 'status' => 503 )
			);
		}

		$order->update_status(
			'cancelled',
			__( 'Order cancelled by customer.', 'woocommerce' )
		);
		$response = new WP_REST_Response(
			array( 'order' => $this->order_payload( $order ) ),
			200
		);
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}

	/** Build a deliberately small response without addresses or private notes. */
	private function order_payload( $order ): array {
		$currency = sanitize_text_field( (string) $order->get_currency() );
		$total    = wc_format_decimal( $order->get_total(), wc_get_price_decimals() );
		$items    = array();
		foreach ( $order->get_items( 'line_item' ) as $item ) {
			if ( ! is_object( $item ) || ! is_callable( array( $item, 'get_name' ) ) ) {
				continue;
			}
			$quantity = max( 1, (int) $item->get_quantity() );
			$items[]  = array(
				'name'     => sanitize_text_field( (string) $item->get_name() ),
				'quantity' => $quantity,
			);
		}

		$date         = $order->get_date_created();
		$date_created = '';
		if ( is_object( $date ) && is_callable( array( $date, 'date' ) ) ) {
			$date_created = (string) $date->date( DATE_ATOM );
		} elseif ( $date instanceof DateTimeInterface ) {
			$date_created = $date->format( DATE_ATOM );
		}
		$total_display = html_entity_decode(
			wp_strip_all_tags(
				wc_price(
					$order->get_total(),
					array( 'currency' => $currency )
				)
			),
			ENT_QUOTES | ENT_HTML5,
			'UTF-8'
		);

		$status = sanitize_key( (string) $order->get_status() );
		return array(
			'id'            => (int) $order->get_id(),
			'number'        => sanitize_text_field( (string) $order->get_order_number() ),
			'status'        => $status,
			'status_name'   => sanitize_text_field( (string) wc_get_order_status_name( $status ) ),
			'date_created'  => $date_created,
			'total'         => $total,
			'total_display' => sanitize_text_field( $total_display ),
			'currency_code' => $currency,
			'item_count'    => max( 0, (int) $order->get_item_count() ),
			'items'         => $items,
			'can_cancel'    => $this->can_cancel_order( $order ),
		);
	}

	/** Respect the exact cancel action and filters used by WooCommerce My Account. */
	private function can_cancel_order( $order ): bool {
		if ( function_exists( 'wc_get_account_orders_actions' ) ) {
			$actions = wc_get_account_orders_actions( $order );
			return is_array( $actions ) && isset( $actions['cancel'] );
		}

		$status = is_callable( array( $order, 'get_status' ) )
			? sanitize_key( (string) $order->get_status() )
			: '';
		$valid_statuses = apply_filters(
			'woocommerce_valid_order_statuses_for_cancel',
			array( 'pending', 'failed' ),
			$order
		);
		return is_array( $valid_statuses ) && in_array( $status, $valid_statuses, true );
	}

	private function unauthorized_error(): WP_Error {
		return new WP_Error(
			'woo_mobile_auth_unauthorized',
			__( 'The customer session is missing or expired.', 'kidia-mobile-cms' ),
			array( 'status' => 401 )
		);
	}
}
