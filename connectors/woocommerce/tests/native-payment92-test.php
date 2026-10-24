<?php
define('ABSPATH', __DIR__);
require (getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__.'/../source').'/api/class-native-payment92.php';
function check($ok, $label) { if (!$ok) throw new RuntimeException($label); echo "PASS $label\n"; }
$record=['reference'=>'mobile-15-abcdef','merchant'=>'MID-123-123','session'=>'123456789012345678901234','amount'=>'70.00','currency'=>'EGP'];
$tx=['operation'=>'pay','status'=>'SUCCESS','currency'=>'EGP','amount'=>70,'transactionId'=>'TX-123'];
$row=['merchantOrderId'=>$record['reference'],'merchantId'=>$record['merchant'],'sessionId'=>$record['session'],'status'=>'CAPTURED','method'=>'card','order'=>['amount'=>70,'currency'=>'EGP'],'totalCapturedAmount'=>70,'totalRefundedAmount'=>0,'transactions'=>[$tx]];
$response=['status'=>'SUCCESS','data'=>[$row]];
check(MobiShop_Native_Payment92::paid_transaction($response,$record)==='TX-123','exact captured provider payment is accepted');
foreach (['merchantOrderId'=>'other','merchantId'=>'MID-other','sessionId'=>'other','status'=>'AUTHORIZED','method'=>'wallet','totalCapturedAmount'=>75,'totalRefundedAmount'=>1] as $key=>$value) {
  $bad=$response; $bad['data'][0][$key]=$value;
  check(MobiShop_Native_Payment92::paid_transaction($bad,$record)===null,'reject mismatched '.$key);
}
$bad=$response; $bad['data'][0]['order']['currency']='USD';
check(MobiShop_Native_Payment92::paid_transaction($bad,$record)===null,'wrong currency cannot settle order');
$bad=$response; $bad['data'][0]['transactions'][0]['operation']='3dsecure_verify';
check(MobiShop_Native_Payment92::paid_transaction($bad,$record)===null,'3DS success is not a charge');
$bad=$response; $bad['data'][0]['transactions'][0]['status']='FAILURE';
check(MobiShop_Native_Payment92::paid_transaction($bad,$record)===null,'reconciliation envelope is not payment success');
$bad=$response; $bad['data'][]=$row;
check(MobiShop_Native_Payment92::paid_transaction($bad,$record)===null,'ambiguous duplicate provider records do not settle');
foreach (['70.001','-70','7e1',null,[],true] as $value) check(MobiShop_Native_Payment92::money($value)===null,'reject invalid or inexact money');
$data=['amount'=>70,'currency'=>'EGP','merchantOrderId'=>$record['reference'],'status'=>'SUCCESS','method'=>'card','transactionId'=>'TX-123'];
$keys=array_keys($data); sort($keys); $signed=[]; foreach($keys as $key)$signed[$key]=$data[$key];
$data['signatureKeys']=$keys; $signature=hash_hmac('sha256',http_build_query($signed,'','&',PHP_QUERY_RFC3986),'test-key');
check(MobiShop_Native_Payment92::verified_signature($data,$signature,'test-key',$record),'signed identity accepted');
$bad=$data; $bad['amount']=75;
check(!MobiShop_Native_Payment92::verified_signature($bad,$signature,'test-key',$record),'tampered amount rejected');
$bad=$data; $bad['signatureKeys']=array_values(array_diff($keys,['amount']));
check(!MobiShop_Native_Payment92::verified_signature($bad,$signature,'test-key',$record),'unsigned amount rejected');
check(!MobiShop_Native_Payment92::verified_signature($data,$signature,'wrong-key',$record),'other merchant signature rejected');

