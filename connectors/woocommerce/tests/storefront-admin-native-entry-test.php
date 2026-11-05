<?php
/** Integration of authenticated proof to the shopper-only issuing callback. No real calls. */
declare(strict_types=1);
$connector = $argv[1] ?? dirname(__DIR__);
require $connector.'/tests/native-facebook-auth-test.php';
require_once $connector.'/source/api/class-storefront-admin.php';

$before = $GLOBALS['native_checks'];
$verifier = str_repeat('c', 64);
$ownerId = 81200;
$shadowId = 81201;
$GLOBALS['native_users'][$ownerId] = [
    'login'=>'fixture-owner','email'=>'fixture-owner@gmail.com','password'=>'owner-fixture',
    'name'=>'Owner','roles'=>['administrator'],'allcaps'=>['manage_options'=>true,'edit_users'=>true]
];
$GLOBALS['native_users'][$shadowId] = [
    'login'=>'fixture-shopping','email'=>'','password'=>'unusable-fixture',
    'name'=>'Owner','roles'=>['customer'],'allcaps'=>['read'=>true]
];
$issued = [];
$resolved = [];
$endpoint = new MobiShop_Native_Customer_Auth_Endpoint(
    static function($shopper) use (&$issued) {
        $issued[] = $shopper->ID;
        return new WP_REST_Response(['user_id'=>$shopper->ID]);
    },
    static fn($user) => $user->roles === ['customer'],
    null,
    static function($owner) use (&$resolved,$ownerId,$shadowId) {
        native_assert($owner->ID === $ownerId,'Only proven fixture owner reaches resolver');
        $resolved[] = $owner->ID;
        return get_user_by('id',$shadowId);
    }
);
$owner = get_user_by('id',$ownerId);
native_clear_rate();
function owner_password($candidate) {
    global $endpoint, $owner, $verifier;
    return $endpoint->password(native_request(['identifier'=>$owner->user_email,'password'=>$candidate,'verifier'=>$verifier]));
}
function owner_google(array $replacements = [], $other = []) {
    global $endpoint, $owner, $verifier;
    $claims=array_replace(native_google_claims('fixture-owner-sub'),['email'=>$owner->user_email],$replacements);
    return $endpoint->google(native_request(array_merge(['id_token'=>native_jwt($claims),'verifier'=>$verifier],$other)));
}
function storefront_authenticated($r,$id,$label) {
    $data=native_data($r,$label);
    native_assert($data['status']==='authenticated' && $data['user_id']===$id,$label.' issued correct ID');
}
$beforeRow=$GLOBALS['native_users'][$ownerId];
$beforeGoogle=NextendSocialLogin::$providers['google']->links;
native_rejected(owner_password('wrong-fixture'),'Invalid owner password rejected');
native_assert(!$issued && !$resolved,'Unauthenticated request cannot provision shopper');
storefront_authenticated(owner_password('owner-fixture'),$shadowId,'Valid password');
storefront_authenticated(owner_google(),$shadowId,'Signed authoritative Gmail proof');
native_assert(NextendSocialLogin::$providers['google']->links === $beforeGoogle,'Google native flow cannot change dashboard SSO links');
native_rejected(owner_google(['email_verified'=>false]),'Unverified email rejected');
native_rejected(owner_google(['aud'=>'other-fixture.apps.googleusercontent.com']),'Wrong Google audience rejected');
native_rejected(owner_google([],['expected_phone'=>'+201055551234']),'Phone switch does not bypass expected owner number');
NextendSocialLogin::$providers['google']->links['fixture-owner-sub']=$ownerId;
storefront_authenticated(owner_google(),$shadowId,'Existing Google subject');
facebook_http_fixture('812001',$owner->user_email);
$unlinked = native_data(facebook_exchange(facebook_challenge(),['access_token'=>'fixture-access-token']),'Unlinked matching Facebook email');
native_assert(($unlinked['status'] ?? '') !== 'authenticated','Matching Facebook email alone never signs in owner');
$provider->linkUserToProviderIdentifier($ownerId,'812001');
storefront_authenticated(facebook_exchange(facebook_challenge(),['access_token'=>'fixture-access-token']),$shadowId,'Previously linked Facebook subject');
native_assert($issued === [$shadowId,$shadowId,$shadowId,$shadowId] && count($resolved) === count($issued),'Every and only proven owner receives shopper session');
native_assert($GLOBALS['native_users'][$ownerId] === $beforeRow && empty($GLOBALS['native_meta'][$ownerId]['_mobishop_app_last_auth_method']),'Dashboard account stays unmodified');
echo 'Storefront administrator native entry points: '.($GLOBALS['native_checks']-$before)." additional checks passed.\n";
