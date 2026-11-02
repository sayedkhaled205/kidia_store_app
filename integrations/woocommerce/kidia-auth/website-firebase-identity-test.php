<?php
/** Signed Firebase website identity fixtures; no WordPress or real accounts. */
define('ABSPATH',__DIR__);
$GLOBALS['meta']=[];$GLOBALS['users']=[];$GLOBALS['native_calls']=[];$GLOBALS['options']=['fmaServiceProvider'=>'firebase','fma_lwp_projectID'=>'website-project'];
function get_user_meta($id,$key,$single=true){return $GLOBALS['meta'][$id][$key]??'';}function user_can($u,$cap){return !empty($u->caps[$cap]);}
function get_users($args){$out=[];foreach($GLOBALS['users'] as $u){foreach($args['meta_query'] as $clause){if(is_array($clause)&&in_array(get_user_meta($u->ID,$clause['key'],true),$clause['value'],true)){$out[]=$u;break;}}}return $out;}
function get_option($k){return $GLOBALS['options'][$k]??'';}function get_transient($k){return $GLOBALS['certs'];}function wp_doing_ajax(){return true;}function wp_verify_nonce($n,$a){return $n==='fixture-nonce';}function wp_unslash($v){return $v;}function sanitize_key($s){return preg_replace('/[^a-z0-9_-]/','',strtolower($s));}function sanitize_text_field($s){return strip_tags($s);}function nocache_headers(){}
class JsonSent extends Exception {public function __construct(public $data,public $status=200){parent::__construct('JSON response');}}
function wp_send_json($data,$status=200){throw new JsonSent($data,$status);}function is_wp_error($v){return false;}
class WP_REST_Request {public $params=[];function __construct(...$a){}function set_body_params($v){$this->params=$v;}}
class FixtureResponse {function get_data(){return ['status'=>'registration_required','ticket'=>'signed-fixture-ticket'];}}
function kidia_website_auth_engine(){return new class{function phone_verify($request){$GLOBALS['native_calls'][]=$request->params;return new FixtureResponse;}};}
$source=file_get_contents(__DIR__.'/website/kidia-firebase-otp.php');$a=strpos($source,'final class Kidia_Firebase_OTP_265');$b=strpos($source,'// Run before');eval(substr($source,$a,$b-$a));
$n=0;function check($v,$m){global $n;if(!$v)throw new Exception($m);$n++;}
foreach([1,2,3,4] as $id)$GLOBALS['users'][]=(object)['ID'=>$id,'caps'=>[]];
$GLOBALS['meta']=[1=>['billing_phone'=>'+201000000001'],2=>['kidia_login_phone'=>'+201000000001','kidia_unverified_phone'=>'+201099999999'],3=>['kidia_unverified_phone'=>'+201000000001','billing_phone'=>'+201000000001','fme_billing_phone'=>'+201000000001'],4=>['kidia_login_phone'=>'+201000000002','billing_phone'=>'+201000000001']];
$ids=array_map(fn($u)=>$u->ID,Kidia_Firebase_OTP_265::matching_users('+201000000001'));
check(!in_array(3,$ids,true),'Contact-only shipping and vendor copies are not OTP candidates');
check(Kidia_Firebase_OTP_265::eligible_customer($GLOBALS['users'][0],'+201000000001'),'Legacy pre-marker billing identity preserved');
check(Kidia_Firebase_OTP_265::eligible_customer($GLOBALS['users'][1],'+201000000001'),'Dedicated verified identity wins over stale contact marker');
check(!Kidia_Firebase_OTP_265::eligible_customer($GLOBALS['users'][2],'+201000000001'),'OTP cannot open contact claimant');
check(!Kidia_Firebase_OTP_265::eligible_customer($GLOBALS['users'][3],'+201000000001'),'Shipping cannot override different primary identity');
$fixture_key_options=['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA];$conf=dirname(PHP_BINARY).'/extras/ssl/openssl.cnf';if(is_file($conf))$fixture_key_options['config']=$conf;$key=openssl_pkey_new($fixture_key_options);if(!$key)throw new Exception('Cannot generate fixture key');$GLOBALS['certs']=['fixture-key'=>openssl_pkey_get_details($key)['key']];
function b64($s){return rtrim(strtr(base64_encode($s),'+/','-_'),'=');}
function token($phone){global $key;$h=b64(json_encode(['alg'=>'RS256','kid'=>'fixture-key']));$p=b64(json_encode(['aud'=>'website-project','iss'=>'https://securetoken.google.com/website-project','sub'=>'firebase-fixture','exp'=>time()+300,'iat'=>time(),'auth_time'=>time(),'phone_number'=>$phone,'firebase'=>['sign_in_provider'=>'phone']]));openssl_sign($h.'.'.$p,$sig,$key,OPENSSL_ALGO_SHA256);return $h.'.'.$p.'.'.b64($sig);}
$GLOBALS['users']=array_filter($GLOBALS['users'],fn($u)=>$u->ID===3);$_SERVER['REQUEST_METHOD']='POST';
$_POST=['action'=>'fme_lwp_process_otp_validation','nonce'=>'fixture-nonce','phone_number'=>'+201000000001','firebaseIdToken'=>token('+201000000001'),'kidia_native_verifier'=>str_repeat('a',64)];
try{Kidia_Firebase_OTP_265::guard();throw new Exception('Unknown verified phone fell through to legacy account resolution');}catch(JsonSent $response){check(!empty($response->data['registration'])&&$response->data['ticket']==='signed-fixture-ticket','Signed unknown phone receives a native registration ticket before vendor lookup');}
check(count($GLOBALS['native_calls'])===1&&$GLOBALS['native_calls'][0]['client_channel']==='website','Website proof is routed to explicit website channel');
check($GLOBALS['native_calls'][0]['verifier']===str_repeat('a',64),'Ticket stays bound to browser verifier');
$_POST['firebaseIdToken']=token('+201000000002');try{Kidia_Firebase_OTP_265::guard();throw new Exception('Wrong phone proof accepted');}catch(JsonSent $response){check($response->status===403,'Token for another phone rejected before native registration');}
check(count($GLOBALS['native_calls'])===1,'Invalid proof never enters registration service');
echo "Website Firebase identity: $n checks passed.\n";
