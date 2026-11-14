<?php
/**
 * Standalone WordPress boundary tests for the administrator's customer identity.
 * Pass the connector's production class path as argv[1], or set MOBISHOP_CONNECTOR_TEST_ROOT.
 * Only synthetic in-memory state is used.
 */
declare(strict_types=1);
define('ABSPATH', __DIR__);
define('DB_NAME', 'fixture');
define('AUTH_SALT', 'test-only');
class WP_Error {
    public function __construct(public string $code, public string $message = '', public $data = null) {}
    public function get_error_code() { return $this->code; }
}
class WP_User {
    public function __construct(
        public int $ID, public string $user_login, public string $user_email, public array $roles,
        public array $allcaps, public string $display_name = 'Fixture account',
        public string $user_pass = 'unavailable-fixture-hash'
    ) {}
}
class StorefrontFixtureDb {
    public string $users = 'wp_users';
    public string $prefix = 'wp_';
    public string $base_prefix = 'wp_';
    public bool $busy = false;
    public int $held = 0;
    public function prepare(string $sql, ...$args) { return $sql; }
    public function get_var(string $sql) {
        if (stripos($sql, 'GET_LOCK(') !== false) {
            if ($this->busy) return '0';
            $this->held++;
            return '1';
        }
        if (stripos($sql, 'RELEASE_LOCK(') !== false) {
            $this->held--;
            return '1';
        }
        throw new RuntimeException('Unexpected database operation: '.$sql);
    }
}
function get_current_blog_id() { return 4; }
function is_multisite() { return false; }
function get_role($role) { return $role === 'customer' ? (object)['capabilities' => ['read' => true]] : null; }
function is_super_admin($id) { return false; }
function __($s, $domain = '') { return $s; }
function is_wp_error($v) { return $v instanceof WP_Error; }
function sanitize_email($v) { return filter_var($v, FILTER_SANITIZE_EMAIL); }
function is_email($v) { return filter_var($v, FILTER_VALIDATE_EMAIL); }
function sanitize_text_field($v) { return trim(strip_tags($v)); }
function sanitize_key($v) { return strtolower($v); }
function absint($v) { return abs((int)$v); }
function wp_cache_delete(...$args) { return true; }
function clean_user_cache(...$args) {}
function wp_salt($scheme = 'auth') { return AUTH_SALT; }
function wp_generate_password($length = 12, ...$args) { return substr(bin2hex(random_bytes($length)), 0, $length); }
function get_user_by($field, $value) {
    foreach ($GLOBALS['fixture_users'] as $u) {
        if (($field === 'id' && $u->ID === (int)$value)
            || ($field === 'login' && $u->user_login === $value)
            || ($field === 'email' && $u->user_email === $value)) return clone $u;
    }
    return false;
}
function get_userdata($id) { return get_user_by('id', $id); }
function username_exists($v) { return ($u = get_user_by('login', $v)) ? $u->ID : false; }
function email_exists($v) { return ($u = get_user_by('email', $v)) ? $u->ID : false; }
function add_user_meta($id, $key, $value, $unique = false) {
    if ($unique && isset($GLOBALS['fixture_meta'][$id][$key])) return false;
    $GLOBALS['fixture_meta'][$id][$key] = (string)$value;
    return 1;
}
function update_user_meta($id, $key, $value) { return add_user_meta($id, $key, $value); }
function get_user_meta($id, $key, $single = false) {
    $v = $GLOBALS['fixture_meta'][$id][$key] ?? null;
    return $single ? ($v ?? '') : ($v === null ? [] : [$v]);
}
function delete_user_meta($id, $key, $value) {
    if (get_user_meta($id, $key, true) !== $value) return false;
    unset($GLOBALS['fixture_meta'][$id][$key]);
    return true;
}
function wp_insert_user($row) {
    if (username_exists($row['user_login']) || (!empty($row['user_email']) && email_exists($row['user_email']))) {
        return new WP_Error('duplicate');
    }
    $id = max(array_keys($GLOBALS['fixture_users'])) + 1;
    $GLOBALS['fixture_users'][$id] = new WP_User($id,$row['user_login'],$row['user_email'] ?? '',
        [$row['role']],['read'=>true],$row['display_name'] ?? 'Customer',$row['user_pass']);
    foreach ($row['meta_input'] ?? [] as $key=>$val) add_user_meta($id,$key,$val);
    // The website's user_register hook marks newly inserted customers for onboarding.
    update_user_meta($id, 'kidia_phone_setup_required', 'account');
    return $id;
}
function reset_storefront_fixture() {
    $GLOBALS['wpdb'] = new StorefrontFixtureDb();
    $GLOBALS['fixture_meta'] = [];
    $GLOBALS['fixture_users'] = [
        10=>new WP_User(10,'fixture-owner','owner@example.test',['administrator'],['manage_options'=>true,'edit_users'=>true,'read'=>true]),
        11=>new WP_User(11,'fixture-customer','shopper@example.test',['customer'],['read'=>true]),
        12=>new WP_User(12,'fixture-manager','manager@example.test',['shop_manager'],['manage_woocommerce'=>true,'read'=>true]),
        13=>new WP_User(13,'fixture-other-owner','second@example.test',['administrator'],['manage_options'=>true,'read'=>true]),
    ];
}
$checks = 0;
function verify_storefront(bool $ok, string $label) {
    global $checks;
    if (!$ok) throw new RuntimeException($label);
    $checks++;
}
$root = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__).'/source';
require $argv[1] ?? $root.'/api/class-storefront-admin.php';

