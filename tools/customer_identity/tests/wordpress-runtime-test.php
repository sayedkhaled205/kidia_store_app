<?php
/** Run only via wp eval-file in the disposable CI WordPress/MySQL installation. */
if ( getenv('CI') !== 'true' || ! defined('ABSPATH') || ! defined('DB_NAME') || DB_NAME !== 'kidia_identity_ci'
    || ! defined('WP_ENVIRONMENT_TYPE') || WP_ENVIRONMENT_TYPE !== 'local'
    || ! defined('DB_HOST') || ! preg_match('/^(127\.0\.0\.1|localhost)(:3306)?$/D', DB_HOST)
    || getenv('KIDIA_IDENTITY_RUNTIME_TEST') !== '1' ) {
    throw new RuntimeException('Refusing identity lifecycle test outside its disposable local CI database.');
}
if (get_option('active_plugins') !== array('woocommerce/woocommerce.php') || !function_exists('wc_create_order')) {
    throw new RuntimeException('Only the official WooCommerce plugin may be active.');
}
add_filter('pre_http_request', static fn() => new WP_Error('ci_network_disabled','Outbound HTTP disabled.'), PHP_INT_MAX);
add_filter('pre_wp_mail', static fn() => true, PHP_INT_MAX);
$_SERVER['HTTPS']='on'; $_SERVER['REMOTE_ADDR']='127.0.0.1';
if (defined('MOBISHOP_ACCOUNT_DELETION_ENABLED'))throw new RuntimeException('Unexpected preconfigured connector flag.');
define('MOBISHOP_ACCOUNT_DELETION_ENABLED',true);

