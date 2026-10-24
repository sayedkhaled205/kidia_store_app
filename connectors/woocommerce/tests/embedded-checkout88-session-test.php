<?php
namespace Automattic\WooCommerce\StoreApi\Utilities {
    class CartTokenUtils {
        static $valid = true;
        static $key = 't_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        static function validate_cart_token($token) { return self::$valid && $token === 'fixture-cart'; }
        static function get_cart_token_payload($token) { return ['user_id'=>self::$key,'iss'=>'store-api','exp'=>time()+300]; }
    }
}
namespace {
define('ABSPATH', __DIR__); define('ARRAY_A','ARRAY_A'); define('COOKIEHASH','fixture');
define('MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY', 'fixture-only');
class WP_Error { function __construct(public $code, public $message, public $data) {} }
class WP_REST_Response { public $headers=[]; function __construct(public $data, public $status) {} function header($a,$b) { $this->headers[$a]=$b; } }
class WP_REST_Request { function get_header($key) { return $key==='Cart-Token'?'fixture-cart':''; } }
class MobiShop_Customer_Auth_Endpoint { function session_context_from_request($r) { return ['user_id'=>10,'session_hash'=>str_repeat('a',64),'expires'=>time()+300]; } }
class FixtureDb88 {
    public $prefix='wp_', $options='wp_options', $last_error='', $active=null, $owner=10, $expired=false, $empty=false, $race=false;
    function prepare($sql, ...$args) { return [$sql,$args]; }
    function get_row($q,$format) {
        return ['session_expiry'=>time()+($this->expired?-1:300), 'session_value'=>serialize([
            'cart'=>serialize($this->empty?[]:['item'=>['product_id'=>20,'quantity'=>1,'extension_metadata'=>'retained']]),
            'customer'=>serialize(['id'=>$this->owner]),'order_awaiting_payment'=>999,
        ])];
    }
    function get_var($q) { return $this->active; }
    function query($q) {
        [$sql,$args]=$q; [$key,$expected]=$args;
        if ($this->race || !isset($GLOBALS['options88'][$key]) || serialize($GLOBALS['options88'][$key])!==$expected) return 0;
        unset($GLOBALS['options88'][$key]); return 1;
    }
}
$wpdb=new FixtureDb88(); $options88=[]; $transients88=[]; $sessions88=[['hash'=>str_repeat('a',64),'expires'=>time()+300]];
$current88=10; $writes88=[];
function is_wp_error($x) { return $x instanceof WP_Error; }
function get_current_user_id() { return $GLOBALS['current88']; }
function wp_is_using_https() { return true; }
function get_user_meta(...$args) { return $GLOBALS['sessions88']; }
function home_url($path) { return 'https://merchant.example/shop/'; }
function untrailingslashit($s) { return rtrim($s,'/'); }
function wc_get_checkout_url() { return 'https://merchant.example/shop/check-out/'; }
function wp_parse_url(...$args) { return parse_url(...$args); }
function maybe_unserialize($s) { return is_string($s)?unserialize($s):$s; }
function maybe_serialize($s) { return serialize($s); }
function add_option($key,$value,...$args) { $GLOBALS['options88'][$key]=$value; return true; }
function get_option($key) { return $GLOBALS['options88'][$key]??false; }
function wp_schedule_single_event(...$args) {}
function add_query_arg($key,$value,$url) { return $url.'?'.$key.'='.$value; }
function nocache_headers() {}
function wp_cache_delete(...$args) {}
function wp_set_current_user($id) { $GLOBALS['current88']=$id; }
function apply_filters($hook,$value) { return $value; }
function wp_die(...$args) { throw new \RuntimeException('denied'); }
function set_transient($key,$value,$ttl) { $GLOBALS['transients88'][$key]=$value; }
function get_transient($key) { return $GLOBALS['transients88'][$key]??false; }
function WC() {
    static $wc; return $wc??= (object)['session'=>new class {
        private $customer = 'old-guest';
        function init_session_cookie() { $this->customer = (string) get_current_user_id(); }
        function get_customer_id() { return $this->customer; }
        function set($key,$value) { $GLOBALS['writes88'][$key]=$value; }
        function set_customer_session_cookie($v) {}
        function save_data() {}
    }];
}
require __DIR__.'/../source/api/class-embedded-checkout88.php';
$count=0;
function expect88($ok,$message) { global $count; if (!$ok) throw new \RuntimeException($message); ++$count; }
function denied88($fn,$message) { try { $fn(); } catch (\RuntimeException $e) { expect88($e->getMessage()==='denied',$message); return; } throw new \RuntimeException($message); }
$bridge=new MobiShop_Embedded_Checkout88(); $request=new WP_REST_Request();
$result=$bridge->issue($request);
expect88($result instanceof WP_REST_Response,'valid session issues ticket');
expect88(strlen($result->data['ticket'])===64,'ticket entropy');
expect88(!str_contains($result->data['url'],$result->data['ticket']),'secret not in URL');
expect88($result->headers['Cache-Control']==='no-store, private','no cache');
expect88(!isset($result->data['session_hash']) && !isset($result->data['cart_key']),'no mobile/cart credential disclosure');
foreach (['owner'=>11,'expired'=>true,'empty'=>true,'active'=>'uncertain','last_error'=>'db unavailable'] as $key=>$value) {
    $old=$wpdb->$key; $wpdb->$key=$value;
    expect88(is_wp_error($bridge->issue($request)), 'reject '.$key); $wpdb->$key=$old;
}
\Automattic\WooCommerce\StoreApi\Utilities\CartTokenUtils::$key='11';
expect88(is_wp_error($bridge->issue($request)),'another customer cart key');
\Automattic\WooCommerce\StoreApi\Utilities\CartTokenUtils::$key='t_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
$_GET=['mobishop-checkout88'=>'1']; $_POST=['ticket'=>$result->data['ticket']]; $_SERVER['REQUEST_METHOD']='GET';
denied88(fn()=>$bridge->redeem(),'GET forbidden'); $_SERVER['REQUEST_METHOD']='POST';
$saved=$sessions88; $sessions88=[];
denied88(fn()=>$bridge->redeem(),'revocation before redeem'); $sessions88=$saved;
$wpdb->race=true; denied88(fn()=>$bridge->redeem(),'concurrent redeem rejected'); $wpdb->race=false;
$wpdb->active='new-uncertain-attempt'; denied88(fn()=>$bridge->redeem(),'dispatch started after ticket creation'); $wpdb->active=null;
$bridge->redeem(); $bridge->restore_cart();
expect88(WC()->session->get_customer_id()==='10','early guest handler rebound to ticket customer');
expect88($writes88['cart']['item']['extension_metadata']==='retained','extension cart metadata retained');
expect88(!isset($writes88['customer']) && !isset($writes88['order_awaiting_payment']),'no source identity or pending order copied');
expect88($bridge->customer_capabilities(['read'=>true,'manage_options'=>true,'manage_woocommerce'=>true],[],[],(object)['ID'=>10])===['read'=>true],'never administrator capabilities');
denied88(fn()=>$bridge->redeem(),'ticket replay rejected');
// A revoked/stale cookie must not fall back to an existing administrator cookie.
$_COOKIE=['mobishop_checkout88'=>str_repeat('b',64)];
expect88((new MobiShop_Embedded_Checkout88())->scoped_user(1)===0,'stale cookie cannot use another web login');
$scope=array_values($transients88)[0]; $transients88['mobishop_checkout88_'.hash('sha256',str_repeat('b',64))]=$scope;
$_SERVER['REQUEST_URI']='/shop/check-out/'; $_GET=[];
expect88((new MobiShop_Embedded_Checkout88())->scoped_user(1)===10,'checkout uses exact customer');
$current88=0;
(new MobiShop_Embedded_Checkout88())->restore_identity();
expect88($current88===10,'cached anonymous user resolved before Woo initializes');
$_SERVER['REQUEST_URI']='/shop/wp-admin/';
expect88((new MobiShop_Embedded_Checkout88())->scoped_user(1)===0,'cookie cannot grant admin session');
$current88=1;
(new MobiShop_Embedded_Checkout88())->restore_identity();
expect88($current88===0,'out-of-scope cookie clears cached administrator identity');
$_SERVER['REQUEST_URI']='/shop/check-out/'; $sessions88=[];
expect88((new MobiShop_Embedded_Checkout88())->scoped_user(1)===0,'logout immediately revokes scoped cookie');
$current88=10;
(new MobiShop_Embedded_Checkout88())->restore_identity();
expect88($current88===0,'revoked cookie cannot retain cached customer identity');
$_COOKIE=[]; $current88=22;
(new MobiShop_Embedded_Checkout88())->restore_identity();
expect88($current88===22,'ordinary website login is unchanged without scoped cookie');
echo "$count embedded checkout session checks passed\n";
}
