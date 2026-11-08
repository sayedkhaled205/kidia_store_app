<?php
/** Synthetic phone deletion/re-enrollment lifecycle. No network or real accounts. */
require __DIR__ . '/native-post-deletion-login-test.php';
$before = $GLOBALS['native_checks'];
$settings_before = $GLOBALS['native_options']['mobishop_native_auth_settings'];
$GLOBALS['native_options']['mobishop_native_auth_settings']['phone_enabled'] = true;
$phone = '+201277777771';
$verifier = str_repeat('f', 64);
$proof = native_data(native_phone($endpoint, $verifier, $phone), 'Fresh phone proof');
$account = native_data($endpoint->register_customer(native_request([
    'ticket'=>$proof['ticket'], 'verifier'=>$verifier,
    'name'=>'Deletion Lifecycle Fixture', 'password'=>'fixture-password',
])), 'Initial phone account');
$deleted_id = $account['user_id'];
native_assert(get_user_meta($deleted_id, 'kidia_login_phone', true)===$phone, 'Initial account owns the verified phone');
MobiShop_Customer_Account_Deletion::$pending = [$deleted_id];
$issued_before = count($GLOBALS['native_issued']);
$pending = native_phone($endpoint, $verifier, $phone);
native_assert(is_wp_error($pending) && $pending->get_error_code()==='mobishop_native_account_deletion_pending', 'Pending deletion gives a specific message after proof');
native_assert(count($GLOBALS['native_issued'])===$issued_before, 'Pending deletion does not issue a session');
MobiShop_Customer_Account_Deletion::$pending = [];
// Keep monotonically increasing fixture IDs, as the real database does.
$sentinel = wp_insert_user(['user_login'=>'lifecycle-sentinel', 'user_email'=>'sentinel@example.invalid', 'role'=>'customer']);
wp_delete_user($deleted_id, 0);
native_assert(!get_user_by('id', $deleted_id) && !isset($GLOBALS['native_meta'][$deleted_id]), 'Completed deletion removes the user and phone identity');
native_clear_rate();
$identity = native_data($endpoint->identify(native_request(['identifier'=>$phone])), 'Deleted phone identification with OTP');
native_assert($identity['methods']===['phone_otp'], 'Deleted phone with available OTP starts new verified registration');
$GLOBALS['native_options']['mobishop_native_auth_settings']['phone_enabled'] = false;
native_clear_rate();
$identity = native_data($endpoint->identify(native_request([
    'identifier'=>$phone, 'supports_phone_registration_recovery'=>true,
])), 'Deleted phone identification without OTP');
native_assert($identity['methods']===['email_password'] && ($identity['requires_email_registration']??false)===true, 'Deleted phone without OTP offers explicit email registration, never the deleted password');
$GLOBALS['native_options']['mobishop_native_auth_settings']['phone_enabled'] = true;
$expired = array_merge(native_phone_claims($phone), ['exp'=>time()-1]);
native_rejected(native_phone($endpoint, $verifier, $phone, ['id_token'=>native_jwt($expired)]), 'An old expired phone proof cannot recreate the account');
$recreated_claims = array_merge(native_phone_claims($phone), ['sub'=>'recreated-phone-fixture']);
$fresh = native_data(native_phone($endpoint, $verifier, $phone, ['id_token'=>native_jwt($recreated_claims)]), 'Fresh proof after erasure with a recreated provider identity');
native_assert($fresh['status']==='registration_required', 'Same phone starts fresh registration after completed deletion');
$recreated = native_data($endpoint->register_customer(native_request([
    'ticket'=>$fresh['ticket'], 'verifier'=>$verifier,
    'name'=>'New Lifecycle Fixture', 'password'=>'new-fixture-password',
])), 'Recreated phone account');
native_assert($recreated['status']==='authenticated' && $recreated['user_id']!==$deleted_id, 'A distinct new account is created; the erased account is never restored');
native_assert(get_user_by('id',$recreated['user_id'])->display_name==='New Lifecycle Fixture', 'Old profile data does not return');
$phone_identity_key = '_mobishop_phone_firebase_identity_'.hash('sha256','test-project|recreated-phone-fixture');
native_assert(get_user_meta($recreated['user_id'],$phone_identity_key,true)['uid']==='recreated-phone-fixture', 'The fresh provider identity belongs only to the new account');
// A surviving account with the same phone must still be respected after deletion.
$GLOBALS['native_meta'][$sentinel] = ['kidia_login_phone'=>$phone];
wp_delete_user($recreated['user_id'], 0);
native_clear_rate();
$enroll = $endpoint->phone_enroll(native_request(['phone'=>$phone, 'verifier'=>$verifier]));
native_assert(is_wp_error($enroll) && $enroll->get_error_code()==='mobishop_native_existing_phone', 'Another surviving owner still receives existing-account choices');
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings_before;
echo 'Phone after deletion: '.($GLOBALS['native_checks']-$before).' lifecycle checks passed.'.PHP_EOL;
