<?php
/**
 * Runtime contract for monotonic, non-restarting abandoned-cart imports.
 *
 * Run with: php kidia-mobile-cms/tests/abandoned-cart-import-runtime-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );
define( 'ARRAY_A', 'ARRAY_A' );
define( 'HOUR_IN_SECONDS', 3600 );
define( 'MINUTE_IN_SECONDS', 60 );
define( 'DAY_IN_SECONDS', 86400 );
define( 'WEEK_IN_SECONDS', 604800 );
define( 'MONTH_IN_SECONDS', 2592000 );
define( 'WC_VERSION', '10.1.0' );

$GLOBALS['kidia_options'] = array(
	'kidia_mobile_analytics_db_version' => '4',
);
$GLOBALS['kidia_scheduled_imports'] = 0;

class WC_Product {
	public function __construct( private int $id ) {}

	public function get_name(): string {
		return 'Product ' . $this->id;
	}

	public function get_price(): string {
		return '25';
	}
}

final class Kidia_Import_Test_WPDB {
	public string $prefix = 'wp_';
	public string $usermeta = 'wp_usermeta';
	public int $cart_writes = 0;

	/** @var list<string> */
	public array $cart_queries = array();

	/** @var list<array<string,mixed>> */
	public array $sessions = array();

	/** @var list<array<string,mixed>> */
	public array $persistent = array();

	public function prepare( string $query, ...$args ): string {
		$index = 0;
		return (string) preg_replace_callback(
			'/%[dfis]/',
			static function ( array $match ) use ( &$index, $args ): string {
				$value = $args[ $index++ ] ?? '';
				if ( '%d' === $match[0] ) {
					return (string) (int) $value;
				}
				if ( '%f' === $match[0] ) {
					return (string) (float) $value;
				}
				if ( '%i' === $match[0] ) {
					return '`' . str_replace( '`', '``', (string) $value ) . '`';
				}
				return "'" . str_replace( "'", "''", (string) $value ) . "'";
			},
			$query
		);
	}

	public function get_var( string $query ) {
		if ( str_contains( $query, 'SHOW TABLES LIKE' ) ) {
			return 'wp_woocommerce_sessions';
		}
		if ( str_contains( $query, 'COUNT(*) FROM wp_woocommerce_sessions' ) ) {
			return count( $this->sessions );
		}
		if ( str_contains( $query, 'COUNT(*) FROM wp_usermeta' ) ) {
			return count( $this->persistent );
		}
		return 0;
	}

	/** @return list<array<string,mixed>> */
	public function get_results( string $query, string $output ): array {
		unset( $output );
		preg_match( '/LIMIT\s+(\d+)/', $query, $limit_match );
		$limit = max( 1, (int) ( $limit_match[1] ?? 1 ) );
		if ( str_contains( $query, 'FROM wp_woocommerce_sessions' ) ) {
			preg_match( '/session_id\s*>\s*(\d+)/', $query, $cursor_match );
			$cursor = (int) ( $cursor_match[1] ?? 0 );
			return array_slice(
				array_values(
					array_filter(
						$this->sessions,
						static fn( array $row ): bool => (int) $row['session_id'] > $cursor
					)
				),
				0,
				$limit
			);
		}
		if ( str_contains( $query, 'FROM wp_usermeta' ) ) {
			preg_match( '/umeta_id\s*>\s*(\d+)/', $query, $cursor_match );
			$cursor = (int) ( $cursor_match[1] ?? 0 );
			return array_slice(
				array_values(
					array_filter(
						$this->persistent,
						static fn( array $row ): bool => (int) $row['umeta_id'] > $cursor
					)
				),
				0,
				$limit
			);
		}
		return array();
	}

	public function query( string $query ): int {
		if ( str_contains( $query, 'INSERT INTO `wp_kidia_mobile_carts`' ) || str_contains( $query, 'INSERT INTO wp_kidia_mobile_carts' ) ) {
			++$this->cart_writes;
			$this->cart_queries[] = $query;
		}
		return 1;
	}
}

function absint( $value ): int {
	return abs( (int) $value );
}

