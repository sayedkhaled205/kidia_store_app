<?php
/** Plugin Name: MobiShop stock-aware catalog compatibility */
defined('ABSPATH') || exit;
add_action('plugins_loaded', static function () {
    if (!class_exists('MobiShop_Attribute_Stock_Filter')) {
        require_once __DIR__ . '/mobishop-stock/class-attribute-stock-filter.php';
        (new MobiShop_Attribute_Stock_Filter())->register();
    }
    // Replace legacy post-pagination filtering; retain the existing size UI.
    add_action('wp_loaded', static function () {
        remove_filter('the_posts', 'kidia_ssf_filter_posts', 30);
    }, 100);
}, 30);
