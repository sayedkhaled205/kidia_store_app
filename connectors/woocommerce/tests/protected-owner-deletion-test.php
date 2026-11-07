<?php
/** Focused protected-principal boundary; real WordPress counterpart lives in wordpress-runtime-test.php. */
function get_current_blog_id(){return 1;}
require __DIR__.'/account-deletion-test.php';
deletion_reset();
$GLOBALS['mobishop_users'][18]=array('login'=>'ci-admin','email'=>'ci-owner@example.com','password'=>'owner-fixture','display_name'=>'Owner fixture','roles'=>array('administrator'),'allcaps'=>array('manage_options'=>true));
$GLOBALS['mobishop_users'][19]=array('login'=>'mobishop_shop_1_18','email'=>'ci-alias@example.com','password'=>'alias-fixture','display_name'=>'Alias fixture','roles'=>array('customer'),'allcaps'=>array());
update_user_meta(19,'_mobishop_storefront_owner_1',18);
update_user_meta(18,'billing_address_1','Synthetic canonical address');
$session=$endpoint->login(new DeletionRequest(array('email'=>'ci-alias@example.com','password'=>'alias-fixture')));
mobishop_auth_assert($session instanceof WP_REST_Response&&$session->status===200,'Existing customer-only alias session remains supported');
$request=deletion_request($session);
mobishop_auth_assert($deletion->availability($request)->data['available']===false,'Canonical administrator shopping alias does not advertise self-deletion');
foreach(array('prepare_deletion','approve_apple','finalize_deletion','request_deletion')as $method){
 mobishop_auth_assert(is_wp_error($deletion->$method($request)),'Protected alias rejects '.$method.' before intent or revocation');
}
mobishop_auth_assert($GLOBALS['delete_options']===array()&&!is_wp_error($endpoint->authenticate_route($request)),'Rejected alias deletion creates no jobs/intents and preserves merchant session');
mobishop_auth_assert(get_user_meta(18,'billing_address_1',true)==='Synthetic canonical address'&&isset($GLOBALS['mobishop_users'][18],$GLOBALS['mobishop_users'][19]),'Canonical admin, alias and address remain untouched');
$GLOBALS['delete_options']['mobishop_account_deletion_v1_19']=serialize(array('userId'=>19,'phase'=>0,'cursor'=>0,'receiptHash'=>str_repeat('a',64)));
MobiShop_Customer_Account_Deletion::run_worker(19);
mobishop_auth_assert(maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_19'])['phase']===0&&isset($GLOBALS['mobishop_users'][19]),'Worker refuses protected alias before deletion phases');
unset($GLOBALS['delete_options']['mobishop_account_deletion_v1_19']);
$GLOBALS['mobishop_users'][19]['login']='mobishop_shop_1_999';
mobishop_auth_assert(is_wp_error($deletion->prepare_deletion($request)),'Missing or inconsistent canonical owner fails closed');
$GLOBALS['mobishop_users'][19]['login']='mobishop_shop_1_18';unset($GLOBALS['mobishop_users'][18]);
mobishop_auth_assert($deletion->availability($request)->data['available']===false&&is_wp_error($deletion->request_deletion($request)),'Missing canonical owner fails closed without weakening alias session permissions');
echo "Protected owner deletion boundary checks passed.\n";