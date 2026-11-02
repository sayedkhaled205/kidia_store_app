<?php
/**
 * Plugin Name: Kidia Firebase OTP Verification
 * Description: Verifies Firebase phone identity on the server before the existing customer login flow.
 * Version: 1.2.1
 */
defined('ABSPATH') || exit;

final class Kidia_Firebase_OTP_265 {
    private static $selected_customer = 0;
    private static $verified_phone = "";
    public static function decode(string $part) {
        if (!preg_match('/^[A-Za-z0-9_-]+$/D', $part)) { return false; }
        return base64_decode(strtr($part, '-_', '+/'), true);
    }

    /** No request-provided key, algorithm, URL or project is ever trusted. */
    public static function verify(string $token, string $project, string $phone, array $certs, int $now): bool {
        if ($project === '' || strlen($token) > 10000 || !preg_match('/^\+201[0125][0-9]{8}$/D', $phone)) { return false; }
        $parts = explode('.', $token);
        if (count($parts) !== 3) { return false; }
        $header = json_decode((string) self::decode($parts[0]), true);
        $claims = json_decode((string) self::decode($parts[1]), true);
        if (!is_array($header) || !is_array($claims) || ($header['alg'] ?? '') !== 'RS256') { return false; }
        $kid = $header['kid'] ?? '';
        if (!is_string($kid) || !isset($certs[$kid]) || !is_string($certs[$kid])) { return false; }
        if (($claims['aud'] ?? '') !== $project || ($claims['iss'] ?? '') !== 'https://securetoken.google.com/' . $project
            || !is_string($claims['sub'] ?? null) || $claims['sub'] === '' || strlen($claims['sub']) > 128
            || !is_int($claims['exp'] ?? null) || $claims['exp'] <= $now
            || !is_int($claims['iat'] ?? null) || $claims['iat'] > $now
            || !is_int($claims['auth_time'] ?? null) || $claims['auth_time'] > $now || $claims['auth_time'] < $now - 600
            || ($claims['phone_number'] ?? '') !== $phone
            || ($claims['firebase']['sign_in_provider'] ?? '') !== 'phone') { return false; }
        $signature = self::decode($parts[2]);
        return is_string($signature) && 1 === openssl_verify($parts[0] . '.' . $parts[1], $signature, $certs[$kid], OPENSSL_ALGO_SHA256);
    }

    public static function certificates(): array {
        $cached = get_transient('kidia_firebase_signing_certs265');
        if (is_array($cached) && $cached) { return $cached; }
        $response = wp_remote_get('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com', [
            'timeout' => 12, 'redirection' => 0, 'sslverify' => true, 'limit_response_size' => 32768,
        ]);
        if (is_wp_error($response) || 200 !== wp_remote_retrieve_response_code($response)) { return []; }
        $certs = json_decode(wp_remote_retrieve_body($response), true);
        if (!is_array($certs) || !$certs) { return []; }
        $ttl = 300;
        if (preg_match('/max-age=(\d+)/', (string) wp_remote_retrieve_header($response, 'cache-control'), $m)) {
            $ttl = max(1, min(21600, (int) $m[1]));
        }
        set_transient('kidia_firebase_signing_certs265', $certs, $ttl);
        return $certs;
    }

    private static function reject(string $message): void {
        nocache_headers();
        wp_send_json(['success' => false, 'message' => $message], 403);
    }

