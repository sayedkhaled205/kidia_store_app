<?php
/** Native Facebook proof/identity contracts; all keys and identities are temporary fixtures. */
require __DIR__ . '/native-auth-contract-test.php';
$before_checks = $GLOBALS['native_checks'];
$GLOBALS['native_facebook_rows'] = array();
class Native_Test_Facebook_Settings {
    public array $values = array('appid'=>'123456789','secret'=>'fixture-server-secret');
    public function get($key) { return $this->values[$key] ?? ''; }
}
class Native_Test_Facebook_Provider {
    public $settings;
    public bool $enabled = true;
    public bool $fail_insert = false;
    public function __construct() { $this->settings = new Native_Test_Facebook_Settings(); }
    public function isEnabled() { return $this->enabled; }
    public function getDbID() { return 'fb'; }
    public function getUserIDByProviderIdentifier($subject) {
        foreach ($GLOBALS['native_facebook_rows'] as $row) if ($row['type']==='fb' && $row['subject']===$subject) return $row['id'];
        return null;
    }
    public function linkUserToProviderIdentifier($id,$subject,$isRegister=false) {
        foreach ($GLOBALS['native_facebook_rows'] as $row) if ($row['type']==='fb' && $row['id']===$id) return $row['subject']===$subject;
        if (isset($GLOBALS['native_facebook_before_insert'])) {
            $hook=$GLOBALS['native_facebook_before_insert']; unset($GLOBALS['native_facebook_before_insert']); $hook($id,$subject);
        }
        if (!$this->fail_insert) $GLOBALS['native_facebook_rows'][] = array('type'=>'fb','id'=>$id,'subject'=>$subject);
        return true; // Matches Nextend's actual unchecked database insert result.
    }
    public function removeConnectionByUserID($id) {
        $GLOBALS['native_facebook_rows'] = array_values(array_filter($GLOBALS['native_facebook_rows'],static fn($row)=>$row['type']!=='fb'||$row['id']!==$id));
    }
}
$provider = NextendSocialLogin::$providers['facebook'] = new Native_Test_Facebook_Provider();
$native_settings = $GLOBALS['native_options']['mobishop_native_auth_settings'];
$settings = $native_settings + array('facebook_native_enabled'=>true,'android_facebook_native_ready'=>true,'ios_facebook_native_ready'=>true);
$settings['facebook'] = array('app_id'=>'123456789','client_token'=>'fixture-public-client-token');
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings;
function facebook_config($platform='android') { global $endpoint; return native_data($endpoint->config(native_request(array('platform'=>$platform))),'Facebook config'); }
function facebook_challenge($platform='android',$verifier=null) {
    global $endpoint;
    foreach(array_keys($GLOBALS['native_transients']) as $key) if(str_starts_with($key,'mobishop_native_rate_')) unset($GLOBALS['native_transients'][$key]);
    return native_data($endpoint->facebook_challenge(native_request(array('platform'=>$platform,'verifier'=>$verifier ?? str_repeat('f',64)))),'Facebook challenge');
}
function facebook_exchange($challenge,array $proof=array(),$platform='android',$verifier=null) {
    global $endpoint;
    return $endpoint->facebook(native_request(array_merge(array('platform'=>$platform,'verifier'=>$verifier ?? str_repeat('f',64),'ticket'=>$challenge['ticket']),$proof)));
}
function facebook_http_fixture($subject='700001',$email=null) {
    $GLOBALS['facebook_debug'] = array('data'=>array('is_valid'=>true,'type'=>'USER','app_id'=>'123456789','user_id'=>$subject,'expires_at'=>time()+3600,'data_access_expires_at'=>time()+7200));
    $GLOBALS['facebook_me'] = array('id'=>$subject);
    if ($email!==null) $GLOBALS['facebook_me']['email'] = $email;
    $GLOBALS['facebook_http_status'] = 200;
    $GLOBALS['facebook_http_invalid_json'] = false;
    $GLOBALS['facebook_http_error'] = false;
}
function facebook_jwk($kid='fixture-kid') {
    $rsa = openssl_pkey_get_details($GLOBALS['native_private_key'])['rsa'];
    return array('kid'=>$kid,'kty'=>'RSA','alg'=>'RS256','use'=>'sig','n'=>native_b64($rsa['n']),'e'=>native_b64($rsa['e']));
}
function facebook_claims($challenge,$subject='700001') {
    return array('iss'=>'https://www.facebook.com','aud'=>'123456789','sub'=>$subject,'iat'=>time(),'exp'=>time()+3600,'nonce'=>$challenge['nonce']);
}
$GLOBALS['facebook_jwks'] = array('keys'=>array(facebook_jwk()));
$GLOBALS['native_http_handler'] = static function($url,$args) {
    if (in_array($url,array('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com','https://www.googleapis.com/oauth2/v1/certs'),true)) return null;
    native_assert(($args['redirection']??null)===0 && ($args['sslverify']??null)===true && ($args['timeout']??100)<=10 && ($args['limit_response_size']??100000)<=65536,'Meta HTTP limits and TLS preserved');
    if (!empty($GLOBALS['facebook_http_error'])) return new WP_Error('fixture_network','fixture-access-token must never be forwarded');
    $parts=parse_url($url); parse_str($parts['query']??'',$query);
    if ($url==='https://www.facebook.com/.well-known/oauth/openid/jwks/') $body=$GLOBALS['facebook_jwks'];
    elseif (($parts['scheme']??'')==='https' && ($parts['host']??'')==='graph.facebook.com' && ($parts['path']??'')==='/debug_token') {
        native_assert(($args['headers']['Authorization']??'')==='Bearer 123456789|fixture-server-secret','App secret uses an authorization header');
        native_assert(!isset($query['access_token']) && isset($query['input_token']),'Debug URL does not expose app secret');
        $body=$GLOBALS['facebook_debug'];
    } elseif (($parts['scheme']??'')==='https' && ($parts['host']??'')==='graph.facebook.com' && ($parts['path']??'')==='/me') {
        native_assert(($args['headers']['Authorization']??'')==='Bearer fixture-access-token','Profile request uses bearer user proof');
        native_assert(($query['appsecret_proof']??'')===hash_hmac('sha256','fixture-access-token','fixture-server-secret') && !isset($query['access_token']),'Profile request keeps token out of URL and binds app secret');
        $body=$GLOBALS['facebook_me'];
    } else throw new RuntimeException('Untrusted Meta endpoint');
    return array('response'=>array('code'=>$GLOBALS['facebook_http_status']??200),'body'=>!empty($GLOBALS['facebook_http_invalid_json'])?'invalid-json':json_encode($body));
};
facebook_http_fixture();
$config=facebook_config();
native_assert($config['methods']['facebook_native']===true && $config['facebook']===array('app_id'=>'123456789','client_token'=>'fixture-public-client-token'),'Facebook public SDK configuration');
native_assert(!str_contains(json_encode($config),'fixture-server-secret'),'Public settings exclude app secret');
$provider->linkUserToProviderIdentifier(7,'700001');
$challenge=facebook_challenge();
$returning=native_data(facebook_exchange($challenge,array('access_token'=>'fixture-access-token')),'Returning Nextend Facebook');
native_assert($returning['status']==='authenticated' && $returning['user_id']===7,'Existing Nextend customer retains identity without email');
native_rejected(facebook_exchange($challenge,array('access_token'=>'fixture-access-token')),'Challenge replay rejected');

