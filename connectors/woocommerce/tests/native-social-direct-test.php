<?php
/** Signed synthetic proofs: social sign-in never requires contact enrollment. */
require __DIR__.'/native-facebook-auth-test.php';
$before_direct=$GLOBALS['native_checks'];
$GLOBALS['facebook_jwks']=['keys'=>[facebook_jwk()]];
$GLOBALS['native_options']['mobishop_native_auth_settings']['apple_enabled']=true;
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_apple_native_ready']=true;
$GLOBALS['native_options']['mobishop_native_auth_settings']['firebase']['ios']=['apiKey'=>'fixture','appId'=>'1:123:ios:abc123','projectId'=>'test-project','messagingSenderId'=>'123','iosBundleId'=>'app.fixture.native'];
function direct_social($kind,$sub,$platform='android',$email=null) {
    global $endpoint;
    native_clear_rate();
    if ($kind==='facebook') {
        facebook_http_fixture($sub,$email);
        $challenge=facebook_challenge($platform);
        return facebook_exchange($challenge,$platform==='ios'?['id_token'=>native_jwt(facebook_claims($challenge,$sub))]:['access_token'=>'fixture-access-token'],$platform);
    }
    if ($kind==='google') {
        $claims=array_replace(native_google_claims($sub),['email'=>$email ?? 'direct-'.$sub.'@gmail.com','azp'=>'web.apps.googleusercontent.com']);
    } else {
        $claims=['aud'=>'test-project','iss'=>'https://securetoken.google.com/test-project','sub'=>'firebase-'.$sub,'iat'=>time(),'exp'=>time()+3600,'auth_time'=>time(),
            'firebase'=>['sign_in_provider'=>'apple.com','identities'=>['apple.com'=>[$sub]]]];
        if ($email!==null) {$claims['email']=$email; $claims['email_verified']=true;}
    }
    return $endpoint->$kind(native_request(['platform'=>$platform,'verifier'=>str_repeat('a',64),'id_token'=>native_jwt($claims)]));
}
$direct_ids=[];
foreach ([['google','android','directga'],['google','ios','directgi'],['facebook','android','990001'],['facebook','ios','990002'],['apple','ios','directapple']] as [$kind,$platform,$sub]) {
    $start_users=count($GLOBALS['native_users']);
    $result=native_data(direct_social($kind,$sub,$platform),'New '.$kind.' '.$platform);
    $id=$result['user_id']; $direct_ids[$kind]=$id;
    native_assert($result['status']==='authenticated' && !isset($result['ticket']) && !isset($result['fields']), 'Social proof finishes immediately without enrollment');
    native_assert(count($GLOBALS['native_users'])===$start_users+1 && $GLOBALS['native_users'][$id]['roles']===['customer'], 'Exactly one ordinary customer created');
    native_assert(strlen($GLOBALS['native_users'][$id]['password'])>=64 && $GLOBALS['native_users'][$id]['name']!=='', 'Profile does not require user-supplied name or password');
    native_assert(!get_user_meta($id,'kidia_phone_setup_required',true) && !get_user_meta($id,'_mobishop_social_provisioning',true), 'Only fully provisioned customer reaches session');
    native_assert(get_user_meta($id,'_mobishop_social_login_only',true)==='1' && !get_user_meta($id,'kidia_login_phone',true), 'No fabricated phone identity');
    $again=native_data(direct_social($kind,$sub,$platform),'Repeat social proof');
    native_assert($again['user_id']===$id && count($GLOBALS['native_users'])===$start_users+1, 'Repeat uses same provider account without duplicates');
    $GLOBALS['native_options']['mobishop_native_auth_settings']['registration_enabled']=false;
    native_assert(native_data(direct_social($kind,$sub,$platform),'Existing signup disabled')['user_id']===$id,'Returning social identity ignores registration switch');
    $newsub=$kind==='facebook'?(string)((int)$sub+100):$sub.'disabled';
    native_rejected(direct_social($kind,$newsub,$platform),'Disabled registration blocks new provider account');
    $GLOBALS['native_options']['mobishop_native_auth_settings']['registration_enabled']=true;
}
// Email collision cannot merge customers or grant recovery access to a foreign email.
$old=$GLOBALS['native_users'][7];
foreach ([['google','collision-google'],['facebook','990003'],['apple','collision-apple']] as [$kind,$sub]) {
    $data=native_data(direct_social($kind,$sub,$kind==='apple'?'ios':'android','customer@gmail.com'),'Social email collision');
    native_assert($data['user_id']!==7 && get_user_by('id',$data['user_id'])->user_email==='' && $GLOBALS['native_users'][7]===$old,'Existing email owner and credentials untouched');
}
// Shipping contact is not an OTP identity, including before the bounded candidate limit.
for($i=0;$i<55;$i++) {
    $id=900000+$i; $GLOBALS['native_users'][$id]=['login'=>'contact-'.$i,'email'=>'','roles'=>['customer']];
    $GLOBALS['native_meta'][$id]=['_mobishop_social_login_only'=>'1','billing_phone'=>'+201099998888'];
}
$id=$direct_ids['apple'];
$GLOBALS['native_meta'][$id]['billing_phone']='+201099998888';
$GLOBALS['native_meta'][$id]['fme_billing_phone']='+201099998888';
$phone=native_data(native_phone($endpoint,str_repeat('b',64),'+201099998888'),'Shipping phone proof');
native_assert($phone['status']==='registration_required','OTP cannot enter any phone-less social account through shipping data');
native_assert(str_contains($GLOBALS['phone_lookup_sql'],'mobishop_social_meta'),'Contact exclusion happens in bounded database lookup');
$GLOBALS['native_meta'][$id]['kidia_login_phone']='+201099998889';
native_assert(native_data(native_phone($endpoint,str_repeat('b',64),'+201099998889'),'Explicit verified phone')['user_id']===$id,'Explicitly verified phone remains usable');
// Every required direct write fails closed and allows a clean retry.
foreach (['google','facebook','apple'] as $index=>$kind) {
    foreach (['_mobishop_social_login_only','_mobishop_social_provisioning','kidia_phone_setup_required'] as $j=>$key) {
        $sub=$kind==='facebook'?(string)(991000+$j):'failure-'.$kind.$j;
        $platform=$kind==='apple'?'ios':'android'; $users=count($GLOBALS['native_users']); $issued=count($GLOBALS['native_issued']);
        $GLOBALS['native_fail_meta']=$key;
        native_rejected(direct_social($kind,$sub,$platform),'Required direct metadata failure'); unset($GLOBALS['native_fail_meta']);
        native_assert(count($GLOBALS['native_users'])===$users && count($GLOBALS['native_issued'])===$issued,'Failed provisioning leaves no new customer/session');
        native_assert(native_data(direct_social($kind,$sub,$platform),'Retry direct metadata')['status']==='authenticated','Failure does not reserve identity forever');
    }
}
$GLOBALS['native_fail_delete_meta']='_mobishop_social_provisioning'; $issued=count($GLOBALS['native_issued']);
native_rejected(direct_social('google','recover-provisioning'),'Failed final marker deletion');
native_assert(count($GLOBALS['native_issued'])===$issued,'Unfinished provisioning issues no session'); unset($GLOBALS['native_fail_delete_meta']);
native_assert(native_data(direct_social('google','recover-provisioning'),'Recover durable provisioning')['status']==='authenticated','Fresh verified proof recovers after failed marker delete');
// Overlap after provider mapping but before failed write must not issue a session.
class Direct_Racing_Google extends Native_Test_Google_Provider {
    public function linkUserToProviderIdentifier($id,$sub) {
        $this->links[$sub]=$id;
        $GLOBALS['direct_overlap']=direct_social('google',$sub);
        return false;
    }
    public function removeConnectionByUserID($id) {
        throw new RuntimeException('Synthetic cleanup transport failure');
    }
}
$previous_google=NextendSocialLogin::$providers['google'];
NextendSocialLogin::$providers['google']=new Direct_Racing_Google();
$users=count($GLOBALS['native_users']); $issued=count($GLOBALS['native_issued']);
native_rejected(direct_social('google','direct-overlap'),'Failed provider insertion');
native_rejected($GLOBALS['direct_overlap'],'Overlapping unfinished provider proof cannot log in');
native_assert(count($GLOBALS['native_users'])===$users && count($GLOBALS['native_issued'])===$issued,'Cleanup exception preserves no orphan or premature session');
native_assert(!isset($GLOBALS['native_options'][native_lock_key('google-link:sub:direct-overlap')]),'Rollback always releases subject lease');
NextendSocialLogin::$providers['google']=$previous_google;
echo 'Direct social sign-in: '.($GLOBALS['native_checks']-$before_direct).' additional checks passed.'.PHP_EOL;
