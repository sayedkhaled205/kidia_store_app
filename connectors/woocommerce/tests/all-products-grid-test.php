<?php
declare(strict_types=1);
define('ABSPATH', __DIR__);
function __($value, $domain = '') { return $value; }
function sanitize_key($value) { return strtolower(preg_replace('/[^a-zA-Z0-9_-]/', '', $value)); }
function sanitize_text_field($value) { return strip_tags($value); }
function sanitize_textarea_field($value) { return strip_tags($value); }
function sanitize_hex_color($value) { return preg_match('/^#[a-fA-F0-9]{6}$/', $value) ? $value : null; }
function esc_url_raw($value) { return $value; }
function absint($value) { return abs((int) $value); }
function wp_parse_args($value, $defaults) { return array_merge($defaults, $value); }
function wc_get_products($args) { $GLOBALS['grid_query'] = $args; return []; }
function get_woocommerce_currency() { return 'USD'; }
function get_woocommerce_currency_symbol($code) { return '$'; }
class MobiShop_Block {
    protected function build_action($type, $value) { return $type && $value ? ['type' => $type, 'value' => $value] : null; }
}
require $argv[1] ?? __DIR__.'/../source/includes/blocks/class-mobishop-product-grid-block.php';
$block = new MobiShop_Product_Grid_Block();
$settings = array_merge($block->get_default_settings(), ['limit' => 'all']);
$data = $block->build_api_data($settings);
if ($data['limit'] !== 'all' || $GLOBALS['grid_query']['limit'] !== 20 || $data['source'] !== 'latest') throw new RuntimeException('All must survive transport while the first request stays bounded.');
$settings['limit'] = 37;
$data = $block->build_api_data($settings);
if ($data['limit'] !== 37 || $GLOBALS['grid_query']['limit'] !== 37) throw new RuntimeException('An explicit count must stay finite.');
echo "WordPress All preservation and bounded first-page query: PASS\n";
