<?php
/** Management/customer login parity with synthetic signed proofs, no external calls. */
declare(strict_types=1);
require __DIR__.'/storefront-admin-native-entry-test.php';
$before=$GLOBALS['native_checks'];
$phone='+201055550343';
$GLOBALS['native_meta'][$ownerId]['kidia_login_phone']=$phone;
$ownerRow=$GLOBALS['native_users'][$ownerId];
$ownerMeta=$GLOBALS['native_meta'][$ownerId];
$issueHook=null; $resolveHook=null; $proofs=[];
$endpoint=new MobiShop_Native_Customer_Auth_Endpoint(
    static function($shopper,$ownerProof=null) use (&$issueHook,&$proofs,$shadowId,$ownerId) {
        if ($shopper->ID===$shadowId) {
            native_assert(($ownerProof['id']??0)===$ownerId,'Issuer receives canonical owner proof');
            native_assert($ownerProof['password']===get_user_by('id',$ownerId)->user_pass,'Issuer receives current password version');
            $proofs[]=$ownerProof;
        }
        if ($issueHook) { $hook=$issueHook; $issueHook=null; return $hook($shopper,$ownerProof); }
        return new WP_REST_Response(['user_id'=>$shopper->ID]);
    }, static fn($u)=>$u->roles===['customer'] && empty($u->allcaps['manage_options']) && empty($u->allcaps['edit_users']) && empty($u->allcaps['manage_woocommerce']), null,
    static function($owner) use (&$resolveHook,$shadowId) {
        if ($resolveHook) { $hook=$resolveHook; $resolveHook=null; $hook(); }
        return get_user_by('id',$shadowId);
    }
);
$otp=static function($extra=[]) use (&$endpoint,$phone,$verifier) {
    native_clear_rate();
    return $endpoint->phone_verify(native_request(array_merge(['phone'=>$phone,'verifier'=>$verifier,'id_token'=>native_jwt(native_phone_claims($phone))],$extra)));
};
$password=static function() use (&$endpoint,$phone,$verifier) {
    native_clear_rate(); return $endpoint->password(native_request(['identifier'=>$phone,'password'=>'owner-fixture','verifier'=>$verifier]));
};
$choose=static function($ticket,$id) use (&$endpoint,$verifier) {
    native_clear_rate(); return $endpoint->select(native_request(['ticket'=>$ticket,'account_id'=>$id,'verifier'=>$verifier]));
};
foreach ([['administrator'],['shop_manager'],['customer']] as $roles) {
    $GLOBALS['native_users'][$ownerId]['roles']=$roles;
    $GLOBALS['native_users'][$ownerId]['allcaps']=['manage_woocommerce'=>true];
    native_clear_rate();
    $identified=native_data($endpoint->identify(native_request(['identifier'=>$phone])),'Management identify');
    native_assert($identified['methods']===['password','phone_otp'],'Every management role has customer login choices');
    storefront_authenticated($password(),$shadowId,'Management phone password');
    storefront_authenticated($otp(),$shadowId,'Management verified OTP');
    storefront_authenticated(owner_password('owner-fixture'),$shadowId,'Management email password');
}
$GLOBALS['native_users'][$ownerId]=$ownerRow;
native_assert($GLOBALS['native_meta'][$ownerId]===$ownerMeta,'OTP never mutates management credentials or phone');
native_assert(!get_user_meta($shadowId,'kidia_login_phone',true),'Shopping alias never duplicates canonical phone identity');
native_clear_rate();
$conflict=$endpoint->phone_enroll(native_request(['phone'=>$phone,'verifier'=>$verifier]));
native_assert($conflict instanceof WP_Error && $conflict->get_error_code()==='mobishop_native_existing_phone','Existing management number uses normal existing-account recovery');
storefront_authenticated(owner_google([],['expected_phone'=>$phone]),$shadowId,'Linked Google after entering management phone');
native_rejected(owner_google([],['expected_phone'=>'+201055559999']),'Google cannot switch to unrelated phone');

