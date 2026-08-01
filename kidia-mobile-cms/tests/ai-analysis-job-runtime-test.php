<?php
/** Runtime contract for monotonic AI analysis batches and atomic locking. */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'DAY_IN_SECONDS', 86400 );

$GLOBALS['kidia_ai_transients'] = array();
$GLOBALS['kidia_ai_options']    = array();
$GLOBALS['kidia_ai_user_meta']  = array();
$GLOBALS['kidia_ai_uuid']       = 0;
$GLOBALS['kidia_ai_cache_limit'] = 2048;
$GLOBALS['kidia_ai_order_reloads'] = 0;

$wpdb = new class() {
	public string $prefix = 'wp_';
	public string $posts = 'wp_posts';
	public string $wc_product_meta_lookup = 'wp_wc_product_meta_lookup';
	public function get_col( string $query ): array {
		$GLOBALS['kidia_ai_product_query'] = $query;
		return range( 1, 600 );
	}
};

function __( string $value, string $domain = '' ): string { unset( $domain ); return $value; }
function absint( $value ): int { return abs( (int) $value ); }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function wp_generate_uuid4(): string { return 'runtime-job-' . ++$GLOBALS['kidia_ai_uuid']; }
function kidia_ai_database_accepts( $value ): bool {
	return 1 === preg_match( '//u', serialize( $value ) );
}
function get_transient( string $key ) { return $GLOBALS['kidia_ai_transients'][ $key ] ?? false; }
function set_transient( string $key, $value, int $expiration = 0 ): bool {
	unset( $expiration );
	if ( strlen( serialize( $value ) ) > $GLOBALS['kidia_ai_cache_limit'] ) {
		return false;
	}
	$GLOBALS['kidia_ai_transients'][ $key ] = $value;
	return true;
}
function delete_transient( string $key ): bool { unset( $GLOBALS['kidia_ai_transients'][ $key ] ); return true; }
function add_option( string $key, $value = '', string $deprecated = '', $autoload = 'yes' ): bool {
	unset( $deprecated, $autoload );
	if ( array_key_exists( $key, $GLOBALS['kidia_ai_options'] ) || ! kidia_ai_database_accepts( $value ) ) {
		return false;
	}
	$GLOBALS['kidia_ai_options'][ $key ] = $value;
	return true;
}
function get_option( string $key, $default = false ) { return $GLOBALS['kidia_ai_options'][ $key ] ?? $default; }
function update_option( string $key, $value, $autoload = null ): bool {
	unset( $autoload );
	if ( ! kidia_ai_database_accepts( $value ) ) {
		return false;
	}
	if ( array_key_exists( $key, $GLOBALS['kidia_ai_options'] ) && $GLOBALS['kidia_ai_options'][ $key ] === $value ) {
		return false;
	}
	$GLOBALS['kidia_ai_options'][ $key ] = $value;
	return true;
}
function delete_option( string $key ): bool { unset( $GLOBALS['kidia_ai_options'][ $key ] ); return true; }
function update_user_meta( int $user_id, string $key, $value ): bool {
	$GLOBALS['kidia_ai_user_meta'][ $user_id ][ $key ] = $value;
	return true;
}
function get_user_meta( int $user_id, string $key, bool $single = false ) {
	unset( $single );
	return $GLOBALS['kidia_ai_user_meta'][ $user_id ][ $key ] ?? '';
}
function delete_user_meta( int $user_id, string $key, $value = null ): bool {
	if ( null === $value || ( $GLOBALS['kidia_ai_user_meta'][ $user_id ][ $key ] ?? null ) === $value ) {
		unset( $GLOBALS['kidia_ai_user_meta'][ $user_id ][ $key ] );
	}
	return true;
}
function wp_date( string $format, int $timestamp ): string { return gmdate( $format, $timestamp ); }
function admin_url( string $path = '' ): string { return 'https://example.com/wp-admin/' . ltrim( $path, '/' ); }
function add_query_arg( array $args, string $url ): string { return $url . '?' . http_build_query( $args ); }
function wp_next_scheduled( string $hook, array $args = array() ) { unset( $hook, $args ); return false; }
function wp_schedule_single_event( int $timestamp, string $hook, array $args = array() ): bool {
	unset( $timestamp, $hook, $args );
	return true;
}

final class Kidia_Mobile_Analytics {
	public static function revenue_order_statuses(): array {
		return array( 'processing', 'completed', 'ready-for-shipping', 'delivered' );
	}
	public static function empty_commerce_snapshot(): array {
		return array(
			'orders'         => 0,
			'revenue'        => 0.0,
			'units'          => 0,
			'pairs'          => array(),
			'activity_hours' => array(),
		);
	}
	public static function store_commerce_snapshot( int $from, int $to, string $source, array $snapshot ): bool {
		unset( $from, $to, $source );
		$GLOBALS['kidia_ai_saved_snapshot'] = $snapshot;
		return true;
	}
}

