<?php
/** Signed Firebase website identity fixtures; no WordPress or real accounts. */
define('ABSPATH',__DIR__);
$GLOBALS['meta']=[];$GLOBALS['users']=[];$GLOBALS['native_calls']=[];$GLOBALS['options']=['fmaServiceProvider'=>'firebase','fma_lwp_projectID'=>'website-project'];
function get_user_meta($id,$key,$single=true){return $GLOBALS['meta'][$id][$key]??'';}function user_can($u,$cap){return !empty($u->caps[$cap]);}
function get_users($args){$out=[];foreach($GLOBALS['users'] as $u){foreach($args['meta_query'] as $clause){if(is_array($clause)&&in_array(get_user_meta($u->ID,$clause['key'],true),$clause['value'],true)){$out[]=$u;break;}}}return $out;}
function get_option($k){return $GLOBALS['options'][$k]??'';}function get_transient($k){return $GLOBALS['certs'];}function wp_doing_ajax(){return true;}function wp_verify_nonce($n,$a){return $n==='fixture-nonce';}function wp_unslash($v){return $v;}function sanitize_key($s){return preg_replace('/[^a-z0-9_-]/','',strtolower($s));}function sanitize_text_field($s){return strip_tags($s);}function nocache_headers(){}
class JsonSent extends Exception {public function __construct(public $data,public $status=200){parent::__construct('JSON response');}}
function wp_send_json($data,$status=200){throw new JsonSent($data,$status);}function is_wp_error($v){return $v instanceof WP_Error;}
class WP_Error {function __construct(...$args){}}
class WP_REST_Response {function __construct(public $data){}function get_data(){return $this->data;}}
class WP_REST_Request {public $params=[];function __construct(...$a){}function set_body_params($v){$this->params=$v;}}
class FixtureResponse {function get_data(){return ['status'=>'registration_required','ticket'=>'signed-fixture-ticket'];}}
function kidia_website_auth_engine($issue=null){return new class($issue){
    function __construct(private $issue){}
    function phone_verify($request){
        $GLOBALS['native_calls'][]=$request->params;
        $mode=$GLOBALS['native_mode']??'registration';
        if($mode==='denied')return new WP_Error();
        if($mode==='picker')return new WP_REST_Response(['status'=>'select_account','ticket'=>'selection-fixture']);
        if($mode==='authenticated')return ($this->issue)((object)['ID'=>$GLOBALS['native_selected']]);
        return new FixtureResponse;
    }
    function select($request){
        $GLOBALS['native_selection']=$request->params;
        return ($this->issue)((object)['ID'=>$GLOBALS['native_selected']]);
    }
};}
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

function get_user_by($kind,$id){foreach($GLOBALS['users'] as $user)if($kind==='id'&&$user->ID===$id)return $user;return false;}
class FME_LWP_Users_Controller {
    function is_phone_violating_login_attempt_count_restriction($phone){return false;}
    function is_phone_violating_login_count_restriction($phone){return false;}
    function login_user($id){$GLOBALS['vendor_login']=$id;}
}
foreach(['authenticated','picker','registration','denied','wrong-account'] as $mode){
    $GLOBALS['users']=[(object)['ID'=>40,'caps'=>[]]];
    $GLOBALS['meta']=[40=>['kidia_login_phone'=>'+201000000001']];
    $GLOBALS['native_mode']=$mode==='wrong-account'?'authenticated':$mode;
    $GLOBALS['native_selected']=$mode==='wrong-account'?41:40;
    unset($GLOBALS['vendor_login'],$GLOBALS['native_selection']);
    $_POST=['action'=>'fme_lwp_process_otp_validation','nonce'=>'fixture-nonce','phone_number'=>'+201000000001','firebaseIdToken'=>token('+201000000001'),'kidia_native_verifier'=>str_repeat('b',64)];
    $calls=count($GLOBALS['native_calls']);
    Kidia_Firebase_OTP_265::guard();
    try{Kidia_Firebase_OTP_265::finish_selected_login();throw new Exception('Expected JSON');}catch(JsonSent $response){
        check(count($GLOBALS['native_calls'])===$calls+1,'Existing OTP uses guarded native proof service: '.$mode);
        $request=end($GLOBALS['native_calls']);
        check($request['id_token']===$_POST['firebaseIdToken']&&$request['verifier']===str_repeat('b',64)&&$request['client_channel']==='website','Signed proof and verifier stay intact');
        if(in_array($mode,['authenticated','picker'],true))check(($GLOBALS['vendor_login']??0)===40&&!empty($response->data['success']),'Only verified selected account logs in');
        else check(!isset($GLOBALS['vendor_login']),'Unfinished or mismatched proof never logs in');
        if($mode==='picker')check(($GLOBALS['native_selection']['account_id']??0)===40&&$GLOBALS['native_selection']['ticket']==='selection-fixture','Selected account is checked by native picker');
        if($mode==='registration')check(!empty($response->data['registration']),'Incomplete existing account reaches shared completion');
        if(in_array($mode,['denied','wrong-account'],true))check($response->status===403,'Guard denial/mismatch fails closed');
    }
}
echo "Website existing OTP bridge: $n total checks passed.\n";