// Apple is identified by all three provider bindings, never by email equality.
$GLOBALS['native_options']['mobishop_native_auth_settings']['apple_enabled']=true;
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_apple_native_ready']=true;
$GLOBALS['native_options']['mobishop_native_auth_settings']['firebase']['ios']=['apiKey'=>'fixture','appId'=>'1:123:ios:fixture','projectId'=>'test-project','messagingSenderId'=>'123','iosBundleId'=>'app.fixture.native'];
$apple=['aud'=>'test-project','iss'=>'https://securetoken.google.com/test-project','sub'=>'owner-apple-fixture','iat'=>time(),'auth_time'=>time(),'exp'=>time()+3600,'firebase'=>['sign_in_provider'=>'apple.com','identities'=>['apple.com'=>['owner.apple.fixture']]]];
$GLOBALS['native_meta'][$ownerId]+=['_mobishop_apple_identity'=>hash('sha256','test-project|owner.apple.fixture'),'_mobishop_apple_subject'=>'owner.apple.fixture','_mobishop_firebase_project'=>'test-project','_mobishop_firebase_uid'=>'owner-apple-fixture'];
$appleLogin=static function($claims) use (&$endpoint,$verifier) { native_clear_rate(); return $endpoint->apple(native_request(['platform'=>'ios','verifier'=>$verifier,'id_token'=>native_jwt($claims)])); };
storefront_authenticated($appleLogin($apple),$shadowId,'Linked management Apple');
native_rejected($appleLogin(array_replace($apple,['sub'=>'other-uid'])),'Wrong Apple Firebase UID rejected');
$GLOBALS['native_meta'][$ownerId]=$ownerMeta;

// Shared phone and password require explicit selection, bound to the proven state.
$peerId=81202;
$GLOBALS['native_users'][$peerId]=['login'=>'shared-peer','email'=>'shared@example.test','password'=>'owner-fixture','roles'=>['customer']];
$GLOBALS['native_meta'][$peerId]=['kidia_login_phone'=>$phone];
foreach ([$otp,$password] as $begin) {
    $pick=native_data($begin(),'Shared verified identity');
    native_assert($pick['status']==='select_account' && count($pick['accounts'])===2,'Owner/customer are both explicit choices');
    storefront_authenticated($choose($pick['ticket'],$ownerId),$shadowId,'Select management shopping profile');
    native_rejected($choose($pick['ticket'],$peerId),'Selection ticket cannot replay');
    $pick=native_data($begin(),'Shared proof again');
    storefront_authenticated($choose($pick['ticket'],$peerId),$peerId,'Select ordinary customer');
    foreach (['phone','password','generation','role'] as $change) {
        $pick=native_data($begin(),'Capture owner state');
        if ($change==='phone') $GLOBALS['native_meta'][$ownerId]['kidia_login_phone']='+201055559999';
        if ($change==='password') $GLOBALS['native_users'][$ownerId]['password']='rotated';
        if ($change==='generation') $GLOBALS['native_meta'][$ownerId]['_mobishop_auth_generation_v1']='rotated';
        if ($change==='role') { $GLOBALS['native_users'][$ownerId]['roles']=['customer']; $GLOBALS['native_users'][$ownerId]['allcaps']=[]; }
        native_rejected($choose($pick['ticket'],$ownerId),'Changed '.$change.' rejects stale owner selection');
        $GLOBALS['native_users'][$ownerId]=$ownerRow; $GLOBALS['native_meta'][$ownerId]=$ownerMeta;
    }
    $pick=native_data($begin(),'Capture ordinary customer proof');
    $GLOBALS['native_users'][$peerId]['roles']=['administrator']; $GLOBALS['native_users'][$peerId]['allcaps']=['manage_options'=>true];
    native_rejected($choose($pick['ticket'],$peerId),'Customer promoted after proof cannot become management login');
    $GLOBALS['native_users'][$peerId]['roles']=['customer']; $GLOBALS['native_users'][$peerId]['allcaps']=[];
}
unset($GLOBALS['native_users'][$peerId],$GLOBALS['native_meta'][$peerId]);
$resolveHook=static function() use ($ownerId) { $GLOBALS['native_meta'][$ownerId]['kidia_login_phone']='+201055559999'; };
native_rejected($otp(),'Phone change inside resolver rejects OTP');
$GLOBALS['native_meta'][$ownerId]=$ownerMeta;

