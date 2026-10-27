<?php
/**
 * WP-CLI, staging only. One case per process avoids FlyCart request-cache leakage.
 * Usage: wp eval-file <file> <free_shipping|exclusive|exclusive_shipping> <website|mobile> <all|website|mobile>
 * Runs the installed FlyCart calculator with in-memory rules and rolled-back products.
 * Shipping coverage is its real eligibility calculator, not a carrier/Pro rate integration test.
 */
if ( ! defined( 'WP_CLI' ) || ! WP_CLI || wp_parse_url( home_url(), PHP_URL_HOST ) !== 'staging.kidiastore.com' ) {
    throw new RuntimeException( 'Staging WP-CLI only.' );
}
if ( ! class_exists( 'MobiShop_Discount_Channel' ) || ! class_exists( '\Wdr\App\Controllers\DiscountCalculator' ) ) {
    throw new RuntimeException( 'Install the candidate connector and FlyCart first.' );
}
if ( ! is_callable( array( '\Wdr\App\Controllers\DiscountCalculator', 'getFreeshippingMethod' ) ) ) {
    throw new RuntimeException( 'Installed FlyCart lacks the reviewed getFreeshippingMethod calculator; inspect its shipping implementation before extending this test.' );
}
$case = $args[0] ?? 'free_shipping';
$channel = $args[1] ?? 'website';
$scope = $args[2] ?? 'all';
if ( ! in_array( $case, array( 'free_shipping', 'exclusive', 'exclusive_shipping' ), true ) ||
    ! in_array( $channel, array( 'website', 'mobile' ), true ) ||
    ! in_array( $scope, array( 'all', 'website', 'mobile' ), true ) ) {
    throw new InvalidArgumentException( 'Invalid case, channel or scope.' );
}
$eligible = $scope === 'all' || $scope === $channel;
$is_exclusive = $case !== 'free_shipping';
$is_shipping = $case !== 'exclusive';
$created = array();
$checks = array();
$special_id = -107;
$ordinary_id = -108;

global $wpdb;
foreach ( array( $wpdb->posts, $wpdb->postmeta ) as $table ) {
    $engine = $wpdb->get_var( $wpdb->prepare( 'SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s', $table ) );
    if ( strtoupper( (string) $engine ) !== 'INNODB' ) {
        throw new RuntimeException( 'InnoDB posts and postmeta are required for fixture rollback.' );
    }
}

// No account/session credentials, customer records, shipping providers or mail are used.
wp_set_current_user( 0 );
$_COOKIE = array();
unset( $_GET['rest_route'], $_SERVER['HTTP_X_MOBISHOP_CHANNEL'], $_SERVER['HTTP_X_MOBISHOP_SESSION'] );
$_SERVER['REQUEST_URI'] = '/wp-json/wc/store/v1/cart';
if ( $channel === 'mobile' ) $_SERVER['HTTP_X_MOBISHOP_CHANNEL'] = 'mobile';
if ( MobiShop_Discount_Channel::current() !== $channel ) {
    throw new RuntimeException( 'Request channel was not established.' );
}
$no_external_calls = static function () { throw new RuntimeException( 'An external HTTP or mail call was attempted by the fixture.' ); };
add_filter( 'pre_http_request', $no_external_calls, PHP_INT_MAX );
add_filter( 'pre_wp_mail', $no_external_calls, PHP_INT_MAX );
// Keep the physical cart, while preventing carrier/zone rate calculation.
add_filter( 'woocommerce_cart_ready_to_calc_shipping', '__return_false', PHP_INT_MAX );
if ( ! WC()->session ) WC()->initialize_session();
remove_action( 'shutdown', array( WC()->session, 'save_data' ), 20 );
WC()->customer = new WC_Customer( 0, true );
WC()->cart = new WC_Cart();