reset_storefront_fixture();
$owner = get_userdata(10);
$before = serialize($owner);
verify_storefront(MobiShop_Storefront_Admin::accepts($owner), 'Store administrator can request a shopper');
foreach ([11] as $id) {
    verify_storefront(!MobiShop_Storefront_Admin::accepts(get_userdata($id)), 'Ordinary customer cannot claim management flow');
    verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve(get_userdata($id))), 'Non-owner cannot create a shadow');
}
$shadow = MobiShop_Storefront_Admin::resolve($owner);
verify_storefront($shadow instanceof WP_User && $shadow->ID !== $owner->ID, 'Issue a separate user');
verify_storefront($shadow->roles === ['customer'] && empty($shadow->allcaps['manage_options']), 'Shopper has customer role only');
verify_storefront($shadow->user_email !== $owner->user_email, 'No duplicated WordPress recovery address');
verify_storefront((int)get_user_meta($shadow->ID,'_mobishop_storefront_owner_4',true) === 10, 'Private site-specific binding');
verify_storefront(MobiShop_Storefront_Admin::contact_email($shadow) === $owner->user_email, 'Validated alias exposes contact email to its own shopper');
verify_storefront(get_user_meta($shadow->ID,'kidia_phone_setup_required',true) === '', 'Fresh verified owner shopper is not waiting for new-customer onboarding');
update_user_meta($shadow->ID,'kidia_phone_setup_required','account'); // Created by a previous connector.
update_user_meta(11,'kidia_phone_setup_required','account');
$again = MobiShop_Storefront_Admin::resolve($owner);
verify_storefront($again instanceof WP_User && $again->ID === $shadow->ID && count($GLOBALS['fixture_users']) === 5, 'Repeated login has one stable shopper');
verify_storefront(MobiShop_Storefront_Admin::valid_session_user($shadow), 'Fresh shopper is session-eligible');
verify_storefront(MobiShop_Storefront_Admin::contact_email(get_userdata(11)) === '', 'Ordinary customer never gains owner email');

verify_storefront(get_user_meta($shadow->ID,'kidia_phone_setup_required',true) === '', 'Existing verified owner shopper is repaired on next sign-in');
verify_storefront(get_user_meta(11,'kidia_phone_setup_required',true) === 'account', 'Ordinary customer retains required onboarding');
update_user_meta($shadow->ID,'kidia_phone_setup_required','otp');
MobiShop_Storefront_Admin::resolve($owner);
verify_storefront(get_user_meta($shadow->ID,'kidia_phone_setup_required',true) === 'otp', 'Explicit OTP requirement is preserved');

