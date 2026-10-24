<?php
/** Current merchant configuration only; no customer, order or provider calls. */
declare(strict_types=1);
define('ABSPATH', __DIR__);
function sanitize_key($s) { return strtolower(preg_replace('/[^a-zA-Z0-9_-]/', '', $s)); }
function sanitize_text_field($s) { return trim(strip_tags($s)); }
function wp_strip_all_tags($s) { return strip_tags($s); }
function __($s, $domain = '') { return $s; }
function get_current_user_id() { return 0; }
function get_option($name, $default = false) { return $GLOBALS['options96'][$name] ?? $default; }
function wc_get_base_location() { return ['country' => 'EG']; }
function wc_shipping_enabled() { return $GLOBALS['shipping96']; }
function wc_ship_to_billing_address_only() { return get_option('woocommerce_ship_to_destination') === 'billing_only'; }
function apply_filters($hook, $value, ...$args) {
    return $hook === 'woocommerce_cart_needs_shipping_address' ? ($GLOBALS['filter96'] ?? $value) : $value;
}
class WP_REST_Response {
    public array $headers = [];
    public function __construct(public array $data) {}
    public function header($name, $value) { $this->headers[$name] = $value; }
}
function rest_ensure_response($data) { return new WP_REST_Response($data); }
class WC_Checkout {
    public array $groups = [];
    public function get_checkout_fields($group) { return $this->groups[$group] ?? []; }
}
class WC_Countries {
    public function get_allowed_countries() { return ['EG' => 'Egypt']; }
    public function get_shipping_countries() { return ['EG' => 'Egypt']; }
    public function get_states($country) { return ['EGC' => 'Cairo']; }
}
class WC96 {
    public WC_Checkout $checkout;
    public WC_Countries $countries;
    public function __construct() { $this->checkout = new WC_Checkout(); $this->countries = new WC_Countries(); }
    public function checkout() { return $this->checkout; }
    public function payment_gateways() { return $this; }
    public function payment_gateways_list() { return []; }
}
// Woo payment_gateways() returns a gateway manager, not itself.
class GatewayManager96 { public function payment_gateways() { return []; } }
class Store96 extends WC96 { public function payment_gateways() { return new GatewayManager96(); } }
$wc96 = new Store96();
function WC() { return $GLOBALS['wc96']; }
$root = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__ . '/../source';
require $root . '/includes/class-mobishop-checkout-fields-store.php';
require $root . '/api/class-checkout-config-endpoint.php';
$api = new MobiShop_Checkout_Config_Endpoint();
$options96 = ['woocommerce_ship_to_destination' => 'billing'];
$shipping96 = true;
$filter96 = null;
$wc96->checkout->groups = ['billing' => ['billing_state' => ['label' => 'Region', 'required' => true, 'type' => 'state']]];
$checks96 = 0;
function check96($ok, $message) { if (!$ok) throw new RuntimeException($message); ++$GLOBALS['checks96']; echo "PASS $message\n"; }
$response = $api->get_checkout_config();
check96($response->data['shipping']['allow_different_address'] === true, 'billing default still allows another address');
check96($response->data['version'] === 9 && $response->data['renderer'] === 'native', 'versioned native contract');
check96(str_contains($response->headers['Cache-Control'], 'no-store'), 'merchant fields are never cached');
$options96['woocommerce_ship_to_destination'] = 'billing_only';
check96($api->get_checkout_config()->data['shipping']['allow_different_address'] === false, 'billing-only hides another address');
$filter96 = true;
check96($api->get_checkout_config()->data['shipping']['allow_different_address'] === false, 'filter cannot reopen billing-only');
$options96['woocommerce_ship_to_destination'] = 'shipping';
check96($api->get_checkout_config()->data['shipping']['allow_different_address'] === true, 'shipping default allows address choice');
$filter96 = false;
check96($api->get_checkout_config()->data['shipping']['allow_different_address'] === false, 'merchant suppression filter respected');
$filter96 = null;
$shipping96 = false;
check96($api->get_checkout_config()->data['shipping']['allow_different_address'] === false, 'disabled shipping does not offer address choice');
$wc96->checkout->groups['billing']['billing_state'] = ['label' => 'المحافظة', 'placeholder' => 'اختر المحافظة', 'required' => false, 'type' => 'state', 'options' => ['district' => 'Merchant district']];
$field = $api->get_checkout_config()->data['fields'][0];
check96($field['label'] === 'المحافظة' && $field['placeholder'] === 'اختر المحافظة', 'current merchant labels replace previous labels');
check96($field['required'] === false && $field['options'] === ['district' => 'Merchant district'], 'merchant requirements and choices preserved');
$wc96->checkout->groups['billing'] = [];
check96($api->get_checkout_config()->data['fields'] === [], 'removed merchant fields are not resurrected');
echo "MERCHANT_SCHEMA96_CHECKS=$checks96\n";
