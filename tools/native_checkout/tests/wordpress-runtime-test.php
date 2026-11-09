<?php
/**
 * Disposable WordPress/MySQL checkout integration fixture.
 * Run parent with ordinary PHP (not wp eval-file). It launches one fresh WP request
 * per operation so Woo route objects, sessions, current user and object caches do
 * not leak between requests. Only official WP/Woo and the real connector are used.
 * Synthetic accounts/addresses only. Session tokens remain in anonymous pipes.
 */

declare(strict_types=1);
function cq_assert(bool $condition, string $label): void {
    if (!$condition) throw new RuntimeException('FAIL: '.$label);
    if (!defined('ABSPATH')) echo 'PASS: '.$label.PHP_EOL;
}

function cq_child(array $input): array {
    $command = [PHP_BINARY, getenv('WP_CLI'), 'eval-file', __FILE__, '--use-include', '--path='.getenv('WP_PATH'), '--quiet'];
    $process = proc_open($command, [['pipe','r'],['pipe','w'],['pipe','w']], $pipes);
    cq_assert(is_resource($process), 'Start isolated WordPress request');
    fwrite($pipes[0], json_encode($input, JSON_THROW_ON_ERROR)); fclose($pipes[0]);
    $output=stream_get_contents($pipes[1]); fclose($pipes[1]);
    // Never print raw stderr/response bodies: they can contain ephemeral sessions.
    $stderr=stream_get_contents($pipes[2]); fclose($pipes[2]);
    $exit=proc_close($process);
    $marker='KIDIA_CHECKOUT_RESULT='; $position=strrpos($output,$marker);
    cq_assert($exit===0 && $position!==false, 'WordPress request returns structured result');
    $line=explode("\n",substr($output,$position+strlen($marker)),2)[0];
    $result=json_decode($line,true,512,JSON_THROW_ON_ERROR);
    if(isset($result['failure'])) throw new RuntimeException('Worker failure: '.$result['failure']);
    return $result;
}

function cq_request(string $method,string $route,array $body=[],string $session='',string $cart='',string $key='',string $fault=''): array {
    return cq_child(compact('method','route','body','session','cart','key','fault')+['phase'=>'request']);
}
function cq_cart_header(array $response): string {
    foreach($response['headers'] as $key=>$value) if(strtolower($key)==='cart-token') return (string)$value;
    throw new RuntimeException('Cart bootstrap did not return its real token');
}
function cq_checkout_body(string $email,string $minor='0'): array {
    $address=['first_name'=>'Synthetic','last_name'=>'Fixture','company'=>'','address_1'=>'1 Fixture Street',
        'address_2'=>'','city'=>'San Francisco','state'=>'CA','postcode'=>'94105','country'=>'US'];
    return ['billing_address'=>$address+['email'=>$email,'phone'=>'2025550100'], 'shipping_address'=>$address,
        'customer_note'=>'Disposable CI fixture only','create_account'=>false,'payment_method'=>'','payment_data'=>[],
        'extensions'=>['mobishop_native_checkout50'=>['protocol'=>50,'confirmed'=>[
            'total_price'=>$minor,'currency_code'=>'USD','currency_minor_unit'=>2]]]];
}