// Capability is separate from website fallback, bound to the same enabled Nextend app.
$website_method=$config['methods']['facebook'];
foreach(array('facebook_native_enabled','android_facebook_native_ready') as $key) {
    $GLOBALS['native_options']['mobishop_native_auth_settings'][$key]=false;
    $disabled=facebook_config();
    native_assert(!$disabled['methods']['facebook_native'] && $disabled['facebook']===null && $disabled['methods']['facebook']===$website_method,'Native disable preserves browser capability');
    native_rejected($endpoint->facebook_challenge(native_request(array('verifier'=>str_repeat('f',64)))),'Disabled challenge unavailable');
    $GLOBALS['native_options']['mobishop_native_auth_settings']=$settings;
}
foreach(array(array('app_id'=>'987654321'),array('app_secret'=>'different-secret'),array('client_token'=>''),array('client_token'=>array('bad')),array('app_id'=>array('bad'))) as $override) {
    $GLOBALS['native_options']['mobishop_native_auth_settings']['facebook']=array_merge($settings['facebook'],$override);
    native_assert(!facebook_config()['methods']['facebook_native'],'Invalid native/Nextend setting fails closed');
}
$GLOBALS['native_options']['mobishop_native_auth_settings']=$settings;
$provider->enabled=false; native_assert(!facebook_config()['methods']['facebook_native'],'Disabled Nextend cannot activate native Facebook'); $provider->enabled=true;
unset($GLOBALS['native_options']['mobishop_native_auth_settings']['facebook']['app_id']);
native_assert(facebook_config()['facebook']['app_id']==='123456789','App ID can use verified Nextend setting');
$GLOBALS['native_options']['mobishop_native_auth_settings']=$settings;
$GLOBALS['native_https']=false; native_assert(!facebook_config()['methods']['facebook_native'],'Native Facebook requires HTTPS'); $GLOBALS['native_https']=true;

