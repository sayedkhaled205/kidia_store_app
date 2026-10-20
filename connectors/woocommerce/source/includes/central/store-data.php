<?php
/** Authenticated, read-only store workspace export for the connected central builder. */
defined('ABSPATH') || exit;

add_action('rest_api_init', static function (): void {
    register_rest_route('mobishop/v1', '/central/store-data', [
        'methods' => 'GET',
        'permission_callback' => static function () {
            return current_user_can('manage_woocommerce') && current_user_can('manage_options');
        },
        'callback' => static function (WP_REST_Request $request) {
            if (!class_exists('MobiShop_Central_Commerce') || !class_exists('MobiShop_Analytics')) {
                return new WP_Error('connector_unavailable', 'The store data connector needs updating.', ['status' => 503]);
            }
            $tabs = ['products', 'categories', 'discounts', 'customers', 'orders', 'reports', 'analytics'];
            $tab = (string) $request->get_param('store_tab');
            if (!in_array($tab, $tabs, true)) {
                return new WP_Error('invalid_tab', 'Invalid store data section.', ['status' => 400]);
            }
            $presets = ['all_time', 'today', 'yesterday', 'last_7_days', 'last_30_days', 'this_month', 'previous_month', 'last_year', 'custom'];
            $preset = (string) ($request->get_param('date_preset') ?: 'today');
            if (!in_array($preset, $presets, true)) {
                return new WP_Error('invalid_period', 'Invalid date period.', ['status' => 400]);
            }
            $source = (string) ($request->get_param('store_source') ?: 'all');
            if (!in_array($source, ['all', 'website', 'mobile'], true)) {
                return new WP_Error('invalid_source', 'Invalid data source.', ['status' => 400]);
            }
            if ($preset === 'custom') {
                $from = (string) $request->get_param('date_from');
                $to = (string) $request->get_param('date_to');
                $f = DateTimeImmutable::createFromFormat('!Y-m-d', $from, wp_timezone());
                $t = DateTimeImmutable::createFromFormat('!Y-m-d', $to, wp_timezone());
                if (!$f || !$t || $f->format('Y-m-d') !== $from || $t->format('Y-m-d') !== $to || $t < $f) {
                    return new WP_Error('invalid_dates', 'Choose a valid start and end date.', ['status' => 400]);
                }
            }
            // Reuse the native queries, source attribution, date zone and reporting calculations.
            // Only the readiness flag is supplied for this read; no option or commerce data is written.
            $savedGet = $_GET;
            $allowed = ['date_from', 'date_to', 'product_search', 'product_visibility', 'product_page', 'coupon_search', 'coupon_status', 'coupon_type', 'coupon_scope', 'coupon_channel', 'coupon_page', 'customer_search', 'customer_page', 'order_search', 'order_status', 'order_page'];
            $_GET = ['page' => 'mobishop-store-data', 'store_tab' => $tab, 'date_preset' => $preset, 'store_source' => $source];
            foreach ($allowed as $key) {
                $value = $request->get_param($key);
                if (is_scalar($value) && strlen((string) $value) <= 200) {
                    $_GET[$key] = (string) $value;
                }
            }
            $bufferLevel = ob_get_level();
            try {
                ob_start();
                (new MobiShop_Central_Commerce())->store_data_page();
                $html = ob_get_clean();
            } catch (Throwable $error) {
                return new WP_Error('commerce_read_failed', 'The selected section could not be loaded. Please retry.', ['status'=>503]);
            } finally {
                while (ob_get_level() > $bufferLevel) { ob_end_clean(); }
                $_GET = $savedGet;
            }
            $response = new WP_REST_Response([
                'ok' => true, 'platform' => 'woocommerce', 'html' => $html,
                'store_tab' => $tab, 'checked_at' => gmdate('c'),
                'timezone' => wp_timezone_string(), 'data_mode' => 'live_read', 'store_url' => home_url('/'),
            ]);
            $response->header('Cache-Control', 'no-store, private');
            return $response;
        },
    ]);
});
