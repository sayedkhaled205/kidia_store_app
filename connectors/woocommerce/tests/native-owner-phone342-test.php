<?php
/** Phone/password must reach the existing isolated shopping identity, with customer-equivalent OTP choices. */
declare(strict_types=1);
require __DIR__.'/storefront-admin-native-entry-test.php';
$before = $GLOBALS['native_checks'];
$phone = '+201055550342';
$GLOBALS['native_meta'][$ownerId]['kidia_login_phone'] = $phone;
$ownerRow = $GLOBALS['native_users'][$ownerId];
$ownerMeta = $GLOBALS['native_meta'][$ownerId];
$identify = static function($number) use ($endpoint) {
    native_clear_rate();
    return native_data($endpoint->identify(native_request([
        'identifier'=>$number, 'supports_email_password_recovery'=>true,
    ])), 'Owner phone identify');
};
$login = static function($number, $password='owner-fixture') use ($endpoint,$verifier) {
    native_clear_rate();
    return $endpoint->password(native_request(['identifier'=>$number,'password'=>$password,'verifier'=>$verifier]));
};
foreach ([$phone,'01055550342','٠١٠٥٥٥٥٠٣٤٢','۰۱۰۵۵۵۵۰۳۴۲','(+20) 105-555-0342'] as $number) {
    $data=$identify($number);
    native_assert($data['methods']===['password','phone_otp'], 'Management phone offers password and OTP without email re-entry');
    native_assert($data['identifier']===$phone && !$data['requires_email_registration'], 'Known owner is never offered enrollment');
}
native_assert($GLOBALS['native_users'][$ownerId]===$ownerRow && $GLOBALS['native_meta'][$ownerId]===$ownerMeta, 'Identification has no owner-side effects');
$resolvedCount=count($resolved);
native_rejected($login($phone,'wrong-fixture'),'Wrong phone password rejected');
native_assert(count($resolved)===$resolvedCount,'Wrong password cannot provision shopping identity');
storefront_authenticated($login($phone),$shadowId,'Owner phone and password');
native_assert($GLOBALS['native_users'][$ownerId]===$ownerRow && $GLOBALS['native_meta'][$ownerId]===$ownerMeta,'Phone sign-in preserves management account');
storefront_authenticated(native_phone($endpoint,$verifier,$phone),$shadowId,'OTP opens isolated shopping profile');
native_rejected($endpoint->phone_enroll(native_request(['phone'=>$phone,'verifier'=>$verifier])),'Protected owner cannot be enrolled as new customer');
$GLOBALS['native_after_authenticate_hook']=static function($user) use ($ownerId) { $GLOBALS['native_meta'][$ownerId]['kidia_login_phone']='+201055550343'; };
native_rejected($login($phone),'Phone changed during password authentication fails closed');
$GLOBALS['native_meta'][$ownerId]=$ownerMeta;
$GLOBALS['native_after_authenticate_hook']=static function($user) use ($ownerId) { $GLOBALS['native_users'][$ownerId]['password']='rotated-fixture'; };
native_rejected($login($phone),'Password changed during authentication fails closed');
$GLOBALS['native_users'][$ownerId]=$ownerRow;
$GLOBALS['native_after_authenticate_hook']=static function($user) use ($ownerId) { $GLOBALS['native_users'][$ownerId]['roles']=['editor']; $GLOBALS['native_users'][$ownerId]['allcaps']=['edit_posts'=>true]; };
native_rejected($login($phone),'Owner eligibility changed during authentication fails closed');
$GLOBALS['native_users'][$ownerId]=$ownerRow;
$GLOBALS['native_auth_override']=7;
native_rejected($login($phone),'Authentication hook cannot switch owner');
unset($GLOBALS['native_auth_override']);
$GLOBALS['native_meta'][$ownerId]['billing_phone']='+201055550344';
native_rejected($login('+201055550344'),'Shipping contact never overrides primary owner phone');
$GLOBALS['native_meta'][$ownerId]=$ownerMeta;
$peerId=81202;
$GLOBALS['native_users'][$peerId]=['login'=>'phone-peer','email'=>'peer@example.test','password'=>'owner-fixture','roles'=>['customer']];
$GLOBALS['native_meta'][$peerId]=['kidia_login_phone'=>$phone];
$resolvedCount=count($resolved);
$shared=native_data($login($phone),'Shared password offers explicit selection');
native_assert($shared['status']==='select_account' && count($shared['accounts'])===2,'Both proven accounts selectable');
native_assert(count($resolved)===$resolvedCount,'Ambiguity never resolves owner shopping profile');
$GLOBALS['native_users'][$peerId]['password']='peer-fixture';
storefront_authenticated($login($phone),$shadowId,'Distinct owner password selects only owner');
storefront_authenticated($login($phone,'peer-fixture'),$peerId,'Distinct customer password selects only customer');
native_assert($identify($phone)['methods']===['password','phone_otp'],'Customer sharing phone retains normal choices');
$shared=native_data(native_phone($endpoint,$verifier,$phone),'Shared phone OTP');
native_assert($shared['status']==='select_account' && count($shared['accounts'])===2,'OTP never silently selects a shared account');
unset($GLOBALS['native_users'][$peerId],$GLOBALS['native_meta'][$peerId]);
$withoutOwner=new MobiShop_Native_Customer_Auth_Endpoint(static fn($u)=>new WP_REST_Response([]),static fn($u)=>$u->roles===['customer']);
native_clear_rate();
$data=native_data($withoutOwner->identify(native_request(['identifier'=>$phone,'supports_email_password_recovery'=>true])),'No owner mapping configured');
native_assert($data['methods']===['email_password'],'Unconfigured owner shopping preserves original safe fallback');
native_rejected($withoutOwner->password(native_request(['identifier'=>$phone,'password'=>'owner-fixture','verifier'=>$verifier])),'No owner callback cannot issue owner session');
echo 'Owner phone/password routes: '.($GLOBALS['native_checks']-$before)." additional checks passed.\n";
