<?php
/** Native payment adapters. Merchant credentials and order authority stay here. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Native_Payment92 {

	public function register(): void {
		add_action( 'rest_api_init', function (): void {
			register_rest_route( 'mobishop/v1', '/native-payment/return', array(
				'methods' => 'GET', 'callback' => fn() => $this->response( array( 'status' => 'verifying' ) ),
				'permission_callback' => '__return_true',
			) );
			register_rest_route( 'mobishop/v1', '/customer/orders/(?P<id>[1-9][0-9]*)/native-payment', array(
				'methods' => 'POST', 'callback' => array( $this, 'prepare' ),
				'permission_callback' => array( $this, 'authenticate' ),
			) );
			register_rest_route( 'mobishop/v1', '/customer/orders/(?P<id>[1-9][0-9]*)/native-payment/status', array(
				'methods' => 'GET', 'callback' => array( $this, 'status' ),
				'permission_callback' => array( $this, 'authenticate' ),
			) );
			register_rest_route( 'mobishop/v1', '/native-payment/kashier/webhook/(?P<id>[1-9][0-9]*)', array(
				'methods' => 'POST', 'callback' => array( $this, 'webhook' ),
				'permission_callback' => '__return_true',
			) );
		} );
	}

	public function authenticate( WP_REST_Request $request ) {
		$context = ( new MobiShop_Customer_Auth_Endpoint() )->session_context_from_request( $request );
		return wp_is_using_https() && ! is_wp_error( $context ) && is_array( $context )
			&& (int) ( $context['user_id'] ?? 0 ) > 0 && (int) $context['user_id'] === get_current_user_id()
			? true : self::error( 'unauthorized', 401 );
	}

	/** Capabilities, never a guessed web fallback. Availability still belongs to Woo. */
	public static function adapter( $gateway ): string {
		if ( in_array( $gateway->id, array( 'cod', 'bacs', 'cheque' ), true ) ) return 'offline';
		if ( 'kashier_card' === $gateway->id && $gateway instanceof WC_Gateway_Kashier_Card
			&& ! empty( $gateway->merchant_id ) && ! empty( $gateway->api_key ) && ! empty( $gateway->secret_key )
			&& empty( $gateway->enable_connected_account ) ) return 'kashier';
		return 'unavailable';
	}

	private function owned_order( WP_REST_Request $request ) {
		$order = wc_get_order( (int) $request['id'] );
		return $order instanceof WC_Order && (int) $order->get_customer_id() === get_current_user_id()
			&& '' !== (string) $order->get_meta( '_mobishop_native_attempt50' ) ? $order : null;
	}

	public function prepare( WP_REST_Request $request ) {
		if ( true !== $this->authenticate( $request ) ) return self::error( 'unauthorized', 401 );
		$order = $this->owned_order( $request );
		if ( ! $order ) return self::error( 'unavailable', 404 );
		$id = $order->get_id();
		return $this->locked( $id, function () use ( $id ) {
			$order = wc_get_order( $id );
			$gateway = wc_get_payment_gateway_by_order( $order );
			if ( ! $gateway || 'yes' !== $gateway->enabled || 'kashier' !== self::adapter( $gateway )
				|| ! $order->needs_payment() || $order->is_paid() || 'pending' !== $order->get_status()
				|| '' !== (string) $order->get_meta( '_kidia_inline_reference' ) ) return self::error( 'unavailable', 409 );
			$amount = self::money( $order->get_total( 'edit' ) );
			if ( null === $amount || '0.00' === $amount || ( 'yes' === $gateway->get_option( 'enforce_egp_payment' ) && 'EGP' !== $order->get_currency() ) ) return self::error( 'unavailable', 409 );
			$record = $order->get_meta( '_mobishop_native_payment92' );
			if ( is_array( $record ) ) {
				// A timeout is not permission to issue a second provider payment.
				if ( $record['amount'] !== $amount || $record['currency'] !== $order->get_currency()
					|| $record['merchant'] !== $gateway->merchant_id || $record['test'] !== (bool) $gateway->testmode
					|| empty( $record['session'] ) || $record['expires'] <= time() ) return self::error( 'review_required', 409 );
				return $this->session_response( $id, $record );
			}
			$record = array( 'reference' => 'mobile-' . $id . '-' . bin2hex( random_bytes( 12 ) ),
				'amount' => $amount, 'currency' => $order->get_currency(), 'merchant' => $gateway->merchant_id,
				'test' => (bool) $gateway->testmode, 'expires' => time() + 1800, 'session' => '' );
			$order->update_meta_data( '_mobishop_native_payment92', $record );
			$order->save(); // Durable intent before the only provider POST.
			$body = array( 'merchantId' => $record['merchant'], 'order' => $record['reference'],
				'amount' => $amount, 'currency' => $record['currency'], 'expireAt' => gmdate( 'Y-m-d\TH:i:s\Z', $record['expires'] ),
				'maxFailureAttempts' => 1, 'paymentType' => 'credit', 'type' => 'one-time', 'allowedMethods' => 'card',
				'defaultMethod' => 'card', 'display' => is_rtl() ? 'ar' : 'en', 'enable3DS' => true, 'manualCapture' => false,
				'saveCard' => 'hidden', 'retrieveSavedCard' => false,
				'customer' => array( 'reference' => (string) $order->get_customer_id() ),
				'merchantRedirect' => rest_url( 'mobishop/v1/native-payment/return' ),
				'serverWebhook' => rest_url( 'mobishop/v1/native-payment/kashier/webhook/' . $id ),
			);
			$response = wp_remote_post( $this->api( $record ) . '/v3/payment/sessions', array(
				'headers' => array( 'Authorization' => $gateway->secret_key, 'api-key' => $gateway->api_key, 'Content-Type' => 'application/json' ),
				'body' => wp_json_encode( $body ), 'timeout' => 20, 'redirection' => 0,
			) );
			$data = ! is_wp_error( $response ) && 200 === wp_remote_retrieve_response_code( $response )
				? json_decode( wp_remote_retrieve_body( $response ), true ) : null;
			if ( ! is_array( $data ) || ! preg_match( '/^[a-f0-9]{24}$/D', $data['_id'] ?? '' )
				|| ( $data['merchantId'] ?? '' ) !== $record['merchant']
				|| ( $data['paymentParams']['order'] ?? '' ) !== $record['reference']
				|| self::money( $data['paymentParams']['amount'] ?? null ) !== $record['amount']
				|| ( $data['paymentParams']['currency'] ?? '' ) !== $record['currency'] ) return self::error( 'review_required', 503 );
			$record['session'] = $data['_id'];
			$order->update_meta_data( '_mobishop_native_payment92', $record );
			$order->save();
			return $this->session_response( $id, $record );
		} );
	}

	private function session_response( int $id, array $record ) {
		return $this->response( array( 'adapter' => 'kashier', 'order_id' => $id, 'session_id' => $record['session'],
			'mode' => $record['test'] ? 'test' : 'live', 'amount' => $record['amount'], 'currency' => $record['currency'] ) );
	}

	public function status( WP_REST_Request $request ) {
		if ( true !== $this->authenticate( $request ) ) return self::error( 'unauthorized', 401 );
		$order = $this->owned_order( $request );
		if ( ! $order ) return self::error( 'unavailable', 404 );
		return $this->reconcile( $order->get_id() );
	}

	public function webhook( WP_REST_Request $request ) {
		$order = wc_get_order( (int) $request['id'] );
		$gateway = $order ? wc_get_payment_gateway_by_order( $order ) : null;
		$record = $order ? $order->get_meta( '_mobishop_native_payment92' ) : null;
		$data = $request->get_json_params()['data'] ?? null;
		if ( ! $gateway || ! is_array( $record ) || ! is_array( $data )
			|| ! self::verified_signature( $data, (string) $request->get_header( 'x-kashier-signature' ), $gateway->api_key, $record ) ) return self::error( 'unauthorized', 403 );
		// Even a valid notification is only a trigger for a server-to-provider read.
		return $this->reconcile( $order->get_id() );
	}

	public static function verified_signature( array $data, string $signature, string $key, array $record ): bool {
		$keys = $data['signatureKeys'] ?? null;
		if ( ! is_array( $keys ) || ! array_is_list( $keys ) || count( $keys ) > 40 || '' === $key
			|| ! preg_match( '/^[a-fA-F0-9]{64}$/D', $signature ) ) return false;
		foreach ( array( 'amount', 'currency', 'merchantOrderId', 'status', 'method', 'transactionId' ) as $required ) {
			if ( ! in_array( $required, $keys, true ) ) return false;
		}
		$values = array();
		sort( $keys, SORT_STRING );
		foreach ( $keys as $name ) {
			if ( ! is_string( $name ) || ! preg_match( '/^[a-zA-Z][a-zA-Z0-9]*$/D', $name ) || ! isset( $data[ $name ] ) || ! is_scalar( $data[ $name ] ) ) return false;
			$values[ $name ] = $data[ $name ];
		}
		return ( $data['merchantOrderId'] ?? '' ) === $record['reference'] && ( $data['currency'] ?? '' ) === $record['currency']
			&& self::money( $data['amount'] ?? null ) === $record['amount']
			&& hash_equals( hash_hmac( 'sha256', http_build_query( $values, '', '&', PHP_QUERY_RFC3986 ), $key ), strtolower( $signature ) );
	}

	private function reconcile( int $id ) {
		return $this->locked( $id, function () use ( $id ) {
			$order = wc_get_order( $id );
			$record = $order->get_meta( '_mobishop_native_payment92' );
			$gateway = wc_get_payment_gateway_by_order( $order );
			if ( ! $order->is_paid() && is_array( $record ) && $gateway && 'kashier' === self::adapter( $gateway )
				&& 'pending' === $order->get_status() && $order->needs_payment()
				&& self::money( $order->get_total( 'edit' ) ) === $record['amount'] && $order->get_currency() === $record['currency']
				&& $gateway->merchant_id === $record['merchant'] && (bool) $gateway->testmode === $record['test'] ) {
				$response = wp_remote_get( add_query_arg( 'search', $record['reference'], $this->api( $record ) . '/v3/payment/orders' ), array(
					'headers' => array( 'Authorization' => $gateway->secret_key ), 'timeout' => 15, 'redirection' => 0,
				) );
				$data = ! is_wp_error( $response ) && 200 === wp_remote_retrieve_response_code( $response )
					? json_decode( wp_remote_retrieve_body( $response ), true ) : null;
				$transaction = is_array( $data ) ? self::paid_transaction( $data, $record ) : null;
				if ( null !== $transaction ) $order->payment_complete( $transaction );
			}
			return $this->response( array( 'order_id' => $id, 'paid' => $order->is_paid(), 'status' => $order->get_status() ) );
		} );
	}

	public static function paid_transaction( array $data, array $record ): ?string {
		if ( 'SUCCESS' !== ( $data['status'] ?? '' ) || ! is_array( $data['data'] ?? null ) ) return null;
		$matches = array_values( array_filter( $data['data'], static fn( $row ) => is_array( $row ) && ( $row['merchantOrderId'] ?? '' ) === $record['reference'] ) );
		if ( 1 !== count( $matches ) ) return null;
		$row = $matches[0];
		if ( ( $row['merchantId'] ?? '' ) !== $record['merchant'] || ( $row['status'] ?? '' ) !== 'CAPTURED'
			|| ( $row['sessionId'] ?? '' ) !== $record['session'] || ( $row['method'] ?? '' ) !== 'card'
			|| ( $row['order']['currency'] ?? '' ) !== $record['currency'] || self::money( $row['order']['amount'] ?? null ) !== $record['amount']
			|| self::money( $row['totalCapturedAmount'] ?? null ) !== $record['amount'] || self::money( $row['totalRefundedAmount'] ?? null ) !== '0.00'
			|| ! is_array( $row['transactions'] ?? null ) ) return null;
		foreach ( $row['transactions'] as $transaction ) {
			if ( is_array( $transaction ) && in_array( $transaction['operation'] ?? '', array( 'pay', 'capture' ), true )
				&& ( $transaction['status'] ?? '' ) === 'SUCCESS' && ( $transaction['currency'] ?? '' ) === $record['currency']
				&& self::money( $transaction['amount'] ?? null ) === $record['amount'] && is_string( $transaction['transactionId'] ?? null )
				&& preg_match( '/^[A-Za-z0-9-]{1,100}$/D', $transaction['transactionId'] ) ) return $transaction['transactionId'];
		}
		return null;
	}

	public static function money( $value ): ?string {
		if ( ! is_string( $value ) && ! is_int( $value ) && ! is_float( $value ) ) return null;
		$text = (string) $value;
		if ( ! preg_match( '/^(0|[1-9][0-9]{0,11})(?:\.([0-9]{1,2}))?$/D', $text, $match ) ) return null;
		return $match[1] . '.' . str_pad( $match[2] ?? '', 2, '0' );
	}

	private function locked( int $id, callable $callback ) {
		global $wpdb;
		$name = 'mobishop-payment92-' . substr( hash( 'sha256', ( defined( 'DB_NAME' ) ? DB_NAME : '' ) . ':' . $wpdb->prefix . ':' . $id ), 0, 40 );
		if ( '1' !== (string) $wpdb->get_var( $wpdb->prepare( 'SELECT GET_LOCK(%s,0)', $name ) ) ) return self::error( 'busy', 409 );
		try { return $callback(); }
		catch ( Throwable $error ) { return self::error( 'review_required', 503 ); }
		finally { $wpdb->get_var( $wpdb->prepare( 'SELECT RELEASE_LOCK(%s)', $name ) ); }
	}
	private function api( array $record ): string { return $record['test'] ? 'https://test-api.kashier.io' : 'https://api.kashier.io'; }
	private static function error( string $reason, int $status ) { return new WP_Error( 'native_payment_' . $reason, 'Payment could not be verified. Review this order before paying again.', array( 'status' => $status ) ); }
	private function response( array $data ) { $response = rest_ensure_response( $data ); $response->header( 'Cache-Control', 'no-store' ); return $response; }
}
