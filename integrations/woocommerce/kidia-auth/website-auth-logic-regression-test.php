<?php
/** Synthetic-only audit. Runs the actual selected website class; does not boot WordPress. */
define('HOUR_IN_SECONDS', 3600); define('MINUTE_IN_SECONDS', 60); define('ABSPATH', __DIR__); define('COOKIEPATH', '/');
$source = $argv[1] ?? __DIR__.'/website/kidia-login-page.php';
$GLOBALS['users'] = []; $GLOBALS['meta'] = []; $GLOBALS['current'] = 0;
$GLOBALS['is_account'] = false; $GLOBALS['is_checkout'] = false; $GLOBALS['endpoint'] = '';
$GLOBALS['options'] = ['kidia_login_page_id'=>1];
$GLOBALS['pages'] = [1=>'/login-register/',2=>'/my-account/',3=>'/wishlist/'];
$GLOBALS['account_page_id'] = 2; $GLOBALS['wishlist_page_id'] = 3;
class Redirected extends Exception {}
function sanitize_key($s) { return preg_replace('/[^a-z0-9_-]/', '', strtolower($s)); }
function sanitize_email($s) { return $s; } function sanitize_text_field($s) { return strip_tags($s); }
function is_email($s) { return filter_var($s, FILTER_VALIDATE_EMAIL) !== false; }
function absint($s) { return abs((int)$s); } function wp_unslash($s) { return $s; }
function is_wp_error($s) { return false; } function user_can($u, $cap) { return !empty($u->caps[$cap]); }
function get_user_meta($id, $key, $single=true) { return $GLOBALS['meta'][$id][$key] ?? ''; }
function update_user_meta($id, $key, $value) { $GLOBALS['meta'][$id][$key] = $value; }
function get_user_by($kind, $value) { foreach ($GLOBALS['users'] as $user) if (($kind === 'id' && $user->ID === $value) || ($kind === 'email' && $user->user_email === $value)) return $user; return false; }
function get_users($args) { $out=[]; foreach ($GLOBALS['users'] as $u) { $matched=false; foreach($args['meta_query'] ?? [] as $clause) if(is_array($clause) && in_array(get_user_meta($u->ID,$clause['key']),$clause['value'],true)) $matched=true; if($matched) $out[]=($args['fields'] ?? '') === 'ids' ? $u->ID : $u; } return ($args['number'] ?? -1) < 0 ? $out : array_slice($out,0,$args['number']); }
function wp_update_user($data) { foreach($data as $k=>$v) $GLOBALS['users'][$data['ID']]->$k=$v; return $data['ID']; }
function wc_get_order($id) { return $GLOBALS['order']; }
function email_exists($email) { $u=get_user_by('email',$email); return $u ? $u->ID : false; }
function get_option($key,$default=false) { return $GLOBALS['options'][$key] ?? $default; } function get_post_type($id) { return 'page'; } function get_post_status($id) { return 'publish'; }
function home_url($path='/') { return 'https://example.test'.$path; }
function get_permalink($id=0) { return home_url($GLOBALS['pages'][$id ?: 1] ?? '/'); }
function wc_get_page_id($name) { return $name === 'myaccount' ? $GLOBALS['account_page_id'] : -1; }
function get_page_by_path($path) { return $path === 'wishlist' && $GLOBALS['wishlist_page_id'] ? (object)['ID'=>$GLOBALS['wishlist_page_id']] : null; }
function wc_get_cart_url() { return home_url('/cart/'); } function wc_get_checkout_url() { return home_url('/checkout/'); }
function wp_parse_url($url,$component=-1) { return parse_url($url,$component); }
function untrailingslashit($s) { return rtrim($s, '/\\'); } function esc_url_raw($s) { return $s; }
function wp_validate_redirect($url,$fallback) { $host=parse_url($url,PHP_URL_HOST); return $host && $host !== 'example.test' ? $fallback : $url; }
function remove_query_arg($keys,$url) { $p=parse_url($url); parse_str($p['query'] ?? '',$q); foreach($keys as $key)unset($q[$key]); return ($p['scheme']??'https').'://'.($p['host']??'example.test').(isset($p['port'])?':'.$p['port']:'').($p['path']??'/').($q?'?'.http_build_query($q):'').(isset($p['fragment'])?'#'.$p['fragment']:''); }
function add_query_arg($args,$url) { return $url.'?'.http_build_query($args); }
function wp_safe_redirect($url) { throw new Redirected($url); }
function is_account_page() { return $GLOBALS['is_account']; } function is_checkout() { return $GLOBALS['is_checkout']; }
function is_order_received_page() { return $GLOBALS['endpoint'] === 'order-received'; }
function is_wc_endpoint_url($endpoint) { return $GLOBALS['endpoint'] === $endpoint; }
function apply_filters($name,$value) { return $value; }
function is_user_logged_in() { return $GLOBALS['current'] > 0; } function get_current_user_id() { return $GLOBALS['current']; }
function current_user_can($cap) { return false; } function is_ssl() { return true; }
// Load real OTP identity filtering so password candidates include both verified and contact-only owners.
$firebase=file_get_contents(dirname($source).'/kidia-firebase-otp.php');
$start=strpos($firebase,'final class Kidia_Firebase_OTP_265'); $end=strpos($firebase,'// Run before'); eval(substr($firebase,$start,$end-$start));
$php=file_get_contents($source); eval(substr($php,strpos($php,'final class Kidia_Store_Custom_Login_Page_V020')));
$instance=Kidia_Store_Custom_Login_Page_V020::instance();
function invoke($method,...$args) { global $instance; return (new ReflectionMethod($instance,$method))->invoke($instance,...$args); }
$checks=0; $failures=[];
function check($ok,$label,$actual=null) { global $checks,$failures; $checks++; if(!$ok) $failures[]=['check'=>$label,'actual'=>$actual]; }
function fixtureUser($id,$email) { $GLOBALS['users'][$id]=(object)['ID'=>$id,'user_email'=>$email,'user_login'=>'fixture'.$id,'caps'=>[]]; }