/** The sole stub is the external identity service. No WordPress, database, lock or session stubs. */
final class MobiShop_Customer_Identity_Client {
    public static $failure=false, $attempts=0, $erased=array(), $snapshot_calls=0;
    public static function capabilities(): array {self::$snapshot_calls++;return array('available'=>true,'project_id'=>'synthetic-project');}
    public static function lookup(string $project,string $uid): array {self::$snapshot_calls++;return array('status'=>'present','created_at'=>'12345');}
    public static function erase(string $project,string $uid,string $created): array {
        self::$attempts++;
        if(self::$failure)throw new RuntimeException('Synthetic provider outage.');
        self::$erased[]=$uid;return array('status'=>'absent');
    }
}
$repo=realpath((string)getenv('GITHUB_WORKSPACE'));
if($repo===false||!is_file($repo.'/tools/customer_identity/tests/wordpress-runtime-test.php'))throw new RuntimeException('Missing checked-out fixture source.');
require $repo.'/tools/customer_identity/connector/class-customer-identity-links.php';
require $repo.'/tools/customer_identity/connector/class-customer-identity-guard.php';
require $repo.'/tools/customer_identity/connector/class-customer-identity-erasure-stage.php';
require $repo.'/connectors/woocommerce/source/api/class-customer-auth-endpoint.php';
require $repo.'/connectors/woocommerce/source/api/class-customer-account-deletion.php';
global $wpdb, $checks; // wp eval-file executes this script in method scope.
$checks=0;
function runtime_check(bool $ok,string $label): void {
    global $checks;
    if(!$ok)throw new RuntimeException('FAIL: '.$label);
    $checks++;echo 'PASS: '.$label.PHP_EOL;
}
function runtime_rest(string $route,array $body,string $token=''): WP_REST_Response {
    $request=new WP_REST_Request('POST','/mobishop/v1/'.$route);
    $request->set_header('Content-Type','application/json');
    if($token!=='')$request->set_header('X-MobiShop-Session',$token);
    $request->set_body(wp_json_encode($body));
    return rest_do_request($request);
}
$auth=new MobiShop_Customer_Auth_Endpoint();
$auth->register();
$deletion=new MobiShop_Customer_Account_Deletion();$deletion->register();
if(did_action('rest_api_init')){$auth->register_routes();$deletion->register_routes();}else{rest_get_server();}
wp_set_current_user(0);
$target=wp_insert_user(array('user_login'=>'ci-disposable-customer','user_email'=>'identity-target@example.invalid','user_pass'=>'ci-fixture-password-only','role'=>'customer'));
$other=wp_insert_user(array('user_login'=>'ci-unrelated-customer','user_email'=>'identity-other@example.invalid','user_pass'=>'ci-other-password-only','role'=>'customer'));
runtime_check(!is_wp_error($target)&&!is_wp_error($other),'Create disposable customers in real WordPress');
$target=(int)$target;$other=(int)$other;
update_user_meta($target,'billing_address_1','Synthetic fixture address');
update_user_meta($target,'_mobishop_wishlist_product_ids',array(123,456));
update_user_meta($other,'billing_address_1','Unrelated synthetic address');
update_user_meta($other,'_mobishop_wishlist_product_ids',array(789));
$product=new WC_Product_Simple();$product->set_name('CI fixture product');$product->set_regular_price('1');$product->save();
$review=wp_insert_comment(array('comment_post_ID'=>$product->get_id(),'user_id'=>$target,'comment_type'=>'review','comment_content'=>'Synthetic owned review','comment_approved'=>1));
$otherReview=wp_insert_comment(array('comment_post_ID'=>$product->get_id(),'user_id'=>$other,'comment_type'=>'review','comment_content'=>'Synthetic unrelated review','comment_approved'=>1));
$order=wc_create_order(array('customer_id'=>$target,'status'=>'completed'));
$otherOrder=wc_create_order(array('customer_id'=>$other,'status'=>'completed'));
runtime_check(!is_wp_error($order)&&!is_wp_error($otherOrder)&&$review>0&&$otherReview>0,'Create local orders and reviews without invoking gateways');
$first=array('project'=>'synthetic-project','uid'=>'ci-first-uid');$second=array('project'=>'synthetic-project','uid'=>'ci-committed-second-uid');
$identityKey=static fn(array $link):string=>'_mobishop_phone_firebase_identity_'.hash('sha256',$link['project'].'|'.$link['uid']);
update_user_meta($target,$identityKey($first),$first);
$login=runtime_rest('auth/login',array('email'=>'identity-target@example.invalid','password'=>'ci-fixture-password-only'));
$token=$login->get_data()['token']??'';
runtime_check($login->get_status()===200&&is_string($token)&&$token!=='','Real login issues an opaque merchant session');
$primed=get_user_meta($target);
// A separate real MySQL connection represents the other request's committed write.
// Its write occurs under the actual owner/UID guard and cannot invalidate this request-local WP cache.
$writerDb=new wpdb(DB_USER,DB_PASSWORD,DB_NAME,DB_HOST);
MobiShop_Customer_Identity_Guard::writer($target,$second,static function()use($writerDb,$target,$second,$identityKey):void {
    global $wpdb;
    runtime_check($writerDb->insert($wpdb->usermeta,array('user_id'=>$target,'meta_key'=>$identityKey($second),'meta_value'=>maybe_serialize($second)),array('%d','%s','%s'))===1,'Commit second identity on separate real MySQL connection under guard');
});
runtime_check(isset($primed[$identityKey($first)])&&!isset(get_user_meta($target)[$identityKey($second)]),'Real WordPress request cache remains stale after independent committed write');
$receipt=bin2hex(random_bytes(32));$body=array('receipt'=>$receipt,'confirmation'=>'delete-my-account');
$prepared=runtime_rest('customer/account/deletion/prepare',$body,$token);
runtime_check($prepared->get_status()===200&&($prepared->get_data()['status']??'')==='prepared','Real prepare endpoint accepts fresh merchant session');
$hash=hash_hmac('sha256',home_url('/').'|'.$wpdb->options.'|'.$receipt,wp_salt('auth'));
$intent=get_option('mobishop_deletion_intent_v1_'.$hash);
runtime_check(is_array($intent)&&array_column($intent['identityStage']['entries'],'uid')===array($first['uid'],$second['uid']),'Frozen durable intent includes both identities despite primed stale cache');
runtime_check(!MobiShop_Customer_Account_Deletion::is_pending($target),'Prepare does not mark account pending or revoke session');
$accepted=runtime_rest('customer/account/deletion/finalize',$body,$token);
runtime_check($accepted->get_status()===202&&($accepted->get_data()['user_id']??0)===$target,'Real finalize accepts exact authenticated owner');
$sessionRequest=new WP_REST_Request();$sessionRequest->set_header('X-MobiShop-Session',$token);
runtime_check(is_wp_error($auth->authenticate_route($sessionRequest)),'Accepted deletion invalidates real merchant session');
MobiShop_Customer_Identity_Client::$failure=true;
MobiShop_Customer_Account_Deletion::run_worker($target);
$job=get_option('mobishop_account_deletion_v1_'.$target);
runtime_check(MobiShop_Customer_Identity_Client::$attempts===1&&is_array($job)&&$job['phase']===0&&$job['identityStage']['cursor']===0,'Provider failure is reached and durable worker stage does not advance');
runtime_check(get_user_by('id',$target) instanceof WP_User&&get_comment($review)!==null&&(int)wc_get_order($order->get_id())->get_customer_id()===$target,'Provider outage preserves WordPress account, review and owned order');
MobiShop_Customer_Identity_Client::$failure=false;
$stalls=0;$previous='';
for($turn=0;$turn<40&&MobiShop_Customer_Account_Deletion::is_pending($target);$turn++) {
    MobiShop_Customer_Account_Deletion::run_worker($target);
    $job=get_option('mobishop_account_deletion_v1_'.$target);
    $progress=wp_json_encode($job);
    $stalls=$progress===$previous?$stalls+1:0;$previous=$progress;
    runtime_check($stalls<3,'Worker makes bounded durable progress after provider recovery');
}
runtime_check(!MobiShop_Customer_Account_Deletion::is_pending($target)&&get_user_by('id',$target)===false,'Actual worker finishes and removes disposable WordPress account');
runtime_check((int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->usermeta} WHERE user_id=%d",$target))===0,'Owned profile, wishlist and session metadata are erased from MySQL');
runtime_check((int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->comments} WHERE comment_ID=%d",$review))===0,'Own review is erased from real MySQL');
// The factory can return an object cached earlier in this same long-lived CLI request.
// A new order reads persisted storage, as a subsequent customer/admin request would.
$detachedOrder=new WC_Order($order->get_id());
echo 'Persisted retained order detached: '.((int)$detachedOrder->get_customer_id()===0?'yes':'no').PHP_EOL;
runtime_check($detachedOrder->get_id()===$order->get_id()&&(int)$detachedOrder->get_customer_id()===0,'Retained order persists with account association detached');
runtime_check(get_user_by('id',$other) instanceof WP_User&&get_user_meta($other,'_mobishop_wishlist_product_ids',true)===array(789)
    &&get_user_meta($other,'billing_address_1',true)==='Unrelated synthetic address'&&get_comment($otherReview)!==null
    &&(int)wc_get_order($otherOrder->get_id())->get_customer_id()===$other,'Unrelated customer, profile, wishlist, review and order remain unchanged');
runtime_check(MobiShop_Customer_Identity_Client::$erased===array($first['uid'],$second['uid']),'Only the two captured synthetic identities reach provider erase stub');
$remaining=(int)$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->options} WHERE option_name LIKE %s",$wpdb->esc_like('mobishop_identity_guard_v1_').'%'));
runtime_check($remaining===0&&get_option('mobishop_deletion_intent_v1_'.$hash,false)===false,'Real owner/UID reservations and identity intent are cleaned after completion');
$status=runtime_rest('customer/account/deletion/status',array('receipt'=>$receipt));
runtime_check(($status->get_data()['status']??'')==='completed','Receipt recovers durable completion without authentication');

// Privileged owner's customer-only shopping alias is not an independently erasable account.
$admin=wp_insert_user(array('user_login'=>'ci-protected-owner','user_email'=>'identity-owner@example.invalid','user_pass'=>'ci-owner-password-only','role'=>'administrator'));
runtime_check(!is_wp_error($admin),'Create synthetic protected administrator');$admin=(int)$admin;
update_user_meta($admin,'billing_address_1','Synthetic protected canonical address');
update_user_meta($admin,'shipping_address_1','Synthetic protected shipping address');
$canonicalOrder=wc_create_order(array('customer_id'=>$admin,'status'=>'completed'));
$alias=MobiShop_Storefront_Admin::resolve(get_user_by('id',$admin));
runtime_check($alias instanceof WP_User&&MobiShop_Storefront_Admin::data_owner_id($alias->ID)===$admin,'Actual owner bridge resolves administrator shopping alias');
$ownerLogin=runtime_rest('auth/login',array('email'=>'identity-owner@example.invalid','password'=>'ci-owner-password-only'));
$ownerToken=$ownerLogin->get_data()['token']??'';
runtime_check($ownerLogin->get_status()===200&&($ownerLogin->get_data()['user']['id']??0)===$alias->ID,'Owner login keeps existing isolated customer-only session behavior');
$adminCookie=WP_Session_Tokens::get_instance($admin)->create(time()+3600);
$aliasCookie=WP_Session_Tokens::get_instance($alias->ID)->create(time()+3600);
$protectedRequest=new WP_REST_Request('GET','/mobishop/v1/customer/account/deletion');$protectedRequest->set_header('X-MobiShop-Session',$ownerToken);
$availability=rest_do_request($protectedRequest);
runtime_check($availability->get_status()===200&&($availability->get_data()['available']??null)===false,'Protected owner alias does not advertise account erasure');
$protectedReceipt=bin2hex(random_bytes(32));$protectedBody=array('receipt'=>$protectedReceipt,'confirmation'=>'delete-my-account','platform'=>'ios','id_token'=>'must-not-reach-identity-provider');
$providerBefore=MobiShop_Customer_Identity_Client::$attempts+MobiShop_Customer_Identity_Client::$snapshot_calls;
foreach(array('prepare','apple-proof','finalize','')as $suffix){
 $response=runtime_rest('customer/account/deletion'.($suffix!==''?'/'.$suffix:''),$protectedBody,$ownerToken);
 runtime_check($response->get_status()>=400,'Protected owner alias rejects '.($suffix!==''?$suffix:'legacy acceptance').' before identity or revocation');
}
$protectedHash=hash_hmac('sha256',home_url('/').'|'.$wpdb->options.'|'.$protectedReceipt,wp_salt('auth'));
runtime_check(get_option('mobishop_deletion_intent_v1_'.$protectedHash,false)===false&&get_option('mobishop_account_deletion_v1_'.$alias->ID,false)===false,'Protected attempts create no deletion intent or pending job');
// A stale/externally seeded accepted job must also stop at the same protected boundary.
MobiShop_Customer_Identity_Guard::reserve($alias->ID,$protectedHash,array(),time()+600);
$protectedJob=array('userId'=>$alias->ID,'phase'=>0,'cursor'=>0,'receiptHash'=>$protectedHash,'identityStage'=>array('version'=>1,'user_id'=>$alias->ID,'entries'=>array(),'cursor'=>0),'identityLinks'=>array());
add_option('mobishop_account_deletion_v1_'.$alias->ID,$protectedJob,'',false);
MobiShop_Customer_Account_Deletion::run_worker($alias->ID);
runtime_check(get_option('mobishop_account_deletion_v1_'.$alias->ID)===$protectedJob,'Worker does not advance a protected alias deletion job');
MobiShop_Customer_Identity_Guard::release($alias->ID,$protectedHash,array());
delete_option('mobishop_account_deletion_v1_'.$alias->ID);wp_clear_scheduled_hook('mobishop_delete_customer_batch',array($alias->ID));
$aliasSession=new WP_REST_Request();$aliasSession->set_header('X-MobiShop-Session',$ownerToken);
runtime_check(!is_wp_error($auth->authenticate_route($aliasSession))&&WP_Session_Tokens::get_instance($admin)->verify($adminCookie)&&WP_Session_Tokens::get_instance($alias->ID)->verify($aliasCookie),'Protected administrator, alias and merchant sessions remain valid');
$canonicalReload=new WC_Order($canonicalOrder->get_id());
runtime_check(get_user_by('id',$admin) instanceof WP_User&&get_user_by('id',$alias->ID) instanceof WP_User
 &&get_user_meta($admin,'billing_address_1',true)==='Synthetic protected canonical address'&&get_user_meta($admin,'shipping_address_1',true)==='Synthetic protected shipping address'
 &&(int)$canonicalReload->get_customer_id()===$admin,'Protected administrator, alias, canonical addresses and order remain intact');
runtime_check(MobiShop_Customer_Identity_Client::$attempts+MobiShop_Customer_Identity_Client::$snapshot_calls===$providerBefore,'Protected owner never reaches identity provider prepare, lookup or erase');

// Real WordPress password hooks must revoke native sessions and the owner's alias.
$resetUser=wp_insert_user(array('user_login'=>'ci-password-lifecycle','user_email'=>'password-lifecycle@example.invalid','user_pass'=>'ci-password-before','role'=>'customer'));
runtime_check(!is_wp_error($resetUser),'Create disposable password lifecycle customer');
$passwordLogin=runtime_rest('auth/login',array('email'=>'password-lifecycle@example.invalid','password'=>'ci-password-before'));
$passwordToken=$passwordLogin->get_data()['token']??'';
$passwordRequest=new WP_REST_Request();$passwordRequest->set_header('X-MobiShop-Session',$passwordToken);
runtime_check($passwordLogin->get_status()===200&&!is_wp_error($auth->authenticate_route($passwordRequest)),'Password lifecycle starts with valid native session');
$beforeReset=get_user_by('id',$resetUser);
wp_set_password('ci-password-after',$resetUser);
runtime_check(is_wp_error($auth->authenticate_route($passwordRequest)),'Real wp_set_password hook rejects prior native token');
$issuer=new ReflectionMethod($auth,'issue_session_response');
runtime_check(is_wp_error($issuer->invoke($auth,$beforeReset)),'Stale password snapshot cannot mint a token after real reset');
$passwordLogin=runtime_rest('auth/login',array('email'=>'password-lifecycle@example.invalid','password'=>'ci-password-after'));
runtime_check($passwordLogin->get_status()===200,'New password signs in after reset');
$passwordRequest->set_header('X-MobiShop-Session',$passwordLogin->get_data()['token']);
reset_password(get_user_by('id',$resetUser),'ci-password-after');
runtime_check(is_wp_error($auth->authenticate_route($passwordRequest)),'Real reset_password revokes sessions even when password is unchanged');
$passwordLogin=runtime_rest('auth/login',array('email'=>'password-lifecycle@example.invalid','password'=>'ci-password-after'));
$passwordRequest->set_header('X-MobiShop-Session',$passwordLogin->get_data()['token']);
wp_update_user(array('ID'=>$resetUser,'display_name'=>'Renamed fixture'));
runtime_check(!is_wp_error($auth->authenticate_route($passwordRequest)),'Real ordinary profile update preserves native session');
wp_update_user(array('ID'=>$resetUser,'user_pass'=>'ci-password-profile'));
runtime_check(is_wp_error($auth->authenticate_route($passwordRequest)),'Real profile password change revokes native session');
$ownerSnapshot=get_user_by('id',$admin);
$ownerProof=array('id'=>$admin,'password'=>$ownerSnapshot->user_pass,'generation'=>(string)get_user_meta($admin,'_mobishop_auth_generation_v1',true));
wp_set_password('ci-owner-password-after',$admin);
runtime_check(is_wp_error($auth->authenticate_route($aliasSession)),'Real owner reset revokes the isolated customer session');
runtime_check(is_wp_error($issuer->invoke($auth,get_user_by('id',$alias->ID),$ownerProof)),'Real owner reset between resolution and issue rejects stale owner proof');
$ownerLogin=runtime_rest('auth/login',array('email'=>'identity-owner@example.invalid','password'=>'ci-owner-password-after'));
runtime_check($ownerLogin->get_status()===200&&($ownerLogin->get_data()['user']['id']??0)===$alias->ID,'Fresh owner password reuses isolated customer profile');

echo 'WordPress/MySQL identity lifecycle: '.$checks.' checks passed; external identity provider only is stubbed.'.PHP_EOL;
