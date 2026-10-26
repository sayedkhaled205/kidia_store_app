<?php
/** Optional push integrations retain their three-argument callback contract. */
class MobiShop_Push_Service {
    public static bool $fail = false;
    public static int $calls = 0;
    public static function unbind_session($user_id, $hash, callable $revoke) {
        self::$calls++;
        $result = $revoke();
        return self::$fail ? new WP_Error('push_unavailable', 'Try again', array('status' => 503)) : $result;
    }
}
require __DIR__ . '/auth-endpoint-contract-test.php';
mobishop_auth_assert(MobiShop_Push_Service::$calls === 1, 'The optional callback capability must be callable.');
$GLOBALS['mobishop_transients'] = array();
$session = $endpoint->login(new WP_REST_Request(array('email' => 'customer@example.com', 'password' => 'correct-password')));
$request = new WP_REST_Request(array(), array('X-MobiShop-Session' => $session->data['token']));
MobiShop_Push_Service::$fail = true;
mobishop_auth_assert(is_wp_error($endpoint->logout($request)), 'Optional integration errors must be returned.');
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($request)), 'Optional integration failure cannot undo verified revocation.');
fwrite(STDOUT, "Optional push logout contract passed.\n");
