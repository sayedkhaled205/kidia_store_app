<?php
/** Offline contract: preset application keeps upper content and fixes the offer row. */
declare(strict_types=1);
define('ABSPATH', __DIR__);
define('MOBISHOP_URL', 'https://store.example/wp-content/plugins/mobi2app-connector/');
$source = getenv('MOBISHOP_CONNECTOR_TEST_ROOT');
if (!$source) { throw new RuntimeException('Explicit candidate source required.'); }
require $source . '/includes/class-mobishop-kids-home-preset.php';
$before = json_decode(file_get_contents(__DIR__ . '/preset-before301.json'), true, 512, JSON_THROW_ON_ERROR);
$preset = json_decode(file_get_contents($source . '/includes/presets/kids-home-tail293.json'), true, 512, JSON_THROW_ON_ERROR);
if (count($preset) !== 8) { throw new RuntimeException('Preset section count changed.'); }
foreach ($preset as $index => $row) {
    $expected = $before[$index];
    $expected['settings']['space_down'] = 0;
    if ($row['id'] === 'kids293_welcome_products') { $expected['settings']['source'] = 'latest'; }
    if ($row['id'] === 'kids293_categories') { $expected['settings']['gap'] = 12; }
    if ($expected !== $row) { throw new RuntimeException('Unreviewed preset delta: ' . $row['id']); }
}
$prefix = [
    ['id' => 'upper-circles', 'type' => 'quick_links', 'settings' => ['items' => [['action_value' => 'merchant-selection']]]],
    ['id' => 'main-hero', 'type' => 'hero_slider', 'settings' => ['image_url' => 'https://store.example/own-hero.jpg']],
];
$applied = MobiShop_Kids_Home_Preset::apply($prefix, '#123456', '#654321');
foreach ([0, 1] as $index) {
    $actual = $applied[$index]; unset($actual['order']);
    if ($actual !== $prefix[$index]) { throw new RuntimeException('Applying tail changed the preserved upper content.'); }
}
$offer_index = array_search('kids293_welcome_products', array_column($applied, 'id'), true);
if ($offer_index === false || $applied[$offer_index - 1]['type'] !== 'image_banner'
    || $applied[$offer_index]['type'] !== 'product_carousel'
    || $applied[$offer_index]['settings']['source'] !== 'latest'
    || $applied[$offer_index]['settings']['limit'] !== 8) {
    throw new RuntimeException('Offer banner must be followed by the eight latest products.');
}
echo "KIDS_TAIL301_CONTRACTS_PASSED\n";