    public static function guard(): void {
        if (!wp_doing_ajax() || 'firebase' !== get_option('fmaServiceProvider')) { return; }
        $action = sanitize_key($_POST['action'] ?? $_GET['action'] ?? '');
        // Kidia completes registration only through a verified phone. Legacy
        // vendor email/link endpoints must not bypass that prerequisite.
        if (in_array($action, ['fme_lwp_init_email_registeration', 'fma_lwp_process_user_email_otp', 'fme_lwp_link_user_account'], true)) {
            self::reject('استخدم صفحة تسجيل الدخول للتحقق من رقم الهاتف أولًا.');
        }
        if ($action !== 'fme_lwp_process_otp_validation') { return; }
        if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST' || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['nonce'] ?? '')), 'ajax-nonce')) {
            self::reject('انتهت جلسة التحقق. حدّث الصفحة وحاول مرة أخرى.');
        }
        if (!empty($_POST['change_request'])) {
            self::reject('تغيير رقم الحساب يحتاج مراجعة منفصلة من إعدادات الحساب.');
        }
        $phone = sanitize_text_field(wp_unslash($_POST['phone_number'] ?? ''));
        $token = is_string($_POST['firebaseIdToken'] ?? null) ? wp_unslash($_POST['firebaseIdToken']) : '';
        if (!self::verify($token, (string) get_option('fma_lwp_projectID'), $phone, self::certificates(), time())) {
            self::reject('تعذر تأكيد كود الهاتف. اطلب كودًا جديدًا ثم حاول مرة أخرى.');
        }
        $users = self::matching_users($phone);
        $eligible = array_values(array_filter($users, static function ($user) use ($phone) {
            return self::eligible_customer($user, $phone);
        }));
        $selected = isset($_POST['kidia_account_id']) ? (string) wp_unslash($_POST['kidia_account_id']) : '';
        if ($selected !== '') {
            if (!ctype_digit($selected) || (int) $selected < 1) { self::reject('اختار أحد الحسابات المعروضة.'); }
            $eligible = array_values(array_filter($eligible, static fn($user) => (int) $user->ID === (int) $selected));
            if (count($eligible) !== 1) { self::reject('الحساب غير متاح لهذا الرقم. أعد التحقق من الهاتف.'); }
        } elseif (count($eligible) > 1) {
            nocache_headers();
            // Account details are returned only after validating the signed, recent phone proof.
            wp_send_json(['success' => true, 'chooseAccount' => true,
                'accounts' => array_map([self::class, 'account_label'], $eligible)]);
        }
        if ($users && !$eligible) { self::reject('استخدم رقم تسجيل الدخول الأصلي للحساب، أو سجّل بالإيميل أو جوجل.'); }
        if (!$eligible) {
            // Never let the legacy vendor resolve a contact/shipping number into an account.
            if (!function_exists('kidia_website_auth_engine')) self::reject('تعذر إكمال التسجيل. استخدم البريد أو جوجل.');
            $request = new WP_REST_Request('POST');
            $request->set_body_params(['phone'=>$phone, 'id_token'=>$token, 'client_channel'=>'website',
                'verifier'=>is_string($_POST['kidia_native_verifier'] ?? null) ? wp_unslash($_POST['kidia_native_verifier']) : '']);
            $result = kidia_website_auth_engine()->phone_verify($request);
            if (is_wp_error($result)) self::reject('تعذر إكمال التحقق. أعد المحاولة أو استخدم البريد أو جوجل.');
            $data = $result->get_data();
            if (($data['status'] ?? '') === 'registration_required') {
                wp_send_json(['success'=>true, 'registration'=>true, 'ticket'=>$data['ticket']]);
            }
            if (($data['status'] ?? '') === 'authenticated') wp_send_json(['success'=>true]);
            self::reject('استخدم البريد أو جوجل لاختيار حسابك.');
        }