// All challenges are one-use and bound to the local attempt, platform and Meta app.
foreach(array(array(),array('access_token'=>'fixture-access-token','id_token'=>'also-present'),array('access_token'=>'fixture-access-token','id_token'=>''),array('access_token'=>array('bad'))) as $proof) {
    $start=facebook_challenge(); native_rejected(facebook_exchange($start,$proof),'Invalid proof shape rejected');
}
$start=facebook_challenge();
native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token'),'android',str_repeat('e',64)),'Foreign verifier cannot use challenge');
native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token'),'ios'),'Foreign platform cannot use challenge');
$provider->settings->values['appid']='987654321';
$GLOBALS['native_options']['mobishop_native_auth_settings']['facebook']['app_id']='987654321';
native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token')),'App change cannot reuse challenge');
$provider->settings->values['appid']='123456789'; $GLOBALS['native_options']['mobishop_native_auth_settings']=$settings;
$start=facebook_challenge();
$ticket_key='_mobishop_native_auth_'.hash_hmac('sha256',$start['ticket'],wp_salt('auth'));
$GLOBALS['native_options'][$ticket_key]['expires']=time()-1;
native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token')),'Expired challenge rejected');
$start=facebook_challenge(); $wpdb->race=true;
$http_before=count($GLOBALS['native_http']);
native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token')),'Atomic challenge loser rejected');
native_assert(count($GLOBALS['native_http'])===$http_before,'Challenge loser makes no provider request');

// Classic proof is checked against Meta before any session/identity mutation.
foreach(array(array('is_valid'=>false),array('is_valid'=>'true'),array('type'=>'PAGE'),array('app_id'=>'987654321'),array('expires_at'=>time()-1),array('expires_at'=>0),array('data_access_expires_at'=>time()-1),array('user_id'=>'not-a-subject')) as $override) {
    facebook_http_fixture(); $GLOBALS['facebook_debug']['data']=array_merge($GLOBALS['facebook_debug']['data'],$override);
    $start=facebook_challenge(); $issued=count($GLOBALS['native_issued']);
    native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token')),'Invalid classic proof rejected');
    native_assert(count($GLOBALS['native_issued'])===$issued,'Invalid classic proof issues no session');
    facebook_http_fixture(); native_rejected(facebook_exchange($start,array('access_token'=>'fixture-access-token')),'Failed proof consumes its challenge');
}
facebook_http_fixture(); $GLOBALS['facebook_me']['id']='other-id';
native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Debug/profile subject mismatch rejected');
foreach(array(302,503) as $status) {
    facebook_http_fixture(); $GLOBALS['facebook_http_status']=$status;
    native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Meta redirect/error rejected');
}
facebook_http_fixture(); $GLOBALS['facebook_http_invalid_json']=true;
native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Malformed Meta JSON rejected');
facebook_http_fixture();
foreach(array('',str_repeat('x',4097),"bad\ntoken") as $token) native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>$token)),'Malformed classic token rejected');