class WP_Error { public function __construct(public $code,public $message,public $data){} }
class WP_REST_Request implements ArrayAccess {
 public function offsetExists($o):bool{return $o==='id';} public function offsetGet($o):mixed{return 15;} public function offsetSet($o,$v):void{} public function offsetUnset($o):void{}
}
class WP_REST_Response { public function __construct(public $data){} public function header($a,$b){} }
class WC_Gateway_Kashier_Card { public $id='kashier_card',$enabled='yes',$merchant_id='MID-123-123',$api_key='key',$secret_key='secret',$testmode=true,$enable_connected_account=false; function get_option($k){return 'no';} }
class WC_Order {
 public $meta=['_mobishop_native_attempt50'=>'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','_mobishop_native_buyer50'=>'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'], $amount='70.00', $customer=7;
 function get_id(){return 15;} function get_customer_id(){return $this->customer;} function get_meta($k){return $this->meta[$k]??'';}
 function update_meta_data($k,$v){$this->meta[$k]=$v;} function save(){} function needs_payment(){return true;} function is_paid(){return false;} function get_status(){return 'pending';} function get_total($c){return $this->amount;} function get_currency(){return 'EGP';}
}
class MobiShop_Customer_Auth_Endpoint { function session_context_from_request($r){return ['user_id'=>7];} }
class MobiShop_Native_Checkout_Wpdb50 {
 function find($buyer,$attempt){return ['state'=>$GLOBALS['guard_state']??'order_created','customer_id'=>7,'order_id'=>15,'buyer_scope'=>$buyer,'attempt_hash'=>$attempt,'guard_passed'=>1,'dispatch_finished'=>1];}
}
class FakeDb { public $prefix='wp_'; function prepare($s,$v){return $s;} function get_var($s){return '1';} }
$wpdb=new FakeDb; $order=new WC_Order; $gateway=new WC_Gateway_Kashier_Card; $posts=0; $timeout=false;
function wc_get_order($id){global $order;return $order;} function wc_get_payment_gateway_by_order($o){global $gateway;return $gateway;}
function get_current_user_id(){return 7;} function wp_is_using_https(){return true;} function is_wp_error($v){return $v instanceof WP_Error;}
function wp_json_encode($v){return json_encode($v);} function home_url($v){return 'https://example.com'.$v;} function rest_url($v){return 'https://example.com/wp-json/'.$v;} function is_rtl(){return false;}
function rest_ensure_response($v){return new WP_REST_Response($v);} function wp_remote_retrieve_response_code($r){return 200;} function wp_remote_retrieve_body($r){return json_encode($r);}
function wp_remote_post($url,$args){global $posts,$timeout; $posts++; if($timeout)return new WP_Error('timeout','',[]);$b=json_decode($args['body'],true);return ['_id'=>'123456789012345678901234','merchantId'=>$b['merchantId'],'paymentParams'=>$b];}
$endpoint=new MobiShop_Native_Payment92; $request=new WP_REST_Request;
$first=$endpoint->prepare($request);$second=$endpoint->prepare($request);
check($first instanceof WP_REST_Response && $second instanceof WP_REST_Response && $posts===1,'repeated taps reuse one durable provider session');
check(!str_contains(json_encode($first),'secret')&&!str_contains(json_encode($first),'api_key'),'mobile response contains no merchant credentials');
$guard_state='in_progress'; check($endpoint->prepare($request) instanceof WP_Error && $posts===1,'unfinished guard cannot start payment');
$guard_state='rejected_before_payment'; check($endpoint->prepare($request) instanceof WP_Error && $posts===1,'rejected order cannot start payment');
$guard_state='order_created';
$order->customer=8;check($endpoint->prepare($request) instanceof WP_Error && $posts===1,'other customer cannot create payment');$order->customer=7;
$order->amount='75.00';check($endpoint->prepare($request) instanceof WP_Error && $posts===1,'changed total cannot reuse or duplicate payment');
$order=new WC_Order;$timeout=true;$endpoint->prepare($request);$endpoint->prepare($request);
check($posts===2,'provider timeout leaves durable uncertainty and cannot replay');
