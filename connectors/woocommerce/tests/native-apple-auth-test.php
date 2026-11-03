<?php
/** Real-signature Apple provider contracts; all identities and keys are fixtures. */
require __DIR__ . '/native-auth-contract-test.php';
$before = $GLOBALS['native_checks'];
$settings = $GLOBALS['native_options']['mobishop_native_auth_settings'];
$settings['phone_enabled'] = false;
$settings['apple_enabled'] = true;
$settings['ios_apple_native_ready'] = true;
$settings['firebase']['ios'] = array( 'apiKey' => 'fixture-ios-api', 'appId' => '1:123:ios:fixture', 'projectId' => 'test-project', 'messagingSenderId' => '123', 'iosBundleId' => 'app.fixture.native' );
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings;
$apple_claims = array( 'aud'=>'test-project', 'iss'=>'https://securetoken.google.com/test-project', 'sub'=>'firebase-apple-fixture',
    'exp'=>time()+3600, 'iat'=>time(), 'auth_time'=>time(), 'email'=>'relay@privaterelay.appleid.com', 'email_verified'=>true,
    'firebase'=>array('sign_in_provider'=>'apple.com','identities'=>array('apple.com'=>array('apple.subject.fixture'))) );
function apple_request(array $claims, array $extra = array()) {
    native_clear_rate();
    return native_request(array_merge(array('id_token'=>native_jwt($claims), 'verifier'=>str_repeat('c',64), 'platform'=>'ios'),$extra));
}
$ios = native_data($endpoint->config(native_request(array('platform'=>'ios'))),'Apple ready config');
native_assert($ios['methods']['apple'] && !$ios['methods']['phone_otp'] && $ios['firebase']['projectId']==='test-project','Apple does not depend on phone OTP');
native_assert(!native_data($endpoint->config(native_request(array('platform'=>'android'))),'Android config')['methods']['apple'],'Apple not advertised on Android');
native_rejected($endpoint->apple(apple_request($apple_claims,array('platform'=>'android'))),'Android cannot opt into Apple');
foreach(array(
    array('aud'=>'other-project'), array('iss'=>'https://securetoken.google.com/other-project'), array('auth_time'=>time()-601),
    array('iat'=>time()+90), array('exp'=>time()-1), array('sub'=>str_repeat('x',129)), array('email_verified'=>false),
    array('firebase'=>array('sign_in_provider'=>'google.com','identities'=>array('apple.com'=>array('apple.subject.fixture')))),
    array('firebase'=>array('sign_in_provider'=>'apple.com','identities'=>array())),
    array('firebase'=>array('sign_in_provider'=>'apple.com','identities'=>array('apple.com'=>array('a','b')))),
) as $override) native_rejected($endpoint->apple(apple_request(array_merge($apple_claims,$override))),'Invalid Apple claims rejected');
native_rejected($endpoint->apple(apple_request($apple_claims,array('id_token'=>'forged'))),'Bad signature rejected');
$issued = count($GLOBALS['native_issued']);
native_rejected($endpoint->apple(apple_request(array_merge($apple_claims,array('email'=>'customer@gmail.com')))),'Matching email cannot merge existing account');
native_assert(count($GLOBALS['native_issued'])===$issued,'Conflict issued no customer session');
$ticket = native_data($endpoint->apple(apple_request($apple_claims)),'New Apple account');
native_assert($ticket['fields']===array('name'),'Apple collects name only, no forced password/phone');
$registration = array('ticket'=>$ticket['ticket'],'verifier'=>str_repeat('c',64),'platform'=>'ios','name'=>'Apple Fixture');
native_rejected($endpoint->register_customer(native_request(array_merge($registration,array('name'=>'')))),'Missing name rejected');
$registered = native_data($endpoint->register_customer(native_request($registration)),'Apple registration');
$apple_id = $registered['user_id'];
native_assert($registered['status']==='authenticated' && $apple_id!==7,'New isolated customer created');
native_assert(get_user_meta($apple_id,'_mobishop_firebase_uid',true)==='firebase-apple-fixture','Verified Firebase identity retained for erasure');
native_assert(!get_user_meta($apple_id,'_mobishop_google_subject',true),'Apple never becomes a Google subject');
native_assert(!get_user_meta($apple_id,'kidia_login_phone',true),'Apple creates no phone ownership claim');
native_rejected($endpoint->register_customer(native_request($registration)),'Registration ticket cannot replay');
$repeat_claims=$apple_claims; unset($repeat_claims['email'],$repeat_claims['email_verified']);
$repeat = native_data($endpoint->apple(apple_request($repeat_claims)),'Returning Apple with no name/email');
native_assert($repeat['user_id']===$apple_id,'Returning proof reaches only linked account');
native_rejected($endpoint->apple(apple_request(array_merge($apple_claims,array('sub'=>'different-firebase-uid')))),'Same Apple subject with unexpected Firebase UID fails closed');
foreach (array('_mobishop_apple_identity', '_mobishop_apple_subject', '_mobishop_firebase_project', '_mobishop_firebase_uid') as $index => $failed_key) {
    $claims = $apple_claims;
    $claims['email'] = "fixture$index@privaterelay.appleid.com";
    $claims['sub'] = "firebase-fixture-$index";
    $claims['firebase']['identities']['apple.com'] = array("apple.subject.$index");
    $ticket = native_data($endpoint->apple(apple_request($claims)), 'Metadata failure registration');
    $request = array('ticket'=>$ticket['ticket'], 'verifier'=>str_repeat('c',64), 'platform'=>'ios','name'=>'Fixture');
    $GLOBALS['native_fail_meta']=$failed_key;
    native_rejected($endpoint->register_customer(native_request($request)), 'Partial identity binding rejected');
    unset($GLOBALS['native_fail_meta']);
    native_assert(!email_exists($claims['email']), 'Failed identity binding rolls back only newly created customer');
    $retry = native_data($endpoint->apple(apple_request($claims)), 'Fresh proof can retry');
    $request['ticket']=$retry['ticket'];
    native_assert(native_data($endpoint->register_customer(native_request($request)), 'Retry registration')['status']==='authenticated','Fresh registration succeeds after failure');
}
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_apple_native_ready']=false;
native_rejected($endpoint->apple(apple_request($apple_claims)),'Disabled Apple provider rejected');
echo 'Apple native: '.($GLOBALS['native_checks']-$before).' additional checks passed.'.PHP_EOL;
