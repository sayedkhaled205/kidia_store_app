<?php
/** Execute stock-aware facet SQL on synthetic data; no production mutations. */
namespace Automattic\WooCommerce\StoreApi\Utilities {
 class ProductQuery {
  public function prepare_objects_query($request) {
   $GLOBALS['prepared_params'][] = $request->params;
   // Like Woo prepare_objects_query, this does not apply the Store API filter.
   return array_merge($request->params, ['post_type'=>'product','post_status'=>'publish']);
  }
  public function add_query_clauses($clauses,$query) {
   $GLOBALS['woo_clause_calls']++;
   $clauses['where'] .= ' AND posts.ID >= 100';
   if ($query->get('include')) $clauses['where'] .= ' AND posts.ID IN (' . implode(',',array_map('intval',$query->get('include'))) . ')';
   return $clauses;
  }
 }
}
namespace {
 $argv[1]='api';
 require __DIR__.'/catalog-stock-visibility-test.php';
 define('ARRAY_A','ARRAY_A');
 class WP_Error { public function __construct(public $code, public $message,public $data) {} }
 function __($v,$domain) {return $v;}
 function remove_filter($hook,$callback,$priority) {
  $GLOBALS['hooks'][$hook][$priority] = array_values(array_filter($GLOBALS['hooks'][$hook][$priority] ?? [], fn($item)=>$item !== $callback));
 }
 class WP_REST_Request {
  public function __construct(public array $params=[],public string $method='GET',public string $route='/wc/store/v1/products/collection-data') {}
  public function get_method(){return $this->method;}
  public function get_route(){return $this->route;}
  public function get_param($k){return $this->params[$k]??null;}
  public function set_param($k,$v){$this->params[$k]=$v;}
 }
 class WP_REST_Response {
  public function __construct(private array $data=[],private int $status=200){}
  public function get_status(){return $this->status;}
  public function get_data(){return $this->data;}
  public function set_data($data){$this->data=$data;}
 }
 function rest_ensure_response($v){return $v instanceof WP_REST_Response?$v:new WP_REST_Response($v);}
 class WP_Query extends CatalogStockFixtureQuery {
  public string $request='';
  public function __construct(){parent::__construct([]);}
  public function query($args){
   foreach($args as $key=>$value)$this->set($key,$value);
   if($GLOBALS['compile_throw']??false)throw new \RuntimeException('Fixture compile failure');
   check(null === apply_filters('posts_pre_query',null,new CatalogStockFixtureQuery([])), 'compiler leaves unrelated queries alone');
   $parts=apply_filters('posts_clauses',['where'=>" AND posts.post_status='publish'"],$this);
   $this->request="SELECT posts.ID FROM posts WHERE posts.post_type='product'".$parts['where'];
   check([]===apply_filters('posts_pre_query',null,$this),'compiler does not materialize all product IDs');
   check($args['posts_per_page']===-1 && $args['no_found_rows'] && !$args['cache_results'],'compiler removes pagination without caching IDs');
   return [];
  }
 }
 $filter=new MobiShop_Attribute_Stock_Filter();
 $wp->query_vars['rest_route']='/wc/store/v1/products/collection-data';
 $_GET=[]; $hide='yes'; $taxes=false; $admin=false;
 $GLOBALS['woo_clause_calls']=0;
 $db->exec("CREATE TABLE terms(term_id INTEGER, slug TEXT, name TEXT);
 ALTER TABLE term_taxonomy ADD COLUMN taxonomy TEXT DEFAULT '';
 UPDATE term_taxonomy SET taxonomy='pa_size' WHERE term_id=21;
 INSERT INTO terms VALUES(21,'m','Medium'),(22,'s','Small'),(31,'green','Green'),(32,'blue','Blue');
 INSERT INTO term_taxonomy VALUES(122,22,'pa_size'),(131,31,'pa_color'),(132,32,'pa_color');");
 $GLOBALS['facet_terms']=[];
 // Explicit objects preserve the same term IDs as the fixture tables.
 $GLOBALS['facet_terms']=array_map(fn($x)=>(object)['term_id'=>$x[0],'slug'=>$x[1],'taxonomy'=>$x[2]],[[21,'m','pa_size'],[22,'s','pa_size'],[31,'green','pa_color'],[32,'blue','pa_color']]);
 function parent_row($id){global $db;$db->exec("INSERT INTO posts VALUES($id,'product',0,'publish');INSERT INTO wc_product_meta_lookup(product_id,stock_status)VALUES($id,'instock');INSERT INTO term_relationships VALUES($id,99),($id,121),($id,122),($id,131),($id,132)");}
 function variant_row($id,$parent,$size,$color,$stock='instock',$price='10'){
  global $db;
  $db->exec("INSERT INTO posts VALUES($id,'product_variation',$parent,'publish');INSERT INTO wc_product_meta_lookup(product_id,stock_status)VALUES($id,'$stock');INSERT INTO postmeta VALUES($id,'_price','$price')");
  foreach(['pa_size'=>$size,'pa_color'=>$color]as$key=>$value)if($value!==null)$db->exec("INSERT INTO postmeta VALUES($id,'attribute_$key',".$db->quote($value).")");
 }
 parent_row(100);variant_row(1001,100,'s','green');variant_row(1002,100,'m','blue');variant_row(1003,100,'m','green','outofstock');
 function facets($params=[]){global $filter;return $filter->available_sizes(new WP_REST_Response(['price_range'=>['min_price'=>'1000']]),null,new WP_REST_Request(array_merge(['mobishop_available_sizes'=>'true','include'=>[100]],$params)));}
 function terms($response){check($response instanceof WP_REST_Response,'facets response successful');return array_column($response->get_data()['available_sizes'],'term');}
 $green=['attributes'=>[['attribute'=>'pa_color','slug'=>'green','operator'=>'in']]];
 check(terms(facets($green))===['s'],'same color and size must be on one available child');
 check(terms(facets())===['m','s'],'unfiltered facets include both available colors');
 $selected=$green;$selected['attributes'][]=['attribute'=>'pa_size','slug'=>'m','operator'=>'in'];
 check(terms(facets($selected))===['s'],'own selected size is removed while color remains');
 check(terms(facets($green+['min_price'=>'1100']))===[],'price cannot match a different child');
 $db->exec("UPDATE postmeta SET meta_value='20' WHERE post_id=1002 AND meta_key='_price'");
 check(terms(facets($green+['min_price'=>'1500']))===[],'blue expensive size cannot leak into green price scope');
 parent_row(101);variant_row(1011,101,'','green');
 check(terms(facets($green+['include'=>[101]]))===['m','s'],'Any size expands only actual parent terms');
 parent_row(102);variant_row(1021,102,null,'green');variant_row(1022,102,'m','blue');
 check(terms(facets($green+['include'=>[102]]))===[],'missing key on one child is not Any');
 parent_row(103);variant_row(1031,103,null,'green');
 check(terms(facets($green+['include'=>[103]]))===['m','s'],'descriptive parent size is supported when no children have that dimension');
 $db->exec("UPDATE posts SET post_status='draft' WHERE ID=103");
 check(terms(facets($green+['include'=>[103]]))===[],'scope excludes non-public parent');
 $before=count($wpdb->facet_queries);$params=$green+['search'=>'shoes','category'=>'5','brand'=>'6','tag'=>'7','on_sale'=>true,'min_price'=>'0'];facets($params);
 $captured=end($GLOBALS['prepared_params']);foreach(['search','category','brand','tag','on_sale','min_price']as$key)check($captured[$key]===$params[$key],'scope preserves '.$key);
 check(count($wpdb->facet_queries)===$before+1,'one aggregate query per metadata request');
 $hide='no';
 check(terms(facets($green+['min_price'=>'1500']))===[],'hide-off facets still require same-child price');
 $db->exec("UPDATE postmeta SET meta_value='' WHERE post_id=1001 AND meta_key='_price'");
 check(terms(facets($green))===[],'unpriced variations do not offer a purchasable size');
 $db->exec("UPDATE postmeta SET meta_value='10' WHERE post_id=1001 AND meta_key='_price'");
 $hide='yes';
 parent_row(104);$db->exec("DELETE FROM term_relationships WHERE object_id=104 AND term_taxonomy_id=99; INSERT INTO postmeta VALUES(104,'_price','10')");
 check(terms(facets(['include'=>[104]]))===['m','s'],'priced simple product exposes its sizes');
 $db->exec("UPDATE postmeta SET meta_value='' WHERE post_id=104 AND meta_key='_price'");
 check(terms(facets(['include'=>[104]]))===[],'unpriced simple product does not invent available sizes');
 parent_row(105);$hide='no';check(terms(facets(['include'=>[105]]))===[],'variable parent without children has no purchasable sizes');$hide='yes';
 $before=count($wpdb->facet_queries);$start=microtime(true);
 foreach(range(200,399) as $id){parent_row($id);variant_row($id+2000,$id,'s','green');}
 check(terms(facets($green+['include'=>range(200,399)]))===['s'],'aggregate handles 200 products with the same fixed query count');
 check(count($wpdb->facet_queries)===$before+1,'product count does not add metadata queries');
 echo 'INFO fixture200 elapsed_ms='.round((microtime(true)-$start)*1000)."\n";
 $response=new WP_REST_Response([]);foreach([['GET','/wc/store/v1/cart',true],['POST','/wc/store/v1/products/collection-data',true],['GET','/wc/store/v1/products/collection-data',false]]as[$method,$route,$opt])check($filter->available_sizes($response,null,new WP_REST_Request(['mobishop_available_sizes'=>$opt],$method,$route))===$response,'route opt-in guard');
 $count_hooks=fn()=>array_sum(array_map(fn($priorities)=>array_sum(array_map('count',$priorities)),$GLOBALS['hooks']));
 $count=$count_hooks();$GLOBALS['compile_throw']=true;check(facets() instanceof WP_Error,'compile failure is retryable');$GLOBALS['compile_throw']=false;check($count===$count_hooks(),'compile exception removes temporary hooks');
 $wpdb->simulate='error';check(facets() instanceof WP_Error,'SQL failure is not authoritative empty facets');$wpdb->simulate='';
 check($GLOBALS['woo_clause_calls']>0 && !$wpdb->stock_queries,'Woo clauses used without materializing product IDs');
 echo "PASS stock-aware size facets integration.\n";
}