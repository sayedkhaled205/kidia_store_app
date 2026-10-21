<?php
/**
 * Local contracts for guarded website-payment deferral; no provider is called.
 * Reuses the existing safety fixture and runs its regression suite first.
 * Set WORDPRESS_HOOK_TEST_FILE to a local class-wp-hook.php to use real WP hooks.
 * This test never fetches source; deployed Woo/payment behavior still needs QA.
 */
declare( strict_types=1 );

namespace Automattic\WooCommerce\StoreApi\Payments {
	class PaymentContext {
		public function __construct( public $order, public string $payment_method, public array $payment_data = array() ) {}
		public function get_payment_method_instance() {
			if ( $GLOBALS['during_gateway78'] ?? false ) {
				$GLOBALS['wp_filter'][ \PAYMENT_HOOK78 ]->add_filter( \PAYMENT_HOOK78, function () { ++$GLOBALS['gateway_calls78']; }, PHP_INT_MIN, 2 );
			}
			return $GLOBALS['gateways78'][ $this->payment_method ] ?? null;
		}
	}
	class PaymentResult {
		public string $status = '';
		public function set_status( string $status ): void { $this->status = $status; }
	}
}

namespace {
	class WC_Payment_Gateway {
		public function __construct( public string $id ) {}
	}
	if ( ! function_exists( '_wp_filter_build_unique_id' ) ) {
		function _wp_filter_build_unique_id( $name, $callback, $priority ) {
			if ( is_string( $callback ) ) { return $callback; }
			if ( is_object( $callback ) ) { $callback = array( $callback, '' ); }
			return is_object( $callback[0] ) ? spl_object_hash( $callback[0] ) . $callback[1] : $callback[0] . '::' . $callback[1];
		}
	}
	$real_hook78 = getenv( 'WORDPRESS_HOOK_TEST_FILE' );
	if ( is_string( $real_hook78 ) && '' !== $real_hook78 ) {
		if ( ! is_file( $real_hook78 ) ) { throw new RuntimeException( 'Requested WordPress hook source is missing.' ); }
		require_once $real_hook78;
	}
	/** May be preloaded with real WordPress WP_Hook for its iteration semantics. */
	if ( ! class_exists( 'WP_Hook' ) ) {
	class WP_Hook {
		public array $callbacks = array();
		public function add_filter( string $name, $callback, int $priority, int $accepted_args ): void {
			$this->callbacks[ $priority ][ _wp_filter_build_unique_id( $name, $callback, $priority ) ] = array( 'function' => $callback, 'accepted_args' => $accepted_args );
		}
		public function remove_all_filters(): void { $this->callbacks = array(); }
		public function do_action( array $args ): void {
			ksort( $this->callbacks );
			foreach ( array_keys( $this->callbacks ) as $priority ) {
				foreach ( $this->callbacks[ $priority ] ?? array() as $row ) {
					call_user_func_array( $row['function'], $args );
				}
			}
		}
	}
	}
	function do_action_ref_array( string $name, array $args ): void {
		if ( isset( $GLOBALS['wp_filter'][ $name ] ) ) { $GLOBALS['wp_filter'][ $name ]->do_action( $args ); }
	}

