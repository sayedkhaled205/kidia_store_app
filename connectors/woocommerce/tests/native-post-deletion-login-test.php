<?php
/** Synthetic deletion state and signed provider proofs; no external accounts. */
final class MobiShop_Customer_Account_Deletion {
    public static array $pending = [];
    public static function is_pending(int $id): bool { return in_array($id, self::$pending, true); }
}
require __DIR__ . '/native-apple-auth-test.php';
$before = $GLOBALS['native_checks'];
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_apple_native_ready'] = true;
$issued = count($GLOBALS['native_issued']);
MobiShop_Customer_Account_Deletion::$pending = [$apple_id];
foreach ([$apple_claims['sub'], 'recreated-firebase-fixture'] as $uid) {
    $claims = array_merge($apple_claims, ['sub'=>$uid]);
    $result = $endpoint->apple(apple_request($claims));
    native_assert(is_wp_error($result) && $result->get_error_code()==='mobishop_native_account_deletion_pending', 'Pending Apple erasure is explicit for original and recreated provider UID');
    native_assert(count($GLOBALS['native_issued'])===$issued, 'Pending deletion never issues a session');
}
native_clear_rate();
$independent = native_data($endpoint->google(native_request(['id_token'=>native_jwt(native_google_claims()),'verifier'=>str_repeat('c',64)])),'Independent Google account during Apple erasure');
native_assert($independent['status']==='authenticated','Pending deletion does not block a different account');
MobiShop_Customer_Account_Deletion::$pending = [7];
$issued_before_pending_google = count($GLOBALS['native_issued']);
native_clear_rate();
$pending_google = $endpoint->google(native_request(['id_token'=>native_jwt(native_google_claims()),'verifier'=>str_repeat('c',64)]));
native_assert(is_wp_error($pending_google) && $pending_google->get_error_code()==='mobishop_native_account_deletion_pending','Validated Google proof cannot reach registration or session while deletion is pending');
native_assert(count($GLOBALS['native_issued'])===$issued_before_pending_google,'Pending finish issues no session');
MobiShop_Customer_Account_Deletion::$pending = [];
$different = $endpoint->apple(apple_request(array_merge($apple_claims,['sub'=>'recreated-firebase-fixture'])));
native_assert(is_wp_error($different) && $different->get_error_code()==='mobishop_native_invalid_credentials', 'Nonpending UID mismatch still fails closed');
wp_delete_user($apple_id,0);
$fresh = native_data($endpoint->apple(apple_request(array_merge($apple_claims,['sub'=>'recreated-firebase-fixture']))),'Completed deletion permits fresh registration');
native_assert($fresh['status']==='registration_required', 'Erased Apple account starts registration rather than returning deleted data');
$new = native_data($endpoint->register_customer(native_request(['ticket'=>$fresh['ticket'],'verifier'=>str_repeat('c',64),'platform'=>'ios','name'=>'Recreated Fixture'])),'Fresh Apple registration');
native_assert($new['status']==='authenticated','Fresh verified account can sign in after completed erasure');
$saved_phone = $GLOBALS['native_meta'][8]['kidia_login_phone'];
$GLOBALS['native_meta'][8]['kidia_login_phone'] = '+201500000001';
$ticket_count = count(native_ticket_options());
$blocked = $endpoint->phone_enroll(native_request(['phone'=>'+201500000001','verifier'=>str_repeat('c',64)]));
native_assert(is_wp_error($blocked) && $blocked->get_error_code()==='mobishop_native_phone_account_conflict','Privileged phone conflict is not mislabeled as a Google link failure');
native_assert(count(native_ticket_options())===$ticket_count,'Privileged phone still creates no enrollment ticket');
$GLOBALS['native_meta'][8]['kidia_login_phone'] = $saved_phone;
echo 'Post-deletion login: '.($GLOBALS['native_checks']-$before).' additional checks passed.'.PHP_EOL;
