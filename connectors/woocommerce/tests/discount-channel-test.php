<?php
define( 'ABSPATH', __DIR__ );
$hooks = array(); $checks = 0;
function add_filter( $name, $callback, $priority, $args ) { $GLOBALS['hooks'][$name] = $callback; }
function check( $ok, $message ) { $GLOBALS['checks']++; if ( ! $ok ) throw new RuntimeException( $message ); }
require __DIR__ . '/../source/includes/class-mobishop-discount-channel.php';
MobiShop_Discount_Channel::register();
$rule = static fn( $scope ) => (object) array( 'additional' => json_encode( array( 'mobishop_channel' => $scope, 'condition_relationship' => 'and' ) ) );
foreach ( array( 'website', 'mobile' ) as $channel ) {
    $_SERVER = array( 'REQUEST_URI' => '/shop/wp-json/wc/store/v1/cart' ); $_GET = array();
    if ( $channel === 'mobile' ) $_SERVER['HTTP_X_MOBISHOP_CHANNEL'] = 'mobile';
    foreach ( array( 'all', 'website', 'mobile' ) as $scope ) {
        $allowed = $scope === 'all' || $scope === $channel;
        check( MobiShop_Discount_Channel::allowed( $rule( $scope ) ) === $allowed, 'channel matrix' );
        check( $hooks['advanced_woo_discount_rules_has_rule_conditions']( false, $rule( $scope ) ) === ! $allowed, 'conditionless rules cannot escape' );
        check( $hooks['advanced_woo_discount_rules_is_conditions_passed']( true, null, $rule( $scope ) ) === $allowed, 'conditions constrain eligibility' );
        check( $hooks['advanced_woo_discount_rules_is_conditions_passed']( false, null, $rule( $scope ) ) === false, 'never turn failing conditions true' );
        check( $hooks['advanced_woo_discount_rules_is_rule_passed_for_exclusive_rule']( true, null, (object) array('rule'=>$rule($scope)) ) === $allowed, 'excluded exclusive rule cannot hide eligible offers' );
        check( $hooks['advanced_woo_discount_rules_do_process_discounts_of_each_rule']( true, true, $rule($scope) ) === $allowed, 'calculation gate' );
    }
}
$_SERVER = array( 'REQUEST_URI'=>'/check-out/', 'HTTP_X_MOBISHOP_CHANNEL'=>'mobile' );
$_GET = array( 'mobishop_channel'=>'mobile', 'mobishop-checkout88'=>'1' );
$_COOKIE = array( 'mobishop_checkout88'=>str_repeat('a',64) );
check( MobiShop_Discount_Channel::current() === 'website', 'forged flags/cookie/header on website do not grant checkout context' );
check( MobiShop_Discount_Channel::scope((object)array()) === 'all', 'legacy default all' );
check( MobiShop_Discount_Channel::scope($rule('unexpected')) === 'all', 'old invalid metadata retains legacy default' );
check( ! MobiShop_Discount_Channel::api_route('/fake/wc/store/v1/cart'), 'not arbitrary path' );
check( MobiShop_Discount_Channel::api_route('/shop/', '/wc/store/v1/cart'), 'plain permalinks route' );
check( ! MobiShop_Discount_Channel::api_route('/wp-admin/admin.php'), 'admin not app' );
MobiShop_Discount_Channel::verified_embedded_checkout();
check( MobiShop_Discount_Channel::current() === 'mobile', 'verified embedded flow retains app eligibility' );
echo "PASS: $checks discount channel checks\n";