function add_option( string $name, $value, string $deprecated = '', bool $autoload = true ): bool {
	unset( $deprecated, $autoload );
	if ( array_key_exists( $name, $GLOBALS['kidia_options'] ) ) {
		return false;
	}
	$GLOBALS['kidia_options'][ $name ] = $value;
	return true;
}

function get_option( string $name, $default = false ) {
	return $GLOBALS['kidia_options'][ $name ] ?? $default;
}

function update_option( string $name, $value, bool $autoload = true ): bool {
	unset( $autoload );
	$GLOBALS['kidia_options'][ $name ] = $value;
	return true;
}

function delete_option( string $name ): bool {
	unset( $GLOBALS['kidia_options'][ $name ] );
	return true;
}

function sanitize_text_field( $value ): string {
	return trim( (string) $value );
}

function sanitize_email( $value ): string {
	return filter_var( (string) $value, FILTER_SANITIZE_EMAIL ) ?: '';
}

function sanitize_key( $value ): string {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: '';
}

function wp_json_encode( $value ): string {
	return (string) json_encode( $value );
}

function wp_unslash( $value ) {
	return $value;
}

function maybe_unserialize( $value ) {
	if ( ! is_string( $value ) ) {
		return $value;
	}
	$decoded = @unserialize( $value, array( 'allowed_classes' => false ) );
	return false === $decoded && 'b:0;' !== $value ? $value : $decoded;
}

function apply_filters( string $hook, $value ) {
	unset( $hook );
	return $value;
}

function get_current_blog_id(): int {
	return 1;
}

function get_userdata( int $user_id ) {
	unset( $user_id );
	return false;
}

function get_user_meta( int $user_id, string $key, bool $single = false ) {
	unset( $user_id, $key, $single );
	return time();
}

function current_time( string $type, bool $gmt = false ): string {
	unset( $type, $gmt );
	return gmdate( 'Y-m-d H:i:s' );
}

function get_woocommerce_currency(): string {
	return 'EGP';
}

function wc_get_product( int $product_id ): WC_Product {
	return new WC_Product( $product_id );
}

function as_has_scheduled_action(): bool {
	return false;
}

function as_enqueue_async_action(): int {
	++$GLOBALS['kidia_scheduled_imports'];
	return $GLOBALS['kidia_scheduled_imports'];
}

function kidia_import_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$wpdb = new Kidia_Import_Test_WPDB();
for ( $session_id = 1; $session_id <= 5; ++$session_id ) {
	$cart = array(
		'item-' . $session_id => array(
			'product_id' => $session_id,
			'quantity'   => 1,
			'line_total' => 25,
		),
	);
	$wpdb->sessions[] = array(
		'session_id'     => $session_id,
		'session_key'    => 5 === $session_id ? '205' : 'guest-' . $session_id,
		'session_value'  => serialize(
			array(
				'cart'     => serialize( $cart ),
				'customer' => serialize( array( 'email' => 'guest' . $session_id . '@example.com' ) ),
			)
		),
		'session_expiry' => time() + ( 5 === $session_id ? WEEK_IN_SECONDS : 2 * DAY_IN_SECONDS ),
	);
}
for ( $meta_id = 1; $meta_id <= 2; ++$meta_id ) {
	$wpdb->persistent[] = array(
		'umeta_id'  => $meta_id,
		'user_id'   => 100 + $meta_id,
		'meta_value' => serialize(
			array(
				'cart' => array(
					'persistent-' . $meta_id => array(
						'product_id' => 100 + $meta_id,
						'quantity'   => 1,
						'line_total' => 25,
					),
				),
			)
		),
	);
}
$GLOBALS['wpdb'] = $wpdb;

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-analytics.php';

kidia_import_assert( 2 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'The first request must import exactly one batch.' );
$first = Kidia_Mobile_Analytics::website_session_import_status();
kidia_import_assert( 2 === $first['processed'] && 2 === $first['imported'], 'Progress must persist after the first batch.' );

