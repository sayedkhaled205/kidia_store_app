<?php
/** Native banner destinations survive legacy link values and editor round trips. */
declare(strict_types=1);
require __DIR__ . '/home-blocks-contract-test.php';
require dirname(__DIR__) . '/includes/blocks/class-mobishop-hero-slider-block.php';
require dirname(__DIR__) . '/includes/blocks/class-mobishop-image-banner-block.php';
function esc_attr_e(string $text, string $domain = ''): void { echo esc_attr(__($text, $domain)); }
$hero = new MobiShop_Hero_Slider_Block();
$settings = ['items' => [[
    'id' => 'shoes', 'image_url' => 'https://example.com/shoes.jpg',
    'action_type' => 'category', 'action_value' => '123',
    'button_link' => 'https://example.com/old-shoes/',
]]];
$native = $hero->sanitize_settings($settings);
mobishop_home_assert($native['items'][0]['action_type'] === 'category', 'Explicit native hero action must win over stale website link.');
mobishop_home_assert($native['items'][0]['action_value'] === '123', 'Hero category ID must survive sanitization.');
mobishop_home_assert($native['items'][0]['button_link'] === '', 'Native hero must clear its legacy external link.');
$api = $hero->build_api_data($native);
mobishop_home_assert($api['items'][0]['action'] === ['type' => 'category', 'value' => '123'], 'Hero API must emit native category action.');
ob_start(); $hero->render_settings(0, $native); $html = ob_get_clean();
mobishop_home_assert(str_contains($html, '[action_type]') && str_contains($html, '[action_value]'), 'Hero editor must retain editable native destination fields.');
$legacy = $settings; unset($legacy['items'][0]['action_type'], $legacy['items'][0]['action_value']);
$legacy = $hero->sanitize_settings($legacy);
mobishop_home_assert($legacy['items'][0]['action_type'] === 'external' && $legacy['items'][0]['action_value'] === 'https://example.com/old-shoes/', 'Legacy external hero links remain backward compatible.');
$external = $settings; $external['items'][0]['action_type'] = 'external'; $external['items'][0]['action_value'] = 'https://example.com/new-shoes/';
$external = $hero->sanitize_settings($external);
mobishop_home_assert($external['items'][0]['action_value'] === 'https://example.com/new-shoes/', 'Edited external destination must win over its stale legacy URL.');
$banner = new MobiShop_Image_Banner_Block();
$support = $banner->build_api_data(['image_url' => 'https://example.com/support.jpg', 'action_type' => 'support', 'action_value' => '']);
mobishop_home_assert($support['action'] === ['type' => 'support', 'value' => 'support'], 'Support banner must emit the native customer support destination.');
echo "Native banner actions passed.\n";