        if ($eligible) {
            self::$selected_customer = (int) $eligible[0]->ID;
            self::$verified_phone = $phone;
        }
        // Unknown phones retain the existing verified registration flow. Existing
        // customers are logged in by exact ID once WooCommerce has initialized.
        $_POST['firebaseResponse'] = 'server-verified';
    }

    public static function matching_users(string $phone): array {
        $local = '0' . substr($phone, 3);
        $forms = array_unique([$phone, substr($phone, 1), $local, substr($local, 1)]);
        $query = ['relation' => 'OR'];
        foreach (['kidia_login_phone', 'fme_billing_phone', 'billing_phone'] as $key) {
            $query[] = ['key' => $key, 'value' => $forms, 'compare' => 'IN'];
        }
        $users = get_users(['number' => -1, 'count_total' => false, 'orderby' => 'ID', 'order' => 'ASC', 'meta_query' => $query]);
        // A checkout phone on a contact-only account is not an OTP owner.
        return array_values(array_filter($users, static fn($user) => !get_user_meta($user->ID, 'kidia_unverified_phone', true) || get_user_meta($user->ID, 'kidia_login_phone', true)));
    }

    public static function eligible_customer($user, string $phone): bool {
        if (!$user || user_can($user, 'manage_options') || user_can($user, 'edit_users') || user_can($user, 'manage_woocommerce')) { return false; }
        $local = '0' . substr($phone, 3);
        $forms = [$phone, substr($phone, 1), $local, substr($local, 1)];
        // A shipping number must never override a different established login identity.
        foreach (['kidia_login_phone', 'fme_billing_phone', 'billing_phone'] as $key) {
            if (in_array($key, ['fme_billing_phone','billing_phone'], true) && get_user_meta($user->ID, 'kidia_unverified_phone', true)) continue;
            $identity = trim((string) get_user_meta($user->ID, $key, true));
            if ($identity !== '') { return in_array($identity, $forms, true); }
        }
        return false;
    }

    public static function account_label($user): array {
        $name = trim(wp_strip_all_tags((string) $user->display_name));
        if ($name === '' || preg_match('/^[+0-9 _-]+$/D', $name)) { $name = 'حسابك في كيديا'; }
        $email = (string) $user->user_email;
        $hint = '';
        if (is_email($email)) {
            [$local, $domain] = explode('@', $email, 2);
            $hint = substr($local, 0, min(2, max(1, strlen($local) - 1))) . '•••@' . $domain;
        }
        return ['id' => (int) $user->ID, 'name' => $name, 'email' => $hint,
            'since' => mysql2date('m/Y', $user->user_registered)];
    }

    public static function finish_selected_login(): void {
        if (!self::$selected_customer) { return; }
        $id = self::$selected_customer;
        self::$selected_customer = 0;
        $user = get_user_by('id', $id);
        if (!self::eligible_customer($user, self::$verified_phone) || !class_exists('FME_LWP_Users_Controller')) {
            self::reject('تعذر إكمال الدخول. أعد التحقق من الهاتف.');
        }
        $controller = new FME_LWP_Users_Controller();
        if ($controller->is_phone_violating_login_attempt_count_restriction(self::$verified_phone)
            || $controller->is_phone_violating_login_count_restriction(self::$verified_phone)) {
            self::reject('محاولات كثيرة خلال وقت قصير. حاول لاحقًا أو استخدم الإيميل أو جوجل.');
        }
        update_user_meta($id, 'kidia_login_phone', self::$verified_phone);
        update_user_meta($id, 'fme_billing_phone', self::$verified_phone);
        // Reuse the vendor's established auth-cookie, wp_login and cart restore path.
        $controller->login_user($id);
        nocache_headers();
        wp_send_json(['success' => true]);
    }

    public static function assets(): void {
        $scripts = wp_scripts();
        if (isset($scripts->registered['kidia-login-page'])) {
            $scripts->registered['kidia-login-page']->ver = '0.6.15-shared1';
            wp_enqueue_style('kidia-phone-methods', plugin_dir_url(__FILE__) . 'kidia-phone-methods.css', ['kidia-login-page'], '1.0.0');
        }
        if (!wp_script_is('fme_lwp_public_script', 'enqueued') || get_option('fmaServiceProvider') !== 'firebase') { return; }
        foreach (['fma_lwp_firebase_app' => 'app', 'fma_lwp_firebase_auth' => 'auth', 'fma_lwp_firebase_analytics' => 'analytics', 'fma_lwp_firestore' => 'firestore'] as $handle => $library) {
            if (isset($scripts->registered[$handle])) {
                $scripts->registered[$handle]->src = 'https://www.gstatic.com/firebasejs/13.0.0/firebase-' . $library . '-compat.js';
                $scripts->registered[$handle]->ver = '13.0.0';
                if ($library !== 'app') { $scripts->registered[$handle]->deps = ['fma_lwp_firebase_app']; }
            }
        }
        wp_enqueue_script('kidia-firebase-otp265', plugin_dir_url(__FILE__) . 'kidia-firebase-otp.js', ['fme_lwp_public_script', 'fma_lwp_firebase_auth'], '1.2.3', true);
        wp_enqueue_style('kidia-otp-accounts', plugin_dir_url(__FILE__) . 'kidia-otp-accounts.css', [], '1.2.0');
    }
}

// Run before Kidia's account matching at init priority 1.
add_action('init', ['Kidia_Firebase_OTP_265', 'guard'], 0);
add_action('wp_ajax_nopriv_fme_lwp_process_otp_validation', ['Kidia_Firebase_OTP_265', 'finish_selected_login'], 0);
add_action('wp_ajax_fme_lwp_process_otp_validation', ['Kidia_Firebase_OTP_265', 'finish_selected_login'], 0);
add_action('wp_enqueue_scripts', ['Kidia_Firebase_OTP_265', 'assets'], 100);
// This authentication page contains fresh nonces and an ordered Firebase SDK.
// Product/catalog pages retain their existing performance optimizations.
add_action('template_redirect', static function (): void {
    if (is_page((int) get_option('kidia_login_page_id'))) {
        if (!defined('DONOTROCKETOPTIMIZE')) { define('DONOTROCKETOPTIMIZE', true); }
        if (!defined('DONOTCACHEPAGE')) { define('DONOTCACHEPAGE', true); }
        nocache_headers();
    }
}, 0);
// Administrators can preview the public login UI without a false network error.
foreach (['email', 'phone'] as $kind) {
    add_action('wp_ajax_kidia_check_' . $kind, static function () use ($kind): void {
        if (class_exists('Kidia_Store_Custom_Login_Page_V020')) {
            Kidia_Store_Custom_Login_Page_V020::instance()->{'ajax_check_' . $kind}();
        }
    });
}
