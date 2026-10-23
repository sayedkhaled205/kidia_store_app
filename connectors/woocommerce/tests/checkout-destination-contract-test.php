<?php
// Standalone contract: public native checkout preserves merchant destinations.
define('ABSPATH', __DIR__);
function sanitize_key($s) { return strtolower(preg_replace('/[^a-zA-Z0-9_-]/','',$s)); }
function sanitize_text_field($s) { return trim(strip_tags($s)); }
function wp_strip_all_tags($s) { return strip_tags($s); }
class WC_Countries {
    public array $allowed = ['US'=>'United States','CA'=>'Canada'];
    public function get_allowed_countries() { return $this->allowed; }
    public function get_shipping_countries() { return $this->allowed; }
    public function get_states($country) { return ['US'=>['CA'=>'California'],'CA'=>['ON'=>'Ontario'],'EG'=>['EGC'=>'Cairo']][$country] ?? []; }
}
$wc = (object)['countries'=>new WC_Countries()];
function WC() { global $wc; return $wc; }
$root = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__ . '/../source';
require $root . '/api/class-checkout-config-endpoint.php';
$endpoint = new MobiShop_Checkout_Config_Endpoint();
$method = new ReflectionMethod($endpoint,'normalize_fields');
$groups=['billing'=>[
    'billing_country'=>['type'=>'country','label'=>'Country','required'=>true],
    'billing_state'=>['type'=>'state','label'=>'State','required'=>true],
    'billing_postcode'=>['type'=>'text','label'=>'ZIP','required'=>true],
    'billing_email'=>['type'=>'email','label'=>'Email','required'=>true],
]];
function check($ok,$label) { if (!$ok) throw new RuntimeException($label); echo "PASS $label\n"; }
$fields=array_column($method->invoke($endpoint,$groups,'US'),null,'key');
check($fields['billing_country']['type']==='select' && count($fields['billing_country']['options'])===2,'international countries remain selectable');
check($fields['billing_postcode']['required'] && $fields['billing_postcode']['type']==='text','merchant-required postcode stays visible');
check($fields['billing_email']['required'],'merchant email field retained');
check($fields['billing_state']['options_by_country']['CA']===['ON'=>'Ontario'],'destination state options come from WooCommerce');
$wc->countries->allowed=['EG'=>'Egypt'];
$fields=array_column($method->invoke($endpoint,$groups,'EG'),null,'key');
check($fields['billing_country']['type']==='hidden' && $fields['billing_country']['default']==='EG','single-country store needs no country choice');
$groups['billing']['billing_state']['options']=['custom'=>'Merchant region'];
$fields=array_column($method->invoke($endpoint,$groups,'EG'),null,'key');
check($fields['billing_state']['options']===['custom'=>'Merchant region'],'merchant region overrides preserved');
