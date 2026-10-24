<?php
/** Run via wp eval-file after deploying the connector. Metadata only; no payment/status changes. */
if (!defined('ABSPATH') || !class_exists('MobiShop_Native_Payment92')) throw new RuntimeException('Load WordPress and the updated connector first.');
$orders=wc_get_orders(['limit'=>100,'orderby'=>'date','order'=>'DESC','meta_query'=>[['key'=>'_mobishop_order_source','value'=>'mobile'],['key'=>'_mobishop_native_payment92','compare'=>'EXISTS']]]);
foreach($orders as $order) {
 if($order->get_meta('kashierOrderId') || !$order->get_date_paid() || !$order->get_transaction_id())continue;
 $r=$order->get_meta('_mobishop_native_payment92');$g=wc_get_payment_gateway_by_order($order);
 if(!is_array($r) || !$g || MobiShop_Native_Payment92::adapter($g)!=='kashier'
   || $g->merchant_id!==$r['merchant'] || (bool)$g->testmode!==$r['test']
   || MobiShop_Native_Payment92::money($order->get_total('edit'))!==$r['amount'] || $order->get_currency()!==$r['currency'])continue;
 $response=wp_remote_get(add_query_arg('search',$r['reference'],($r['test']?'https://test-api.kashier.io':'https://api.kashier.io').'/v3/payment/orders'),['headers'=>['Authorization'=>$g->secret_key],'timeout'=>15,'redirection'=>0]);
 $data=!is_wp_error($response) && 200===wp_remote_retrieve_response_code($response)?json_decode(wp_remote_retrieve_body($response),true):null;
 $receipt=is_array($data)?MobiShop_Native_Payment92::verified_receipt($data,$r):null;
 if(!$receipt || !hash_equals($order->get_transaction_id(),$receipt['transaction_id'])){echo 'SKIPPED '.$order->get_id()." unverified\n";continue;}
 $before=[$order->get_status(),$order->get_total(),$order->get_transaction_id(),$order->get_date_paid()->getTimestamp()];
 $order->update_meta_data('kashierOrderId',$receipt['gateway_order_id']);
 $order->update_meta_data('_mobishop_verified_card98',$receipt);
 $order->save_meta_data();
 $after=wc_get_order($order->get_id());
 if($before!==[$after->get_status(),$after->get_total(),$after->get_transaction_id(),$after->get_date_paid()->getTimestamp()])throw new RuntimeException('Order state changed; review required.');
 echo 'RECEIPT_RESTORED '.$order->get_id().' status_unchanged='.$after->get_status()."\n";
}