function cq_parent(): void {
    cq_assert(getenv('CI')==='true' && getenv('KIDIA_CHECKOUT_RUNTIME_TEST')==='1', 'Explicit disposable CI invocation');
    $temp=realpath((string)getenv('RUNNER_TEMP')); $path=realpath((string)getenv('WP_PATH'));
    cq_assert($temp!==false && $path!==false && $path===$temp.DIRECTORY_SEPARATOR.'kidia-wordpress'
        && is_file((string)getenv('WP_CLI')), 'Only the workflow disposable WordPress path is accepted');
    $seed=cq_child(['phase'=>'seed']);
    $login=cq_request('POST','/mobishop/v1/auth/login',['email'=>'checkout-a@example.invalid','password'=>'ci-checkout-fixture-only']);
    cq_assert($login['status']===200 && !empty($login['data']['token']), 'Actual password endpoint issues customer session');
    $session=$login['data']['token'];
    $cap=cq_request('GET','/mobishop/v1/native-checkout-capabilities');
    cq_assert($cap['status']===200 && ($cap['data']['enforced']??false)===true, 'Real schema, Woo hooks and transactional safety ledger are supported');
    $cartResponse=cq_request('GET','/wc/store/v1/cart',[],$session); $cart=cq_cart_header($cartResponse);
    cq_assert($cartResponse['status']===200 && count($cartResponse['data']['items'])===0, 'Actual authenticated Store API cart is empty');
    $invalid=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['zero_product'],'quantity'=>0],$session,$cart);
    cq_assert($invalid['status']>=400 && $invalid['status']<500, 'Invalid zero quantity is rejected by actual Store API schema');
    $added=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['zero_product'],'quantity'=>2],$session,$cart);
    cq_assert($added['status']===200 && ($added['data']['items'][0]['quantity']??0)===2, 'Real cart persists quantity across fresh WP requests');
    $body=cq_checkout_body('checkout-a@example.invalid'); $key='ci-zero-order-1';
    $checkout=cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,$key);
    $order=(int)($checkout['data']['order_id']??0);
    cq_assert($checkout['status']===200 && $order>0 && ($checkout['data']['payment_result']['payment_status']??'')==='success', 'Real Store API creates a zero-payment order');
    $snapshot=cq_child(['phase'=>'snapshot']);
    cq_assert($snapshot['zero_stock']===4 && $snapshot['processed']===1, 'Real stock decreases once by purchased quantity');
    $after=cq_request('GET','/wc/store/v1/cart',[],$session,$cart);
    cq_assert($after['status']===200 && count($after['data']['items'])===0, 'Purchased cart is durably emptied');
    $recovery=cq_request('GET','/mobishop/v1/customer/checkout-attempts/'.$key,[],$session,$cart);
    cq_assert($recovery['status']===200 && ($recovery['data']['order']['id']??0)===$order
        && ($recovery['data']['checkout_locked']??true)===false, 'Lost-acknowledgement recovery reads the same completed order');
    $replay=cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,$key);
    cq_assert($replay['status']===200 && ($replay['data']['order']['id']??0)===$order, 'Identical duplicate POST recovers existing order');
    $same=cq_child(['phase'=>'snapshot']);
    cq_assert($same['orders']===$snapshot['orders'] && $same['zero_stock']===4 && $same['processed']===1,
        'Duplicate POST creates no second order and performs no second stock reduction');
    $added=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['zero_product'],'quantity'=>1],$session,$cart);
    cq_assert($added['status']===200,'A new basket can start after successful purchase');
    cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,$key);
    $after=cq_request('GET','/wc/store/v1/cart',[],$session,$cart);
    cq_assert(($after['data']['items'][0]['quantity']??0)===1, 'Old-attempt replay cannot empty a new basket');
    $removed=cq_request('POST','/wc/store/v1/cart/remove-item',['key'=>$after['data']['items'][0]['key']],$session,$cart);
    cq_assert($removed['status']===200 && count($removed['data']['items'])===0, 'Actual remove endpoint persists removal');

    // Price mismatch before payment, then explicit reconfirmation using a new key.
    $priced=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['priced_product'],'quantity'=>1],$session,$cart);
    cq_assert($priced['status']===200 && $priced['data']['totals']['total_price']==='2000','Actual priced basket has expected confirmed total');
    $mismatch=cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,'ci-stale-total');
    cq_assert($mismatch['status']===409 && ($mismatch['data']['code']??'')==='mobishop_native_checkout50_confirmed_total_mismatch', 'Changed total rejects checkout before payment');
    $check=cq_child(['phase'=>'snapshot']);
    cq_assert($check['priced_stock']===8 && $check['processed']===1,'Total rejection does not reduce stock or process payment');
    $rejected=cq_request('GET','/mobishop/v1/customer/checkout-attempts/ci-stale-total',[],$session,$cart);
    cq_assert($rejected['status']===409 && ($rejected['data']['state']??'')==='rejected_before_payment','Total rejection is durably recoverable');
    $discount=cq_request('POST','/wc/store/v1/cart/apply-coupon',['code'=>'ci-checkout-free'],$session,$cart);
    cq_assert($discount['status']===200 && $discount['data']['totals']['total_price']==='0','Real Woo coupon reduces checkout to zero without a gateway');
    $second=cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,'ci-coupon-order');
    cq_assert($second['status']===200 && (int)($second['data']['order_id']??0)>0,'Explicit reconfirmation succeeds under a fresh attempt key');
    $check=cq_child(['phase'=>'snapshot']);
    cq_assert($check['priced_stock']===7 && $check['processed']===2,'Coupon order changes stock exactly once');

    // Different owner cannot use the first buyer's cart or recover their receipt.
    $otherLogin=cq_request('POST','/mobishop/v1/auth/login',['email'=>'checkout-b@example.invalid','password'=>'ci-checkout-fixture-only']);
    cq_assert($otherLogin['status']===200,'Second independent customer signs in'); $other=$otherLogin['data']['token'];
    $stolen=cq_request('POST','/wc/store/v1/checkout',$body,$other,$cart,'ci-wrong-owner');
    cq_assert($stolen['status']===403,'Cross-customer Cart-Token is rejected');
    $stolen=cq_request('GET','/mobishop/v1/customer/checkout-attempts/'.$key,[],$other,$cart);
    cq_assert(($stolen['data']['order']['id']??0)===0,'Other owner cannot recover the first customer order');
    $otherCart=cq_cart_header(cq_request('GET','/wc/store/v1/cart',[],$other));
    $stock=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['zero_product'],'quantity'=>999],$other,$otherCart);
    cq_assert($stock['status']>=400 && $stock['status']<500,'Actual Woo stock limit rejects excessive quantity');
    $added=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['zero_product'],'quantity'=>1],$other,$otherCart);
    cq_assert($added['status']===200,'Valid quantity remains available after stock rejection');
    $faultBody=cq_checkout_body('checkout-b@example.invalid');
    $unknown=cq_request('POST','/wc/store/v1/checkout',$faultBody,$other,$otherCart,'ci-before-payment-fault','throw_before_payment');
    cq_assert($unknown['status']===503 && ($unknown['data']['code']??'')==='mobishop_native_checkout50_outcome_unknown', 'Injected pre-payment exception produces unknown outcome');
    $unknownSnapshot=cq_child(['phase'=>'snapshot']);
    cq_assert($unknownSnapshot['zero_stock']===4 && $unknownSnapshot['processed']===3,'Fault reaches actual order hook without reducing stock');
    $repeat=cq_request('POST','/wc/store/v1/checkout',$faultBody,$other,$otherCart,'ci-before-payment-fault');
    cq_assert($repeat['status']===202 && ($repeat['data']['state']??'')==='in_progress','Unknown attempt is recovered without redispatch');
    $newAttempt=cq_request('POST','/wc/store/v1/checkout',$faultBody,$other,$otherCart,'ci-must-not-retry');
    cq_assert($newAttempt['status']===409,'A new key cannot bypass unresolved buyer attempt');
    $final=cq_child(['phase'=>'snapshot']);
    cq_assert($final['orders']===$unknownSnapshot['orders'] && $final['processed']===3 && $final['zero_stock']===4,
        'Failure and retries do not create another order or repeat stock side effects');
    cq_assert($final['mail_blocked']>0,'Real order emails reached the suppression filter without delivery');
    echo 'Real WordPress/MySQL/Store API checkout passed all runtime assertions.'.PHP_EOL;
}

