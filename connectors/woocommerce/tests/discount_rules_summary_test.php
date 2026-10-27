<?php
/**
 * Standalone test harness for MobiShop_Discount_Rules_Summary.
 * Run with: php discount_rules_summary_test.php
 * Provides minimal WP/wpdb stubs; no real WordPress or database is used.
 */

error_reporting( E_ALL & ~E_DEPRECATED );

define( 'ABSPATH', __DIR__ . '/' );
define( 'ARRAY_A', 'ARRAY_A' );
define( 'OBJECT', 'OBJECT' );

// ---- WordPress function stubs -------------------------------------------------

$GLOBALS['TEST_CAN_MANAGE_WOOCOMMERCE'] = true;
$GLOBALS['TEST_CAN_MANAGE_OPTIONS']     = true;
$GLOBALS['TEST_HAS_WDR_FILTER']         = true;
$GLOBALS['TEST_NOW']                    = 1000000;
$GLOBALS['TEST_WRITE_ATTEMPTED']        = false;

function current_user_can( $cap ) {
	if ( 'manage_woocommerce' === $cap ) {
		return $GLOBALS['TEST_CAN_MANAGE_WOOCOMMERCE'];
	}
	if ( 'manage_options' === $cap ) {
		return $GLOBALS['TEST_CAN_MANAGE_OPTIONS'];
	}
	return false;
}

function has_filter( $tag ) {
	return 'advanced_woo_discount_rules_get_product_discount_price' === $tag && $GLOBALS['TEST_HAS_WDR_FILTER'];
}

function sanitize_text_field( $value ) {
	return trim( strip_tags( (string) $value ) );
}

function sanitize_key( $value ) {
	$value = strtolower( (string) $value );
	return preg_replace( '/[^a-z0-9_\-]/', '', $value );
}

function wp_unslash( $value ) {
	return $value;
}

function absint( $value ) {
	return abs( (int) $value );
}

function __( $text, $domain = 'default' ) {
	return $text;
}

function esc_html__( $text, $domain = 'default' ) {
	return esc_html( $text );
}

function esc_attr__( $text, $domain = 'default' ) {
	return esc_attr( $text );
}

function esc_html( $text ) {
	return htmlspecialchars( (string) $text, ENT_QUOTES );
}

function esc_attr( $text ) {
	return htmlspecialchars( (string) $text, ENT_QUOTES );
}

function esc_url( $url ) {
	return htmlspecialchars( (string) $url, ENT_QUOTES );
}

function admin_url( $path = '' ) {
	return 'http://example.test/wp-admin/' . $path;
}

function wp_timezone_string() {
	return 'UTC';
}

function current_time( $type ) {
	return $GLOBALS['TEST_NOW'];
}

function add_query_arg( $key, $value = null ) {
	return 'http://example.test/wp-admin/admin.php';
}

function paginate_links( $args ) {
	return '<a>PAGINATE</a>';
}

function wp_kses_post( $html ) {
	return $html;
}

// ---- Stub $wpdb capturing every query, no real DB, no writes allowed ---------

class Test_Stub_WPDB {
	public $prefix = 'wp_';
	public $queries = array();
	public $var_queue = array();
	public $results_queue = array();

	public function prepare( $query, $args ) {
		if ( ! is_array( $args ) ) {
			$args = array( $args );
		}
		$i = 0;
		return preg_replace_callback(
			'/%[sd]/',
			static function ( $matches ) use ( &$i, $args ) {
				$value = $args[ $i ] ?? '';
				++$i;
				if ( '%d' === $matches[0] ) {
					return (string) intval( $value );
				}
				return "'" . addslashes( (string) $value ) . "'";
			},
			$query
		);
	}

	public function esc_like( $text ) {
		return addcslashes( (string) $text, '_%\\' );
	}

	public function get_var( $query ) {
		$this->queries[] = $query;
		return array_shift( $this->var_queue );
	}

	public function get_results( $query, $output = OBJECT ) {
		$this->queries[] = $query;
		return array_shift( $this->results_queue );
	}

