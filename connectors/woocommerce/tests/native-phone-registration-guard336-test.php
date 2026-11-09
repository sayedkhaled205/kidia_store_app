<?php
/** Failure injection at the existing deletion identity guard, no provider/network. */
declare(strict_types=1);
$audit_source = dirname(__DIR__, 3);
require $audit_source . '/connectors/woocommerce/tests/native-identity-guard-test.php';
$phone = '+201299990003';
$verifier = str_repeat('b',64);
$GLOBALS['native_options']['mobishop_native_auth_settings']['phone_enabled'] = true;
MobiShop_Customer_Identity_Guard::$deny = true;
$claims = array_merge(native_phone_claims($phone),['sub'=>'reserved-phone-provider-fixture']);
$start = native_data(native_phone($endpoint,$verifier,$phone,['id_token'=>native_jwt($claims)]), 'Obtain phone proof for reserved provider identity');
$created_before = count($GLOBALS['native_created']);
native_clear_rate();
$register = $endpoint->register_customer(native_request(['ticket'=>$start['ticket'],'verifier'=>$verifier,'name'=>'Reserved phone fixture','password'=>'guard-fixture-password']));
$id = count($GLOBALS['native_created'])>$created_before ? end($GLOBALS['native_created']) : 0;
native_clear_rate();
$retry = $endpoint->password(native_request(['identifier'=>$phone,'password'=>'guard-fixture-password','verifier'=>$verifier]));
$key = '_mobishop_phone_firebase_identity_'.hash('sha256','test-project|reserved-phone-provider-fixture');
$observed = [
    'scenario'=>'new phone registration rejected by provider deletion guard',
    'registration_rejected'=>is_wp_error($register),
    'error'=>is_wp_error($register)?$register->get_error_code():null,
    'partial_customer_left_behind'=>$id>0 && get_user_by('id',$id)!==false,
    'phone_identity_stored'=>$id>0 && get_user_meta($id,'kidia_login_phone',true)===$phone,
    'provider_identity_missing'=>$id>0 && get_user_meta($id,$key,true)==='',
    'subsequent_password_login_succeeds'=>$retry instanceof WP_REST_Response && ($retry->data['status'] ?? '')==='authenticated',
];
echo json_encode($observed, JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES), PHP_EOL;
if (!$observed['registration_rejected'] || $observed['partial_customer_left_behind'] || $observed['subsequent_password_login_succeeds']) exit(1);
