<?php
/** Deterministic two-connection model; no WordPress install or live data. */
define( 'ABSPATH', __DIR__ );
define( 'ARRAY_A', 'ARRAY_A' );
define( 'DB_NAME', 'discount_channel_fixture' );
$hooks = array(); $checks = 0;
function add_filter( $name, $callback, $priority, $args ) { $GLOBALS['hooks'][ $name ] = $callback; }
function add_action( $name, $callback, $priority, $args ) { add_filter( $name, $callback, $priority, $args ); }
function wp_json_encode( $value ) { return json_encode( $value ); }
function check( $ok, $message ) { $GLOBALS['checks']++; if ( ! $ok ) throw new RuntimeException( $message ); }
function expect_failure( callable $callback, string $message ): void {
    try { $callback(); } catch ( RuntimeException $error ) { check( true, $message ); return; }
    check( false, $message );
}

final class DiscountLockDatabase {
    public array $owners = array();
    public array $rows = array( 7 => array( 'additional' => '{"mobishop_channel":"mobile"}' ) );
}
final class DiscountLockConnection {
    public string $prefix = 'wp_';
    public array $queries = array();
    public bool $fail_read = false;
    public bool $fail_lock = false;
    public ?string $last_lock = null;
    public function __construct( public DiscountLockDatabase $database, public string $owner ) {}
    public function prepare( $sql, ...$args ): string { return vsprintf( str_replace( '%s', "'%s'", $sql ), $args ); }
    public function get_var( string $sql ) {
        $this->queries[] = $sql;
        if ( preg_match( "/^SELECT GET_LOCK\('([a-z0-9_]+)', [05]\)$/", $sql, $match ) ) {
            $this->last_lock = $match[1];
            if ( $this->fail_lock ) return null;
            if ( isset( $this->database->owners[ $match[1] ] ) && $this->database->owners[ $match[1] ] !== $this->owner ) return 0;
            $this->database->owners[ $match[1] ] = $this->owner;
            return 1;
        }
        if ( preg_match( "/^SELECT RELEASE_LOCK\('([a-z0-9_]+)'\)$/", $sql, $match ) ) {
            if ( ( $this->database->owners[ $match[1] ] ?? null ) !== $this->owner ) return 0;
            unset( $this->database->owners[ $match[1] ] );
            return 1;
        }
        throw new LogicException( 'Unexpected query: ' . $sql );
    }
    public function get_row( string $sql, $format ) {
        $this->queries[] = $sql;
        if ( ( $this->database->owners[ $this->last_lock ] ?? null ) !== $this->owner ) throw new RuntimeException( 'Channel read happened without the shared lock.' );
        if ( $this->fail_read ) throw new RuntimeException( 'Simulated database read failure.' );
        if ( ! preg_match( '/ WHERE id=([0-9]+)$/', $sql, $match ) ) throw new LogicException( 'Unexpected rule read.' );
        return $this->database->rows[ (int) $match[1] ] ?? null;
    }
    public function acquire( string $name ): bool { return $this->get_var( $this->prepare( 'SELECT GET_LOCK(%s, 0)', $name ) ) === 1; }
    public function release( string $name ): void { $this->get_var( $this->prepare( 'SELECT RELEASE_LOCK(%s)', $name ) ); }
}

// An optional source path also lets this regression test exercise its baseline.
require $argv[1] ?? __DIR__ . '/../source/includes/class-mobishop-discount-channel.php';
MobiShop_Discount_Channel::register();
$database = new DiscountLockDatabase();
$wpdb = new DiscountLockConnection( $database, 'native-editor' );
$builder = new DiscountLockConnection( $database, 'central-builder' );
$incoming = array( 'additional' => '{"condition_relationship":"or"}', 'title' => 'Edited title' );
$before = $hooks['advanced_woo_discount_rules_before_save_rule_column'];

// The formerly failing order: native read -> central change -> native write.
$columns = $before( $incoming, 7 );
$name = $wpdb->last_lock;
check( is_string( $name ) && strlen( $name ) <= 64, 'MySQL lock name is bounded.' );
check( ! $builder->acquire( $name ), 'Central update cannot enter between the native read and write.' );
$database->rows[7] = $columns; // FlyCart DBTable::saveRule.
$after = $hooks['advanced_woo_discount_rules_after_save_rule'];
$after( 7 ); // Rule::save dispatches this only after DBTable::saveRule.
check( $builder->acquire( $name ), 'Central writer can continue after native save.' );
$database->rows[7]['additional'] = '{"mobishop_channel":"website"}';
$builder->release( $name );
$columns = $before( $incoming, 7 );
check( MobiShop_Discount_Channel::scope( $columns ) === 'website', 'A later native save preserves the latest central channel.' );
check( json_decode( $columns['additional'], true )['condition_relationship'] === 'or' && $columns['title'] === 'Edited title', 'Native editor fields are preserved.' );
$database->rows[7] = $columns;
$after( 7 );

