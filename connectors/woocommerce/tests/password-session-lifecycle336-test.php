<?php
require __DIR__ . '/auth-endpoint-contract-test.php';
function get_current_blog_id() { return 1; }
function is_multisite() { return false; }
$endpoint->register();
function reset_fixture_login($endpoint, $password = 'correct-password') {
    $GLOBALS['mobishop_transients'] = array();
    $login = $endpoint->login(new WP_REST_Request(array('email'=>'customer@example.com','password'=>$password)));
    mobishop_auth_assert($login instanceof WP_REST_Response, 'Fixture sign-in succeeds');
    return new WP_REST_Request(array(), array('X-MobiShop-Session'=>$login->data['token']));
}
function reset_fixture_hook($hook, ...$args) {
    foreach ($GLOBALS['mobishop_actions'][$hook] ?? array() as $callback) $callback(...$args);
}
$session = reset_fixture_login($endpoint);
$old = get_user_by('id', 7);
$GLOBALS['mobishop_users'][7]['password_hash'] = 'fixture-rehashed:correct-password';
reset_fixture_hook('wp_set_password', 'correct-password', 7, $old);
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route($session)), 'Transparent rehash preserves existing session');
$old = get_user_by('id', 7);
unset($GLOBALS['mobishop_users'][7]['password_hash']);
$GLOBALS['mobishop_users'][7]['password'] = 'changed-fixture-password';
reset_fixture_hook('wp_set_password', 'changed-fixture-password', 7, $old);
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($session)), 'Changed password revokes previous session');
$session = reset_fixture_login($endpoint, 'changed-fixture-password');
reset_fixture_hook('after_password_reset', get_user_by('id', 7));
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($session)), 'Explicit reset to same password still revokes old sessions');
$session = reset_fixture_login($endpoint, 'changed-fixture-password');
$old = get_user_by('id', 7);
reset_fixture_hook('profile_update', 7, $old);
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route($session)), 'Ordinary profile edit preserves sign-in');
$GLOBALS['mobishop_users'][7]['password'] = 'profile-password';
reset_fixture_hook('profile_update', 7, $old);
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($session)), 'Profile password change revokes native session');
reset_fixture_login($endpoint, 'profile-password');
$issuer = new ReflectionMethod($endpoint, 'issue_session_response');
mobishop_auth_assert(is_wp_error($issuer->invoke($endpoint, $old)), 'Old password proof cannot issue a session after reset');

$GLOBALS['mobishop_users'][18]=array('login'=>'fixture-owner','email'=>'owner@example.invalid','password'=>'owner-password','display_name'=>'Owner','roles'=>array('administrator'));
$GLOBALS['mobishop_users'][19]=array('login'=>'mobishop_shop_1_18','email'=>'','password'=>'alias-password','display_name'=>'Shopper','roles'=>array('customer'),'allcaps'=>array('read'=>true));
update_user_meta(19,'_mobishop_storefront_owner_1',18);
$owner=get_user_by('id',18); $alias=get_user_by('id',19);
$proof=array('id'=>18,'password'=>$owner->user_pass,'generation'=>'');
$issued=$issuer->invoke($endpoint,$alias,$proof);
mobishop_auth_assert($issued instanceof WP_REST_Response,'Verified owner proof issues isolated shopping session');
$request=new WP_REST_Request(array(),array('X-MobiShop-Session'=>$issued->data['token']));
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route($request)),'Isolated shopping session starts valid');
$GLOBALS['mobishop_users'][18]['password']='changed-owner-password';
reset_fixture_hook('wp_set_password','changed-owner-password',18,$owner);
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route($request)),'Owner password reset revokes existing shopping alias');
mobishop_auth_assert(is_wp_error($issuer->invoke($endpoint,$alias,$proof)),'Owner reset after resolution before issue rejects stale owner proof');
$owner=get_user_by('id',18); $proof=array('id'=>18,'password'=>$owner->user_pass,'generation'=>get_user_meta(18,'_mobishop_auth_generation_v1',true));
mobishop_auth_assert($issuer->invoke($endpoint,get_user_by('id',19),$proof) instanceof WP_REST_Response,'Fresh owner proof can sign in after reset');
echo "Password session lifecycle checks passed.\n";
