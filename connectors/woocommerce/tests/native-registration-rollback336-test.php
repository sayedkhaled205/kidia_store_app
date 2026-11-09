<?php
/** Failed new-account binding must not reserve contact details or adopt another mapping. */
require __DIR__ . '/native-auth-contract-test.php';
class Native_Failed_Registration_Google extends Native_Test_Google_Provider {
    public bool $fail = true;
    public function linkUserToProviderIdentifier($id, $subject) {
        if (!$this->fail) return parent::linkUserToProviderIdentifier($id, $subject);
        $this->links[$subject] = 7; // A competing owner must survive rollback.
        return false;
    }
    public function removeConnectionByUserID($id) {
        $this->links = array_filter($this->links, static fn($owner) => $owner !== (int)$id);
    }
}
$provider = new Native_Failed_Registration_Google();
NextendSocialLogin::$providers['google'] = $provider;
$email = 'rollback-fixture@gmail.com'; $subject = 'rollback-fixture-subject';
$verifier = str_repeat('e',64); $phone = '+201299990002';
$start = static function()use($endpoint,$email,$subject,$verifier,$phone) {
    native_clear_rate();
    $claims = array_replace(native_google_claims($subject),array('email'=>$email));
    $google = native_data($endpoint->google(native_request(array('id_token'=>native_jwt($claims),'verifier'=>$verifier))), 'Fresh Google registration');
    $prepared = native_data($endpoint->phone_enroll(native_request(array('phone'=>$phone,'ticket'=>$google['ticket'],'verifier'=>$verifier))), 'Prepare contact');
    return native_data($endpoint->phone_confirm(native_request(array('phone'=>$phone,'ticket'=>$prepared['ticket'],'verifier'=>$verifier))), 'Confirm contact');
};
$pending = $start(); $before = count($GLOBALS['native_users']); $issued = count($GLOBALS['native_issued']);
$failed = $endpoint->register_customer(native_request(array('ticket'=>$pending['ticket'],'verifier'=>$verifier,'name'=>'Rollback fixture','password'=>'fixture-password')));
native_rejected($failed,'Failed Google link rejects registration');
native_assert(count($GLOBALS['native_users'])===$before && !email_exists($email),'Failed new registration releases its email and user');
native_assert($provider->links[$subject]===7,'Rollback preserves competing provider mapping');
native_assert(count($GLOBALS['native_issued'])===$issued,'Failed registration creates no session');
unset($provider->links[$subject]); $provider->fail=false;
$pending=$start();
$success=native_data($endpoint->register_customer(native_request(array('ticket'=>$pending['ticket'],'verifier'=>$verifier,'name'=>'Retry fixture','password'=>'fixture-password'))),'Independent new attempt succeeds');
native_assert($success['status']==='authenticated' && email_exists($email)===$success['user_id'],'Same email and contact can register after rollback');
echo "New registration rollback passed.\n";
