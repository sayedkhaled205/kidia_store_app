<?php
/**
 * Runtime contract for the shared Store Data WooCommerce order source.
 *
 * Run with: php mobishop/tests/store-data-orders-runtime-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );
define( 'ARRAY_A', 'ARRAY_A' );

$GLOBALS['mobishop_query_mode']  = 'fallback';
$GLOBALS['mobishop_query_calls'] = array();

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
		return '_mobishop_order_source' === $key ? $this->source : '';
	}
}

function absint( $value ): int {
	return abs( (int) $value );
}

function sanitize_key( $value ): string {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: '';
}

function wc_get_is_paid_statuses(): array {
	return array( 'processing', 'completed' );
}

function wc_get_order_statuses(): array {
	return array(
		'wc-pending'        => 'Pending payment',
		'wc-processing'     => 'Processing',
		'wc-on-hold'        => 'On hold',
		'wc-completed'      => 'Completed',
		'wc-cancelled'      => 'Cancelled',
		'wc-refunded'       => 'Refunded',
		'wc-failed'         => 'Failed',
		'wc-checkout-draft' => 'Draft',
		'wc-done-2'         => 'DONE 2',
		'wc-confirmed-ar'   => 'تم التأكيد',
		'wc-editing'        => 'تعديل',
	);
}

function wc_orders_count( string $status ): int {
	$counts = array(
		'pending'      => 4,
		'processing'   => 10,
		'on-hold'      => 3,
		'completed'    => 20,
		'cancelled'    => 2,
		'refunded'     => 1,
		'failed'       => 5,
		'done-2'       => 120,
		'confirmed-ar' => 200,
		'editing'      => 30,
	);
	return $counts[ $status ] ?? 0;
}

function wc_get_orders( array $args ): object {
	$GLOBALS['mobishop_query_calls'][] = $args;
	if ( 'native' === $GLOBALS['mobishop_query_mode'] ) {
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

function mobishop_orders_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/includes/class-mobishop-analytics.php';

$from = ( new DateTimeImmutable( '2026-07-28T00:00:00+00:00' ) )->getTimestamp();
$to   = ( new DateTimeImmutable( '2026-07-28T23:59:59+00:00' ) )->getTimestamp();

$all = MobiShop_Analytics::orders_in_period( $from, $to );
mobishop_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $all ) === array( 10, 11 ), 'Fallback must return only orders inside the exact period.' );
mobishop_orders_assert( 2 === count( $GLOBALS['mobishop_query_calls'] ), 'Fallback must stop after reaching an order older than the period.' );
mobishop_orders_assert( isset( $GLOBALS['mobishop_query_calls'][0]['date_created'] ), 'The supported native WooCommerce range must be attempted first.' );
mobishop_orders_assert( ! isset( $GLOBALS['mobishop_query_calls'][1]['date_created'] ), 'An unfiltered newest-first fallback must run when the native range is unexpectedly empty.' );

$GLOBALS['mobishop_query_calls'] = array();
$website = MobiShop_Analytics::orders_in_period( $from, $to, 'website', array( 'processing', 'completed' ) );
mobishop_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $website ) === array( 11 ), 'Website results must exclude mobile orders.' );
mobishop_orders_assert( $GLOBALS['mobishop_query_calls'][0]['status'] === array( 'processing', 'completed' ), 'Paid status filters must be preserved.' );

$GLOBALS['mobishop_query_calls'] = array();
$mobile = MobiShop_Analytics::orders_in_period( $from, $to, 'mobile' );
mobishop_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $mobile ) === array( 10 ), 'Mobile results must require the mobile order source.' );

$GLOBALS['mobishop_query_mode']  = 'native';
$GLOBALS['mobishop_query_calls'] = array();
$native = MobiShop_Analytics::orders_in_period( $from, $to, 'website' );
mobishop_orders_assert( array_map( static fn( WC_Order $order ): int => $order->get_id(), $native ) === array( 20 ), 'A valid native range result must be returned directly.' );
mobishop_orders_assert( 1 === count( $GLOBALS['mobishop_query_calls'] ), 'A successful native range must not run the fallback.' );

$revenue_statuses = MobiShop_Analytics::revenue_order_statuses();
mobishop_orders_assert( in_array( 'done-2', $revenue_statuses, true ), 'Custom DONE 2 orders must contribute to revenue.' );
mobishop_orders_assert( in_array( 'confirmed-ar', $revenue_statuses, true ), 'Custom confirmed orders must contribute to revenue.' );
mobishop_orders_assert( in_array( 'editing', $revenue_statuses, true ), 'Custom editing workflow orders must contribute to revenue.' );
mobishop_orders_assert( ! in_array( 'pending', $revenue_statuses, true ), 'Pending core orders must not be counted as paid revenue.' );
mobishop_orders_assert( ! in_array( 'cancelled', $revenue_statuses, true ), 'Cancelled core orders must not be counted as paid revenue.' );
mobishop_orders_assert( ! in_array( 'refunded', $revenue_statuses, true ), 'Refunded core orders must not be counted as paid revenue.' );
mobishop_orders_assert( ! in_array( 'failed', $revenue_statuses, true ), 'Failed core orders must not be counted as paid revenue.' );

$reporting_statuses = MobiShop_Analytics::reporting_order_statuses();
mobishop_orders_assert( in_array( 'refunded', $reporting_statuses, true ), 'WooCommerce reporting must include refunded rows so they reduce net sales.' );
mobishop_orders_assert( in_array( 'on-hold', $reporting_statuses, true ), 'WooCommerce reporting must follow the configured Analytics status exclusions.' );
mobishop_orders_assert( ! in_array( 'pending', $reporting_statuses, true ), 'Pending orders must follow the default WooCommerce Analytics exclusion.' );
mobishop_orders_assert( ! in_array( 'cancelled', $reporting_statuses, true ), 'Cancelled orders must follow the default WooCommerce Analytics exclusion.' );
mobishop_orders_assert( ! in_array( 'failed', $reporting_statuses, true ), 'Failed orders must follow the default WooCommerce Analytics exclusion.' );

$countable_statuses = MobiShop_Analytics::countable_order_statuses();
mobishop_orders_assert( in_array( 'pending', $countable_statuses, true ), 'Pending orders must remain in the real order total.' );
mobishop_orders_assert( in_array( 'done-2', $countable_statuses, true ), 'Custom statuses must remain in the real order total.' );
mobishop_orders_assert( ! in_array( 'checkout-draft', $countable_statuses, true ), 'Checkout drafts must not inflate the order total.' );
mobishop_orders_assert( 395 === MobiShop_Analytics::total_order_count(), 'The order total must sum every built-in and custom real order status.' );

final class MobiShop_Reporting_WPDB {
	public string $prefix = 'wp_';
	public string $postmeta = 'wp_postmeta';
	public string $wc_order_stats = 'wp_wc_order_stats';
	public string $wc_order_product_lookup = 'wp_wc_order_product_lookup';
	/** @var string[] */
	public array $queries = array();

	public function esc_like( string $value ): string {
		return $value;
	}

	public function prepare( string $sql, ...$args ): string {
		foreach ( $args as $arg ) {
			$sql = preg_replace_callback(
				'/%[dis]/',
				static function ( array $match ) use ( $arg ): string {
					if ( '%i' === $match[0] ) {
						return '`' . str_replace( '`', '``', (string) $arg ) . '`';
					}
					return is_numeric( $arg ) ? (string) $arg : "'" . addslashes( (string) $arg ) . "'";
				},
				$sql,
				1
			) ?? $sql;
		}
		return $sql;
	}

	public function get_var( string $sql ): string {
		$this->queries[] = $sql;
		if ( preg_match( "/SHOW TABLES LIKE '([^']+)'/", $sql, $matches ) ) {
			return $matches[1];
		}
		return '';
	}

	/** @return array<string,string|int|float> */
	public function get_row( string $sql, string $output ): array {
		unset( $output );
		$this->queries[] = $sql;
		return array(
			'all_orders'        => 8,
			'reportable_orders' => 5,
			'net_revenue'       => 1000.50,
			'units'             => 12,
			'gross_order_net'   => 1250.0,
			'customers'         => 4,
		);
	}

	/** @return array<int,array<string,string|int|float>> */
	public function get_results( string $sql, string $output ): array {
		unset( $output );
		$this->queries[] = $sql;
		if ( str_contains( $sql, 'GROUP BY orders.status' ) ) {
			return array(
				array( 'status' => 'wc-completed', 'status_count' => 5 ),
				array( 'status' => 'wc-cancelled', 'status_count' => 3 ),
			);
		}
		return array(
			array( 'product_id' => 71, 'units' => 7, 'revenue' => 700.25, 'order_count' => 3 ),
			array( 'product_id' => 81, 'units' => 5, 'revenue' => 300.25, 'order_count' => 2 ),
		);
	}
}