if ( $wpdb->query( 'START TRANSACTION' ) === false ) {
    throw new RuntimeException( 'Cannot begin fixture transaction.' );
}
try {
    $now = current_time( 'mysql' );
    $inserted = $wpdb->insert( $wpdb->posts, array(
        'post_author' => 0, 'post_date' => $now, 'post_date_gmt' => gmdate( 'Y-m-d H:i:s' ),
        'post_modified' => $now, 'post_modified_gmt' => gmdate( 'Y-m-d H:i:s' ),
        'post_title' => 'WooMobile special discount QA fixture',
        'post_name' => 'woomobile-special-discount-qa-' . wp_generate_uuid4(),
        'post_status' => 'publish', 'post_type' => 'product', 'post_content' => '', 'post_excerpt' => '',
        'comment_status' => 'closed', 'ping_status' => 'closed', 'to_ping' => '', 'pinged' => '', 'post_content_filtered' => '',
    ) );
    $product_id = (int) $wpdb->insert_id;
    if ( $inserted !== 1 || $product_id <= 0 ) throw new RuntimeException( 'Fixture product creation failed.' );
    $created[] = $product_id;
    foreach ( array( '_price' => '100', '_regular_price' => '100', '_virtual' => 'no', '_stock_status' => 'instock', '_manage_stock' => 'no', '_tax_status' => 'none' ) as $key => $value ) {
        if ( $wpdb->insert( $wpdb->postmeta, array( 'post_id' => $product_id, 'meta_key' => $key, 'meta_value' => $value ) ) !== 1 ) {
            throw new RuntimeException( 'Fixture product metadata creation failed.' );
        }
    }
    clean_post_cache( $product_id );

    $manager = \Wdr\App\Router::$manage_discount;
    if ( ! $manager instanceof \Wdr\App\Controllers\ManageDiscount ) throw new RuntimeException( 'FlyCart manager is not initialized.' );
    $make_rule = static function ( $id, $type, $rule_scope, $exclusive, $percentage ) use ( $manager, $product_id ) {
        $rule = (object) array(
            'id' => $id, 'enabled' => 1, 'deleted' => 0, 'exclusive' => (int) $exclusive,
            'priority' => $exclusive ? 1 : 2, 'title' => 'WooMobile isolated special discount test',
            'apply_to' => '', 'discount_type' => $type,
            'filters' => wp_json_encode( array( '1' => array( 'type' => 'products', 'method' => 'in_list', 'value' => array( $product_id ) ) ) ),
            'conditions' => '[]', 'additional' => wp_json_encode( array( 'mobishop_channel' => $rule_scope ) ),
            'date_from' => null, 'date_to' => null, 'usage_limits' => 0, 'used_limits' => 0,
            'product_adjustments' => $type === 'wdr_simple_discount'
                ? wp_json_encode( array( 'type' => 'percentage', 'value' => (string) $percentage, 'apply_as_cart_rule' => '0' ) ) : '[]',
            'cart_adjustments' => '[]', 'bulk_adjustments' => '[]', 'set_adjustments' => '[]',
            'buy_x_get_x_adjustments' => '[]', 'buy_x_get_y_adjustments' => '[]', 'other_discounts' => '[]',
        );
        return new \Wdr\App\Helpers\Rule( $rule, $manager->getAvailableConditions() );
    };
    $rules = array( $special_id => $make_rule( $special_id, $is_shipping ? 'wdr_free_shipping' : 'wdr_simple_discount', $scope, $is_exclusive, 20 ) );
    if ( $is_exclusive ) $rules[$ordinary_id] = $make_rule( $ordinary_id, 'wdr_simple_discount', 'all', false, 10 );
    // No real rule is inserted, activated or changed.
    \Wdr\App\Controllers\ManageDiscount::$available_rules = $rules;
    \Wdr\App\Controllers\ManageDiscount::$calculator = new \Wdr\App\Controllers\DiscountCalculator( $rules );
    \Wdr\App\Controllers\DiscountCalculator::$filtered_exclusive_rule = false;
    \Wdr\App\Controllers\DiscountCalculator::$applied_rules = array();
    \Wdr\App\Controllers\DiscountCalculator::$total_discounts = array();
    \Wdr\App\Controllers\DiscountCalculator::$cart_adjustments = array();
    \Wdr\App\Controllers\DiscountCalculator::$price_discount_apply_as_cart_discount = array();
    $cart_key = WC()->cart->add_to_cart( $product_id, 1 );
    if ( ! $cart_key ) throw new RuntimeException( 'Could not add fixture to cart.' );
    if ( $is_shipping && ! WC()->cart->needs_shipping() ) throw new RuntimeException( 'The physical fixture must need shipping.' );

    $expected_total = ! $is_exclusive ? 100 : ( $eligible ? ( $is_shipping ? 100 : 80 ) : 90 );
    for ( $repeat = 0; $repeat < 3; $repeat++ ) {
        WC()->cart->calculate_totals();
        $total = (float) WC()->cart->get_total( 'edit' );
        if ( abs( $total - $expected_total ) > 0.005 ) {
            throw new RuntimeException( "Cart mismatch: case=$case channel=$channel scope=$scope repeat=$repeat actual=$total expected=$expected_total" );
        }
        // This is the installed calculator consumed by FlyCart shipping, not a mocked eligibility filter.
        $shipping = \Wdr\App\Controllers\DiscountCalculator::getFreeshippingMethod();
        $expected_shipping = $is_shipping && $eligible ? array( 'free_shipping' => 1 ) : array();
        if ( $shipping !== $expected_shipping ) throw new RuntimeException( 'Free-shipping calculator mismatch: ' . wp_json_encode( $shipping ) );
        $remaining_rules = array_keys( \Wdr\App\Controllers\DiscountCalculator::$rules );
        $applied_rules = array_keys( \Wdr\App\Controllers\DiscountCalculator::$applied_rules );
        if ( $is_exclusive && $eligible && $remaining_rules !== array( $special_id ) ) {
            throw new RuntimeException( 'An eligible exclusive rule did not suppress ordinary rules.' );
        }
        if ( $is_exclusive && ! $eligible && ( ! in_array( $ordinary_id, $remaining_rules, true ) || ! in_array( $ordinary_id, $applied_rules, true ) ) ) {
            throw new RuntimeException( 'A wrong-channel exclusive rule blocked the eligible ordinary rule.' );
        }
        if ( ! $eligible && in_array( $special_id, $applied_rules, true ) ) {
            throw new RuntimeException( 'A wrong-channel special rule was recorded as applied.' );
        }
        if ( $is_shipping && $eligible && ! in_array( $special_id, $applied_rules, true ) ) {
            throw new RuntimeException( 'Allowed free shipping was not recorded against the physical cart.' );
        }
        $checks[] = array( 'repeat' => $repeat, 'cart_total' => $total, 'free_shipping' => ! empty( $shipping ), 'retained_rules' => $remaining_rules, 'applied_rules' => $applied_rules );
    }
} finally {
    remove_action( 'shutdown', array( WC()->session, 'save_data' ), 20 );
    WC()->cart->cart_contents = array();
    if ( $wpdb->query( 'ROLLBACK' ) === false ) throw new RuntimeException( 'Fixture rollback failed.' );
    foreach ( $created as $id ) { clean_post_cache( $id ); wp_cache_delete( $id, 'post_meta' ); }
    $ids = implode( ',', array_map( 'intval', $created ?: array( 0 ) ) );
    $posts_remaining = $wpdb->get_var( 'SELECT COUNT(*) FROM ' . $wpdb->posts . ' WHERE ID IN (' . $ids . ')' );
    $meta_remaining = $wpdb->get_var( 'SELECT COUNT(*) FROM ' . $wpdb->postmeta . ' WHERE post_id IN (' . $ids . ')' );
    if ( $posts_remaining === null || $meta_remaining === null || (int) $posts_remaining !== 0 || (int) $meta_remaining !== 0 ) {
        throw new RuntimeException( 'Could not verify zero fixture posts and metadata after rollback.' );
    }
}
print( 'DISCOUNT_SPECIAL_QA ' . wp_json_encode( array(
    'case' => $case, 'channel' => $channel, 'scope' => $scope, 'checks' => $checks,
    'shipping_coverage' => 'installed FlyCart getFreeshippingMethod calculator',
    'fixture_posts_remaining' => 0, 'fixture_meta_remaining' => 0, 'passed' => true,
) ) . "\n" );