function cq_worker(): array {
    cq_assert(getenv('CI')==='true' && getenv('KIDIA_CHECKOUT_RUNTIME_TEST')==='1', 'Worker CI opt-in');
    cq_assert(defined('DB_NAME') && DB_NAME==='kidia_identity_ci', 'Worker disposable database');
    cq_assert(defined('WP_ENVIRONMENT_TYPE') && WP_ENVIRONMENT_TYPE==='local', 'Worker local environment');
    cq_assert(defined('DB_HOST') && (bool)preg_match('/^(127\.0\.0\.1|localhost)(:3306)?$/D',DB_HOST), 'Worker loopback database host');
    cq_assert(get_option('active_plugins')===['woocommerce/woocommerce.php'], 'Worker sole official Woo plugin');
    cq_assert(defined('WC_VERSION') && WC_VERSION==='10.9.4', 'Worker pinned Woo version');
    cq_assert(home_url('/', 'https')==='https://kidia-identity.test/', 'Worker disposable site origin');
    global $wpdb;
    add_filter('pre_http_request',static fn()=>new WP_Error('ci_network_disabled','Outbound HTTP disabled.'),PHP_INT_MAX);
    add_filter('pre_wp_mail',static function(){update_option('cq_mail_blocked',(int)get_option('cq_mail_blocked',0)+1,false);return true;},PHP_INT_MAX);
    add_action('phpmailer_init',static function(){throw new RuntimeException('Mail transport must never initialize.');},PHP_INT_MIN);
    $_SERVER['HTTPS']='on'; $_SERVER['REMOTE_ADDR']='127.0.0.1';
    $input=json_decode(stream_get_contents(STDIN),true,512,JSON_THROW_ON_ERROR);
    $repo=realpath((string)getenv('GITHUB_WORKSPACE'));
    if($repo===false || !is_file($repo.'/connectors/woocommerce/source/api/class-native-checkout-safety50.php')) throw new RuntimeException('Missing real connector source');
    if(defined('MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY')) throw new RuntimeException('Unexpected preconfigured ledger key');
    define('MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY',hash('sha256','disposable-checkout-fixture-only-key'));
    require_once $repo.'/tools/customer_identity/connector/class-customer-identity-links.php';
    require_once $repo.'/tools/customer_identity/connector/class-customer-identity-guard.php';
    require_once $repo.'/connectors/woocommerce/source/api/class-customer-auth-endpoint.php';
    require_once $repo.'/connectors/woocommerce/source/api/class-native-checkout-safety50.php';
    if($input['phase']==='seed') {
        if(get_option('cq_seed',false)!==false) throw new RuntimeException('Fixture requires a fresh database, not reset/reuse');
        $store=new MobiShop_Native_Checkout_Wpdb50();
        foreach($store->installation_sql() as $sql) cq_assert($wpdb->query($sql)!==false,'Create exact real safety ledger');
        cq_assert((string)$wpdb->get_var('SELECT @@in_transaction')==='0', 'Database supports explicit inactive transaction guard');
        cq_assert($store->ready(),'Exact transactional ledger passes production readiness');
        update_option('woocommerce_currency','USD'); update_option('woocommerce_price_num_decimals','2');
        update_option('woocommerce_default_country','US:CA'); update_option('woocommerce_calc_taxes','no');
        update_option('woocommerce_manage_stock','yes'); update_option('woocommerce_hold_stock_minutes','60');
        update_option('woocommerce_enable_guest_checkout','no');
        $users=[];
        foreach(['a','b'] as $letter) {
            $user=wp_insert_user(['user_login'=>'ci-checkout-'.$letter,'user_email'=>'checkout-'.$letter.'@example.invalid',
                'user_pass'=>'ci-checkout-fixture-only','role'=>'customer']);
            cq_assert(!is_wp_error($user),'Create synthetic checkout customer'); $users[]=(int)$user;
        }
        $products=[];
        foreach([['zero','0',6],['priced','20',8]] as [$name,$price,$stock]) {
            $product=new WC_Product_Simple(); $product->set_name('Disposable checkout '.$name);
            $product->set_status('publish'); $product->set_virtual(true); $product->set_regular_price($price);
            $product->set_manage_stock(true); $product->set_stock_quantity($stock); $product->set_backorders('no');
            $product->save(); $products[$name.'_product']=$product->get_id();
        }
        $coupon=new WC_Coupon(); $coupon->set_code('ci-checkout-free'); $coupon->set_discount_type('percent'); $coupon->set_amount(100); $coupon->save();
        $seed=$products+['users'=>$users]; add_option('cq_seed',$seed,'',false); return $seed;
    }
    $seed=get_option('cq_seed'); cq_assert(is_array($seed),'Disposable seed exists');
    if($input['phase']==='snapshot') {
        $orders=[];
        foreach($seed['users'] as $customer) {
            $orders=array_merge($orders,wc_get_orders(['customer_id'=>$customer,'limit'=>-1,'return'=>'ids',
                'status'=>array_unique(array_merge(array_keys(wc_get_order_statuses()),['wc-checkout-draft']))]));
        }
        $orders=array_values(array_unique($orders)); sort($orders);
        return ['orders'=>$orders,'zero_stock'=>(int)(new WC_Product_Simple($seed['zero_product']))->get_stock_quantity(),
            'priced_stock'=>(int)(new WC_Product_Simple($seed['priced_product']))->get_stock_quantity(),
            'processed'=>(int)get_option('cq_order_processed',0),'mail_blocked'=>(int)get_option('cq_mail_blocked',0)];
    }
    cq_assert($input['phase']==='request' && !did_action('rest_api_init'),'REST extension registers before schemas');
    if(!defined('REST_REQUEST')) define('REST_REQUEST',true);
    $_SERVER['HTTP_X_MOBISHOP_SESSION']=$input['session']; $_SERVER['HTTP_CART_TOKEN']=$input['cart'];
    $_SERVER['REQUEST_METHOD']=$input['method']; $_SERVER['REQUEST_URI']='/wp-json'.$input['route'];
    $GLOBALS['wp']->query_vars['rest_route']=$input['route'];
    $auth=new MobiShop_Customer_Auth_Endpoint(); $auth->register();
    $safety=new MobiShop_Native_Checkout_Safety50(); $safety->register(); $safety->register_extension();
    // Actual native determine_current_user executes; no wp_set_current_user(owner) shortcut.
    unset($GLOBALS['current_user']); wp_get_current_user();
    add_action('woocommerce_store_api_checkout_order_processed',static function(){
        update_option('cq_order_processed',(int)get_option('cq_order_processed',0)+1,false);
    },PHP_INT_MIN);
    if($input['fault']==='throw_before_payment') add_action('woocommerce_store_api_checkout_order_processed',static function(){
        throw new RuntimeException('Synthetic pre-payment failure');
    },PHP_INT_MAX);
    $request=new WP_REST_Request($input['method'],$input['route']); $request->set_header('Content-Type','application/json');
    if($input['session']!=='') $request->set_header('X-MobiShop-Session',$input['session']);
    if($input['cart']!=='') $request->set_header('Cart-Token',$input['cart']);
    if($input['key']!=='') $request->set_header('Idempotency-Key',$input['key']);
    if($input['method']!=='GET') $request->set_body(wp_json_encode($input['body']));
    $response=rest_do_request($request);
    if(WC()->session && is_callable([WC()->session,'save_data'])) WC()->session->save_data();
    return ['status'=>$response->get_status(),'headers'=>$response->get_headers(),'data'=>$response->get_data()];
}

try {
    if(defined('ABSPATH')) echo 'KIDIA_CHECKOUT_RESULT='.json_encode(cq_worker(),JSON_THROW_ON_ERROR).PHP_EOL;
    else cq_parent();
} catch(Throwable $error) {
    if(defined('ABSPATH')) {
        // No exception arguments, SQL, headers or response dumps in CI logs.
        $detail=$error instanceof RuntimeException && str_starts_with($error->getMessage(),'FAIL: ')
            ? $error->getMessage() : get_class($error).' at '.basename($error->getFile()).':'.$error->getLine();
        echo 'KIDIA_CHECKOUT_RESULT='.json_encode(['failure'=>$detail]).PHP_EOL;
    } else {fwrite(STDERR,$error->getMessage().PHP_EOL); exit(1);}
}