$GLOBALS['wpdb'] = new MobiShop_Reporting_WPDB();
$reporting = MobiShop_Analytics::reporting_snapshot( $from, $to, 'all' );
mobishop_orders_assert( 8 === $reporting['all_orders'], 'Reports must count every non-draft order in the selected period.' );
mobishop_orders_assert( 5 === $reporting['orders'], 'Analytics commerce must count paid orders only.' );
mobishop_orders_assert( 1000.50 === $reporting['revenue'], 'Paid revenue must come from WooCommerce net sales after refunds.' );
mobishop_orders_assert( 12 === $reporting['units'], 'Units must come from WooCommerce refund-aware reporting facts.' );
mobishop_orders_assert( 4 === $reporting['customers'], 'Reporting customers must remain an exact distinct count.' );
mobishop_orders_assert( 250.0 === $reporting['average_order_value'], 'Average order value must use parent-order net totals before refund rows.' );
mobishop_orders_assert( array( 'completed' => 5, 'cancelled' => 3 ) === $reporting['status_counts'], 'Status distribution must include paid and unpaid real orders.' );
mobishop_orders_assert( 71 === $reporting['products'][0]['object_id'], 'Best sellers must use WooCommerce product net revenue ordering.' );
$reporting_sql = implode( "\n", $GLOBALS['wpdb']->queries );
mobishop_orders_assert( str_contains( $reporting_sql, 'SUM(CASE WHEN is_reportable = 1 THEN net_total ELSE 0 END)' ), 'Net sales must include negative WooCommerce refund rows.' );
mobishop_orders_assert( str_contains( $reporting_sql, 'SUM(CASE WHEN is_reportable = 1 THEN num_items_sold ELSE 0 END)' ), 'Items sold must include negative WooCommerce refund quantities.' );
mobishop_orders_assert( str_contains( $reporting_sql, 'products.product_gross_revenue >= 0' ), 'Product order counts must not count refund rows as new orders.' );
mobishop_orders_assert( ! str_contains( $reporting_sql, 'order_facts.parent_id = 0' ), 'Product totals must retain refund facts instead of filtering them out.' );

$GLOBALS['wpdb']->queries = array();
MobiShop_Analytics::reporting_snapshot( $from, $to, 'mobile' );
$mobile_sql = implode( "\n", $GLOBALS['wpdb']->queries );
mobishop_orders_assert( str_contains( $mobile_sql, 'wp_wc_orders_meta' ), 'Mobile filtering must read HPOS order metadata when available.' );
mobishop_orders_assert( str_contains( $mobile_sql, "meta_value = 'mobile'" ), 'Mobile filtering must require the explicit mobile order marker.' );
mobishop_orders_assert( str_contains( $mobile_sql, 'order_id IN' ), 'Mobile reports must include only marked mobile orders.' );
mobishop_orders_assert( str_contains( $mobile_sql, 'CASE WHEN facts.parent_id > 0 THEN facts.parent_id ELSE facts.order_id END' ), 'Refund facts must inherit their parent order channel.' );

echo "Store Data order runtime tests passed.\n";