final class Kidia_Mobile_AI_Offer_Engine {
	public static function clear_cache( int $from, int $to, string $source ): void {
		unset( $from, $to, $source );
	}
	public static function recommendations( int $from, int $to, string $source ): array {
		unset( $from, $to, $source );
		return array();
	}
}

class WC_Product {}

final class Kidia_Runtime_Order_Item {
	public function __construct( private int $product_id, private string $name ) {}
	public function get_product_id(): int { return $this->product_id; }
	public function get_variation_id(): int { return 0; }
	public function get_quantity(): int { return 1; }
	public function get_total(): float { return 10.0; }
	public function get_name(): string { return $this->name; }
}

class WC_Order {
	public function __construct( private int $id ) {}
	public function get_total(): float { return 10.0; }
	public function get_customer_id(): int { return $this->id; }
	public function get_billing_email(): string { return 'customer' . $this->id . '@example.com'; }
	public function get_items(): array {
		$product_id = 10 === $this->id % 2 ? 20 : 10;
		return array( new Kidia_Runtime_Order_Item( $product_id, 'Product ' . $product_id ) );
	}
	public function get_date_created() { return null; }
}

function wc_get_is_paid_statuses(): array { return array( 'processing', 'completed' ); }
function wc_get_order( int $order_id ) {
	unset( $order_id );
	++$GLOBALS['kidia_ai_order_reloads'];
	return null;
}
function wc_get_orders( array $args ) {
	$GLOBALS['kidia_ai_order_queries'][] = $args;
	if ( ! empty( $args['paginate'] ) ) {
		/* Reproduce an HPOS/CPT migration where the reported total is doubled. */
		return (object) array( 'total' => 8, 'orders' => array( new WC_Order( 1 ) ) );
	}
	$page = max( 1, (int) ( $args['page'] ?? 1 ) );
	if ( $page > 2 ) {
		return array();
	}
	$first = ( $page - 1 ) * 2 + 1;
	return array( new WC_Order( $first ), (object) array( 'legacy_row' => true ), new WC_Order( $first + 1 ) );
}

function kidia_ai_runtime_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-ai-analysis-job.php';

$binary_bitmap    = str_repeat( "\0", 8192 );
$binary_bitmap[0] = chr( 128 );
kidia_ai_runtime_assert(
	false === add_option( 'invalid-utf8-analysis-control', array( 'customer_bitmap' => $binary_bitmap ), '', 'no' ),
	'The runtime must reproduce MySQL refusing an analysis job with an invalid utf8mb4 bitmap.'
);

kidia_ai_runtime_assert(
	false === set_transient( 'oversized-analysis-control', str_repeat( 'x', 4096 ), HOUR_IN_SECONDS ),
	'The runtime must reproduce an object cache refusing a large analysis value.'
);

$started = Kidia_Mobile_AI_Analysis_Job::start( 1, 2000000000, 'all', 7, 'all_time' );
$job_id  = (string) $started['job_id'];
kidia_ai_runtime_assert( 0 === $started['processed'] && 0 === $started['revision'], 'A new job must start at revision zero.' );
kidia_ai_runtime_assert(
	array( 'processing', 'completed', 'ready-for-shipping', 'delivered' )
		=== ( $GLOBALS['kidia_ai_order_queries'][0]['status'] ?? array() ),
	'The count query must include paid orders moved into registered custom workflow statuses.'
);
kidia_ai_runtime_assert(
	false !== strpos( $GLOBALS['kidia_ai_product_query'], "product_variation" )
		&& false !== strpos( $GLOBALS['kidia_ai_product_query'], "wc_product_meta_lookup" ),
	'The inventory population must come from WooCommerce stock lookup rows and include variation SKUs.'
);
kidia_ai_runtime_assert(
	false !== strpos( (string) $started['result_url'], 'date_preset=all_time' )
		&& false === strpos( (string) $started['result_url'], 'date_from=' ),
	'An all-time job must reopen the exact all-time snapshot instead of a custom 1970 range.'
);

$job_key_method = new ReflectionMethod( Kidia_Mobile_AI_Analysis_Job::class, 'key' );
if ( PHP_VERSION_ID < 80100 ) {
	$job_key_method->setAccessible( true );
}
$job_key   = (string) $job_key_method->invoke( null, $job_id );
$saved_job = get_option( $job_key, false );
kidia_ai_runtime_assert( is_array( $saved_job ), 'A large job must be persisted outside the transient cache.' );
kidia_ai_runtime_assert(
	strlen( serialize( $saved_job ) ) > $GLOBALS['kidia_ai_cache_limit'],
	'The saved job must exceed the simulated object-cache item limit.'
);

