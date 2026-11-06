<?php
/** Real auth endpoints, synthetic fixtures; route scope and single-use concurrency. */
require __DIR__ . '/auth-endpoint-contract-test.php';
define('REST_REQUEST', true);
$GLOBALS['mobishop_transients'] = array();
$login = $endpoint->login(new WP_REST_Request(array('email'=>'customer@example.com','password'=>'correct-password')));
$_SERVER['HTTP_X_MOBISHOP_SESSION'] = $login->data['token'];
$GLOBALS['wp'] = (object) array('query_vars'=>array('rest_route'=>'/wp/v2/users/me'));
$_SERVER['REQUEST_URI'] = '/wp-json/wp/v2/users/me?decoy=/wp-json/mobishop/v1/auth/me';
mobishop_auth_assert($endpoint->determine_current_user(0) === 0, 'Canonical foreign route must not accept allowed-looking query data.');
$_SERVER['REQUEST_URI'] = '/wp-json/mobishop/v1/auth/me';
mobishop_auth_assert($endpoint->determine_current_user(0) === 0, 'Canonical foreign route takes precedence over URI fallback.');
foreach (array('/mobishop/v1/auth/me','/wc/store/v1/cart') as $route) {
    $GLOBALS['wp']->query_vars['rest_route'] = $route;
    mobishop_auth_assert($endpoint->determine_current_user(0) === 7, 'Canonical mobile and Store API routes still accept a session.');
}
unset($GLOBALS['wp']->query_vars['rest_route']);
foreach (array('/wp-json/wp/v2/users/me?decoy=/wp-json/mobishop/v1/auth/me','/other/wp-json/mobishop/v1/auth/me', '//foreign.example/wp-json/mobishop/v1/auth/me', 'https://foreign.example/wp-json/mobishop/v1/auth/me', "/wp-json/mobishop/v1/auth/me\n", array('/wp-json/mobishop/v1/auth/me')) as $uri) {
    $_SERVER['REQUEST_URI'] = $uri;
    mobishop_auth_assert($endpoint->determine_current_user(0) === 0, 'Fallback must use the actual REST path prefix only.');
}
$_SERVER['REQUEST_URI'] = '/wp-json/mobishop/v1/auth/me';
mobishop_auth_assert($endpoint->determine_current_user(0) === 7, 'Fallback retains the normal plugin route.');

// Plain permalinks depend on WordPress's canonical route, never a fabricated path.
$root_cases = array(
    array('empty root', '', '/mobishop/v1/auth/me', null, 0),
    array('root without REST prefix', 'https://shop.example.com/', '/mobishop/v1/auth/me', null, 0),
    array('plain fabricated path', 'https://shop.example.com/index.php?rest_route=/', '/index.php/mobishop/v1/auth/me', null, 0),
    array('plain subdirectory fabricated path', 'https://shop.example.com/store/index.php?rest_route=/', '/store/index.php/mobishop/v1/auth/me', null, 0),
    array('plain canonical customer route', 'https://shop.example.com/index.php?rest_route=/', '/index.php?rest_route=/mobishop/v1/auth/me', '/mobishop/v1/auth/me', 7),
    array('plain canonical foreign route', 'https://shop.example.com/index.php?rest_route=/', '/index.php?rest_route=/wp/v2/users/me', '/wp/v2/users/me', 0),
    array('pretty subdirectory', 'https://shop.example.com/store/wp-json/', '/store/wp-json/mobishop/v1/auth/me', null, 7),
    array('pretty index permalinks', 'https://shop.example.com/index.php/wp-json/', '/index.php/wp-json/mobishop/v1/auth/me', null, 7),
);
foreach ($root_cases as [$label, $root, $uri, $route, $expected]) {
    $GLOBALS['mobishop_rest_url'] = $root;
    $_SERVER['REQUEST_URI'] = $uri;
    if ($route === null) unset($GLOBALS['wp']->query_vars['rest_route']);
    else $GLOBALS['wp']->query_vars['rest_route'] = $route;
    mobishop_auth_assert($endpoint->determine_current_user(0) === $expected, 'REST root scope: ' . $label);
}
unset($GLOBALS['mobishop_rest_url']);
unset($_SERVER['HTTP_X_MOBISHOP_SESSION']);

$GLOBALS['mobishop_transients'] = array();
$params = array('provider'=>'google','state'=>str_repeat('s',64),'verifier'=>str_repeat('v',64));
$endpoint->social_start(new WP_REST_Request($params));
NextendSocialLogin::$tracker_data = $GLOBALS['mobishop_social_tracker'];
$endpoint->capture_social_login(7,'google');
$callback = $endpoint->social_callback(new WP_REST_Request(array('request_id'=>substr(NextendSocialLogin::$tracker_data,strlen('mobishop:')))));
parse_str(parse_url($callback->headers['Location'],PHP_URL_QUERY),$query);
$request = new WP_REST_Request(array('code'=>$query['code'],'state'=>$params['state'],'verifier'=>$params['verifier']));
$nested = null;
$GLOBALS['mobishop_after_transient_read'] = function($key) use($endpoint,$request,&$nested) {
    if (!str_starts_with($key,'mobishop_auth_social_code_')) return;
    unset($GLOBALS['mobishop_after_transient_read']);
    $nested = $endpoint->social_exchange($request);
};
$outer = $endpoint->social_exchange($request);
mobishop_auth_assert($nested instanceof WP_REST_Response, 'First redemption creates its session.');
mobishop_auth_assert(is_wp_error($outer) && $outer->get_error_data()['status'] === 401, 'Overlapping stale redemption loses.');
mobishop_auth_assert($endpoint->authenticate_route(new WP_REST_Request(array(),array('X-MobiShop-Session'=>$nested->data['token']))) === true, 'Winning social session remains valid.');
mobishop_auth_assert(is_wp_error($endpoint->social_exchange($request)), 'Sequential replay remains rejected.');
echo "Auth route scope and handoff concurrency: 23 checks passed.\n";