// A new Google identity plus verified phone creates app-only access, never dashboard SSO.
$google=static function($sub,$extra=[]) use (&$endpoint,$verifier) { native_clear_rate(); return $endpoint->google(native_request(array_merge(['verifier'=>$verifier,'id_token'=>native_jwt(array_replace(native_google_claims($sub),['email'=>'new-fixture@gmail.com']))],$extra))); };
$GLOBALS['native_string_ids']=true;
$remoteBefore=NextendSocialLogin::$providers['google']->links;
$start=native_data($google('app-only-owner-google'),'New Google proof');
$parallel=native_data($google('app-only-owner-google'),'Parallel older Google ticket');
storefront_authenticated($otp(['ticket'=>$start['ticket']]),$shadowId,'Verified owner phone completes new app-only Google link');
native_assert(NextendSocialLogin::$providers['google']->links===$remoteBefore,'New mobile grant never changes dashboard SSO');
storefront_authenticated($google('app-only-owner-google'),$shadowId,'Returning app-only Google');
$GLOBALS['native_users'][81300]=['login'=>'other-phone-owner','email'=>'other-phone@example.test','password'=>'other-pass','roles'=>['customer']];
$GLOBALS['native_meta'][81300]=['kidia_login_phone'=>'+201055550999'];
native_rejected($otp(['ticket'=>$parallel['ticket'],'phone'=>'+201055550999','id_token'=>native_jwt(native_phone_claims('+201055550999'))]),'Stale customer ticket cannot steal app-reserved Google subject');
native_assert(NextendSocialLogin::$providers['google']->links===$remoteBefore,'Stale ticket does not add canonical Google binding');
$grantBefore=$GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant'];
$resolveHook=static function() use ($shadowId) { NextendSocialLogin::$providers['google']->links['app-only-owner-google']=7; $GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']['active']=false; };
native_rejected($google('app-only-owner-google'),'Changed grant/mapping during profile resolution cannot issue a session');
unset(NextendSocialLogin::$providers['google']->links['app-only-owner-google']);
$GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']=$grantBefore;

storefront_authenticated($google('app-only-owner-google',['expected_phone'=>$phone]),$shadowId,'Returning app-only Google from phone step');
$GLOBALS['native_users'][$ownerId]['password']='reset-password';
$GLOBALS['native_meta'][$ownerId]['_mobishop_auth_generation_v1']='reset-generation';
storefront_authenticated($google('app-only-owner-google'),$shadowId,'Active provider binding survives ordinary password reset');
$GLOBALS['native_users'][$ownerId]=$ownerRow; $GLOBALS['native_meta'][$ownerId]=$ownerMeta;
NextendSocialLogin::$providers['google']->links['app-only-owner-google']=7;
native_rejected($google('app-only-owner-google'),'Conflicting website/provider mapping is never ignored');
unset(NextendSocialLogin::$providers['google']->links['app-only-owner-google']);
$saved=$endpoint;
$endpoint=new MobiShop_Native_Customer_Auth_Endpoint(static fn($u)=>new WP_REST_Response(['user_id'=>$u->ID]),static fn($u)=>$u->roles===['customer']);
native_rejected($google('app-only-owner-google'),'App-only grant cannot authenticate website/no-callback channel');
native_rejected($otp(),'No callback cannot open management OTP');
$endpoint=$saved;

// Failed issuer leaves a pending grant unusable. Fresh OTP can recover it.
unset($GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_identity'],$GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']);
$start=native_data($google('pending-owner-google'),'Prepare pending grant');
$issueHook=static fn()=>new WP_Error('fixture_issue_failed');
native_rejected($otp(['ticket'=>$start['ticket']]),'Failed session issuer');
native_assert($GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']['active']===false,'Failed grant remains pending');
$GLOBALS['native_options']['mobishop_native_auth_settings']['registration_enabled']=false;
$retry=native_data($google('pending-owner-google'),'Pending grant requires fresh phone proof even with new registrations disabled');
native_assert($retry['status']==='registration_required','Pending grant cannot log in');
storefront_authenticated($otp(['ticket'=>$retry['ticket']]),$shadowId,'Fresh phone proof recovers pending grant');
storefront_authenticated($google('pending-owner-google'),$shadowId,'Recovered grant can log in');
$GLOBALS['native_options']['mobishop_native_auth_settings']['registration_enabled']=true;

// A concurrent newer attempt cannot be activated by an older issuer response.
unset($GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_identity'],$GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']);
$start=native_data($google('cas-owner-google'),'Prepare CAS race');
$issueHook=static function() use ($shadowId) { $GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']['attempt']='newer-attempt'; return new WP_REST_Response(['user_id'=>$shadowId]); };
native_rejected($otp(['ticket'=>$start['ticket']]),'Older issuer cannot activate a newer pending attempt');
native_assert($GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']['active']===false,'Newer grant remains pending');
$retry=native_data($google('cas-owner-google'),'Prepare owner version race');
$issueHook=static function() use ($ownerId,$shadowId) { $GLOBALS['native_users'][$ownerId]['password']='raced'; return new WP_REST_Response(['user_id'=>$shadowId]); };
native_rejected($otp(['ticket'=>$retry['ticket']]),'Owner reset during issuer prevents grant activation');
$GLOBALS['native_users'][$ownerId]=$ownerRow;
native_assert($GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_google_grant']['active']===false,'Raced grant never activates');

// Facebook follows the same isolated grant path with strict app-scoped provider proof.
$fbRemote=$GLOBALS['native_facebook_rows'];
facebook_http_fixture('812003','new-facebook@example.test');
$fbStart=native_data(facebook_exchange(facebook_challenge(),['access_token'=>'fixture-access-token']),'New Facebook identity');
$fbParallel=native_data(facebook_exchange(facebook_challenge(),['access_token'=>'fixture-access-token']),'Parallel Facebook ticket');
storefront_authenticated($otp(['ticket'=>$fbStart['ticket'],'verifier'=>str_repeat('f',64)]),$shadowId,'Facebook and phone link app shopper only');
native_assert($GLOBALS['native_facebook_rows']===$fbRemote,'Facebook app link never changes dashboard mappings');
native_rejected($otp(['ticket'=>$fbParallel['ticket'],'verifier'=>str_repeat('f',64),'phone'=>'+201055550999','id_token'=>native_jwt(native_phone_claims('+201055550999'))]),'Stale customer ticket cannot steal app-reserved Facebook identity');
native_assert($GLOBALS['native_facebook_rows']===$fbRemote,'Stale Facebook ticket does not add canonical binding');

storefront_authenticated(facebook_exchange(facebook_challenge(),['access_token'=>'fixture-access-token']),$shadowId,'Returning app-only Facebook');
$GLOBALS['native_meta'][$shadowId]['_mobishop_storefront_facebook_identity']='wrong-scope';
$unlinked=native_data(facebook_exchange(facebook_challenge(),['access_token'=>'fixture-access-token']),'Different Facebook scope');
native_assert($unlinked['status']!=='authenticated','Other app/subject cannot reuse grant');
native_assert($GLOBALS['native_meta'][$ownerId]===$ownerMeta,'Management record remains unchanged by mobile linking');
echo 'Management login parity: '.($GLOBALS['native_checks']-$before)." additional checks passed.\n";
