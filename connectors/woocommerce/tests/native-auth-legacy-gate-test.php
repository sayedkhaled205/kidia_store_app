<?php
/** All original customer session entry points honor the required profile step. */
require __DIR__ . '/auth-endpoint-contract-test.php';

$legacy_gate_checks = 0;
function legacy_gate_assert( $condition, $label ) {
    global $legacy_gate_checks;
    if ( ! $condition ) throw new RuntimeException( $label );
    $legacy_gate_checks++;
}
function legacy_session_count( $id ) {
    $sessions = get_user_meta( $id, '_mobishop_customer_sessions_v1', true );
    return is_array( $sessions ) ? count( $sessions ) : 0;
}
function legacy_social_request( $endpoint, $id ) {
    $state = bin2hex( random_bytes( 32 ) );
    $verifier = bin2hex( random_bytes( 32 ) );
    $start = $endpoint->social_start( new WP_REST_Request( array( 'provider' => 'google', 'state' => $state, 'verifier' => $verifier ) ) );
    legacy_gate_assert( $start instanceof WP_REST_Response, 'A social attempt can begin independently of profile completion' );
    NextendSocialLogin::$tracker_data = $GLOBALS['mobishop_social_tracker'];
    $endpoint->capture_social_login( $id, 'google' );
    $request_id = substr( NextendSocialLogin::$tracker_data, strlen( 'mobishop:' ) );
    $callback = $endpoint->social_callback( new WP_REST_Request( array( 'request_id' => $request_id ) ) );
    legacy_gate_assert( $callback instanceof WP_REST_Response && $callback->status === 302, 'Verified social account produces its normal one-time callback' );
    parse_str( (string) parse_url( $callback->headers['Location'], PHP_URL_QUERY ), $query );
    return new WP_REST_Request( array( 'code' => $query['code'], 'state' => $state, 'verifier' => $verifier ) );
}

$login_request = new WP_REST_Request( array( 'email' => 'customer@example.com', 'password' => 'correct-password' ) );
update_user_meta( 7, 'kidia_phone_setup_required', 'otp' );
$before = legacy_session_count( 7 );
$blocked = $endpoint->login( $login_request );
legacy_gate_assert( is_wp_error( $blocked ) && $blocked->get_error_data()['status'] === 403, 'Legacy email login cannot bypass required phone completion' );
legacy_gate_assert( legacy_session_count( 7 ) === $before, 'Blocked legacy password login stores no session' );
update_user_meta( 7, 'kidia_phone_setup_required', false );
$ready = $endpoint->login( $login_request );
legacy_gate_assert( $ready instanceof WP_REST_Response && isset( $ready->data['token'] ), 'Legacy email login resumes after profile completion' );
legacy_gate_assert( legacy_session_count( 7 ) === $before + 1, 'Completed legacy login issues exactly one session' );

// A token obtained before the marker was set must also stop resolving the account.
$token_request = new WP_REST_Request( array(), array( 'X-MobiShop-Session' => $ready->data['token'] ) );
update_user_meta( 7, 'kidia_phone_setup_required', 'account' );
legacy_gate_assert( is_wp_error( $endpoint->current_customer( $token_request ) ), 'Existing token cannot fetch the profile while completion becomes required' );
legacy_gate_assert( is_wp_error( $endpoint->authenticate_route( $token_request ) ), 'Existing token cannot authorize routes while completion becomes required' );
update_user_meta( 7, 'kidia_phone_setup_required', false );
legacy_gate_assert( $endpoint->current_customer( $token_request ) instanceof WP_REST_Response, 'Existing token resolves again when its required profile step is completed' );
$GLOBALS['mobishop_users'][7]['allcaps']['edit_users'] = true;
legacy_gate_assert( is_wp_error( $endpoint->login( $login_request ) ) && is_wp_error( $endpoint->authenticate_route( $token_request ) ), 'A customer with user-editing privileges cannot log in or reuse an older customer token' );
unset( $GLOBALS['mobishop_users'][7]['allcaps']['edit_users'] );

// Simulate the website registration hook marking a newly allocated customer incomplete.
$next_id = max( array_keys( $GLOBALS['mobishop_users'] ) ) + 1;
update_user_meta( $next_id, 'kidia_phone_setup_required', 'otp' );
$new_email = 'profile-gated-registration@example.com';
$registered_pending = $endpoint->register_customer( new WP_REST_Request( array( 'email' => $new_email, 'password' => 'registration-password' ) ) );
legacy_gate_assert( email_exists( $new_email ) === $next_id && is_wp_error( $registered_pending ), 'Legacy registration does not issue a session for a customer marked incomplete by the website' );
legacy_gate_assert( legacy_session_count( $next_id ) === 0, 'Incomplete new customer stores no session' );
update_user_meta( $next_id, 'kidia_phone_setup_required', false );
$new_ready = $endpoint->login( new WP_REST_Request( array( 'email' => $new_email, 'password' => 'registration-password' ) ) );
legacy_gate_assert( $new_ready instanceof WP_REST_Response, 'The same newly registered account signs in after required completion' );

$GLOBALS['mobishop_transients'] = array();
update_user_meta( 7, 'kidia_phone_setup_required', 'otp' );
$social_request = legacy_social_request( $endpoint, 7 );
$before = legacy_session_count( 7 );
$social_blocked = $endpoint->social_exchange( $social_request );
legacy_gate_assert( is_wp_error( $social_blocked ) && $social_blocked->get_error_data()['status'] === 403, 'Legacy social exchange cannot bypass required phone completion' );
legacy_gate_assert( legacy_session_count( 7 ) === $before, 'Blocked legacy social exchange stores no session' );
update_user_meta( 7, 'kidia_phone_setup_required', false );
legacy_gate_assert( is_wp_error( $endpoint->social_exchange( $social_request ) ), 'A previously consumed blocked social callback is not reusable' );
$social_ready = $endpoint->social_exchange( legacy_social_request( $endpoint, 7 ) );
legacy_gate_assert( $social_ready instanceof WP_REST_Response && isset( $social_ready->data['token'] ), 'Fresh social login succeeds after profile completion' );
legacy_gate_assert( legacy_session_count( 7 ) === $before + 1, 'Fresh completed social login issues one session' );

echo 'Native auth legacy gate: ' . $legacy_gate_checks . ' contract/security checks passed.' . PHP_EOL;