// Real RSA signatures prove the iOS Limited Login path; Graph is not used here.
$start=facebook_challenge('ios'); $http_before=count($GLOBALS['native_http']);
$limited=native_data(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start))),'ios'),'Limited Login linked user');
native_assert($limited['user_id']===7,'Limited Login preserves existing Facebook identity');
foreach(array_slice($GLOBALS['native_http'],$http_before) as $call) native_assert($call['url']==='https://www.facebook.com/.well-known/oauth/openid/jwks/','Limited Login uses only fixed JWKS');
foreach(array(array('iss'=>'https://attacker.invalid'),array('aud'=>'wrong-app'),array('nonce'=>'wrong-nonce'),array('nonce'=>array('bad')),array('exp'=>time()-1),array('iat'=>time()+90),array('iat'=>time()-601),array('nbf'=>time()+90),array('sub'=>'bad-subject')) as $override) {
    $start=facebook_challenge('ios');
    native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(array_merge(facebook_claims($start),$override))),'ios'),'Invalid Limited Login claim rejected');
}
foreach(array(array('alg'=>'HS256'),array('kid'=>''),array('crit'=>array('exp')),array('jku'=>'https://attacker.invalid/keys')) as $header) {
    $start=facebook_challenge('ios'); native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start),$header)),'ios'),'Unsafe JWT header rejected');
}
$start=facebook_challenge('ios'); $jwt=native_jwt(facebook_claims($start)); $parts=explode('.',$jwt); $parts[2]=native_b64(str_repeat('x',256));
native_rejected(facebook_exchange($start,array('id_token'=>implode('.',$parts)),'ios'),'Forged RSA signature rejected');
$start=facebook_challenge(); native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start)))),'Android cannot use Limited Login path');
foreach(array(array('keys'=>array(facebook_jwk(),facebook_jwk())),array('keys'=>array(array_merge(facebook_jwk(),array('n'=>'bad')))),array('keys'=>array(array_merge(facebook_jwk(),array('alg'=>'HS256'))))) as $jwks) {
    delete_transient('mobishop_native_facebook_certs'); delete_transient('mobishop_native_facebook_certs_refresh'); $GLOBALS['facebook_jwks']=$jwks;
    $start=facebook_challenge('ios'); native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start))),'ios'),'Ambiguous or malformed JWKS rejected');
}
$GLOBALS['facebook_jwks']=array('keys'=>array(facebook_jwk('rotated-kid'))); delete_transient('mobishop_native_facebook_certs_refresh');
$start=facebook_challenge('ios');
native_assert(native_data(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start),array('kid'=>'rotated-kid'))),'ios'),'Rotated Meta key')['user_id']===7,'Rotated Meta key accepted after bounded refresh');
$http_before=count($GLOBALS['native_http']);
for($index=0;$index<2;$index++) {
    $start=facebook_challenge('ios'); native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start),array('kid'=>'unknown-'.$index))),'ios'),'Unknown Meta kid rejected');
}
native_assert(count($GLOBALS['native_http'])===$http_before,'Random kid does not trigger unbounded JWKS refresh');

// Identity policy: elevated accounts, duplicate mappings and stale local caches fail closed.
foreach(array(8,10) as $id) {
    $subject=(string)(700000+$id); $provider->linkUserToProviderIdentifier($id,$subject); facebook_http_fixture($subject);
    native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Elevated customer cannot receive native Facebook session');
}
$GLOBALS['native_facebook_rows'][]=array('type'=>'fb','id'=>9,'subject'=>'700001'); facebook_http_fixture();
native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Duplicate Nextend mapping rejected');
array_pop($GLOBALS['native_facebook_rows']);
$GLOBALS['native_meta'][7]['_mobishop_facebook_identity']=hash('sha256','123456789|700001');
$provider->removeConnectionByUserID(7);
$unlinked=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Unlinked identity');
native_assert($unlinked['status']==='registration_required','Local marker alone cannot resurrect a Nextend unlink');
$provider->linkUserToProviderIdentifier(7,'700001');

