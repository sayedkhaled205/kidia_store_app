<?php
/** Verified website contact completion must retain its signed provider identity for erasure. */
declare(strict_types=1);
$audit_source = dirname(__DIR__, 3);
require $audit_source . '/connectors/woocommerce/tests/native-auth-contract-test.php';
$id = 40001;
$phone = '+201299990002';
$GLOBALS['native_users'][$id] = ['login'=>'website-contact-fixture','email'=>'website-contact@example.invalid','password'=>'website-fixture-password','name'=>'Website fixture','roles'=>['customer']];
$GLOBALS['native_meta'][$id] = ['kidia_phone_setup_required'=>'account','kidia_profile_details_collected'=>'1'];
$GLOBALS['website_user'] = $id;
$GLOBALS['website_session'] = 'synthetic-website-session';
$website = new MobiShop_Native_Customer_Auth_Endpoint(static fn($user)=>new WP_REST_Response(['user_id'=>$user->ID]),static fn($user)=>true,'test-project');
$params = ['phone'=>$phone,'client_channel'=>'website','verifier'=>str_repeat('c',64),'nonce'=>'fixture-nonce'];
native_clear_rate();
$prepared = native_data($website->website_contact(native_request($params+['mode'=>'prepare'])), 'Prepare website contact');
$claims = array_merge(native_phone_claims($phone), ['sub'=>'website-contact-provider-uid']);
$finished = native_data($website->website_contact(native_request($params+['mode'=>'verify','ticket'=>$prepared['ticket'],'id_token'=>native_jwt($claims)])), 'Finish website verified contact');
$key = '_mobishop_phone_firebase_identity_'.hash('sha256','test-project|website-contact-provider-uid');
$observed = [
    'scenario'=>'website email account completes phone with a signed Firebase proof',
    'completion_succeeded'=>($finished['user_id'] ?? 0)===$id,
    'verified_phone_stored'=>get_user_meta($id,'kidia_login_phone',true)===$phone,
    'verified_provider_identity_stored'=>get_user_meta($id,$key,true)!=='',
];
echo json_encode($observed, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES), PHP_EOL;
if (!$observed['completion_succeeded'] || !$observed['verified_phone_stored'] || !$observed['verified_provider_identity_stored']) exit(1);