fixtureUser(1,'owner@example.test');
$GLOBALS['meta'][1]=['kidia_login_phone'=>'+201000000001'];
$GLOBALS['order']=new class { function get_customer_id(){return 1;} function get_billing_email(){return 'recipient@example.test';} };
$instance->sync_order_email_to_customer(9001);
check($GLOBALS['users'][1]->user_email === 'owner@example.test','Checkout contact email must not replace the account email without email proof',$GLOBALS['users'][1]->user_email);
check(get_user_meta(1,'billing_email') === 'recipient@example.test','Checkout contact email may remain billing contact');
fixtureUser(2,'other@example.test');
$GLOBALS['order']=new class { function get_customer_id(){return 1;} function get_billing_email(){return 'other@example.test';} };
$instance->sync_order_email_to_customer(9002);
check($GLOBALS['users'][1]->user_email !== 'other@example.test','Existing owner email cannot be claimed by checkout');

// Shared household/legacy phone: one verified owner and another contact-only password account.
$GLOBALS['meta'][2]=['kidia_unverified_phone'=>'+201000000001'];
check(count(invoke('phone_password_candidates','01000000001')) === 2,'Password selector sees verified and contact-only accounts');
check(count(invoke('phone_signin_candidates','01000000001')) === 1,'OTP selector excludes unverified contact-only account');
check(invoke('phone_password_customer','01000000001','other@example.test')->ID === 2,'Explicit email can select contact-only account with password');
try { invoke('redirect_back_to_phone','01000000001','invalid_password'); } catch(Redirected $e) { parse_str(parse_url($e->getMessage(),PHP_URL_QUERY),$retry); }
check(($retry['kidia_phone_multiple'] ?? '') === '1','Failed password retry must retain the required account-email selector',$retry);
check(invoke('phone_password_customer','01000000001','') === false,'Missing account selector cannot guess a duplicate phone owner');

