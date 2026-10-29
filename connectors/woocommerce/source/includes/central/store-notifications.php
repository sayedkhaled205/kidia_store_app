<?php
defined('ABSPATH') || exit;

/** Store-owned notification transport; provider secrets remain on WooMobile. */
final class MobiShop_Store_Notifications {
    private const OPTION = 'mobishop_store_notifications_v1';
    private const BASE = 'https://api.woomobile.app/v1/stores/';

    public static function connection(): array {
        $value = get_option(self::OPTION, []);
        return is_array($value) && self::valid($value)
            && ($value['origin'] ?? '') === untrailingslashit(home_url()) ? $value : [];
    }

    private static function valid(array $value): bool {
        return is_string($value['store_id'] ?? null)
            && preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/D', $value['store_id'])
            && is_string($value['token'] ?? null)
            && preg_match('/^[A-Za-z0-9]{80}$/D', $value['token']);
    }

    public static function connect(WP_REST_Request $request) {
        if (!current_user_can('manage_options') || !current_user_can('manage_woocommerce')) {
            return new WP_Error('notification_connection_forbidden', 'Store administrator access is required.', ['status'=>403]);
        }
        $body = $request->get_json_params();
        if (!is_array($body) || !self::valid($body) || wp_parse_url(home_url(), PHP_URL_SCHEME) !== 'https') {
            return new WP_Error('invalid_notification_connection', 'A valid store connection is required.', ['status'=>400]);
        }
        $previous = self::connection();
        if ($previous && $previous['store_id'] !== $body['store_id']) {
            return new WP_Error('notification_store_mismatch', 'The existing store connection must be reviewed.', ['status'=>409]);
        }
        // Verify the token against the exact central store before persisting it.
        $project = self::request('project', 'GET', [], false, $body);
        if (is_wp_error($project)) return $project;
        if (($project['ok'] ?? false) !== true || ($project['firebase_project']['status'] ?? '') !== 'ready'
            || ($project['firebase_project']['messaging_ready'] ?? false) !== true) {
            return new WP_Error('notifications_not_ready', 'Store notifications are still being prepared.', ['status'=>503]);
        }
        update_option(self::OPTION, ['store_id'=>$body['store_id'], 'token'=>$body['token'], 'origin'=>untrailingslashit(home_url())], false);
        delete_transient('mobishop_firebase_project_status_v1');
        delete_transient('mobishop_firebase_client_config_v2_android');
        delete_transient('mobishop_firebase_client_config_v2_ios');
        return new WP_REST_Response(['ok'=>true, 'store_id'=>$body['store_id']], 200, ['Cache-Control'=>'private, no-store']);
    }

    public static function request(string $path, string $method = 'GET', array $body = [], bool $raw = false, ?array $connection = null) {
        $connection = $connection ?? self::connection();
        $path = trim($path, '/');
        $method = strtoupper($method);
        $allowed = ['project'=>['GET','POST'], 'messages'=>['POST'], 'project/android-config'=>['GET'], 'project/ios-config'=>['GET']];
        if (!self::valid($connection) || !isset($allowed[$path]) || !in_array($method, $allowed[$path], true)) {
            return new WP_Error('invalid_notification_request', 'A valid notification request is required.', ['status'=>400]);
        }
        $args = ['method'=>$method, 'timeout'=>35, 'redirection'=>0, 'headers'=>[
            'Authorization'=>'Bearer '.$connection['token'], 'Accept'=>$raw?'*/*':'application/json', 'Content-Type'=>'application/json',
        ]];
        if ($method === 'POST') $args['body'] = wp_json_encode($body);
        $response = wp_remote_request(self::BASE.$connection['store_id'].'/notifications/'.$path, $args);
        if (is_wp_error($response)) return new WP_Error('notifications_unavailable', 'Could not reach store notifications.', ['status'=>503]);
        $status = wp_remote_retrieve_response_code($response);
        $contents = wp_remote_retrieve_body($response);
        if ($status < 200 || $status >= 300) {
            $failure = json_decode($contents, true);
            if ($path === 'messages' && $status === 410 && ($failure['code'] ?? '') === 'fcm_token_unregistered') {
                return new WP_Error('push_token_unregistered', 'This device registration has expired. Open the app to register again.', ['status'=>410]);
            }
            return new WP_Error('notifications_unconfirmed', 'The notification connection could not be verified.', ['status'=>503]);
        }
        if ($raw) return trim($contents) !== '' ? $contents : new WP_Error('notifications_config_empty', 'The application configuration is unavailable.', ['status'=>503]);
        $result = json_decode($contents, true);
        if (!is_array($result) || (isset($result['ok']) && $result['ok'] !== true)) {
            return new WP_Error('notifications_invalid_response', 'The notification response is invalid.', ['status'=>503]);
        }
        return $result;
    }
}

add_action('rest_api_init', static function (): void {
    register_rest_route('mobishop/v1', '/central/notifications-connection', [
        'methods'=>'POST',
        'permission_callback'=>static fn (): bool => current_user_can('manage_options') && current_user_can('manage_woocommerce'),
        'callback'=>[MobiShop_Store_Notifications::class, 'connect'],
    ]);
}, 20);
