<?php
/** Read-only WP-CLI check for the installed merchant route; emits no customer data. */
if (!defined('WP_CLI') || !WP_CLI) { throw new RuntimeException('WP-CLI only'); }
if (!class_exists('MobiShop_Discount_Rules_Summary')) throw new RuntimeException('Discount module not loaded');
$ids=get_users(array('role'=>'administrator','number'=>1,'fields'=>'ID'));
if (!$ids) throw new RuntimeException('No merchant administrator');
wp_set_current_user((int)$ids[0]);
$result=MobiShop_Discount_Rules_Summary::query();
if (!$result['available'] || $result['error']) throw new RuntimeException('Merchant rule summary unavailable');
$request=new WP_REST_Request('GET','/mobishop/v1/central/store-data');
$request->set_param('store_tab','discounts');
$response=rest_do_request($request);
$data=$response->get_data();
$html=$data['html'] ?? '';
if ($response->get_status()!==200 || !str_contains($html,'mobishop-discount-rules')) throw new RuntimeException('Merchant rules missing from private builder response');
wp_set_current_user(0);
$denied=rest_do_request($request);
if (!in_array($denied->get_status(),array(401,403),true)) throw new RuntimeException('Anonymous merchant data not blocked');
echo 'DISCOUNTS_ACCESS '.json_encode(array('merchant_status'=>$response->get_status(),'anonymous_status'=>$denied->get_status(),'total_rules'=>$result['total'],'listed_rules'=>count($result['rows']),'passed'=>true))."\n";