$_GET=[]; $_POST=[]; $_COOKIE=[];
foreach(['/cart/','/checkout/','/checkout/order-pay/9001/?pay_for_order=true&key=fixture-key#payment'] as $path) {
  $url=home_url($path); check(invoke('get_purchase_return_target',$url) === $url,'Preserves purchase destination '.$path);
}
foreach(['/my-account/','/my-account/orders/','/my-account/view-order/9001/','/wishlist/'] as $path) {
  $_GET=['redirect_to'=>home_url($path)]; $actual=invoke('get_redirect_target');
  check($actual === home_url($path),'Preserves explicitly requested customer destination '.$path,$actual);
}
foreach(['https://outside.test/checkout/','http://example.test/checkout/','https://example.test:8443/checkout/','https://example.test/checkout/../wp-admin/','https://example.test/wp-admin/','https://example.test/login-register/','https://user@example.test/checkout/'] as $url) {
  check(invoke('get_purchase_return_target',$url) === '','Rejects unsafe return URL '.$url);
}
check(invoke('get_purchase_return_target',home_url('/cart/?add-to-cart=12&wc-ajax=remove&coupon=fixture#totals')) === home_url('/cart/?coupon=fixture#totals'),'Return removes mutating cart query args and preserves benign context');
$GLOBALS['is_account']=true; $GLOBALS['endpoint']='lost-password';
check(!invoke('should_redirect_current_page'),'WooCommerce lost-password/reset endpoint remains accessible to a logged-out customer',invoke('should_redirect_current_page'));
$GLOBALS['endpoint']='orders';
check(invoke('should_redirect_current_page'),'Regular customer account endpoints still require login');
$GLOBALS['is_account']=false; $GLOBALS['is_checkout']=true;
foreach(['order-pay','order-received'] as $endpoint) { $GLOBALS['endpoint']=$endpoint; check(!invoke('should_redirect_current_page'),'Existing public checkout endpoint remains accessible '.$endpoint); }
$GLOBALS['endpoint']='';check(invoke('should_redirect_current_page'),'Regular checkout still requires login');
foreach(['/my-account/customer-logout/','/my-account/delete-payment-method/123/','/my-account/unknown/','/wishlist/unknown/'] as $path)check(invoke('get_purchase_return_target',home_url($path)) === '','Unknown or mutating customer destination is not allowed '.$path);
check(invoke('get_purchase_return_target',home_url('/my-account/orders/?action=delete&_wpnonce=fixture&page=2#orders')) === home_url('/my-account/orders/?page=2#orders'),'Customer return strips action/nonce but preserves pagination and fragment');
$GLOBALS['pages'][2]='/customer-area/'; $GLOBALS['options']['woocommerce_myaccount_orders_endpoint']='purchases';
check(invoke('get_purchase_return_target',home_url('/customer-area/purchases/2/')) === home_url('/customer-area/purchases/2/'),'Uses configured WooCommerce account page and endpoint');
check(invoke('get_purchase_return_target',home_url('/my-account/orders/')) === '','Old account path is not implicitly authorized after configuration changes');
check(invoke('get_purchase_return_target',home_url('/customer-area/orders/')) === '','Old endpoint slug is not implicitly authorized after configuration changes');
$GLOBALS['wishlist_page_id']=0;
check(invoke('get_purchase_return_target',home_url('/wishlist/')) === '','Missing wishlist page does not permit an invented route');
$GLOBALS['account_page_id']=-1;
check(invoke('get_purchase_return_target',home_url('/customer-area/purchases/')) === '','Missing WooCommerce account page does not permit an invented route');

echo json_encode(['checks'=>$checks,'failures'=>count($failures),'details'=>$failures],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES)."\n";
exit($failures?1:0);