// Unlinked Facebook email is only profile data; verified phone and selection grant account access.
facebook_http_fixture('710001','customer@gmail.com');
$start=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Matching email Facebook');
native_assert($start['status']==='registration_required' && !$provider->getUserIDByProviderIdentifier('710001'),'Matching email does not link or authenticate');
native_rejected($endpoint->register_customer(native_request(array('ticket'=>$start['ticket'],'verifier'=>str_repeat('f',64),'name'=>'Fixture','password'=>'fixture-password'))),'No registration without phone proof');
$phone=native_data(native_phone($endpoint,str_repeat('f',64),'+201012345678',array('ticket'=>$start['ticket'])),'Facebook verified shared phone');
native_assert($phone['status']==='select_account' && !$provider->getUserIDByProviderIdentifier('710001'),'Shared phone requires explicit selection before linking');
$original_email=$GLOBALS['native_users'][9]['email'];
$selected=native_data(native_select($endpoint,$phone['ticket'],str_repeat('f',64),9),'Facebook selected phone customer');
native_assert($selected['user_id']===9 && $provider->getUserIDByProviderIdentifier('710001')===9 && $GLOBALS['native_users'][9]['email']===$original_email,'Independent phone proof links selected customer without changing email');
native_assert(!get_user_meta(9,'_mobishop_google_subject',true) || get_user_meta(9,'_mobishop_google_subject',true)!=='710001','Facebook never writes a Google subject');

// New missing-email registration may collect an explicitly unverified contact, never a phone identity.
function facebook_registration($subject,$phone,$email=null) {
    global $endpoint;
    facebook_http_fixture($subject,$email);
    $start=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'New Facebook identity');
    $enroll=native_data($endpoint->phone_enroll(native_request(array('ticket'=>$start['ticket'],'verifier'=>str_repeat('f',64),'phone'=>$phone))),'Facebook contact prepare');
    return native_data($endpoint->phone_confirm(native_request(array('ticket'=>$enroll['ticket'],'verifier'=>str_repeat('f',64),'phone'=>$phone))),'Facebook contact confirm');
}
function facebook_register($ticket,$extra=array()) {
    global $endpoint;
    return $endpoint->register_customer(native_request(array_merge(array('ticket'=>$ticket['ticket'],'verifier'=>str_repeat('f',64),'name'=>'Facebook fixture','password'=>'fixture-password'),$extra)));
}
$registration=facebook_registration('720001','+201088887771');
$registered=native_data(facebook_register($registration),'New Facebook registration'); $facebook_id=$registered['user_id'];
native_assert($provider->getUserIDByProviderIdentifier('720001')===$facebook_id && $GLOBALS['native_users'][$facebook_id]['email']==='','New missing-email identity binds to Nextend');
native_assert(get_user_meta($facebook_id,'kidia_unverified_phone',true)==='+201088887771' && !get_user_meta($facebook_id,'kidia_login_phone',true) && !get_user_meta($facebook_id,'billing_phone',true),'Contact never becomes verified login/billing phone');
native_rejected(facebook_register($registration),'Registration ticket replay rejected');
$owner=native_data(native_phone($endpoint,str_repeat('f',64),'+201088887771'),'Real phone owner after contact claim');
native_assert($owner['status']==='registration_required','OTP cannot authenticate unverified contact claimant');

