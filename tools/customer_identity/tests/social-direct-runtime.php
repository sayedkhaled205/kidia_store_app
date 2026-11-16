<?php
/** Real WordPress persistence/session/SQL checks; synthetic signed provider proofs only. */
if (getenv('CI') !== 'true' || !defined('ABSPATH') || !defined('DB_NAME') || DB_NAME !== 'kidia_identity_ci'
    || !defined('WP_ENVIRONMENT_TYPE') || WP_ENVIRONMENT_TYPE !== 'local'
    || !defined('DB_HOST') || !preg_match('/^(127\.0\.0\.1|localhost)(:3306)?$/D', DB_HOST)
    || getenv('KIDIA_IDENTITY_RUNTIME_TEST') !== '1'
    || get_option('active_plugins') !== ['woocommerce/woocommerce.php']) {
    throw new RuntimeException('Refusing social runtime test outside disposable CI database.');
}
add_filter('pre_http_request', static fn() => new WP_Error('ci_network_disabled', 'No outbound HTTP.'), PHP_INT_MAX);
add_filter('pre_wp_mail', static fn() => true, PHP_INT_MAX);
$_SERVER['HTTPS']='on'; $_SERVER['REMOTE_ADDR']='127.0.0.1';
define('MOBISHOP_ACCOUNT_DELETION_ENABLED', true);
$repo = realpath((string)getenv('GITHUB_WORKSPACE'));
require $repo.'/connectors/woocommerce/source/api/class-customer-identity-guard.php';
require $repo.'/connectors/woocommerce/source/api/class-customer-auth-endpoint.php';
$auth = new MobiShop_Customer_Auth_Endpoint(); $auth->register();
$issue = new ReflectionMethod($auth, 'issue_session_response');
$allowed = new ReflectionMethod($auth, 'is_allowed_customer');
$endpoint = new MobiShop_Native_Customer_Auth_Endpoint(
    static fn($user) => $issue->invoke($auth, $user),
    static fn($user) => $allowed->invoke($auth, $user)
);
global $wpdb, $social_checks, $social_private_key;
$social_checks = 0;
function social_check($ok, string $label): void {
    global $social_checks;
    if (!$ok) throw new RuntimeException('FAIL: '.$label);
    ++$social_checks; echo 'PASS: '.$label.PHP_EOL;
}
function social_request(array $data): WP_REST_Request {
    $r = new WP_REST_Request('POST');
    foreach ($data as $k=>$v) $r->set_param($k,$v);
    return $r;
}
function social_jwt(array $claims): string {
    global $social_private_key;
    $b64 = static fn($s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
    $input = $b64(wp_json_encode(['alg'=>'RS256','kid'=>'ci-social-key','typ'=>'JWT'])).'.'.$b64(wp_json_encode($claims));
    if (!openssl_sign($input,$signature,$social_private_key,OPENSSL_ALGO_SHA256)) throw new RuntimeException('Fixture signing failed');
    return $input.'.'.$b64($signature);
}
function social_login($endpoint, string $kind, string $subject, string $platform, ?string $email=null) {
    $claims = ['sub'=>$subject,'iat'=>time(),'exp'=>time()+3600];
    if ($kind==='google') {
        $claims += ['aud'=>'web.apps.googleusercontent.com','azp'=>'web.apps.googleusercontent.com','iss'=>'https://accounts.google.com',
            'email'=>$email ?? $subject.'@gmail.com','email_verified'=>true];
    } else {
        $claims += ['aud'=>'test-project','iss'=>'https://securetoken.google.com/test-project','auth_time'=>time(),
            'firebase'=>['sign_in_provider'=>'apple.com','identities'=>['apple.com'=>[$subject]]]];
        if ($email !== null) $claims += ['email'=>$email,'email_verified'=>true];
    }
    return $endpoint->$kind(social_request(['platform'=>$platform,'verifier'=>str_repeat('a',64),'id_token'=>social_jwt($claims)]));
}
function social_data($response): array {
    if (is_wp_error($response)) throw new RuntimeException('Unexpected sign-in error: '.$response->get_error_code());
    return $response->get_data();
}
update_option('mobishop_native_auth_settings', [
    'registration_enabled'=>true,'phone_country_code'=>'20','require_phone'=>true,'google_enabled'=>true,
    'google'=>['server_client_id'=>'web.apps.googleusercontent.com','android_client_ids'=>['android.apps.googleusercontent.com'],'ios_client_id'=>'ios.apps.googleusercontent.com'],
    'apple_enabled'=>true,'ios_apple_native_ready'=>true,'firebase_project_id'=>'test-project',
    'firebase'=>['ios'=>['apiKey'=>'fixture','appId'=>'1:123:ios:abc123','projectId'=>'test-project','messagingSenderId'=>'123','iosBundleId'=>'app.fixture.native']],
]);
$social_private_key = openssl_pkey_new(['private_key_bits'=>2048,'private_key_type'=>OPENSSL_KEYTYPE_RSA]);
$public = openssl_pkey_get_details($social_private_key)['key'];
// Replace only external certificate retrieval. All JWT verification runs normally.
foreach (['https://www.googleapis.com/oauth2/v1/certs','https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com'] as $url) {
    set_transient('mobishop_native_certs_'.hash('sha256',$url), ['ci-social-key'=>$public], 300);
}
add_action('user_register', static fn($id) => update_user_meta($id,'kidia_phone_setup_required','account'));
wp_set_current_user(0);
$ids=[];
foreach ([['google','android'],['google','ios'],['apple','ios']] as [$kind,$platform]) {
    $subject='ci-social-'.$kind.'-'.$platform;
    $data=social_data(social_login($endpoint,$kind,$subject,$platform));
    $id=(int)($data['user']['id'] ?? 0);
    // Customer session response exposes the customer under user.
    if (!$id && !empty($data['token'])) $id=(int)(explode('.',$data['token'])[1] ?? 0);
    $ids[]=$id;
    social_check(($data['status']??'')==='authenticated' && !isset($data['ticket']) && $id>0, $kind.' '.$platform.' direct authenticated session');
    social_check(get_user_by('id',$id)->roles===['customer'] && get_user_meta($id,'_mobishop_social_login_only',true)==='1', 'Ordinary customer with social-only identity');
    social_check(!get_user_meta($id,'kidia_phone_setup_required',true) && !get_user_meta($id,'kidia_login_phone',true), 'Website registration hook does not force phone enrollment');
    $session=social_request([]); $session->set_header('X-MobiShop-Session',$data['token']);
    social_check(!is_wp_error($auth->authenticate_route($session)), 'Issued merchant session is actually usable');
    $again=social_data(social_login($endpoint,$kind,$subject,$platform));
    social_check(explode('.',$again['token'])[1]===(string)$id, 'Returning provider keeps the same customer');
    if ($kind==='apple') social_check(get_user_by('id',$id)->user_email==='', 'Apple without shared email creates a valid blank-email customer');
}
$old=(int)wp_insert_user(['user_login'=>'ci-social-existing','user_email'=>'ci-collision@gmail.com','user_pass'=>'synthetic-existing-password','role'=>'customer']);
update_user_meta($old,'billing_address_1','Synthetic old address');
$oldPassword=get_user_by('id',$old)->user_pass;
$collision=social_data(social_login($endpoint,'google','ci-collision-new','android','ci-collision@gmail.com'));
$new=(int)explode('.',$collision['token'])[1];
social_check($new!==$old && get_user_by('id',$new)->user_email==='' && get_user_by('id',$old)->user_pass===$oldPassword
    && get_user_meta($old,'billing_address_1',true)==='Synthetic old address', 'Email collision preserves old account and creates separate customer');
$phone='+201099998888';
for ($i=0;$i<55;$i++) {
    $id=(int)wp_insert_user(['user_login'=>'ci-shipping-'.$i,'user_pass'=>wp_generate_password(32),'role'=>'customer']);
    update_user_meta($id,'_mobishop_social_login_only','1'); update_user_meta($id,'billing_phone',$phone);
}
$lookup=new ReflectionMethod($endpoint,'phone_users');
social_check($lookup->invoke($endpoint,$phone)===[], 'Real SQL excludes social shipping numbers before the 51-user limit');
$owner=(int)wp_insert_user(['user_login'=>'ci-phone-owner','user_pass'=>wp_generate_password(32),'role'=>'customer']);
delete_user_meta($owner,'kidia_phone_setup_required'); update_user_meta($owner,'kidia_login_phone',$phone);
$found=$lookup->invoke($endpoint,$phone);
social_check(is_array($found) && count($found)===1 && $found[0]->ID===$owner, 'Verified owner after 55 shipping contacts remains reachable');
// Real nested WP_Meta_Query fallback must not turn two legacy owners into one.
// Load the exact website class; its plugin bootstrap also requires a separately deployed shipping package.
$websiteSource=file_get_contents($repo.'/integrations/woocommerce/kidia-auth/website/kidia-login-page.php');
$classStart=strpos($websiteSource,'final class Kidia_Store_Custom_Login_Page_V020');
if ($classStart===false) throw new RuntimeException('Website class missing from source');
eval(substr($websiteSource,$classStart));
$website=Kidia_Store_Custom_Login_Page_V020::instance();
$legacyPhone='+201099998887';
foreach (['0-social','1-legacy-a','2-legacy-b'] as $suffix) {
    $id=(int)wp_insert_user(['user_login'=>'ci-legacy-'.$suffix,'user_pass'=>wp_generate_password(32),'role'=>'customer']);
    delete_user_meta($id,'kidia_phone_setup_required'); update_user_meta($id,'billing_phone',$legacyPhone);
    if ($suffix==='0-social') update_user_meta($id,'_mobishop_social_login_only','1');
}
$find=new ReflectionMethod($website,'find_customer_by_phone');
social_check($find->invoke($website,$legacyPhone)===false, 'Real website query preserves ambiguous legacy owners before LIMIT 2');
echo 'Social direct WordPress runtime: '.$social_checks.' checks passed.'.PHP_EOL;
