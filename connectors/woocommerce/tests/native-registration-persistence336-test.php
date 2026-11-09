<?php
/** Required contact writes and provider failures cannot produce a completed partial signup. */
declare(strict_types=1);
require __DIR__ . '/native-facebook-auth-test.php';

function persistence_google_signup(string $subject, string $email, string $phone, string $verifier): array {
    global $endpoint;
    native_clear_rate();
    $claims = array_replace(native_google_claims($subject), array('email' => $email));
    $start = native_data($endpoint->google(native_request(array('id_token' => native_jwt($claims), 'verifier' => $verifier))), 'Google signup');
    $prepared = native_data($endpoint->phone_enroll(native_request(array('phone' => $phone, 'ticket' => $start['ticket'], 'verifier' => $verifier))), 'Prepare contact');
    return native_data($endpoint->phone_confirm(native_request(array('phone' => $phone, 'ticket' => $prepared['ticket'], 'verifier' => $verifier))), 'Confirm contact');
}

$verifier = str_repeat('a', 64);
foreach (array('kidia_phone_setup_required', 'kidia_unverified_phone') as $index => $key) {
    foreach (array('google', 'facebook') as $kind) {
        $email = 'persistence-' . $kind . '-' . $index . ($kind === 'google' ? '@gmail.com' : '@example.invalid');
        $phone = '+2012999900' . ($kind === 'google' ? '6' : '7') . $index;
        $subject = $kind === 'google' ? 'persistence-google-' . $index : '88007' . $index;
        native_clear_rate();
        $pending = $kind === 'google'
            ? persistence_google_signup($subject, $email, $phone, $verifier)
            : facebook_registration($subject, $phone, $email);
        $before = count($GLOBALS['native_users']);
        $issued = count($GLOBALS['native_issued']);
        $GLOBALS['native_fail_meta'] = $key;
        $failed = $kind === 'google'
            ? $endpoint->register_customer(native_request(array('ticket' => $pending['ticket'], 'verifier' => $verifier, 'name' => 'Persistence fixture', 'password' => 'fixture-password')))
            : facebook_register($pending);
        unset($GLOBALS['native_fail_meta']);
        native_rejected($failed, $kind . ' rejects failed required ' . $key);
        native_assert(count($GLOBALS['native_users']) === $before && !email_exists($email), 'Failed signup releases newly created user and email');
        native_assert(count($GLOBALS['native_issued']) === $issued, 'Failed signup issues no session');
        native_clear_rate();
        $pending = $kind === 'google'
            ? persistence_google_signup($subject, $email, $phone, $verifier)
            : facebook_registration($subject, $phone, $email);
        $retry = $kind === 'google'
            ? $endpoint->register_customer(native_request(array('ticket' => $pending['ticket'], 'verifier' => $verifier, 'name' => 'Persistence retry', 'password' => 'fixture-password')))
            : facebook_register($pending);
        $data = native_data($retry, 'Fresh signup succeeds after persistence returns');
        native_assert($data['status'] === 'authenticated' && get_user_meta($data['user_id'], 'kidia_unverified_phone', true) === $phone, 'Retry preserves required contact');
    }
}

// Verified phone registration also needs durable login and billing contact fields.
foreach (array('kidia_login_phone', 'fme_billing_phone', 'billing_phone') as $index => $key) {
    native_clear_rate();
    $GLOBALS['native_options']['mobishop_native_auth_settings']['phone_enabled'] = true;
    $phone = '+20129999008' . $index;
    $pending = native_data(native_phone($endpoint, $verifier, $phone), 'Verified phone signup');
    $before = count($GLOBALS['native_users']); $issued = count($GLOBALS['native_issued']);
    $GLOBALS['native_fail_meta'] = $key;
    $failed = $endpoint->register_customer(native_request(array('ticket' => $pending['ticket'], 'verifier' => $verifier, 'name' => 'Phone persistence', 'password' => 'fixture-password')));
    unset($GLOBALS['native_fail_meta']);
    native_rejected($failed, 'Reject failed verified phone field ' . $key);
    native_assert(count($GLOBALS['native_users']) === $before && count($GLOBALS['native_issued']) === $issued, 'Verified phone write failure leaves no new account/session');
}