$GLOBALS['kidia_options']['kidia_mobile_website_cart_import_lock_v4'] = time() + 120;
kidia_import_assert( 0 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'A concurrent request must not duplicate the active batch.' );
$locked = Kidia_Mobile_Analytics::website_session_import_status();
kidia_import_assert( 2 === $locked['processed'] && 2 === $wpdb->cart_writes, 'Lock contention must leave progress and writes unchanged.' );

$GLOBALS['kidia_options']['kidia_mobile_website_cart_import_lock_v4'] = time() - 1;
kidia_import_assert( 2 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'An expired lock must recover and continue from the saved cursor.' );
kidia_import_assert( 2 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'The third batch must cross from sessions into persistent carts.' );
kidia_import_assert( 1 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'The final batch must import the remaining persistent cart.' );

$complete = Kidia_Mobile_Analytics::website_session_import_status();
kidia_import_assert( 'complete' === $complete['phase'], 'The import must reach a durable complete state.' );
kidia_import_assert( 7 === $complete['processed'] && 7 === $complete['imported'], 'Every retained cart must be processed and imported exactly once.' );
kidia_import_assert( 7 === $wpdb->cart_writes, 'No cursor range may be written twice.' );
kidia_import_assert(
	array_reduce(
		$wpdb->cart_queries,
		static fn( bool $valid, string $query ): bool => $valid && str_contains( $query, gmdate( 'Y-m-d' ) ),
		true
	),
	'Guest and registered WooCommerce sessions must resolve to current activity dates instead of future dates.'
);
$started_at = $complete['started_at'];

kidia_import_assert( 0 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'Reading a completed import must never start it again.' );
$after_complete = Kidia_Mobile_Analytics::website_session_import_status();
kidia_import_assert( 'complete' === $after_complete['phase'], 'Completed progress must remain complete.' );
kidia_import_assert( 7 === $after_complete['processed'] && 7 === $after_complete['imported'], 'Completed counters must never reset to zero.' );
kidia_import_assert( $started_at === $after_complete['started_at'], 'A completed import must retain its original run identity.' );
kidia_import_assert( 7 === $wpdb->cart_writes, 'Refreshing the report after completion must not re-import carts.' );

/* WooCommerce edits session_value in place without allocating a new session_id. */
$changed_cart = array(
	'changed-existing-session' => array(
		'product_id' => 999,
		'quantity'   => 3,
		'line_total' => 75,
	),
);
$wpdb->sessions[0]['session_value'] = serialize(
	array(
		'cart'     => serialize( $changed_cart ),
		'customer' => serialize( array( 'email' => 'changed@example.com' ) ),
	)
);
$update = ( new Kidia_Mobile_Analytics() )->ensure_website_session_import( true );
kidia_import_assert( 'running' === $update['phase'] && 'update' === $update['mode'], 'Update must start a distinct comparison scan.' );
kidia_import_assert( 0 === $update['session_cursor'] && 0 === $update['persistent_cursor'], 'Update must recheck existing source ids instead of starting after the previous cursors.' );
kidia_import_assert( 7 === $update['total'] && 0 === $update['processed'], 'Previously displayed carts must stay stored while every retained source row is scheduled for comparison.' );

kidia_import_assert( 2 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'Update must revisit the first existing session-id batch.' );
kidia_import_assert( 2 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'Update must continue across all existing session ids.' );
kidia_import_assert( 2 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'Update must cross into persistent carts after rechecking sessions.' );
kidia_import_assert( 1 === Kidia_Mobile_Analytics::sync_website_sessions( 2 ), 'Update must finish the full retained-source comparison.' );

$updated = Kidia_Mobile_Analytics::website_session_import_status();
kidia_import_assert( 'complete' === $updated['phase'] && 7 === $updated['processed'], 'Update must complete only after every retained source row was checked.' );
kidia_import_assert( 14 === $wpdb->cart_writes, 'The comparison scan must revisit existing ids exactly once without duplicating a cursor range.' );
kidia_import_assert(
	array_reduce(
		$wpdb->cart_queries,
		static fn( bool $found, string $query ): bool => $found || str_contains( $query, '"product_id":999' ),
		false
	),
	'An in-place WooCommerce session change must reach the stored abandoned-cart row during Update.'
);

echo "Abandoned cart import runtime batches passed.\n";
