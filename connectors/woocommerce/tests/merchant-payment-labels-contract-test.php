<?php
/** Different stores inherit only their own public payment labels, without secrets. */
declare(strict_types=1);
define('ABSPATH', __DIR__);
function wp_strip_all_tags($value) { return strip_tags($value); }
final class MerchantPaymentFixture {
    public string $id = '';
    public string $secret_key = 'fixture-private-never-public';
    public function __construct(public string $enabled, public string $title) {}
    public function get_title(): string { return $this->title; }
}
$merchant_methods = [];
function WC() {
    return new class {
        public function payment_gateways() {
            return new class {
                public function payment_gateways(): array { return $GLOBALS['merchant_methods']; }
            };
        }
    };
}
$source = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__) . '/source';
require $source . '/api/class-checkout-config-endpoint.php';
require $source . '/api/class-native-payment92.php';
$endpoint = new MobiShop_Checkout_Config_Endpoint();
$fixtures = [
    [
        'custom_card' => new MerchantPaymentFixture('yes', '<strong>Card &amp; instalments</strong>'),
        'cod' => new MerchantPaymentFixture('yes', 'Pay the courier'),
        'disabled_bank' => new MerchantPaymentFixture('no', 'Unavailable bank'),
    ],
    ['bacs' => new MerchantPaymentFixture('yes', 'Merchant two bank transfer')],
    [],
];
$expected = [
    [['id' => 'custom_card', 'title' => 'Card & instalments', 'native_adapter' => 'unavailable'], ['id' => 'cod', 'title' => 'Pay the courier', 'native_adapter' => 'offline']],
    [['id' => 'bacs', 'title' => 'Merchant two bank transfer', 'native_adapter' => 'offline']],
    [],
];
foreach ($fixtures as $index => $merchant_methods) {
    foreach ($merchant_methods as $id => $method) $method->id = $id;
    $actual = $endpoint->payment_method_labels();
    if ($actual !== $expected[$index]) {
        throw new RuntimeException('Merchant payment labels leaked between stores or ignored the enabled state.');
    }
    if (str_contains(json_encode($actual), 'fixture-private')) {
        throw new RuntimeException('Private gateway settings were exposed.');
    }
}
echo "MERCHANT_PAYMENT_LABELS_CONTRACTS_PASSED\n";
