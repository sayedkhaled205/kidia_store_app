<?php
/** Run in a fresh staging `wp eval-file` process. No fixture is committed. */
if ( ! defined( 'WP_CLI' ) || ! WP_CLI || wp_parse_url( home_url(), PHP_URL_HOST ) !== 'staging.kidiastore.com' ) throw new RuntimeException( 'Staging WP-CLI only.' );
if ( ! class_exists( 'MobiShop_Discount_Channel' ) || ! method_exists( 'MobiShop_Discount_Channel', 'lock_rule' ) ) throw new RuntimeException( 'Install the lock candidate first.' );

// Prevent a failed second connection from displaying database diagnostics.
final class Discount_Lock_QA_Connection extends wpdb {
    public function db_connect( $allow_bail = true ) {
        $this->hide_errors();
        $this->suppress_errors( true );
        return parent::db_connect( false );
    }
}

global $wpdb;
$checks = 0; $fixture = 0; $name = ''; $other = null; $transaction = false;
$cleanup_ok = true;
$assert = static function( $ok, $message ) use ( &$checks ): void {
    ++$checks;
    if ( ! $ok ) throw new RuntimeException( $message );
};
$table = $wpdb->prefix . 'wdr_rules';
$previous_suppression = $wpdb->suppress_errors( true );
try {
    $assert( has_action( 'advanced_woo_discount_rules_after_save_rule', array( 'MobiShop_Discount_Channel', 'unlock_rule' ) ) !== false, 'After-save release hook must be registered.' );
    $engine = $wpdb->get_var( $wpdb->prepare( 'SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s', $table ) );
    $assert( strtoupper( (string) $engine ) === 'INNODB', 'Fixture table must support rollback.' );

    $other = new Discount_Lock_QA_Connection( DB_USER, DB_PASSWORD, DB_NAME, DB_HOST );
    $first_connection = (int) $wpdb->get_var( 'SELECT CONNECTION_ID()' );
    $second_connection = (int) $other->get_var( 'SELECT CONNECTION_ID()' );
    $assert( $first_connection > 0 && $second_connection > 0 && $first_connection !== $second_connection, 'Two independent MySQL connections are required.' );

    $assert( $wpdb->query( 'START TRANSACTION' ) !== false, 'Fixture transaction must start.' );
    $transaction = true;
    $inserted = $wpdb->insert( $table, array(
        'title' => 'WooMobile isolated lock fixture ' . wp_generate_uuid4(),
        'enabled' => 0,
        'deleted' => 1,
        'filters' => '[]',
        'bulk_adjustments' => '[]',
        'set_adjustments' => '[]',
        'additional' => wp_json_encode( array( 'mobishop_channel' => 'mobile' ) ),
    ) );
    $fixture = $inserted === 1 ? (int) $wpdb->insert_id : 0;
    $assert( $inserted === 1 && $fixture > 0, 'An isolated fixture rule must be inserted.' );

    $incoming = array( 'additional' => wp_json_encode( array( 'condition_relationship' => 'or' ) ) );
    $columns = MobiShop_Discount_Channel::preserve_channel( $incoming, $fixture );
    $assert( MobiShop_Discount_Channel::scope( $columns ) === 'mobile', 'Preserve must retain the fixture channel.' );
    $assert( json_decode( $columns['additional'], true )['condition_relationship'] === 'or', 'Preserve must keep native editor changes.' );

    // Inspect the production name so this test does not duplicate its derivation.
    $lock_name = new ReflectionMethod( 'MobiShop_Discount_Channel', 'lock_name' );
    $lock_name->setAccessible( true );
    $name = $lock_name->invoke( null, $fixture );
    $assert( (int) $other->get_var( $other->prepare( 'SELECT IS_USED_LOCK(%s)', $name ) ) === $first_connection, 'Native connection must own the fixture lock.' );
    $assert( (string) $other->get_var( $other->prepare( 'SELECT GET_LOCK(%s, 0)', $name ) ) === '0', 'Second connection must be excluded before the native write.' );

    // The same SQL phase used by FlyCart, restricted to this uncommitted fixture.
    $assert( $wpdb->update( $table, $columns, array( 'id' => $fixture ) ) === 1, 'Fixture native write must succeed.' );
    $assert( (string) $other->get_var( $other->prepare( 'SELECT GET_LOCK(%s, 0)', $name ) ) === '0', 'Native write must retain the lock until the after-save hook.' );
    do_action( 'advanced_woo_discount_rules_after_save_rule', $fixture, array( 'rule_id' => $fixture ), $columns, array( 'condition_relationship' => 'or' ) );
    $assert( (string) $other->get_var( $other->prepare( 'SELECT GET_LOCK(%s, 0)', $name ) ) === '1', 'Second connection must acquire after the real after-save hook.' );
    $assert( (string) $other->get_var( $other->prepare( 'SELECT RELEASE_LOCK(%s)', $name ) ) === '1', 'Second connection must release its lock.' );
} finally {
    // Attempt every cleanup even if an earlier cleanup step fails. Never print
    // SQL errors, connection details, fixture contents or credential constants.
    try {
        if ( $fixture > 0 ) MobiShop_Discount_Channel::unlock_rule( $fixture );
    } catch ( Throwable $error ) { $cleanup_ok = false; }
    try {
        if ( $other && $name !== '' ) $other->get_var( $other->prepare( 'SELECT RELEASE_LOCK(%s)', $name ) );
    } catch ( Throwable $error ) { $cleanup_ok = false; }
    try {
        if ( $transaction && $wpdb->query( 'ROLLBACK' ) === false ) $cleanup_ok = false;
        if ( $fixture > 0 ) {
            $remaining = $wpdb->get_var( $wpdb->prepare( "SELECT COUNT(*) FROM {$table} WHERE id=%d", $fixture ) );
            if ( (string) $remaining !== '0' ) $cleanup_ok = false;
        }
        if ( $name !== '' && (string) $wpdb->get_var( $wpdb->prepare( 'SELECT IS_FREE_LOCK(%s)', $name ) ) !== '1' ) $cleanup_ok = false;
    } catch ( Throwable $error ) { $cleanup_ok = false; }
    try {
        if ( $other && ! $other->close() ) $cleanup_ok = false;
    } catch ( Throwable $error ) { $cleanup_ok = false; }
    $wpdb->suppress_errors( $previous_suppression );
    $assert( $cleanup_ok, 'Fixture rollback and lock cleanup must complete.' );
}
echo 'DISCOUNT_LOCKS_QA ' . wp_json_encode( array( 'checks' => $checks, 'passed' => true, 'connections' => 2, 'fixture_rules_remaining' => 0 ) ) . PHP_EOL;