$original = clone $GLOBALS['fixture_users'][10];
foreach (['user_email' => 'later@example.test','user_pass'=>'rotated-fixture-hash','roles'=>['customer']] as $field=>$newValue) {
    $GLOBALS['fixture_users'][10]->$field = $newValue;
    if ($field === 'roles') $GLOBALS['fixture_users'][10]->allcaps = ['read'=>true];
    verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve($owner)), 'Stale owner proof rejected after '.$field.' changes');
    $GLOBALS['fixture_users'][10] = clone $original;
}
$GLOBALS['fixture_users'][$shadow->ID]->allcaps['edit_posts'] = true;
verify_storefront(!MobiShop_Storefront_Admin::valid_session_user(get_userdata($shadow->ID)), 'Direct privileged cap invalidates an issued shopper token');
verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve($owner)), 'Cannot issue a shopper carrying an unexpected capability');
unset($GLOBALS['fixture_users'][$shadow->ID]->allcaps['edit_posts']);
verify_storefront(serialize(get_userdata(10)) === $before, 'Dashboard credentials, email and roles untouched');
verify_storefront($GLOBALS['wpdb']->held === 0, 'Success releases creation lock');

$GLOBALS['fixture_meta'][$shadow->ID]['_mobishop_storefront_owner_4']='13';
verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve($owner)), 'Collision pointing to another owner fails closed');
verify_storefront(MobiShop_Storefront_Admin::contact_email(get_userdata($shadow->ID)) !== 'second@example.test', 'Forged marker cannot expose another email');
unset($GLOBALS['fixture_meta'][$shadow->ID]['_mobishop_storefront_owner_4']);
verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve($owner)), 'Pre-existing matching login never adopted without reciprocal proof');
verify_storefront($GLOBALS['wpdb']->held === 0, 'Rejection releases the lock');
$GLOBALS['fixture_meta'][$shadow->ID]['_mobishop_storefront_owner_4']='10';
$GLOBALS['fixture_users'][$shadow->ID]->roles=['administrator'];
$GLOBALS['fixture_users'][$shadow->ID]->allcaps=['manage_options'=>true];
verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve($owner)), 'Previously valid shopper promoted to admin is rejected');

reset_storefront_fixture();
$GLOBALS['wpdb']->busy = true;
verify_storefront(is_wp_error(MobiShop_Storefront_Admin::resolve(get_userdata(10))), 'Unavailable creation lock fails closed');
verify_storefront(count($GLOBALS['fixture_users']) === 4 && $GLOBALS['wpdb']->held === 0, 'Contention never creates or releases another worker lock');
reset_storefront_fixture();
$shadow = MobiShop_Storefront_Admin::resolve(get_userdata(10));
verify_storefront(MobiShop_Storefront_Admin::data_owner_id($shadow->ID) === 10, 'Verified customer principal resolves only its historical data owner');
verify_storefront(MobiShop_Storefront_Admin::data_owner_id(11) === 11, 'Ordinary customer data ownership unchanged');
$GLOBALS['fixture_meta'][$shadow->ID]['_mobishop_storefront_owner_4']='13';
verify_storefront(MobiShop_Storefront_Admin::data_owner_id($shadow->ID) === 0, 'Forged marker fails closed for data access');
$GLOBALS['fixture_meta'][$shadow->ID]['_mobishop_storefront_owner_4']='10';
$GLOBALS['fixture_users'][10]->roles=['customer'];
$GLOBALS['fixture_users'][10]->allcaps=['read'=>true];
verify_storefront(MobiShop_Storefront_Admin::data_owner_id($shadow->ID) === 0, 'Owner removed from administrator role invalidates historic access');
$GLOBALS['fixture_users'][10]->roles=['administrator'];
$GLOBALS['fixture_users'][10]->allcaps=['manage_options'=>true,'edit_users'=>true,'read'=>true];
$GLOBALS['fixture_users'][$shadow->ID]->allcaps['edit_posts']=true;
verify_storefront(MobiShop_Storefront_Admin::data_owner_id($shadow->ID) === 0, 'Privileged shopper cannot resolve data owner');

echo 'Storefront administrator isolation: '.$checks." checks passed.\n";
