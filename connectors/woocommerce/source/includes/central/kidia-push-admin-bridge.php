<?php
/** Authenticated read-only bridge to the existing MobiShop device registry. */
defined('ABSPATH') || exit;

add_action('rest_api_init', static function (): void {
    register_rest_route('mobishop/v1', '/builder/push-status', [
        'methods' => WP_REST_Server::READABLE,
        'permission_callback' => static fn (): bool => current_user_can('manage_options'),
        'callback' => static function () {
            if (!class_exists('MobiShop_Push_Service')) {
                return new WP_Error('mobishop_push_unavailable', 'The push service is unavailable.', ['status' => 503]);
            }
            $status = MobiShop_Push_Service::connection_status();
            $metrics = MobiShop_Push_Service::aggregate_metrics();
            $history = [];
            foreach (array_slice((array) get_option('mobishop_push_history', []), 0, 100) as $row) {
                if (!is_array($row)) continue;
                $history[] = [
                    'title' => sanitize_text_field((string) ($row['title'] ?? '')),
                    'message' => sanitize_textarea_field((string) ($row['message'] ?? '')),
                    'status' => sanitize_key((string) ($row['status'] ?? 'saved')),
                    'created_at' => max(0, (int) ($row['created_at'] ?? $row['sent_at'] ?? 0)),
                ];
            }
            // Do not expose registry entries, tokens, client identifiers or Firebase SDK keys.
            return rest_ensure_response([
                'ok' => true,
                'devices' => max(0, (int) ($status['devices'] ?? 0)),
                'delivered' => max(0, (int) ($metrics['delivered'] ?? 0)),
                'opened' => max(0, (int) ($metrics['opened'] ?? 0)),
                'converted' => max(0, (int) ($metrics['converted'] ?? 0)),
                'history' => $history,
            ]);
        },
    ]);
});

add_action('rest_api_init', static function (): void {
    register_rest_route('mobishop/v1', '/builder/push-actions', [
        'methods' => WP_REST_Server::CREATABLE,
        'permission_callback' => static fn (): bool => current_user_can('manage_options'),
        'callback' => static function (WP_REST_Request $request) {
            if (!class_exists('MobiShop_Central_Push_Actions')) {
                return new WP_Error('mobishop_push_unavailable', 'The push workflow is unavailable.', ['status' => 503]);
            }
            $body = $request->get_json_params();
            if (!is_array($body) || !is_array($body['fields'] ?? null) || count($body['fields']) > 80
                || !is_string($body['request_id'] ?? null)
                || (isset($body['validate_only']) && !is_bool($body['validate_only']))) {
                return new WP_Error('invalid_draft', 'A valid notification draft is required.', ['status' => 400]);
            }
            foreach ($body['fields'] as $value) {
                if (is_string($value) && strlen($value) > 5000) {
                    return new WP_Error('invalid_draft', 'A notification field is too long.', ['status' => 400]);
                }
            }
            $result = MobiShop_Central_Push_Actions::process($body['fields'], $body['request_id'], ($body['validate_only'] ?? false) === true);
            return is_wp_error($result) ? $result : rest_ensure_response($result);
        },
    ]);
});