	public function insert( $table, $data, $format = null ) {
		$GLOBALS['TEST_WRITE_ATTEMPTED'] = true;
		throw new RuntimeException( 'write attempted: insert' );
	}

	public function update( $table, $data, $where, $format = null, $where_format = null ) {
		$GLOBALS['TEST_WRITE_ATTEMPTED'] = true;
		throw new RuntimeException( 'write attempted: update' );
	}

	public function query( $sql ) {
		$GLOBALS['TEST_WRITE_ATTEMPTED'] = true;
		throw new RuntimeException( 'write attempted: query' );
	}
}

$root = getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: __DIR__ . '/../source';
function add_action( ...$args ) {}
function wp_json_encode( $value ) { return json_encode( $value ); }
require $root . '/includes/class-mobishop-discount-channel.php';
require $root . '/includes/central/class-discount-rules-admin.php';
require $root . '/includes/central/class-discount-rules-summary.php';

// ---- Minimal test runner ------------------------------------------------------

$failures = 0;
$passed   = 0;

function check( string $label, bool $condition ): void {
	global $failures, $passed;
	if ( $condition ) {
		++$passed;
		echo "PASS: {$label}\n";
	} else {
		++$failures;
		echo "FAIL: {$label}\n";
	}
}

function reset_globals(): void {
	global $wpdb;
	$GLOBALS['TEST_CAN_MANAGE_WOOCOMMERCE'] = true;
	$GLOBALS['TEST_CAN_MANAGE_OPTIONS']     = true;
	$GLOBALS['TEST_HAS_WDR_FILTER']         = true;
	$GLOBALS['TEST_NOW']                    = 1000000;
	$_GET                                   = array();
	$wpdb                                   = new Test_Stub_WPDB();
}

global $wpdb;

// 1. Unauthorized user: no DB access, forbidden-empty result, render emits nothing.
reset_globals();
$GLOBALS['TEST_CAN_MANAGE_OPTIONS'] = false;
$result = MobiShop_Discount_Rules_Summary::query();
check( '1a unauthorized query returns error=true', true === $result['error'] );
check( '1b unauthorized query returns available=false', false === $result['available'] );
check( '1c unauthorized query performs no DB calls', empty( $wpdb->queries ) );
ob_start();
MobiShop_Discount_Rules_Summary::render();
$output = ob_get_clean();
check( '1d unauthorized render emits nothing', '' === $output );

// 2. Plugin not active: available=false, error=false, no DB calls.
reset_globals();
$GLOBALS['TEST_HAS_WDR_FILTER'] = false;
$result = MobiShop_Discount_Rules_Summary::query();
check( '2a inactive plugin available=false', false === $result['available'] );
check( '2b inactive plugin error=false', false === $result['error'] );
check( '2c inactive plugin performs no DB calls', empty( $wpdb->queries ) );

// 3. Plugin active but rules table missing.
reset_globals();
$wpdb->var_queue = array( null ); // SHOW TABLES LIKE returns nothing.
$result = MobiShop_Discount_Rules_Summary::query();
check( '3a missing table available=false', false === $result['available'] );
check( '3b missing table error=false', false === $result['error'] );
check( '3c missing table stops after existence check', 1 === count( $wpdb->queries ) );

// 4. Prepared search is escaped; malicious title is escaped on render; deleted=0 enforced;
//    whitelisted columns only; stable pagination ordering.
reset_globals();
$wpdb->var_queue     = array( 'wp_wdr_rules', 3 ); // table exists, then COUNT(*) = 3
$wpdb->results_queue = array(
	array(
		array(
			'id'            => '7',
			'title'         => "<script>alert('x')</script>",
			'discount_type' => 'wdr_cart_discount',
			'enabled'       => '1',
			'priority'      => '2',
			'exclusive'     => '0',
			'date_from'     => null,
			'date_to'       => null,
			'usage_limits'  => '0',
			'used_limits'   => null,
		),
	),
);
$result = MobiShop_Discount_Rules_Summary::query(
	array(
		'search' => "o'Reilly",
		'type'   => 'all',
		'page'   => 10, // out of bounds on purpose
	)
);
check( '4a available true when plugin+table present', true === $result['available'] );
check( '4b total reflects COUNT(*) result', 3 === $result['total'] );
check( '4c page is clamped to max valid page', 1 === $result['page'] && 1 === $result['pages'] );
check( '4d one normalized row returned', 1 === count( $result['rows'] ) );