// Reverse order: a central transaction already owns the lock.
check( $builder->acquire( $name ), 'Central acquires before its transaction.' );
$read_count = count( array_filter( $wpdb->queries, static fn( $sql ) => str_starts_with( $sql, 'SELECT additional' ) ) );
expect_failure( static fn() => $before( $incoming, 7 ), 'Native save fails closed when lock acquisition times out.' );
check( count( array_filter( $wpdb->queries, static fn( $sql ) => str_starts_with( $sql, 'SELECT additional' ) ) ) === $read_count, 'A timed-out save does not read stale data.' );
check( $database->owners[ $name ] === 'central-builder', 'Failure never releases another connection lock.' );
$database->rows[7]['additional'] = '{"mobishop_channel":"mobile"}';
$builder->release( $name );
$columns = $before( $incoming, 7 );
check( MobiShop_Discount_Channel::scope( $columns ) === 'mobile', 'Retry observes the completed central update.' );
$after( 7 );

// A nested FlyCart save must not release an enclosing central operation lock.
MobiShop_Discount_Channel::lock_rule( 7 );
$lock_calls = count( $wpdb->queries );
$columns = $before( $incoming, 7 );
check( count( $wpdb->queries ) === $lock_calls + 1, 'Nested acquisition does not reacquire the database lock.' );
$after( 7 );
check( ! $builder->acquire( $name ), 'After-save releases only the nested acquisition.' );
MobiShop_Discount_Channel::unlock_rule( 7 );
check( $builder->acquire( $name ), 'Outer release makes the rule available.' );
$builder->release( $name );

// Native query failures must not turn the hidden channel into its legacy default.
$wpdb->fail_read = true;
expect_failure( static fn() => $before( $incoming, 7 ), 'Read failure aborts saving.' );
check( ! isset( $database->owners[ $name ] ), 'Read exception releases the lock.' );
$wpdb->fail_read = false;
expect_failure( static fn() => $before( $incoming, 99 ), 'Missing rule aborts saving.' );
check( count( $database->owners ) === 0, 'Missing rule releases the lock.' );
$wpdb->fail_lock = true;
expect_failure( static fn() => $before( $incoming, 7 ), 'Database lock errors abort saving.' );
check( count( $database->owners ) === 0, 'Failed acquisition records no owned lock.' );
$wpdb->fail_lock = false;

$database->rows[7]['additional'] = null;
$columns = $before( $incoming, 7 );
check( MobiShop_Discount_Channel::scope( $columns ) === 'all', 'Legacy rules still default to both channels.' );
$after( 7 );
$query_count = count( $wpdb->queries );
check( $before( $incoming, 0 ) === $incoming, 'Creation is unchanged.' );
$after( 123 );
check( count( $wpdb->queries ) === $query_count, 'Unpaired create hook releases no unrelated lock.' );

// Separate rule/site names do not serialize unrelated edits; abandoned saves clean up.
MobiShop_Discount_Channel::lock_rule( 7 );
MobiShop_Discount_Channel::lock_rule( 8 );
$wpdb->prefix = 'wp_second_';
MobiShop_Discount_Channel::lock_rule( 7 );
check( count( $database->owners ) === 3, 'Locks are scoped by site and rule.' );
MobiShop_Discount_Channel::release_all_locks();
check( count( $database->owners ) === 0, 'Shutdown cleanup releases all pending native saves.' );
$wpdb->prefix = 'wp_';
MobiShop_Discount_Channel::lock_rule( 7 );
check( $wpdb->last_lock === $name && $database->owners[ $name ] === 'native-editor', 'Cleanup clears local ownership so the next acquisition reaches MySQL.' );
MobiShop_Discount_Channel::unlock_rule( 7 );
MobiShop_Discount_Channel::unlock_rule( 7 );
check( count( $database->owners ) === 0, 'An extra release is harmless.' );

echo "PASS: $checks discount concurrency checks (deterministic two-connection model)\n";
