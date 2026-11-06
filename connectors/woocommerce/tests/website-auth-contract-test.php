<?php
/** Security regressions for browser binding and one-time native exchange. */
require __DIR__ . '/auth-endpoint-contract-test.php';
require_once ( getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__).'/source' ) . '/api/class-website-auth-endpoint.php';
class Kidia_Firebase_OTP_265 {}

$options = array( 'kidia_login_page_id' => 10 );
function get_option( $key, $default = false ) { global $options; return $options[$key] ?? $default; }
function add_option( $key, $value, $unused = '', $autoload = false ) { global $options; if (isset($options[$key])) return false; $options[$key] = $value; return true; }
function delete_option( $key ) { global $options; unset($options[$key]); return true; }
function get_permalink( $id ) { return home_url('/login/'); }
function wc_get_page_permalink( $page ) { return $GLOBALS['woo_account_url'] ?? home_url('/my-account/'); }
function wc_get_page_id( $page ) { return $GLOBALS['woo_account_id'] ?? 20; }
function maybe_serialize( $value ) { return serialize($value); }
function wp_schedule_single_event( $time, $hook, $args ) {}
function is_user_logged_in() { return $GLOBALS['web_logged_in'] ?? false; }
function wp_verify_nonce($nonce, $action) { return $nonce === 'valid-'.$action; }
function wp_logout() { $GLOBALS['web_logged_in']=false; $GLOBALS['web_logouts']=($GLOBALS['web_logouts']??0)+1; }
function wp_nonce_field($action) { echo '<input type="hidden" name="_wpnonce" value="valid-'.$action.'">'; }
function esc_html($value) { return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8'); }
define('MOBISHOP_URL', 'https://shop.example.com/wp-content/plugins/mobi2app-connector/');
define('MOBISHOP_VERSION', 'test');
function wp_register_style($handle,$url,...$args) { $GLOBALS['web_styles'][$handle]=$url; }
function wp_enqueue_style($handle) { $GLOBALS['web_style_queue'][]=$handle; }
function wp_print_styles($handles) { foreach($handles as $handle) echo '<link rel="stylesheet" href="'.esc_html($GLOBALS['web_styles'][$handle]).'">'; }

// Simulate compare-and-swap against a persistent option store, including races.
$wpdb = new class {
    public $options = 'wp_options';
    public $race = false;
    public $usermeta = 'wp_usermeta';
    public $last_error = '';
    public function prepare($sql, ...$args) { return [$sql, $args]; }
    public function get_var($query) {
        [$sql,$args] = $query;
        if (str_contains($sql, 'GET_LOCK')) return '1';
        throw new RuntimeException('Unexpected read in website auth fixture');
    }
    public function get_results($query, $output) {
        [$sql,$args] = $query;
        if ($output !== ARRAY_A || $sql !== 'SELECT meta_value FROM wp_usermeta WHERE user_id = %d AND meta_key = %s ORDER BY umeta_id ASC LIMIT 1') {
            throw new RuntimeException('Unexpected session read in website auth fixture');
        }
        return mobishop_session_db_rows((int)$args[0], $args[1]);
    }
    public function query($query) {
        global $options;
        [$sql, $args] = $query;
        if (str_contains($sql, 'RELEASE_LOCK')) return 1;
        if ($this->race) { $this->race=false; return 0; }
        if (str_starts_with($sql, 'DELETE')) {
            [$key,$old] = $args;
            if (serialize($options[$key] ?? false) !== $old) return 0;
            unset($options[$key]); return 1;
        }
        [$next,$key,$old] = $args;
        if (serialize($options[$key] ?? false) !== $old) return 0;
        $options[$key] = unserialize($next); return 1;
    }
};
$issued = 0;
$bridge = new MobiShop_Website_Auth_Endpoint(
    function($user) use (&$issued) { $issued++; return new WP_REST_Response(['user_id'=>$user->ID]); },
    fn($user) => $user->ID === 7
);
$web_checks = 0;
$bridge->register_assets();
function web_assert($condition, $label) { global $web_checks; if (!$condition) throw new RuntimeException($label); $web_checks++; }
function start_web($bridge) {
    $state = bin2hex(random_bytes(32)); $verifier = bin2hex(random_bytes(32));
    $response=$bridge->start(new WP_REST_Request(['state'=>$state,'challenge'=>hash('sha256',$verifier)]));
    parse_str(parse_url($response->data['authorize_url'], PHP_URL_QUERY), $args);
    return [$args['mobishop_login'],$state,$verifier];
}
web_assert($bridge->config()->data['enabled'], 'Detects configured website flow');
web_assert($bridge->facebook_enabled(), 'Configured Facebook is available');
$destination = new ReflectionMethod($bridge, 'destination');
$destination->setAccessible(true);
web_assert(str_contains($destination->invoke($bridge, ['provider'=>'facebook']), 'loginSocial=facebook'), 'Anonymous Facebook starts chosen provider');
$GLOBALS['web_logged_in'] = true;
$GLOBALS['mobishop_social_html_override'] = '';
web_assert($destination->invoke($bridge, ['provider'=>'facebook']) === get_permalink(10), 'Existing browser account goes to confirmation despite hidden Nextend button');
$GLOBALS['web_logged_in'] = false;
web_assert(!$bridge->facebook_enabled(), 'Disabled provider is hidden');
foreach (['https://evil.example/wp-login.php?loginSocial=facebook','https://user@shop.example.com/wp-login.php?loginSocial=facebook','https://shop.example.com/wp-login.php?loginSocial=google','//evil.example/?loginSocial=facebook'] as $unsafe) {
    $GLOBALS['mobishop_social_html_override'] = '<a href="'.$unsafe.'">Login</a>';
    web_assert(!$bridge->facebook_enabled(), 'Unsafe or wrong-provider URL rejected');
}
unset($GLOBALS['mobishop_social_html_override']);
$before_provider_start = count($options);
web_assert(is_wp_error($bridge->start(new WP_REST_Request(['provider'=>'unknown']))), 'Unknown provider is rejected before creating attempt');
web_assert(count($options)===$before_provider_start, 'Rejected provider creates no pending login');
$fb=$bridge->start(new WP_REST_Request(['provider'=>'facebook','state'=>str_repeat('c',64),'challenge'=>str_repeat('d',64)]));
parse_str(parse_url($fb->data['authorize_url'],PHP_URL_QUERY),$fb_args);
web_assert($options['_mobishop_web_login_'.$fb_args['mobishop_login']]['provider']==='facebook', 'Chosen provider retained in bound server attempt');
$options['kidia_login_page_id']=0;$GLOBALS['woo_account_id']=-1;
web_assert(!$bridge->facebook_enabled(), 'Missing account page disables provider');
$options['kidia_login_page_id']=10;unset($GLOBALS['woo_account_id']);
web_assert(is_wp_error($bridge->start(new WP_REST_Request(['state'=>'bad','challenge'=>'bad']))), 'Invalid request rejected');
[$id,$state,$verifier] = start_web($bridge);
$key='_mobishop_web_login_'.$id;
$secret=bin2hex(random_bytes(32));
$options[$key]['binding']=hash('sha256',$secret);
$_COOKIE['__Host-mobishop_login']=$id.'.'.$secret;
foreach ([$id.'.'.$secret."\n", [$id.'.'.$secret], '<b>'.$id.'.'.$secret.'</b>'] as $malformed) {
    $_COOKIE['__Host-mobishop_login']=$malformed;
    $bridge->verified(get_user_by('id',7));
    web_assert($options[$key]['user']===0, 'Malformed browser binding cannot authenticate');
}
$_COOKIE['__Host-mobishop_login']=$id.'.'.$secret;
$bridge->verified(get_user_by('id',8));
web_assert($options[$key]['user']===0, 'Privileged account blocked');
$_COOKIE['__Host-mobishop_login']=$id.'.'.str_repeat('f',64);
$bridge->verified(get_user_by('id',7));
web_assert($options[$key]['user']===0, 'Wrong browser cannot authenticate request');
$_COOKIE['__Host-mobishop_login']=$id.'.'.$secret;
$bridge->verified(get_user_by('id',7));
web_assert($options[$key]['user']===7, 'Verified account captured in matching browser');
$code=$id.'.'.bin2hex(random_bytes(32));
$params=['code'=>$code,'state'=>$state,'verifier'=>$verifier];
web_assert(is_wp_error($bridge->exchange(new WP_REST_Request($params))), 'Cannot exchange before callback');
$options[$key]['code']=hash('sha256',$code);
foreach (['state','verifier','code'] as $field) {
    $bad=$params; $bad[$field]=str_repeat('e',64);
    web_assert(is_wp_error($bridge->exchange(new WP_REST_Request($bad))), 'Reject altered '.$field);
}
$wpdb->race=true;
web_assert(is_wp_error($bridge->exchange(new WP_REST_Request($params))), 'Losing concurrent exchange cannot issue session');
web_assert($issued===0, 'No premature session');
update_user_meta(7,'kidia_phone_setup_required',true);
web_assert(is_wp_error($bridge->exchange(new WP_REST_Request($params))), 'Required website account completion preserved');
update_user_meta(7,'kidia_phone_setup_required',false);
$result=$bridge->exchange(new WP_REST_Request($params));
web_assert($result->data['user_id']===7 && $issued===1, 'Selected customer session issued');
web_assert(is_wp_error($bridge->exchange(new WP_REST_Request($params))) && $issued===1, 'Replay rejected');
[$id,$state,$verifier] = start_web($bridge);
$options['_mobishop_web_login_'.$id]['expires']=time()-1;
$code=$id.'.'.bin2hex(random_bytes(32));
web_assert(is_wp_error($bridge->exchange(new WP_REST_Request(['code'=>$code,'state'=>$state,'verifier'=>$verifier]))), 'Expired request rejected');

// Registration is exercised through the actual current customer auth endpoint.
$endpoint->register();
foreach ( $GLOBALS['mobishop_actions']['rest_api_init'] as $callback ) $callback();
foreach ( ['config'=>'GET','start'=>'POST','exchange'=>'POST'] as $route=>$verb ) {
    $registration=$GLOBALS['mobishop_routes']['mobishop/v1/auth/website/'.$route] ?? null;
    web_assert(is_array($registration) && $registration['methods']===$verb, 'Published endpoint registers website '.$route);
}
web_assert(count($GLOBALS['mobishop_actions']['wp_login'] ?? [])===1, 'WordPress verified login hook registered');
web_assert(count($GLOBALS['mobishop_actions']['nsl_login'] ?? [])===2, 'Website social login hook and existing social hook retained');

$login_url=new ReflectionMethod($bridge,'login_url');
$login_url->setAccessible(true);
web_assert($login_url->invoke($bridge)===home_url('/login/'), 'Existing verified OTP/account-selection page takes precedence');
$options['kidia_login_page_id']=0;
web_assert($login_url->invoke($bridge)===home_url('/my-account/'), 'Any WooCommerce store discovers its account page without Kidia configuration');
$GLOBALS['woo_account_id']=-1;
web_assert(!$bridge->config()->data['enabled'], 'Absent WooCommerce account page is not falsely ready');
$GLOBALS['woo_account_id']=20;
$GLOBALS['woo_account_url']='http://shop.example.com/my-account/';
web_assert(!$bridge->config()->data['enabled'], 'Insecure Woo account URL disables bridge');
unset($GLOBALS['woo_account_url']);
foreach ( ['https://other.example/login/','http://shop.example.com/login/','https://user:pass@shop.example.com/login/','https://shop.example.com:444/login/','https://shop.example.com/login/#part'] as $unsafe ) {
    $GLOBALS['website_login_override']=$unsafe;
    web_assert(!$bridge->config()->data['enabled'], 'Unsafe configured login origin rejected: '.$unsafe);
    $unavailable=$bridge->start(new WP_REST_Request(['state'=>str_repeat('a',64),'challenge'=>str_repeat('b',64)]));
    web_assert(is_wp_error($unavailable) && $unavailable->get_error_data()['status']===404, 'No attempt created while website flow unavailable');
}
$GLOBALS['website_login_override']='https://SHOP.EXAMPLE.COM/login/';
web_assert($bridge->config()->data['enabled'], 'Host comparison is case insensitive');
unset($GLOBALS['website_login_override']);
$GLOBALS['mobishop_home']='https://shop.example.com/store/';
web_assert($login_url->invoke($bridge)==='https://shop.example.com/store/my-account/', 'WordPress subdirectory login is preserved');
[$sub_id,$sub_state,$sub_verifier]=start_web($bridge);
web_assert(isset($options['_mobishop_web_login_'.$sub_id]), 'Subdirectory store can start authorization');
$GLOBALS['mobishop_home']='http://shop.example.com/';
$GLOBALS['website_login_override']='https://shop.example.com/my-account/';
web_assert(!$bridge->config()->data['enabled'], 'Insecure home origin cannot advertise HTTPS native authorization');
unset($GLOBALS['mobishop_home'],$GLOBALS['website_login_override']);
$config=$bridge->config();
web_assert($config->data['version']===1 && str_contains($config->headers['Cache-Control'],'no-store'), 'Version 1 contract and no-store responses retained');

// Authorization is rechecked at exchange, even when the account changed after login.
[$id,$state,$verifier]=start_web($bridge);
$key='_mobishop_web_login_'.$id;
$code=$id.'.'.bin2hex(random_bytes(32));
$options[$key]['code']=hash('sha256',$code);
$params=['code'=>$code,'state'=>$state,'verifier'=>$verifier];
foreach ([0,8,999999] as $unavailable_user) {
    $options[$key]['user']=$unavailable_user;
    $blocked=$bridge->exchange(new WP_REST_Request($params));
    web_assert(is_wp_error($blocked) && $blocked->get_error_data()['status']===403 && $issued===1, 'Missing or privileged account cannot obtain mobile session');
}
$options[$key]['user']=7;
$options[$key]['expires']=time()-1;
web_assert(is_wp_error($bridge->exchange(new WP_REST_Request($params))) && $issued===1, 'Expired issued callback cannot obtain mobile session');

// CAS rejects a stale browser binding mutation; verifying after code issuance cannot switch user.
[$id,$state,$verifier]=start_web($bridge);
$key='_mobishop_web_login_'.$id;
$secret=bin2hex(random_bytes(32));
$options[$key]['binding']=hash('sha256',$secret);
$_COOKIE['__Host-mobishop_login']=$id.'.'.$secret;
$wpdb->race=true;
$bridge->verified(get_user_by('id',7));
web_assert($options[$key]['user']===0, 'Losing browser-binding update does not authorize customer');
$options[$key]['code']=str_repeat('a',64);
$bridge->verified(get_user_by('id',7));
web_assert($options[$key]['user']===0, 'Issued callback cannot be reassigned to another login');

// A privileged browser session can explicitly switch, but can never continue
// into the app. A pending request and its PKCE/binding survive the switch.
$switch = new ReflectionMethod($bridge, 'handle_switch');
$confirm = new ReflectionMethod($bridge, 'confirmation');
$admin = get_user_by('id',8);
$admin->display_name = '<Admin fixture>';
ob_start(); $confirm->invoke($bridge, $id, $admin, true); $html=ob_get_clean();
web_assert(str_contains($html, 'public/css/mobishop-website-auth-confirmation.css') && !str_contains($html, '<style'), 'Standalone confirmation loads only its registered stylesheet');
web_assert(str_contains($html, 'value="switch"') && !str_contains($html, 'value="continue"'), 'Admin gets switch only, never customer continuation');
web_assert(str_contains($html, '&lt;Admin fixture&gt;') && !str_contains($html, '<Admin fixture>'), 'Confirmation escapes the displayed account');
ob_start(); $confirm->invoke($bridge, $id, get_user_by('id',7), false); $html=ob_get_clean();
web_assert(str_contains($html, 'value="switch"') && str_contains($html, 'value="continue"'), 'Customer retains both confirmation choices');
[$id,$state,$verifier]=start_web($bridge); $key='_mobishop_web_login_'.$id;
$secret=bin2hex(random_bytes(32));
$options[$key]['binding']=hash('sha256',$secret);
$options[$key]['provider']='facebook';
$_COOKIE['__Host-mobishop_login']=$id.'.'.$secret;
$before_switch=$options[$key]; $GLOBALS['web_logouts']=0; $GLOBALS['web_logged_in']=true;
$_POST=['choice'=>'switch','_wpnonce'=>'valid-mobishop_continue_'.$id];
$_SERVER['REQUEST_METHOD']='GET';
web_assert(!$switch->invoke($bridge,$id), 'GET cannot log a browser out');
$_SERVER['REQUEST_METHOD']='POST'; $_POST['_wpnonce']='invalid';
web_assert(!$switch->invoke($bridge,$id), 'Invalid CSRF proof cannot switch');
$_POST['_wpnonce']='valid-mobishop_continue_'.$id;
foreach (['valid-mobishop_continue_'.$id."\n", ['valid-mobishop_continue_'.$id], '<b>valid-mobishop_continue_'.$id.'</b>'] as $bad_nonce) {
    $_POST['_wpnonce']=$bad_nonce;
    web_assert(!$switch->invoke($bridge,$id), 'Malformed nonce does not change identity');
}
$_POST['_wpnonce']='valid-mobishop_continue_'.$id;
$_COOKIE['__Host-mobishop_login']=$id.'.'.str_repeat('f',64);
web_assert(!$switch->invoke($bridge,$id), 'Different browser cannot switch attempt');
$_COOKIE['__Host-mobishop_login']=$id.'.'.$secret;
$wpdb->race=true;
web_assert(!$switch->invoke($bridge,$id), 'Losing CAS cannot switch');
web_assert($GLOBALS['web_logouts']===0 && $options[$key]===$before_switch, 'Rejected switches preserve browser identity and request');
web_assert($switch->invoke($bridge,$id), 'Admin with no captured customer can explicitly switch');
web_assert($GLOBALS['web_logouts']===1 && $options[$key]['user']===0 && $options[$key]!==$before_switch, 'Switch performs a real database update even when user was zero');
foreach (['provider','state','challenge','binding','expires','code'] as $field) web_assert($options[$key][$field]===$before_switch[$field], 'Switch preserves '.$field);
web_assert(str_contains($destination->invoke($bridge,$options[$key]),'loginSocial=facebook'), 'Switched browser restarts selected provider');
$options[$key]['user']=7;
web_assert($switch->invoke($bridge,$id) && $options[$key]['user']===0, 'Switch clears previous customer authorization');
$options[$key]['code']=str_repeat('a',64);
web_assert(!$switch->invoke($bridge,$id) && $GLOBALS['web_logouts']===2, 'Issued callback cannot be switched');
$options[$key]['code']=''; $options[$key]['expires']=time()-1;
web_assert(!$switch->invoke($bridge,$id) && $GLOBALS['web_logouts']===2, 'Expired attempt cannot log browser out');
unset($_POST,$_COOKIE['__Host-mobishop_login']); $_SERVER['REQUEST_METHOD']='GET';

// Shared IP limit is enforced before persisting another request.
$rate='mobishop_web_rate_'.hash_hmac('sha256',$_SERVER['REMOTE_ADDR'],wp_salt());
set_transient($rate,30,600);
$before=count($options);
$blocked=$bridge->start(new WP_REST_Request(['state'=>str_repeat('a',64),'challenge'=>str_repeat('b',64)]));
web_assert(is_wp_error($blocked) && $blocked->get_error_data()['status']===429 && count($options)===$before, 'Rate-limited attempt has no stored authorization');
echo 'Connector 1.46.75 website auth: '.$web_checks.' contract/security checks passed.'.PHP_EOL;
