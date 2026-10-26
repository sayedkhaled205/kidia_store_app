<?php
// The packaged adapter must be automatic, buyer-scoped and coexist with MU installs.
define( 'ABSPATH', __DIR__ );
$mode = $argv[1] ?? 'normal';
$root = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__ . '/../source';
$callbacks = array(); $reads = array(); $current_user = 7;
function check( $condition, $message ) { if (!$condition) throw new Exception($message); }
function add_filter( $name, $callback, $priority, $args ) {
    global $callbacks;
    check($name === 'mobishop_native_checkout_addresses92' && $args === 2, 'Wrong public contract');
    $callbacks[] = $callback;
}
function get_current_user_id() { global $current_user; return $current_user; }
function get_user_meta( $id, $key, $single ) {
    global $reads;
    $reads[] = $id;
    check($key === 'kidia_shipping_addresses_v1' && $single, 'Unknown metadata scanned');
    return array(
        'home' => array('id'=>'home', 'label'=>'Home', 'address_1'=>"Buyer $id home", 'city'=>'Town',
            'checkout_fields'=>array('billing_phone1'=>'alternate', 'order_comments'=>'exclude')),
        'work' => array('id'=>'work', 'label'=>'Work', 'address_1'=>"Buyer $id work"),
        'invalid' => array('label'=>'No address'),
    );
}
if ($mode !== 'no-provider') { final class Kidia_Shipping_Addresses {} }
if ($mode === 'legacy') {
    function mobishop_kidia_address_book(array $rows, int $id): array { return $rows; }
    add_filter('mobishop_native_checkout_addresses92', 'mobishop_kidia_address_book', 10, 2);
}
require $root . '/integrations/kidia-address-book.php';
check($callbacks === array('mobishop_kidia_address_book'), 'Duplicate adapter registration');
check(str_contains(file_get_contents($root . '/includes/class-mobishop.php'),
    "require_once MOBISHOP_PATH . 'integrations/kidia-address-book.php';"), 'Adapter not loaded by connector');
$native = array(array('id'=>'billing', 'values'=>array('address_1'=>'Native billing')));
if ($mode === 'legacy' || $mode === 'no-provider') {
    check(mobishop_kidia_address_book($native,7) === $native, 'Existing or unsupported provider changed');
    check($reads === array(), 'Unsupported provider metadata read');
} else {
    foreach (array(7, 19) as $buyer) {
        $current_user = $buyer;
        $result = mobishop_kidia_address_book($native,$buyer);
        check(count($result) === 3, 'Saved and native addresses not preserved');
        check($result[0]['values']['address_1'] === "Buyer $buyer home", 'Wrong buyer');
        check($result[0]['values']['phone1'] === 'alternate', 'Custom field missing');
        check(!isset($result[0]['values']['order_comments']), 'Order data in address');
        check($result[1]['id'] === 'address-book-work', 'Stable ID lost');
        check(mobishop_kidia_address_book($native,$buyer+1) === $native, 'Cross-customer access');
    }
    $current_user = 0;
    check(mobishop_kidia_address_book($native,0) === $native, 'Guest address access');
    check($reads === array(7,19), 'Unauthorized metadata access');
}
echo "PASS: packaged address adapter ($mode)\n";
