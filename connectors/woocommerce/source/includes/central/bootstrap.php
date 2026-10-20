<?php
defined('ABSPATH') || exit;
/** Server-to-server setup, using the administrator's existing authorized connection. */
add_action('rest_api_init', static function (): void {
    $permission = static fn (): bool => current_user_can('manage_options') && current_user_can('manage_woocommerce');
    register_rest_route('mobishop/v1', '/central/capabilities', [
        'methods' => 'GET', 'permission_callback' => $permission,
        'callback' => static function () {
            return new WP_REST_Response(['ok'=>true, 'version'=>MOBISHOP_VERSION,
                'contract'=>296, 'capabilities'=>['store_data','application_state','push_status','push_actions','bootstrap'],
                'installation_id'=>(string) get_option('mobishop_installation_id','')], 200, ['Cache-Control'=>'no-store, private']);
        },
    ]);
    register_rest_route('mobishop/v1', '/central/bootstrap', [
        'methods'=>'POST', 'permission_callback'=>$permission,
        'callback'=>static function (WP_REST_Request $request) {
            $body=$request->get_json_params();
            if (!is_array($body) || !is_string($body['license_key']??null) || strlen($body['license_key'])>200) {
                return new WP_Error('invalid_setup','A valid setup request is required.',['status'=>400]);
            }
            $manager=new MobiShop_License_Manager();
            $result=$manager->verify();
            if (is_wp_error($result) || !$manager->is_active()) $result=$manager->activate($body['license_key']);
            if (is_wp_error($result)) return new WP_Error('activation_unconfirmed','Store activation could not be confirmed.',['status'=>503]);
            // Token and signed proof remain solely in the native license manager.
            return new WP_REST_Response(['ok'=>true,'active'=>$manager->is_active(),
                'installation_id'=>(string)get_option('mobishop_installation_id','')],200,['Cache-Control'=>'no-store, private']);
        },
    ]);
}, 20);
