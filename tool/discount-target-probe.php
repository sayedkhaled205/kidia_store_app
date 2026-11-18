<?php
/** Read-only candidate/quote cost probe for the observed live rules. */
if (!defined('WP_CLI') || !WP_CLI || wp_parse_url(home_url(), PHP_URL_HOST)!=='kidiastore.com') throw new RuntimeException('Audit store only');
global $wpdb,$wp_filter;
$start=microtime(true);
$sql="SELECT p.ID,
MAX(tt.taxonomy='pwb-brand' AND tt.term_id=1065) b,
MAX(tt.taxonomy='product_tag' AND tt.term_id=202) t,
MAX(tt.taxonomy='product_cat' AND tt.term_id IN (16,20,39,18,70,41)) c,
MAX(tt.taxonomy='product_tag' AND tt.term_id IN (192,255,124,49,159,186,197,250,1043,169,176,50,117,236,112,224,35,205,201,215,254,113,114,165,212,210,116,252,806,38,243,953,88,108,1008,194,119,92,171,174,61,76,60,206,63,183,1066,157,158,175,221)) x
FROM {$wpdb->posts} p JOIN {$wpdb->term_relationships} tr ON tr.object_id=p.ID
JOIN {$wpdb->term_taxonomy} tt ON tt.term_taxonomy_id=tr.term_taxonomy_id
WHERE p.post_type='product' AND p.post_status='publish'
AND tt.taxonomy IN ('pwb-brand','product_tag','product_cat') GROUP BY p.ID";
$rows=$wpdb->get_results($sql,ARRAY_A);
$counts=['r42_or'=>0,'r42_and'=>0,'r43'=>0,'candidate_or'=>0,'candidate_and'=>0]; $candidates=[];
foreach($rows as $r) {
    $or=$r['b']||$r['t']; $and=$r['b']&&$r['t']; $r43=$r['c']&&!$r['x'];
    $counts['r42_or']+=(int)$or; $counts['r42_and']+=(int)$and; $counts['r43']+=(int)$r43;
    $counts['candidate_or']+=(int)($or||$r43); $counts['candidate_and']+=(int)($and||$r43);
    if($or||$r43) $candidates[]=(int)$r['ID'];
}
echo 'TARGET_COUNTS '.wp_json_encode($counts+['sql_seconds'=>round(microtime(true)-$start,4)]).PHP_EOL;
foreach(['advanced_woo_discount_rules_is_valid_filter_type','advanced_woo_discount_rules_filter_passed','advanced_woo_discount_rules_get_product_categories','woocommerce_product_get_category_ids','woocommerce_product_get_tag_ids','woocommerce_product_variation_get_parent_id'] as $tag) {
    $callbacks=[];
    foreach(($wp_filter[$tag]->callbacks??[]) as $priority=>$items) foreach($items as $item) {
        $cb=$item['function'];
        $callbacks[]=is_array($cb)?(is_object($cb[0])?get_class($cb[0]):$cb[0]).'::'.$cb[1]:(is_string($cb)?$cb:'Closure');
    }
    echo 'CALLBACKS '.$tag.' '.wp_json_encode($callbacks).PHP_EOL;
}
$_SERVER['REQUEST_URI']='/wp-json/wc/store/v1/products'; $_SERVER['HTTP_X_MOBISHOP_CHANNEL']='mobile';
$start=microtime(true); $sample=array_slice($candidates,0,100); $sale=0;
foreach($sample as $id) {
    $p=wc_get_product($id); if(!$p) continue;
    $r=MobiShop_Discount_Rules_Prices::prices($p,['currency_minor_unit'=>0,'price'=>(string)$p->get_price(),'regular_price'=>(string)$p->get_regular_price()]);
    if($r['regular_price']!=='' && (int)$r['price']<(int)$r['regular_price']) $sale++;
}
echo 'TARGET_QUOTE_SAMPLE '.wp_json_encode(['count'=>count($sample),'on_sale'=>$sale,'seconds'=>round(microtime(true)-$start,4)]).PHP_EOL;
