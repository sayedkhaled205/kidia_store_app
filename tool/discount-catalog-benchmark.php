<?php
/** Read-only quote cost probe. Never create an order or change catalogue data. */
if (!defined('WP_CLI') || !WP_CLI || !in_array(wp_parse_url(home_url(), PHP_URL_HOST), ['staging.kidiastore.com','kidiastore.com'],true)) throw new RuntimeException('Audit stores only');
$_SERVER['REQUEST_URI']='/wp-json/wc/store/v1/products';
$_SERVER['HTTP_X_MOBISHOP_CHANNEL']='mobile';
global $wpdb;
$rows=$wpdb->get_results("SELECT id,discount_type,filters,conditions,additional,date_from,date_to FROM {$wpdb->prefix}wdr_rules WHERE enabled=1 AND deleted=0",ARRAY_A);
foreach($rows as $row) echo 'RULE '.json_encode($row).PHP_EOL;
$ids=get_posts(['post_type'=>'product','post_status'=>'publish','numberposts'=>100,'fields'=>'ids']);
$start=microtime(true);$types=[];
foreach($ids as $id) {
    $product=wc_get_product($id);
    if(!$product) continue;
    $types[$product->get_type()]=1+($types[$product->get_type()]??0);
    MobiShop_Discount_Rules_Prices::prices($product,['currency_minor_unit'=>0,'price'=>(string)$product->get_price(),'regular_price'=>(string)$product->get_regular_price()]);
}
echo 'BENCH '.json_encode(['count'=>count($ids),'seconds'=>round(microtime(true)-$start,3),'types'=>$types]).PHP_EOL;
