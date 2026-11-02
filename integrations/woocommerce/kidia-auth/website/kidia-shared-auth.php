<?php
/** Plugin Name: Kidia shared account completion
 * Reuses the connector's registration and identity protections for the website.
 */
defined('ABSPATH') || exit;
function kidia_website_auth_engine() {
    return new MobiShop_Native_Customer_Auth_Endpoint(
        static function($user) {
            wp_set_current_user((int)$user->ID);
            wp_set_auth_cookie((int)$user->ID,true,is_ssl());
            do_action('wp_login',(string)$user->user_login,$user);
            return new WP_REST_Response(['status'=>'authenticated']);
        },
        static fn($user) => $user instanceof WP_User && !user_can($user,'manage_options') && !user_can($user,'edit_users') && !user_can($user,'manage_woocommerce'),
        get_option('fmaServiceProvider') === 'firebase' ? (string)get_option('fma_lwp_projectID') : ''
    );
}
function kidia_shared_auth_action(): void {
    nocache_headers();
    check_ajax_referer('mobishop_website_auth', 'nonce');
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST' || !class_exists('MobiShop_Native_Customer_Auth_Endpoint')) {
        wp_send_json_error(['code'=>'unavailable'], 503);
    }
    $method = is_string($_POST['method'] ?? null) ? sanitize_key(wp_unslash($_POST['method'])) : '';
    $allowed = ['phone_enroll','phone_confirm','register_customer','website_contact'];
    if (!in_array($method,$allowed,true)) wp_send_json_error(['code'=>'invalid_request'],400);
    $params = ['client_channel'=>'website'];
    foreach (['nonce','phone','verifier','ticket','name','password','confirm_password','email','mode','id_token'] as $key) {
        if (isset($_POST[$key])) {
            if (!is_string($_POST[$key]) || strlen($_POST[$key]) > 12000) wp_send_json_error(['code'=>'invalid_request'],400);
            $params[$key] = wp_unslash($_POST[$key]);
        }
    }
    if ($method === 'register_customer' && (!isset($params['password'],$params['confirm_password']) || !hash_equals($params['password'],$params['confirm_password']))) {
        wp_send_json_error(['code'=>'invalid_profile'],400);
    }
    $engine = kidia_website_auth_engine();
    $request = new WP_REST_Request('POST');
    $request->set_body_params($params);
    $result = $engine->$method($request);
    if (is_wp_error($result)) wp_send_json_error(['code'=>$result->get_error_code()], (int)($result->get_error_data()['status'] ?? 400));
    wp_send_json_success($result->get_data(),$result->get_status());
}
add_action('wp_ajax_kidia_shared_auth','kidia_shared_auth_action');
add_action('wp_ajax_nopriv_kidia_shared_auth','kidia_shared_auth_action');
add_action('wp_enqueue_scripts', static function(): void {
    if (!class_exists('Kidia_Store_Custom_Login_Page_V020') || !Kidia_Store_Custom_Login_Page_V020::instance()->is_login_page()) return;
    wp_enqueue_script('kidia-shared-auth',plugin_dir_url(__FILE__).'kidia-shared-auth.js',['kidia-login-page'],'1.0.2',true);
    wp_localize_script('kidia-shared-auth','KidiaSharedAuth',[
        'nonce'=>wp_create_nonce('mobishop_website_auth'),
        'ajaxUrl'=>admin_url('admin-ajax.php'),
        'loginUrl'=>Kidia_Store_Custom_Login_Page_V020::instance()->get_login_url(),
        'logoutUrl'=>wp_logout_url(Kidia_Store_Custom_Login_Page_V020::instance()->get_login_url()),
    ]);
},110);
