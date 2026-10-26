<?php
define( 'ABSPATH', __DIR__ );
final class Kidia_Shipping_Addresses {}
$current_user = 7;
$reads = array();
$meta = array( 7 => array(
	'home' => array( 'id' => 'home', 'label' => 'Home', 'address_1' => 'Test street', 'city' => 'Cairo',
		'checkout_fields' => array( 'billing_phone1' => 'test-alternate', 'order_comments' => 'not an address' ) ),
	'work' => array( 'id' => 'work', 'label' => 'Work', 'address_1' => 'Test office', 'city' => 'Giza' ),
	'invalid' => array( 'label' => 'Invalid' ),
) );
function add_filter( $name, $callback, $priority, $args ) {
	if ( $name !== 'mobishop_native_checkout_addresses92' || $args !== 2 ) throw new Exception('Invalid contract');
}
function get_current_user_id() { global $current_user; return $current_user; }
function get_user_meta( $id, $key, $single ) {
	global $meta, $reads; $reads[] = $id;
	if ( $key !== 'kidia_shipping_addresses_v1' || !$single ) throw new Exception('Wrong source');
	return $meta[$id] ?? '';
}
require __DIR__ . '/../../integrations/woocommerce/kidia-address-book.php';
function check( $condition, $message ) { if ( !$condition ) throw new Exception($message); }
$rows = mobishop_kidia_address_book(array(),7);
check(count($rows) === 2, 'Both valid website addresses are visible');
check($rows[0]['values']['phone1'] === 'test-alternate', 'Custom merchant field missing');
check(!isset($rows[0]['values']['order_comments']), 'Order note leaked into address');
check($rows[1]['id'] === 'address-book-work', 'Stable address ID missing');
check(mobishop_kidia_address_book(array(),8) === array(), 'Another customer must not be queried');
$current_user = 0;
check(mobishop_kidia_address_book(array(),0) === array(), 'Guests have no saved addresses');
check($reads === array(7), 'Unauthorized user metadata was read');
echo "PASS: two website addresses, custom fields, stable IDs, guest and cross-customer isolation\n";