// Pending existing accounts retain independent phone proof and recheck ownership under leases.
$GLOBALS['native_meta'][7]['kidia_phone_setup_required']='account'; facebook_http_fixture();
$pending=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Pending existing Facebook');
native_assert($pending['status']==='registration_required','Existing Facebook pending profile not bypassed');
native_rejected($endpoint->phone_enroll(native_request(array('ticket'=>$pending['ticket'],'verifier'=>str_repeat('f',64),'phone'=>'+201088887772'))),'Existing account cannot relax phone proof');
$verified=native_data(native_phone($endpoint,str_repeat('f',64),'+201012345678',array('ticket'=>$pending['ticket'])),'Pending Facebook phone verified');
$before_user=$GLOBALS['native_users'][7]; $provider->removeConnectionByUserID(7);
native_rejected(facebook_register($verified),'Revoked Facebook mapping cannot complete old ticket');
native_assert($GLOBALS['native_users'][7]===$before_user,'Revoked proof changes no profile');
$provider->linkUserToProviderIdentifier(7,'700001'); delete_user_meta(7,'kidia_phone_setup_required');

// Subject races, partial provider writes and metadata failure cannot duplicate customers or reserve email forever.
foreach(array('insert','metadata') as $index=>$failure) {
    $subject=(string)(730001+$index); $email='facebook-failure-'.$index.'@example.test';
    $registration=facebook_registration($subject,'+20108888778'.$index,$email);
    if($failure==='insert') $provider->fail_insert=true; else $GLOBALS['native_fail_meta']='_mobishop_facebook_identity';
    native_rejected(facebook_register($registration),'Partial Facebook binding rejected');
    native_assert(!email_exists($email) && !$provider->getUserIDByProviderIdentifier($subject),'Only new failed customer and its mapping rolled back');
    $provider->fail_insert=false; unset($GLOBALS['native_fail_meta']);
}
$first=facebook_registration('740001','+201088887781'); $second=facebook_registration('740001','+201088887782');
$one=native_data(facebook_register($first),'First parallel registration');
$created_before=count($GLOBALS['native_created']);
native_rejected(facebook_register($second),'Competing registration ticket rejected');
native_assert(count($GLOBALS['native_created'])===$created_before && $provider->getUserIDByProviderIdentifier('740001')===$one['user_id'],'Parallel subject cannot create second customer');
$registration=facebook_registration('750001','+201088887783');
$GLOBALS['on_native_lock']=static function() use($provider) { unset($GLOBALS['on_native_lock']); $provider->linkUserToProviderIdentifier(11,'750001'); };
$created_before=count($GLOBALS['native_created']); native_rejected(facebook_register($registration),'Subject ownership change under lease rejected');
native_assert(count($GLOBALS['native_created'])===$created_before && $provider->getUserIDByProviderIdentifier('750001')===11,'Concurrent subject owner preserved');

// Network failure stays generic; a failed first JWKS read is also rate-bounded.
facebook_http_fixture(); $GLOBALS['facebook_http_error']=true;
$failed=facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token'));
native_rejected($failed,'Meta network failure rejected');
native_assert(!str_contains($failed->get_error_message(),'fixture-access-token'),'Provider error never leaks proof');
delete_transient('mobishop_native_facebook_certs'); delete_transient('mobishop_native_facebook_certs_refresh');
$start=facebook_challenge('ios'); native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start))),'ios'),'JWKS outage rejected');
$http_before=count($GLOBALS['native_http']);
$start=facebook_challenge('ios'); native_rejected(facebook_exchange($start,array('id_token'=>native_jwt(facebook_claims($start))),'ios'),'Repeated JWKS outage remains rejected');
native_assert(count($GLOBALS['native_http'])===$http_before,'Empty JWKS cache cannot bypass refresh cooldown');
facebook_http_fixture();

// Another Facebook subject already attached to the selected user cannot be replaced.
facebook_http_fixture('760001');
$start=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'New Facebook to occupied user');
$phone=native_data(native_phone($endpoint,str_repeat('f',64),'+201012345678',array('ticket'=>$start['ticket'])),'Occupied shared phone');
native_rejected(native_select($endpoint,$phone['ticket'],str_repeat('f',64),7),'Existing customer provider subject cannot be overwritten');
native_assert($provider->getUserIDByProviderIdentifier('700001')===7 && !$provider->getUserIDByProviderIdentifier('760001'),'Original provider binding preserved');

