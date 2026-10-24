<?php
/** Current merchant configuration only; no customer, order or provider calls. */
declare(strict_types=1);
define('ABSPATH', __DIR__);
function sanitize_key($s) { return strtolower(preg_replace('/[^a-zA-Z0-9_-]/', '', $s)); }
function sanitize_text_field($s) { return trim(strip_tags($s)); }
function wp_strip_all_tags($s) { return strip_tags($s); }
function __($s, $domain = '') { return $s; }
function get_current_user_id() { return $GLOBALS['buyer96'] ?? 0; }
function wp_json_encode($value) { return json_encode($value); }
function get_option($name, $default = false) { return $GLOBALS['options96'][$name] ?? $default; }
function wc_get_base_location() { return ['country' => $GLOBALS['country96'] ?? 'EG']; }
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
    public function get_allowed_countries() { return $GLOBALS['countries96'] ?? ['EG' => 'Egypt']; }
    public function get_shipping_countries() { return $this->get_allowed_countries(); }
    public function get_states($country) { return ['EG' => ['EGC' => 'Cairo'], 'US' => ['CA' => 'California'], 'GB' => []][$country] ?? []; }
}
class WC_Customer {
    public function __construct(private int $id) {}
    public function get_billing() { return $GLOBALS['addresses96'][$this->id]['billing'] ?? []; }
    public function get_shipping() { return $GLOBALS['addresses96'][$this->id]['shipping'] ?? []; }
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
check96($response->data['version'] === 8 && $response->data['renderer'] === 'native', 'additive policy preserves installed v8 clients');
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
// Independent international and digital-only merchants, without a store ID.
foreach ([
    ['US', ['US' => 'United States', 'GB' => 'United Kingdom'], 'State', true, 'billing'],
    ['GB', ['GB' => 'United Kingdom'], 'County', true, 'billing_only'],
    ['EG', ['EG' => 'Egypt'], 'Delivery district', false, 'shipping'],
] as [$country96, $countries96, $label96, $shipping96, $destination96]) {
    $options96 = ['woocommerce_ship_to_destination' => $destination96];
    $filter96 = null;
    $wc96 = new Store96();
    $wc96->checkout->groups = ['billing' => [
        'billing_country' => ['type' => 'country', 'label' => 'Country', 'required' => true],
        'billing_state' => ['type' => 'state', 'label' => $label96, 'required' => false],
    ]];
    $data96 = $api->get_checkout_config()->data;
    $fields96 = array_column($data96['fields'], null, 'key');
    check96($data96['defaults']['country'] === $country96, "$country96 reads its own base country");
    check96($fields96['billing_state']['label'] === $label96, "$country96 reads its own field label");
    check96($fields96['billing_country']['options'] === $countries96, "$country96 preserves its allowed countries");
    check96($fields96['billing_country']['type'] === (count($countries96) > 1 ? 'select' : 'hidden'), "$country96 shows country choice only when needed");
    check96($data96['shipping']['allow_different_address'] === ($shipping96 && $destination96 !== 'billing_only'), "$country96 applies its own shipping policy");
    check96($fields96['billing_state']['options'] === $wc96->countries->get_states($country96), "$country96 never inherits another country's states");
}
$addresses96 = [
    7 => ['billing' => ['address_1' => 'Fixture Alpha address', 'first_name' => 'Alpha']],
    8 => ['billing' => ['address_1' => 'Fixture Beta address', 'first_name' => 'Beta']],
];
foreach ([7, 8, 0, 7] as $buyer96) {
    $saved96 = $api->get_checkout_config()->data['saved_addresses'];
    check96($buyer96 === 0 ? $saved96 === [] :
        count($saved96) === 1 && $saved96[0]['values'] === $addresses96[$buyer96]['billing'],
        "saved addresses belong only to current buyer $buyer96");
}
echo "MERCHANT_SCHEMA96_CHECKS=$checks96\n";
