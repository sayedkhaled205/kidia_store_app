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
function web_assert($condition, $label) { global $web_checks; if (!$condition) throw new RuntimeException($label); $web_checks++; }
function start_web($bridge) {
    $state = bin2hex(random_bytes(32)); $verifier = bin2hex(random_bytes(32));
    $response=$bridge->start(new WP_REST_Request(['state'=>$state,'challenge'=>hash('sha256',$verifier)]));
    parse_str(parse_url($response->data['authorize_url'], PHP_URL_QUERY), $args);
    return [$args['mobishop_login'],$state,$verifier];
}
web_assert($bridge->config()->data['enabled'], 'Detects configured website flow');
web_assert(is_wp_error($bridge->start(new WP_REST_Request(['state'=>'bad','challenge'=>'bad']))), 'Invalid request rejected');
[$id,$state,$verifier] = start_web($bridge);
$key='_mobishop_web_login_'.$id;
$secret=bin2hex(random_bytes(32));
$options[$key]['binding']=hash('sha256',$secret);
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

// Shared IP limit is enforced before persisting another request.
$rate='mobishop_web_rate_'.hash_hmac('sha256',$_SERVER['REMOTE_ADDR'],wp_salt());
set_transient($rate,30,600);
$before=count($options);
$blocked=$bridge->start(new WP_REST_Request(['state'=>str_repeat('a',64),'challenge'=>str_repeat('b',64)]));
web_assert(is_wp_error($blocked) && $blocked->get_error_data()['status']===429 && count($options)===$before, 'Rate-limited attempt has no stored authorization');
echo 'Connector 1.46.75 website auth: '.$web_checks.' contract/security checks passed.'.PHP_EOL;
