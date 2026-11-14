<?php
/** Management roles use the same restricted shopping identity, never a staff token. */
declare(strict_types=1);
require __DIR__.'/storefront-admin-test.php';
$beforeStaffChecks = $checks;
foreach ([
    ['shop_manager'], ['administrator'], ['custom_management'],
] as $roles) {
    reset_storefront_fixture();
    $GLOBALS['fixture_users'][12]->roles = $roles;
    $GLOBALS['fixture_users'][12]->allcaps = ['read'=>true, 'manage_woocommerce'=>true];
    $manager = get_userdata(12);
    $unchanged = serialize($manager);
    verify_storefront(MobiShop_Storefront_Admin::accepts($manager), 'Management identity can open its mobile shopping profile');
    $shopper = MobiShop_Storefront_Admin::resolve($manager);
    verify_storefront($shopper instanceof WP_User && $shopper->ID !== $manager->ID, 'Manager receives a separate principal');
    verify_storefront($shopper->roles === ['customer'] && $shopper->allcaps === ['read'=>true], 'Management capabilities never reach shopper');
    verify_storefront(MobiShop_Storefront_Admin::data_owner_id($shopper->ID) === $manager->ID, 'Existing data remains bound to the proven manager');
    verify_storefront(serialize(get_userdata(12)) === $unchanged, 'Management account remains unchanged');
}
foreach (['manage_options', 'edit_users', 'manage_woocommerce'] as $capability) {
    reset_storefront_fixture();
    $GLOBALS['fixture_users'][12]->roles = ['custom_staff'];
    $GLOBALS['fixture_users'][12]->allcaps = ['read'=>true, $capability=>true];
    verify_storefront(MobiShop_Storefront_Admin::accepts(get_userdata(12)), 'Explicit management capability uses restricted shopper');
}
reset_storefront_fixture();
$GLOBALS['fixture_users'][12]->roles = ['editor'];
$GLOBALS['fixture_users'][12]->allcaps = ['read'=>true, 'edit_posts'=>true];
verify_storefront(!MobiShop_Storefront_Admin::accepts(get_userdata(12)), 'Unrelated roles do not acquire management identity mapping');
echo 'Management shopping343: '.($checks-$beforeStaffChecks)." additional checks passed.\n";