// Failure while completing an existing account must preserve that account.
function persistence_existing_facebook(): array {
    global $endpoint;
    native_clear_rate();
    facebook_http_fixture();
    $pending = native_data(facebook_exchange(facebook_challenge(), array('access_token' => 'fixture-access-token')), 'Existing pending Facebook');
    return native_data(native_phone($endpoint, str_repeat('f', 64), '+201012345678', array('ticket' => $pending['ticket'])), 'Independent phone proof');
}
$facebook_provider = NextendSocialLogin::$providers['facebook'];
$GLOBALS['native_meta'][7]['kidia_phone_setup_required'] = 'account';
unset($GLOBALS['native_meta'][7]['fme_billing_phone']);
$pending = persistence_existing_facebook();
$email_before = $GLOBALS['native_users'][7]['email'];
$before = count($GLOBALS['native_users']); $issued = count($GLOBALS['native_issued']);
$GLOBALS['native_fail_meta'] = 'fme_billing_phone';
$failed = facebook_register($pending);
unset($GLOBALS['native_fail_meta']);
native_rejected($failed, 'Failed existing required field rejects completion');
native_assert(count($GLOBALS['native_users']) === $before && $GLOBALS['native_users'][7]['email'] === $email_before
    && $facebook_provider->getUserIDByProviderIdentifier('700001') === 7
    && get_user_meta(7, 'kidia_phone_setup_required', true) === 'account'
    && count($GLOBALS['native_issued']) === $issued, 'Existing user and mapping preserved, pending and without a session');
$pending = persistence_existing_facebook();
$GLOBALS['native_fail_meta'] = 'kidia_login_phone'; // Already correct; false also means unchanged.
$retry = facebook_register($pending);
unset($GLOBALS['native_fail_meta']);
$retry = native_data($retry, 'Existing account completes after retry');
native_assert($retry['status'] === 'authenticated' && $retry['user_id'] === 7
    && get_user_meta(7, 'fme_billing_phone', true) === '+201012345678', 'Retry retains original account and accepts unchanged contact');

$provider = new class extends Native_Test_Google_Provider {
    public bool $throws = true;
    public function linkUserToProviderIdentifier($id, $subject) {
        $result = parent::linkUserToProviderIdentifier($id, $subject);
        if ($this->throws) throw new RuntimeException('Synthetic provider failure after mapping');
        return $result;
    }
    public function removeConnectionByUserID($id) {
        $this->links = array_filter($this->links, static fn($owner) => $owner !== (int) $id);
    }
};
NextendSocialLogin::$providers['google'] = $provider;
$GLOBALS['native_options']['mobishop_native_auth_settings']['phone_enabled'] = false;
$email = 'persistence-throw@gmail.com'; $subject = 'persistence-throw'; $phone = '+201299990090';
$pending = persistence_google_signup($subject, $email, $phone, $verifier);
$before = count($GLOBALS['native_users']); $issued = count($GLOBALS['native_issued']);
$failed = $endpoint->register_customer(native_request(array('ticket' => $pending['ticket'], 'verifier' => $verifier, 'name' => 'Provider failure', 'password' => 'fixture-password')));
native_rejected($failed, 'Provider exception is a recoverable error');
native_assert(count($GLOBALS['native_users']) === $before && !email_exists($email) && !$provider->getUserIDByProviderIdentifier($subject), 'Provider exception removes only newly created user and its mapping');
native_assert(count($GLOBALS['native_issued']) === $issued, 'Provider exception issues no session');
$provider->throws = false;
$pending = persistence_google_signup($subject, $email, $phone, $verifier);
$retry = native_data($endpoint->register_customer(native_request(array('ticket' => $pending['ticket'], 'verifier' => $verifier, 'name' => 'Provider retry', 'password' => 'fixture-password'))), 'Retry after provider exception');
native_assert($retry['status'] === 'authenticated', 'New independent attempt succeeds');
echo "Registration persistence failure and recovery checks passed.\n";