	require __DIR__ . '/native-checkout-safety50-contract-test.php';
	const PAYMENT_HOOK78 = 'woocommerce_rest_checkout_process_payment_with_context';
	class Payment_Order78 extends WC_Order {
		public function __construct( int $id = 0, int $customer = 7, $total = '12.50', public string $method = 'website_card' ) { parent::__construct( $id, $customer, $total ); }
		public function get_payment_method(): string { return $this->method; }
	}
	function payment_fixture78( string $method = 'website_card' ): array {
		[ $api, $store ] = fixture50();
		$GLOBALS['wp_filter'] = array();
		$GLOBALS['gateway_calls78'] = 0;
		$GLOBALS['during_gateway78'] = false;
		$GLOBALS['gateways78'] = array( $method => new WC_Payment_Gateway( $method ) );
		$original = new WP_Hook();
		$original->add_filter( PAYMENT_HOOK78, function ( $context, &$result ) {
			++$GLOBALS['gateway_calls78']; // Intentionally ignores an existing result.
			$context->order->status = 'on-hold';
			$GLOBALS['orders50'][ $context->order->id ] = clone $context->order;
			$result->set_status( 'success' );
		}, 1, 2 );
		$GLOBALS['wp_filter'][ PAYMENT_HOOK78 ] = $original;
		$request = request50( 'payment-fixture', 7, array( 'total_price' => '1250', 'currency_code' => 'EGP', 'currency_minor_unit' => 2 ) );
		$request->body['payment_method'] = $method;
		$request->body['payment_data'] = array();
		return array( $api, $store, $request, $original );
	}
	function payment_core78( $api, string $mode = '' ): Closure {
		return function ( $request ) use ( $api, $mode ) {
			++$GLOBALS['core_calls50'];
			$order = new Payment_Order78( 0, 7, 'free' === $mode ? '0.00' : '12.50', $request->get_param( 'payment_method' ) );
			$api->before_save( $order );
			$order->id = 101;
			$GLOBALS['orders50'][ 101 ] = clone $order;
			$api->after_save( $order );
			$api->validate_final( $order, new WP_Error() );
			++$GLOBALS['stock50'];
			$order->status = 'pending';
			$GLOBALS['orders50'][ 101 ] = clone $order;
			if ( 'early_owner' === $mode ) { $order->customer = 9; }
			if ( 'early_total' === $mode ) { $order->total = '12.51'; }
			do_action( 'woocommerce_store_api_checkout_order_processed', $order );
			if ( 'throw' === $mode ) { throw new RuntimeException( 'Failure after arming hand-off.' ); }
			$context = new \Automattic\WooCommerce\StoreApi\Payments\PaymentContext( $order, $request->get_param( 'payment_method' ), $request->get_param( 'payment_data' ) );
			$result = new \Automattic\WooCommerce\StoreApi\Payments\PaymentResult();
			if ( 'late_owner' === $mode ) { $order->customer = 9; }
			if ( 'late_total' === $mode ) { $order->total = '12.51'; }
			if ( 'persisted_total' === $mode ) { $GLOBALS['orders50'][ 101 ]->total = '12.51'; }
			if ( 'persisted_method' === $mode ) { $GLOBALS['orders50'][ 101 ]->method = 'other'; }
			if ( 'context_method' === $mode ) { $context->payment_method = 'other'; }
			if ( 'context_data' === $mode ) { $context->payment_data = array( 'token' => 'unexpected' ); }
			if ( 'missing_gateway' === $mode ) { $GLOBALS['gateways78'] = array(); }
			if ( 'paid' === $mode ) { $order->status = 'completed'; }
			if ( in_array( $mode, array( 'late_handler', 'same_priority_handler' ), true ) ) {
				$GLOBALS['wp_filter'][ PAYMENT_HOOK78 ]->add_filter( PAYMENT_HOOK78, function () { ++$GLOBALS['gateway_calls78']; }, 'same_priority_handler' === $mode ? PHP_INT_MIN : 999, 2 );
			}
			$GLOBALS['during_gateway78'] = 'during_gateway' === $mode;
			if ( 'free' === $mode ) {
				$order->status = 'completed';
				$GLOBALS['orders50'][ 101 ] = clone $order;
				$result->set_status( 'success' );
			} else {
				do_action_ref_array( PAYMENT_HOOK78, array( $context, &$result ) );
				if ( in_array( $mode, array( 'repeat_action', 'repeat_with_handler' ), true ) ) {
					if ( 'repeat_with_handler' === $mode ) {
						$GLOBALS['wp_filter'][ PAYMENT_HOOK78 ]->add_filter( PAYMENT_HOOK78, function () { ++$GLOBALS['gateway_calls78']; }, PHP_INT_MIN, 2 );
					}
					$result = new \Automattic\WooCommerce\StoreApi\Payments\PaymentResult();
					do_action_ref_array( PAYMENT_HOOK78, array( $context, &$result ) );
				}
			}
			return new WP_REST_Response( array( 'order_id' => 101, 'status' => $order->status, 'payment_result' => array( 'payment_status' => $result->status ) ), 200 );
		};
	}
	function payment_restored78( $original ): void {
		check50( ( $GLOBALS['wp_filter'][ PAYMENT_HOOK78 ] ?? null ) === $original, 'Exact original WP_Hook object restored.' );
	}
	$GLOBALS['count78_start'] = $GLOBALS['count50'];
	test50( 'website hand-off never calls hostile gateway and creates one unpaid order', function () {
		[ $api, $store, $request, $original ] = payment_fixture78();
		$response = dispatch50( $api, $request, payment_core78( $api ) );
		check50( 200 === status50( $response ), 'Handoff completed.' );
		$data = $response->get_data();
		check50( 'order_created' === $data['state'] && 'pending' === $data['payment_status'] && 'pending' === $data['order']['status'] && false === $data['checkout_locked'], 'Only pending unpaid receipt returned.' );
		check50( 0 === $GLOBALS['gateway_calls78'] && 1 === $GLOBALS['stock50'] && 1 === count( $GLOBALS['orders50'] ) && ! wc_get_order( 101 )->is_paid(), 'No payment provider or duplicate order.' );
		payment_restored78( $original );
		$retry = dispatch50( $api, $request, payment_core78( $api ) );
		check50( 200 === status50( $retry ) && 101 === $retry->get_data()['order']['id'] && 1 === $GLOBALS['core_calls50'], 'Identical retry recovers same order.' );
		check50( ! str_contains( json_encode( $store->attempts ), 'website_card' ), 'Ledger retains no gateway details.' );
	} );
	test50( 'added payment handlers fail closed including identical minimum priority', function () {
		foreach ( array( 'late_handler', 'same_priority_handler', 'during_gateway' ) as $mode ) {
			[ $api, , $request, $original ] = payment_fixture78();
			check50( 503 === status50( dispatch50( $api, $request, payment_core78( $api, $mode ) ) ) && 0 === $GLOBALS['gateway_calls78'], 'Added handler never runs: ' . $mode );
			payment_restored78( $original );
		}
	} );
	test50( 'repeated payment context fails closed before any provider', function () {
		foreach ( array( 'repeat_action', 'repeat_with_handler' ) as $mode ) {
			[ $api, , $request, $original ] = payment_fixture78();
			check50( 503 === status50( dispatch50( $api, $request, payment_core78( $api, $mode ) ) ) && 0 === $GLOBALS['gateway_calls78'], 'Repeated context never calls provider: ' . $mode );
			payment_restored78( $original );
		}
	} );
	test50( 'exception after arming restores original and leaves retry locked', function () {
		[ $api, , $request, $original ] = payment_fixture78();
		check50( 503 === status50( dispatch50( $api, $request, payment_core78( $api, 'throw' ) ) ), 'Unknown failure remains unknown.' );
		payment_restored78( $original );
		check50( 0 === $GLOBALS['gateway_calls78'] && 202 === status50( dispatch50( $api, $request, payment_core78( $api ) ) ) && 1 === $GLOBALS['core_calls50'], 'No automatic replay after unknown outcome.' );
	} );
	test50( 'deferral rejects changed owner total method payment data or paid state', function () {
		foreach ( array( 'early_owner', 'early_total', 'late_owner', 'late_total', 'persisted_total', 'persisted_method', 'context_method', 'context_data', 'missing_gateway', 'paid' ) as $mode ) {
			[ $api, , $request, $original ] = payment_fixture78();
			check50( 503 === status50( dispatch50( $api, $request, payment_core78( $api, $mode ) ) ), 'Fail closed: ' . $mode );
			check50( 0 === $GLOBALS['gateway_calls78'], 'No provider on failed guard: ' . $mode );
			payment_restored78( $original );
		}
	} );
	test50( 'all built-in offline gateways retain native processing', function () {
		foreach ( array( 'cod', 'bacs', 'cheque' ) as $method ) {
			[ $api, , $request, $original ] = payment_fixture78( $method );
			check50( 200 === status50( dispatch50( $api, $request, payment_core78( $api ) ) ) && 1 === $GLOBALS['gateway_calls78'] && 'on-hold' === wc_get_order( 101 )->get_status(), 'Original offline path: ' . $method );
			payment_restored78( $original );
		}
	} );
	test50( 'explicit gateway payload is not converted into a website hand-off', function () {
		[ $api, , $request, $original ] = payment_fixture78();
		$request->body['payment_data'] = array( array( 'key' => 'token', 'value' => 'fixture' ) );
		check50( 200 === status50( dispatch50( $api, $request, payment_core78( $api ) ) ) && 1 === $GLOBALS['gateway_calls78'], 'Existing explicit-data flow preserved.' );
		payment_restored78( $original );
	} );
	test50( 'zero-total checkout remains on the original free-order path', function () {
		[ $api, , $request, $original ] = payment_fixture78();
		$request->body['extensions'][ MobiShop_Native_Checkout_Safety50::NAMESPACE ]['confirmed']['total_price'] = '0';
		check50( 200 === status50( dispatch50( $api, $request, payment_core78( $api, 'free' ) ) ) && 0 === $GLOBALS['gateway_calls78'] && 'completed' === wc_get_order( 101 )->get_status(), 'Free checkout still completes in core.' );
		payment_restored78( $original );
	} );
	test50( 'unmarked website request keeps its original gateway hook callable', function () {
		[ $api, , $request, $original ] = payment_fixture78();
		unset( $request->body['extensions'] );
		check50( null === dispatch50( $api, $request, payment_core78( $api ) ), 'Website passed through.' );
		$order = new Payment_Order78( 201 ); $order->status = 'pending';
		$api->validate_before_gateway( $order );
		$context = new \Automattic\WooCommerce\StoreApi\Payments\PaymentContext( $order, 'website_card' );
		$result = new \Automattic\WooCommerce\StoreApi\Payments\PaymentResult();
		do_action_ref_array( PAYMENT_HOOK78, array( $context, &$result ) );
		check50( 1 === $GLOBALS['gateway_calls78'] && 'success' === $result->status, 'Website gateway still processes.' );
		payment_restored78( $original );
	} );
	test50( 'originally absent payment hook is absent again after hand-off', function () {
		[ $api, , $request ] = payment_fixture78();
		unset( $GLOBALS['wp_filter'][ PAYMENT_HOOK78 ] );
		check50( 200 === status50( dispatch50( $api, $request, payment_core78( $api ) ) ) && ! isset( $GLOBALS['wp_filter'][ PAYMENT_HOOK78 ] ), 'No persistent hook installed.' );
	} );
	echo 'LOCAL_WEBSITE_PAYMENT_CONTRACTS=' . ( $GLOBALS['count50'] - $GLOBALS['count78_start'] ) . "\n";
	echo 'PAYMENT_HOOK_RUNTIME=' . ( $real_hook78 ? 'WORDPRESS' : 'LOCAL_STUB_OR_PRELOADED' ) . "\n";
}
