<?php
/** Verified owner address integration; synthetic records only. */
putenv('MOBISHOP_ACCOUNT_TEST_ROOT=' . dirname(__DIR__) . '/source/api');
require dirname(__DIR__, 3) . '/mobishop/tests/customer-account-endpoint-contract-test.php';

class MobiShop_Storefront_Admin {
    public static function data_owner_id(int $id): int { return $GLOBALS['fixture_data_owner'] ?? $id; }
    public static function contact_email($user): string { return ''; }
}
class WP_User {}
function get_user_by($key,$id) { return false; }
$GLOBALS['mobishop_current_user_id'] = 70;
$GLOBALS['fixture_data_owner'] = 7;
$GLOBALS['mobishop_customers'][7] = $GLOBALS['mobishop_customer'];
$GLOBALS['mobishop_customers'][7]['billing']['address_1'] = 'Historical owner address';
$GLOBALS['mobishop_customers'][70] = $GLOBALS['mobishop_customer'];
$GLOBALS['mobishop_customers'][70]['billing']['address_1'] = '';
$view = $endpoint->get_account();
mobishop_account_assert($view->data['profile']['id'] === 70, 'Session/profile identity remains isolated shopper');
mobishop_account_assert($view->data['billing']['billing_address_1'] === 'Historical owner address', 'Saved canonical owner address is visible');
$write = $endpoint->update_address(new WP_REST_Request(['type'=>'billing'], ['billing_address_1'=>'Updated own address','role'=>'administrator','user_email'=>'attacker@example.test']));
mobishop_account_assert($write instanceof WP_REST_Response && $GLOBALS['mobishop_customers'][7]['billing']['address_1'] === 'Updated own address', 'Address allowlist writes canonical owner address');
mobishop_account_assert($GLOBALS['mobishop_customers'][70]['billing']['address_1'] === '', 'Shopper duplicate does not replace canonical address');
mobishop_account_assert($GLOBALS['mobishop_customers'][7]['email'] === $GLOBALS['mobishop_customer']['email'] && !isset($GLOBALS['mobishop_customers'][7]['role']), 'Address request cannot alter login email or privileges');
$GLOBALS['fixture_data_owner'] = 0;
mobishop_account_assert($endpoint->get_account() instanceof WP_Error, 'Invalid owner mapping denies address view');
mobishop_account_assert($endpoint->update_address(new WP_REST_Request(['type'=>'billing'], [])) instanceof WP_Error, 'Invalid owner mapping denies address mutation');
echo "Owner shopping address regression passed.\n";