$select_query = $wpdb->queries[2];
check( '4e merchant revision is available', 64 === strlen( $result['rows'][0]['revision'] ) );
check( '4f response excludes raw targeting columns', ! array_intersect( array_keys( $result['rows'][0] ), array( 'filters', 'conditions', 'used_coupons', 'created_by', 'modified_by', 'apply_to', 'additional' ) ) );
check( '4g select includes deleted = 0', false !== strpos( $select_query, 'deleted = 0' ) );
check( '4h select orders by priority ASC, id ASC', false !== strpos( $select_query, 'ORDER BY priority ASC, id ASC' ) );
check( '4i search is escaped via prepare (quote is backslash-escaped)', false !== strpos( $select_query, "o\\'Reilly" ) );
check( '4j search uses LIKE with wildcard', false !== strpos( $select_query, "LIKE '%o\\'Reilly%'" ) );

// Re-arm the stub with the same malicious row for a fresh render() pass.
$wpdb->var_queue     = array( 'wp_wdr_rules', 1 );
$wpdb->results_queue = array(
	array(
		array(
			'id'            => '7',
			'title'         => "<script>alert('x')</script>",
			'discount_type' => 'wdr_cart_discount',
			'enabled'       => '1',
			'priority'      => '2',
			'exclusive'     => '0',
			'date_from'     => null,
			'date_to'       => null,
			'usage_limits'  => '0',
			'used_limits'   => null,
		),
	),
);
ob_start();
MobiShop_Discount_Rules_Summary::render(
	array(
		'search' => '',
		'type'   => 'all',
		'page'   => 1,
	)
);
$rendered = ob_get_clean();
check( '4k malicious title is escaped in render output', false === strpos( $rendered, '<script>' ) );
check( '4l escaped title text is present', false !== strpos( $rendered, '&lt;script&gt;' ) );

// 5. Unknown discount_type filter means no rule-type filter is applied.
reset_globals();
$wpdb->var_queue     = array( 'wp_wdr_rules', 0 );
$wpdb->results_queue = array( array() );
$result = MobiShop_Discount_Rules_Summary::query(
	array(
		'search' => '',
		'type'   => 'fixed_cart', // a WooCommerce coupon type, not a FlyCart rule type
		'page'   => 1,
	)
);
$count_query = $wpdb->queries[1];
check( '5a unknown type applies no discount_type filter', false === strpos( $count_query, 'discount_type' ) );
check( '5b zero total yields empty rows without a select query', 2 === count( $wpdb->queries ) );

// 6. normalize_row status boundaries (pure function, no WP/DB calls).
$now = 1000000;

$disabled_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 1, 'title' => 'A', 'discount_type' => 'wdr_simple_discount', 'enabled' => '0', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => null, 'usage_limits' => '0', 'used_limits' => null ),
	$now
);
check( '6a enabled=0 is disabled regardless of dates', 'disabled' === $disabled_row['status'] );

$scheduled_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 2, 'title' => 'B', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => $now + 1, 'date_to' => null, 'usage_limits' => '0', 'used_limits' => null ),
	$now
);
check( '6b date_from strictly greater than now is scheduled', 'scheduled' === $scheduled_row['status'] );

$boundary_from_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 3, 'title' => 'C', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => $now, 'date_to' => null, 'usage_limits' => '0', 'used_limits' => null ),
	$now
);
check( '6c date_from equal to now is inclusive (active, not scheduled)', 'active' === $boundary_from_row['status'] );

