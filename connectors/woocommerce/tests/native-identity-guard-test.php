<?php
require __DIR__.'/native-apple-auth-test.php';
// Boundary spy is introduced after legacy contracts; real helper behavior has its own DB tests.
eval('final class MobiShop_Customer_Identity_Guard {
    public static $deny=false, $held=false, $calls=0;
    public static function writer($id,$link,$action,$existing=null) {
        self::$calls++; self::$held=true;
        try { if ($existing && $existing()===true) return true; if(self::$deny) throw new RuntimeException("reserved"); return $action(); }
        finally { self::$held=false; }
    }
    public static function new_identity($link,$action) {
        self::$calls++; self::$held=true;
        try { if(self::$deny) throw new RuntimeException("reserved"); return $action(); }
        finally { self::$held=false; }
    }
}');
$before=$GLOBALS['native_checks'];
$method=new ReflectionMethod(MobiShop_Native_Customer_Auth_Endpoint::class,'persist_phone_identity'); $method->setAccessible(true);
$proof=['phone_firebase_identity'=>['project'=>'test-project','uid'=>'guard-fixture-phone']];
MobiShop_Customer_Identity_Guard::$deny=true;
$metaBefore=$GLOBALS['native_meta'];
native_assert($method->invoke($endpoint,7,$proof)===false,'Reserved phone UID refuses metadata write');
native_assert($GLOBALS['native_meta']===$metaBefore,'Reserved phone failure leaves metadata unchanged');
MobiShop_Customer_Identity_Guard::$deny=false;
native_assert($method->invoke($endpoint,7,$proof)===true,'Unreserved phone identity persists through guard');
MobiShop_Customer_Identity_Guard::$deny=true;
native_assert($method->invoke($endpoint,7,$proof)===true,'Read-only existing verified phone can reauthenticate during reservation');
native_assert(!MobiShop_Customer_Identity_Guard::$held,'Phone guard released before caller can issue session');
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_apple_native_ready']=true;
$guardEndpoint=new MobiShop_Native_Customer_Auth_Endpoint(function($user) {
    native_assert(!MobiShop_Customer_Identity_Guard::$held,'Apple session issuance occurs outside UID guard');
    return new WP_REST_Response(['user_id'=>$user->ID]);
}, static fn($user)=>$user instanceof WP_User);
$claims=$apple_claims; $claims['sub']='guard-apple-uid'; $claims['email']='guard-fixture@privaterelay.appleid.com'; $claims['firebase']['identities']['apple.com']=['guard-apple-subject'];
$ticket=native_data($guardEndpoint->apple(apple_request($claims)),'Guard Apple registration proof');
$registration=['ticket'=>$ticket['ticket'],'verifier'=>str_repeat('c',64),'platform'=>'ios','name'=>'Guard Fixture'];
native_rejected($guardEndpoint->register_customer(native_request($registration)),'Reserved Apple UID refuses new account');
native_assert(!email_exists($claims['email']),'Reserved Apple UID creates no partial user');
MobiShop_Customer_Identity_Guard::$deny=false;
$ticket=native_data($guardEndpoint->apple(apple_request($claims)),'Fresh unreserved Apple proof'); $registration['ticket']=$ticket['ticket'];
native_assert(native_data($guardEndpoint->register_customer(native_request($registration)),'Unreserved Apple registration')['status']==='authenticated','Apple identity guard preserves successful registration');
native_assert(MobiShop_Customer_Identity_Guard::$calls>=5,'Both native writer boundaries use guard');
echo 'Native identity guard: '.($GLOBALS['native_checks']-$before).' additional checks passed.'.PHP_EOL;
