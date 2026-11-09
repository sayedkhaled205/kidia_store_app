<?php
/** Load as a CI-only MU plugin, before Woo initializes its routes and session. */
if (getenv('CI') !== 'true' || getenv('KIDIA_CHECKOUT_RUNTIME_TEST') !== '1'
    || !defined('DB_NAME') || DB_NAME !== 'kidia_identity_ci'
    || !defined('WP_ENVIRONMENT_TYPE') || WP_ENVIRONMENT_TYPE !== 'local') {
    throw new RuntimeException('Checkout fixture bootstrap requires disposable CI.');
}
register_shutdown_function(static function() {
    $error=error_get_last();
    if($error && in_array($error['type'],[E_ERROR,E_PARSE,E_CORE_ERROR,E_COMPILE_ERROR],true)) {
        echo 'KIDIA_CHECKOUT_RESULT='.json_encode(['failure'=>'Bootstrap fatal at '.basename($error['file']).':'.(int)$error['line']]).PHP_EOL;
    }
});
$input=json_decode(stream_get_contents(STDIN),true,512,JSON_THROW_ON_ERROR);
if(!is_array($input) || !in_array($input['phase']??'', ['seed','snapshot','request'], true)) {
    throw new RuntimeException('Invalid checkout fixture phase.');
}
$GLOBALS['cq_input']=$input;
$GLOBALS['cq_checkout_diagnostic']=[];
// Observe the real callback's exception class/code, without replacing its result.
add_filter('rest_endpoints',static function($routes) {
    foreach($routes['/wc/store/v1/checkout']??[] as $index=>$endpoint) {
        if(!is_array($endpoint) || !isset($endpoint['callback']) || empty($endpoint['methods']['POST'])) continue;
        $callback=$endpoint['callback'];
        $routes['/wc/store/v1/checkout'][$index]['callback']=static function($request) use($callback) {
            try { return call_user_func($callback,$request); }
            catch(Throwable $error) {
                $GLOBALS['cq_checkout_diagnostic']=['exception'=>get_class($error),
                    'code'=>method_exists($error,'getErrorCode') ? $error->getErrorCode() : $error->getCode(),
                    'file'=>basename($error->getFile()),'line'=>$error->getLine()];
                throw $error;
            }
        };
    }
    return $routes;
});
$_SERVER['HTTPS']='on'; $_SERVER['REMOTE_ADDR']='127.0.0.1';
if($input['phase']==='request') {
    define('REST_REQUEST',true);
    $_SERVER['HTTP_X_MOBISHOP_SESSION']=$input['session'];
    $_SERVER['HTTP_CART_TOKEN']=$input['cart'];
    $_SERVER['REQUEST_METHOD']=$input['method'];
    $_SERVER['REQUEST_URI']='/wp-json'.$input['route'];
}
define('MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY',hash('sha256','disposable-checkout-fixture-only-key'));
add_action('plugins_loaded',static function() {
    $repo=realpath((string)getenv('GITHUB_WORKSPACE'));
    if($repo===false) throw new RuntimeException('Missing fixture source');
    // Match the real plugin entrypoint constants before its init callbacks run.
    define('MOBISHOP_URL', 'https://kidia-identity.test/wp-content/plugins/mobishop/');
    define('MOBISHOP_VERSION', 'ci-checkout');
    require_once $repo.'/tools/customer_identity/connector/class-customer-identity-links.php';
    require_once $repo.'/tools/customer_identity/connector/class-customer-identity-guard.php';
    require_once $repo.'/connectors/woocommerce/source/api/class-customer-auth-endpoint.php';
    require_once $repo.'/connectors/woocommerce/source/api/class-native-checkout-safety50.php';
    $auth=new MobiShop_Customer_Auth_Endpoint(); $auth->register();
    $safety=new MobiShop_Native_Checkout_Safety50(); $safety->register();
    $GLOBALS['cq_safety']=$safety;
},1);
