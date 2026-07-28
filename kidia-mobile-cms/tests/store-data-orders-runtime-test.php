<?php
/**
 * Runtime contract for the shared Store Data WooCommerce order source.
 *
 * Run with: php kidia-mobile-cms/tests/store-data-orders-runtime-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_query_mode']  = 'fallback';
$GLOBALS['kidia_query_calls'] = array();

class WC_Order {
	public function __construct(
		private int $id,
		private string $created_at,
		private string $source = 'website'
	) {}

	public function get_id(): int {
		return $this->id;
	}

	public function get_date_created(): DateTimeImmutable {
		return new DateTimeImmutable( $this->created_at );
	}

	public function get_meta( string $key ): string {
		return '_kidia_order_source' === $key ? $this->source : '';
	}
}

function absint( $value ): int {
	return abs( (int) $value );
}

function sanitize_key( $value ): string {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: '';
}

function wc_get_orders( array $args ): object {
	$GLOBALS['kidia_query_calls'][] = $args;
	if ( 'native' === $GLOBALS['kidia_query_mode'] ) {
		return (object) array(
			'orders'        => array( new WC_Order( 20, '2026-07-28T09:00:00+00:00', 'website' ) ),
			'max_num_pages' => 1,
		);
	}

	if ( isset( $args['date_created'] ) ) {
		return (object) array( 'orders' => array(), 'max_num_pages' => 1 );
	}

	return (object) array(
		'orders'        => array(
			new WC_Order( 10, '2026-07-28T10:00:00+00:00', 'mobile' ),
			new WC_Order( 11, '2026-07-28T08:00:00+00:00', 'website' ),
			new WC_Order( 12, '2026-07-29T01:00:00+00:00', 'website' ),
			new WC_Order( 13, '2026-07-27T23:59:59+00:00', 'website' ),
		),
		'max_num_pages' => 12,
	);
}

function kidia_orders_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-analytics.php';

$from = ( new DateTimeImmutable( '2026-07-28T00:00:00+00:00' ) )->getTimestamp();
$to   = ( new DateTimeImmutable( '2026-07-28T23:59:59+00:00' ) )->getTimestamp();

$all = Kidia_Mobile_Analytics::orders_in_period( $from, $to );
kidia_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $all ) === array( 10, 11 ), 'Fallback must return only orders inside the exact period.' );
kidia_orders_assert( 2 === count( $GLOBALS['kidia_query_calls'] ), 'Fallback must stop after reaching an order older than the period.' );
kidia_orders_assert( isset( $GLOBALS['kidia_query_calls'][0]['date_created'] ), 'The supported native WooCommerce range must be attempted first.' );
kidia_orders_assert( ! isset( $GLOBALS['kidia_query_calls'][1]['date_created'] ), 'An unfiltered newest-first fallback must run when the native range is unexpectedly empty.' );

$GLOBALS['kidia_query_calls'] = array();
$website = Kidia_Mobile_Analytics::orders_in_period( $from, $to, 'website', array( 'processing', 'completed' ) );
kidia_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $website ) === array( 11 ), 'Website results must exclude mobile orders.' );
kidia_orders_assert( $GLOBALS['kidia_query_calls'][0]['status'] === array( 'processing', 'completed' ), 'Paid status filters must be preserved.' );

$GLOBALS['kidia_query_calls'] = array();
$mobile = Kidia_Mobile_Analytics::orders_in_period( $from, $to, 'mobile' );
kidia_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $mobile ) === array( 10 ), 'Mobile results must require the mobile order source.' );

$GLOBALS['kidia_query_mode']  = 'native';
$GLOBALS['kidia_query_calls'] = array();
$native = Kidia_Mobile_Analytics::orders_in_period( $from, $to, 'website' );
kidia_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $native ) === array( 20 ), 'A valid native range result must be returned directly.' );
kidia_orders_assert( 1 === count( $GLOBALS['kidia_query_calls'] ), 'A successful native range must not run the fallback.' );

echo "Store Data order runtime tests passed.\n";