// A pending account becoming elevated while acquiring its lease cannot be changed.
$GLOBALS['native_meta'][7]['kidia_phone_setup_required']='account'; facebook_http_fixture();
$pending=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Facebook pending role-race');
$verified=native_data(native_phone($endpoint,str_repeat('f',64),'+201012345678',array('ticket'=>$pending['ticket'])),'Facebook role-race verified phone');
$before_user=$GLOBALS['native_users'][7]; $issued=count($GLOBALS['native_issued']);
$GLOBALS['on_native_lock']=static function() { unset($GLOBALS['on_native_lock']); $GLOBALS['native_users'][7]['roles']=array('administrator'); };
native_rejected(facebook_register($verified),'Elevated account detected inside registration lease');
native_assert($GLOBALS['native_users'][7]['name']===$before_user['name'] && $GLOBALS['native_users'][7]['password']===$before_user['password'] && count($GLOBALS['native_issued'])===$issued,'Role race changes neither profile nor session');
$GLOBALS['native_users'][7]=$before_user; delete_user_meta(7,'kidia_phone_setup_required');

// A website writer does not hold the native lease: post-write ambiguity must issue no session.
$GLOBALS['native_users'][50010]=array('login'=>'race-phone-owner','email'=>'race-phone-owner@example.test','password'=>'fixture-password','name'=>'Race Phone Owner','roles'=>array('customer'));
$GLOBALS['native_users'][50011]=array('login'=>'race-website-owner','email'=>'race-website-owner@example.test','password'=>'fixture-password','name'=>'Race Website Owner','roles'=>array('customer'));
$GLOBALS['native_meta'][50010]=array('kidia_login_phone'=>'+201055550001');
facebook_http_fixture('770001');
$start=native_data(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'External website race start');
$GLOBALS['native_facebook_before_insert']=static function($id,$subject) {
    $GLOBALS['native_facebook_rows'][]=array('type'=>'fb','id'=>50011,'subject'=>$subject);
};
$issued=count($GLOBALS['native_issued']); $profile_before=$GLOBALS['native_users'][50010];
native_rejected(native_phone($endpoint,str_repeat('f',64),'+201055550001',array('ticket'=>$start['ticket'])),'Concurrent website mapping makes native linking fail closed');
native_assert(count($GLOBALS['native_issued'])===$issued && $GLOBALS['native_users'][50010]===$profile_before,'External writer race grants no session and changes no customer profile');
facebook_http_fixture('770001'); native_rejected(facebook_exchange(facebook_challenge(),array('access_token'=>'fixture-access-token')),'Later login also refuses duplicate Nextend subject');
native_assert($provider->getUserIDByProviderIdentifier('770001')===50011,'Native rejection preserves competing website owner');

// If the website wins during new-account insertion, rollback only the newly created native account.
$GLOBALS['native_users'][50012]=array('login'=>'race-insert-owner','email'=>'race-insert-owner@example.test','password'=>'fixture-password','name'=>'Race Insert Owner','roles'=>array('customer'));
$registration=facebook_registration('780001','+201088887790','native-insert-race@example.test');
$GLOBALS['native_before_insert_hook']=static function() {
    $GLOBALS['native_facebook_rows'][]=array('type'=>'fb','id'=>50012,'subject'=>'780001');
};
native_rejected(facebook_register($registration),'Website winner during account insert rejects native registration');
native_assert(!email_exists('native-insert-race@example.test') && $provider->getUserIDByProviderIdentifier('780001')===50012 && isset($GLOBALS['native_users'][50012]),'New-account rollback never deletes the competing website customer or link');
native_assert(!str_contains(json_encode(native_ticket_options()),'fixture-access-token') && !str_contains(json_encode(native_ticket_options()),'fixture-server-secret'),'Stored tickets retain no provider credentials');
echo 'Facebook native: '.($GLOBALS['native_checks']-$before_checks).' additional checks passed.'.PHP_EOL;
