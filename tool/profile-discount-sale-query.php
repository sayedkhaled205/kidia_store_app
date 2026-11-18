<?php
/** Read-only live cost profile; only aggregate timing/counts are printed. */
if (!defined('WP_CLI') || !WP_CLI || wp_parse_url(home_url(),PHP_URL_HOST)!=='kidiastore.com') throw new RuntimeException('Audit store only');
require_once (($args[0]??'')==='candidate' ? '/root/kidia-discount-audit-20261118/query-candidate.php' : MOBISHOP_PATH.'api/class-discount-rules-catalogue-query.php');
$_SERVER['HTTP_X_MOBISHOP_CHANNEL']='mobile'; $_SERVER['REQUEST_URI']='/wp-json/wc/store/v1/products';
$r=new WP_REST_Request('GET','/wc/store/v1/products'); $r->set_header('X-MobiShop-Channel','mobile');
$r->set_param('per_page',20); $r->set_param('page',1);
$r->set_param('order','desc'); $r->set_param('orderby','date');
$pq=new \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery();
$a=$pq->prepare_objects_query($r); $a['posts_per_page']=-1; $a['fields']='ids'; $a['no_found_rows']=true;
$t=microtime(true); add_filter('posts_clauses',[$pq,'add_query_clauses'],10,2);
try {$ids=(new WP_Query())->query($a);} finally {remove_filter('posts_clauses',[$pq,'add_query_clauses'],10);}
$times=['baseline'=>microtime(true)-$t];
$t=microtime(true); $targets=(new ReflectionMethod('MobiShop_Discount_Rules_Catalogue_Query','conservative_targets'))->invoke(null,$ids); $times['targets']=microtime(true)-$t;
$t=microtime(true); (new ReflectionMethod('MobiShop_Discount_Rules_Catalogue_Query','prime_caches'))->invoke(null,$targets); $times['prime']=microtime(true)-$t;
$container=\Automattic\WooCommerce\StoreApi\StoreApi::container();
$schema=new class($container->get(\Automattic\WooCommerce\StoreApi\Schemas\ExtendSchema::class),$container->get(\Automattic\WooCommerce\StoreApi\SchemaController::class)) extends \Automattic\WooCommerce\StoreApi\Schemas\V1\ProductSchema { public function price_fields($p):array{return $this->prepare_product_price_response($p);} };
$times+=['precheck'=>0,'original_sale'=>0,'schema'=>0,'quote'=>0]; $sales=0; $changed=0; $evaluated=[]; $sale_ids=[];
$rules=(new ReflectionMethod('MobiShop_Discount_Rules_Catalogue_Query','active_allowed_rules'))->invoke(null);
foreach($targets as $id) {
 $p=wc_get_product($id); if(!$p)continue;
 $evaluated[]=$id;
 $t=microtime(true); $original=$p->is_on_sale(); $times['original_sale']+=microtime(true)-$t;
 $t=microtime(true); $before=$schema->price_fields($p); $times['schema']+=microtime(true)-$t;
 $t=microtime(true); $after=MobiShop_Discount_Rules_Prices::prices($p,$before); $times['quote']+=microtime(true)-$t;
 $changed+=(int)($before!==$after); $sale=MobiShop_Discount_Rules_Prices::sale_state($before,$after,$original); $sales+=(int)$sale; if($sale)$sale_ids[]=$id;
}
$final=array_values(array_unique(array_merge(array_diff(array_intersect($ids,wc_get_product_ids_on_sale()),$evaluated),$sale_ids)));sort($final,SORT_NUMERIC);
echo 'SALE_QUERY_PROFILE '.wp_json_encode(['mode'=>$args[0]??'before','catalogue'=>count($ids),'candidates'=>count($targets),'evaluated'=>count($evaluated),'changed'=>$changed,'sale'=>$sales,'final_count'=>count($final),'membership_hash'=>hash('sha256',json_encode($final)),'seconds'=>$times]).PHP_EOL;
