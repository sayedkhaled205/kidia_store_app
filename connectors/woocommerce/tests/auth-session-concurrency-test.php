<?php
/** Session storage races and failure semantics against the real endpoint. */
require __DIR__ . '/auth-endpoint-contract-test.php';

function session_login_fixture() {
    $GLOBALS['mobishop_transients'] = array();
    return $GLOBALS['endpoint']->login(new WP_REST_Request(array(
        'email' => 'customer@example.com', 'password' => 'correct-password',
    )));
}
function session_request_fixture($response) {
    return new WP_REST_Request(array(), array('X-MobiShop-Session' => $response->data['token']));
}
function session_assert_unavailable($response, $label) {
    mobishop_auth_assert(is_wp_error($response) && $response->get_error_data()['status'] === 503, $label);
    mobishop_auth_assert(empty($GLOBALS['mobishop_held_locks']), 'Failure must release the session lock.');
}

$key = '_mobishop_customer_sessions_v1';
$GLOBALS['mobishop_user_meta_store'][7][$key] = array();
wp_cache_delete(7, 'user_meta');
$first = session_login_fixture();
$first_request = session_request_fixture($first);
$stale = get_user_meta(7, $key, true);
$endpoint->logout($first_request);
// A request which began before logout still holds the old object-cache snapshot.
$GLOBALS['mobishop_user_meta_cache'][7][$key] = $stale;
$second = session_login_fixture();
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($first_request)), 'Login must never revive a token from a stale cache.');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'The new token must be persisted.');

// A reader SELECTed the old row before logout, then fills a shared cache after
// the next writer deletes it. The lock does not serialize read-only cache fills.
$GLOBALS['mobishop_after_cache_delete'] = function ($user_id) use ($key, $stale) {
    $GLOBALS['mobishop_user_meta_cache'][$user_id][$key] = $stale;
};
$late_cache_login = session_login_fixture();
mobishop_auth_assert($late_cache_login instanceof WP_REST_Response, 'A late cache fill must not block a valid login.');
wp_cache_delete(7, 'user_meta');
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($first_request)), 'A delayed shared-cache fill must not persist a revoked token again.');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'A delayed cache fill must preserve the currently stored session.');
$endpoint->logout(session_request_fixture($late_cache_login));

// A reader that began before logout may refill the shared cache after the last
// invalidation. Authentication must reject the token without another cache delete.
$logout_race_login = session_login_fixture();
$logout_race_request = session_request_fixture($logout_race_login);
$logout_race_stale = get_user_meta(7, $key, true);
$GLOBALS['mobishop_after_cache_delete'] = function () use ($key, $logout_race_stale) {
    $GLOBALS['mobishop_after_cache_delete'] = function ($user_id) use ($key, $logout_race_stale) {
        $GLOBALS['mobishop_user_meta_cache'][$user_id][$key] = $logout_race_stale;
    };
};
$logout_race_result = $endpoint->logout($logout_race_request);
mobishop_auth_assert($logout_race_result instanceof WP_REST_Response && $logout_race_result->data['success'], 'The raced logout must finish successfully.');
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($logout_race_request)), 'A late cache fill after successful logout must never authorize the revoked token.');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'Rejecting a cached revoked token must preserve other valid sessions.');

// A cached valid token is not a fallback when the authoritative read fails.
$GLOBALS['mobishop_session_db_read_failure'] = true;
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'A database read error must deny authentication even with a valid cached token.');
$GLOBALS['mobishop_session_db_read_failure'] = false;
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'Authentication must recover after the database read succeeds.');

// Another login finishes while this request is waiting to enter its critical section.
$nested = null;
$GLOBALS['mobishop_before_lock'] = function () use (&$nested) { $nested = session_login_fixture(); };
$third = session_login_fixture();
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($nested))), 'A concurrent newly issued session must survive.');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($third))), 'Both serialized logins must be valid.');