$lock_key_method = new ReflectionMethod( Kidia_Mobile_AI_Analysis_Job::class, 'step_lock_key' );
if ( PHP_VERSION_ID < 80100 ) {
	$lock_key_method->setAccessible( true );
}
$lock_key = (string) $lock_key_method->invoke( null, $job_id );
add_option( $lock_key, array( 'started_at' => time(), 'token' => 'other-runner' ), '', 'no' );
$busy = Kidia_Mobile_AI_Analysis_Job::status( $job_id, 7, true );
kidia_ai_runtime_assert( true === $busy['busy'], 'A second runner must report contention instead of processing stale state.' );
kidia_ai_runtime_assert( 0 === $busy['processed'] && 0 === $busy['revision'], 'Lock contention must not mutate progress.' );
delete_option( $lock_key );

$first = Kidia_Mobile_AI_Analysis_Job::status( $job_id, 7, true );
kidia_ai_runtime_assert( 2 === $first['processed'] && 1 === $first['revision'], 'The first saved batch must advance monotonically.' );
$saved_after_first = get_option( $job_key, false );
kidia_ai_runtime_assert(
	is_array( $saved_after_first )
		&& 16384 === strlen( (string) ( $saved_after_first['customer_bitmap'] ?? '' ) )
		&& 1 === preg_match( '/\A[0-9a-f]+\z/D', (string) $saved_after_first['customer_bitmap'] )
		&& kidia_ai_database_accepts( $saved_after_first ),
	'The first processed batch must persist its customer bitmap as database-safe ASCII.'
);

add_option( $lock_key, array( 'started_at' => time(), 'token' => 'other-runner' ), '', 'no' );
$busy_after_first = Kidia_Mobile_AI_Analysis_Job::continue_in_background( $job_id, 7 );
kidia_ai_runtime_assert( true === $busy_after_first['busy'], 'Parking during an active batch must defer to the lock owner.' );
kidia_ai_runtime_assert( 2 === $busy_after_first['processed'], 'Moving to the background must return the latest saved progress, not overwrite it with zero.' );
delete_option( $lock_key );

$second = Kidia_Mobile_AI_Analysis_Job::status( $job_id, 7, true );
kidia_ai_runtime_assert( 4 === $second['orders_processed'], 'The second batch must continue after the first one.' );
kidia_ai_runtime_assert( 0 === $GLOBALS['kidia_ai_order_reloads'], 'Paginated order objects must be analysed directly without a second wc_get_order lookup.' );
kidia_ai_runtime_assert(
	2 === ( $GLOBALS['kidia_ai_options'][ $job_key ]['invalid_order_rows'] ?? 0 ),
	'Unreadable legacy CPT/HPOS rows must be measured and skipped without inflating or stopping the canonical order scan.'
);
kidia_ai_runtime_assert( $second['processed'] > $first['processed'] && 2 === $second['revision'], 'Saved progress and revision must never move backwards.' );

$completed = $second;
for ( $attempt = 0; $attempt < 20 && empty( $completed['done'] ); ++$attempt ) {
	$completed = Kidia_Mobile_AI_Analysis_Job::status( $job_id, 7, true );
}
kidia_ai_runtime_assert( true === $completed['done'], 'The oversized durable job must finish every order and product batch.' );
kidia_ai_runtime_assert( 100 === $completed['progress'], 'A fully persisted job must reach 100 percent.' );
kidia_ai_runtime_assert( 'complete' === $completed['phase'], 'The durable job must publish its final complete state.' );
kidia_ai_runtime_assert(
	false !== strpos( (string) $completed['result_url'], 'date_preset=all_time' )
		&& false === strpos( (string) $completed['result_url'], 'date_from=' ),
	'The completed result URL must preserve the original all-time snapshot key.'
);
kidia_ai_runtime_assert(
	4 === ( $GLOBALS['kidia_ai_saved_snapshot']['orders_scanned'] ?? 0 ),
	'Finalization must publish all scanned orders after the cache-size failure scenario.'
);
kidia_ai_runtime_assert(
	4 === ( $GLOBALS['kidia_ai_saved_snapshot']['orders_available'] ?? 0 ),
	'A completed snapshot must replace a duplicated HPOS/CPT estimate with the canonical order-object population.'
);
kidia_ai_runtime_assert(
	array() === array_filter(
		$GLOBALS['kidia_ai_order_queries'],
		static fn( array $query ): bool =>
			array( 'processing', 'completed', 'ready-for-shipping', 'delivered' )
				!== ( $query['status'] ?? array() )
	),
	'Every paginated order batch must use the same complete revenue-status list as the count query.'
);
kidia_ai_runtime_assert(
	4 === ( $GLOBALS['kidia_ai_saved_snapshot']['customers'] ?? 0 ),
	'ASCII bitmap persistence must preserve the distinct-customer estimate.'
);

echo "AI analysis runtime batches, database-safe persistence and atomic locking passed.\n";
