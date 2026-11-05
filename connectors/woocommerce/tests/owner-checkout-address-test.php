<?php
/** Read-only checkout address projection; never mutates a cart or user. */
define('ABSPATH', __DIR__);
$current_id = 70; $data_id = 7; $reads = [];
function get_current_user_id() { return $GLOBALS['current_id']; }
class MobiShop_Storefront_Admin { public static function data_owner_id(int $id): int { return $GLOBALS['data_id']; } }
class WC_Customer {
  public function __construct(public int $id) { $GLOBALS['reads'][] = $id; }
  public function get_billing() { return ['address_1'=>"Buyer {$this->id} saved",'country'=>'EG']; }
  public function get_shipping() { return []; }
}
function apply_filters($name, $rows, $id) { if ($id !== $GLOBALS['current_id']) throw new Exception('Integration must retain authenticated shopper id'); return $rows; }
function sanitize_text_field($v) { return $v; }
function sanitize_key($v) { return $v; }
function wp_json_encode($v) { return json_encode($v); }
require dirname(__DIR__) . '/source/api/class-checkout-config-endpoint.php';
$endpoint = new MobiShop_Checkout_Config_Endpoint();
$method = new ReflectionMethod($endpoint, 'saved_addresses');
function check($condition,$message) { if (!$condition) throw new Exception($message); }
$rows = $method->invoke($endpoint);
check($reads === [7] && $rows[0]['values']['address_1'] === 'Buyer 7 saved','Verified owner historical address not projected');
$current_id = 19; $data_id = 19; $reads = [];
$rows = $method->invoke($endpoint);
check($reads === [19] && $rows[0]['values']['address_1'] === 'Buyer 19 saved','Ordinary buyer changed');
$data_id = 0; $reads = [];
check($method->invoke($endpoint) === [] && $reads === [],'Invalid mapping exposed addresses');
$current_id = 0;
check($method->invoke($endpoint) === [] && $reads === [],'Guest address access');
echo "PASS owner checkout saved-address projection and buyer isolation\n";
