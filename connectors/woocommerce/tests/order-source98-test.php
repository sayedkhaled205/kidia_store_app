<?php
define('ABSPATH',__DIR__);
require (getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__.'/../source').'/includes/class-mobishop-order-source98.php';
function check($ok,$label){if(!$ok)throw new RuntimeException($label);echo "PASS $label\n";}
function is_admin(){return true;}
class SourceQuery98 {
 public function __construct(public array $args){}
 function is_main_query(){return true;}
 function get($key){return $this->args[$key]??null;}
 function set($key,$value){$this->args[$key]=$value;}
}
$filter=new MobiShop_Order_Source98;
$other=['relation'=>'OR',['key'=>'warehouse','value'=>'one'],['key'=>'warehouse','value'=>'two']];
$args=['created_via'=>['store-api'],'status'=>'processing','meta_query'=>$other,'payment_method'=>'kashier_card'];
$_GET=[];check($filter->hpos_query($args)===$args,'ordinary website channel keeps its query');
$_GET=['_created_via'=>'mobishop-mobile'];$got=$filter->hpos_query($args);
check(!isset($got['created_via']) && $got['meta_query']['relation']==='AND','mobile filter uses explicit app metadata, including old Store API orders');
check($got['meta_query'][0]===$other && $got['meta_query'][1]['value']==='mobile','mobile filter preserves warehouse and other source restrictions');
check($got['status']==='processing' && $got['payment_method']==='kashier_card','mobile filter composes with status and card filter');
$_GET=['mobishop_order_source'=>'mobile'];$q=new SourceQuery98(['post_type'=>'shop_order','meta_query'=>$other]);$filter->legacy_query($q);
check($q->args['meta_query'][0]===$other && $q->args['meta_query'][1]['key']==='_mobishop_order_source','legacy orders keep existing restrictions and source condition');
$q=new SourceQuery98(['post_type'=>'product','meta_query'=>$other]);$filter->legacy_query($q);
check($q->args['meta_query']===$other,'product queries are not changed');
$_GET=['_created_via'=>'mobile'];check($filter->hpos_query($args)===$args,'unrecognized channel is not treated as app source');