$expired_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 4, 'title' => 'D', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => $now - 1, 'usage_limits' => '0', 'used_limits' => null ),
	$now
);
check( '6d date_to strictly before now is expired', 'expired' === $expired_row['status'] );

$boundary_to_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 5, 'title' => 'E', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => $now, 'usage_limits' => '0', 'used_limits' => null ),
	$now
);
check( '6e date_to equal to now is inclusive (active, not expired)', 'active' === $boundary_to_row['status'] );

$exhausted_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 6, 'title' => 'F', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => null, 'usage_limits' => '5', 'used_limits' => '5' ),
	$now
);
check( '6f used_limits >= usage_limits is exhausted', 'exhausted' === $exhausted_row['status'] );

$not_exhausted_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 7, 'title' => 'G', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => null, 'usage_limits' => '5', 'used_limits' => '4' ),
	$now
);
check( '6g used_limits below usage_limits is active', 'active' === $not_exhausted_row['status'] );

$unlimited_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 8, 'title' => 'H', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => null, 'usage_limits' => '0', 'used_limits' => '999' ),
	$now
);
check( '6h usage_limits=0 (unlimited) is never exhausted', 'active' === $unlimited_row['status'] );

$null_used_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 9, 'title' => 'I', 'discount_type' => 'x', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => null, 'usage_limits' => '5', 'used_limits' => null ),
	$now
);
check( '6i used_limits=NULL with usage_limits set is active, not exhausted', 'active' === $null_used_row['status'] );

$unknown_type_row = MobiShop_Discount_Rules_Summary::normalize_row(
	array( 'id' => 10, 'title' => 'J', 'discount_type' => 'wdr_totally_unknown', 'enabled' => '1', 'priority' => '1', 'exclusive' => '0', 'date_from' => null, 'date_to' => null, 'usage_limits' => '0', 'used_limits' => null ),
	$now
);
check( '6j unknown discount_type falls back to "Other rule"', 'Other rule' === $unknown_type_row['type_label'] );

// 7. No write methods are ever invoked across the scenarios above.
check( '7a no DB writes were attempted in any scenario', false === $GLOBALS['TEST_WRITE_ATTEMPTED'] );

// 8. Second page of a larger result set computes a correct, stable offset.
reset_globals();
$wpdb->var_queue     = array( 'wp_wdr_rules', 50 );
$wpdb->results_queue = array( array() );
MobiShop_Discount_Rules_Summary::query(
	array(
		'search' => '',
		'type'   => 'all',
		'page'   => 2,
	)
);
$select_query_p2 = $wpdb->queries[2];
check( '8a page 2 uses offset 20 with per-page 20', false !== strpos( $select_query_p2, 'LIMIT 20 OFFSET 20' ) );

if ( ! function_exists( 'get_woocommerce_currency' ) ) { function get_woocommerce_currency() { return 'EGP'; } }
foreach ( array( 'flat' => '20 EGP off per item', 'flat_in_subtotal' => '20 EGP off subtotal', 'fixed_price' => 'Final price: 20 EGP', 'percentage' => '20% off' ) as $kind => $label ) {
	$summary = MobiShop_Discount_Rules_Summary::normalize_row( array( 'discount_type' => 'wdr_simple_discount', 'product_adjustments' => json_encode( array( 'type' => $kind, 'value' => '20' ) ) ), $now );
	check( '9 offer meaning: ' . $kind, $label === $summary['offer'] );
}
$summary = MobiShop_Discount_Rules_Summary::normalize_row( array( 'discount_type' => 'wdr_set_discount', 'set_adjustments' => '{"ranges":{"1":{"from":"2","type":"fixed_set_price","value":"150"}}}' ), $now );
check( '9 bundle total distinguished from discount', '2+: Set price: 150 EGP' === $summary['offer'] );
echo "\n{$passed} passed, {$failures} failed.\n";
exit( $failures > 0 ? 1 : 0 );