// Two independent logouts use fresh storage even if the first has cached both tokens.
$GLOBALS['mobishop_before_lock'] = function () use ($endpoint, $nested) {
    $endpoint->logout(session_request_fixture($nested));
};
$endpoint->logout(session_request_fixture($third));
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route(session_request_fixture($nested))), 'Concurrent logout cannot revive the other token.');
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route(session_request_fixture($third))), 'Both logouts must remain revoked.');

// Expired entries are ignored on reads; cleanup cannot race with a writer.
$rows = get_user_meta(7, $key, true);
$rows[] = array('hash' => str_repeat('a', 64), 'created' => 1, 'expires' => 2);
mobishop_simulate_external_meta_write(7, $key, $rows);
wp_cache_delete(7, 'user_meta');
$writes = $GLOBALS['mobishop_user_meta_write_calls'];
$endpoint->authenticate_route(session_request_fixture($second));
mobishop_auth_assert($writes === $GLOBALS['mobishop_user_meta_write_calls'], 'Token lookup must never write a stale pruned list.');

$GLOBALS['mobishop_deny_lock'] = true;
session_assert_unavailable(session_login_fixture(), 'A missing lock must not issue a token.');
session_assert_unavailable($endpoint->logout(session_request_fixture($second)), 'A missing lock must not claim logout succeeded.');
$GLOBALS['mobishop_deny_lock'] = false;

$GLOBALS['mobishop_force_meta_write_failure'] = true;
session_assert_unavailable(session_login_fixture(), 'A failed save must not issue a token.');
session_assert_unavailable($endpoint->logout(session_request_fixture($second)), 'A failed revoke must not report success.');
$GLOBALS['mobishop_force_meta_write_failure'] = false;

// A delayed reader can also refill cache at verification. Even if its empty
// snapshot matches the requested revoke, a failed database write is not success.
$GLOBALS['mobishop_force_meta_write_failure'] = true;
$GLOBALS['mobishop_after_cache_delete'] = function () use ($key) {
    $GLOBALS['mobishop_after_cache_delete'] = function ($user_id) use ($key) {
        $GLOBALS['mobishop_user_meta_cache'][$user_id][$key] = array();
    };
};
session_assert_unavailable($endpoint->logout(session_request_fixture($second)), 'A delayed empty cache fill must not verify a failed database revoke.');
$GLOBALS['mobishop_force_meta_write_failure'] = false;
wp_cache_delete(7, 'user_meta');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'A failed revoke with a late cache fill preserves the stored session.');

$GLOBALS['mobishop_before_lock'] = function () { $GLOBALS['mobishop_meta_read_failure'] = true; };
session_assert_unavailable($endpoint->logout(session_request_fixture($second)), 'A failed fresh read must not look like an empty session list.');
$GLOBALS['mobishop_meta_read_failure'] = false;
wp_cache_delete(7, 'user_meta');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(session_request_fixture($second))), 'Failed read must preserve the existing session.');

$GLOBALS['mobishop_force_meta_write_failure'] = true;
$GLOBALS['mobishop_fail_verification_read'] = true;
session_assert_unavailable($endpoint->logout(session_request_fixture($second)), 'A failed verification read must not verify an empty revoke result.');
$GLOBALS['mobishop_force_meta_write_failure'] = false;
$GLOBALS['mobishop_fail_verification_read'] = false;
$GLOBALS['mobishop_meta_read_failure'] = false;
wp_cache_delete(7, 'user_meta');

// A second request already revoked this token before the lock was acquired.
$GLOBALS['mobishop_before_lock'] = function () use ($key) {
    mobishop_simulate_external_meta_write(7, $key, array());
};
$noop = $endpoint->logout(session_request_fixture($second));
mobishop_auth_assert($noop instanceof WP_REST_Response && $noop->data['success'], 'An independently verified no-op revoke succeeds.');
mobishop_auth_assert(empty($GLOBALS['mobishop_held_locks']), 'No-op mutation must release the lock.');
fwrite(STDOUT, "Session concurrency and storage-failure regressions passed.\n");
