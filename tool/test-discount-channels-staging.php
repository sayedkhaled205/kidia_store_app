<?php
/** WP-CLI only, staging-only, transactional fixtures. No orders, email or real rule changes. */
if ( ! defined( 'WP_CLI' ) || ! WP_CLI || wp_parse_url( home_url(), PHP_URL_HOST ) !== 'staging.kidiastore.com' ) {
	throw new RuntimeException( 'Staging WP-CLI only.' );
}
// Use the installed connector under test, not a different copied price module.
if (!class_exists('MobiShop_Discount_Channel')) throw new RuntimeException('Install candidate connector first');
$case = $args[0] ?? 'simple';
$quantity = (int) ( $args[1] ?? 1 );
$channel = $args[2] ?? 'website'; $scope = $args[3] ?? 'all';
if (!in_array($channel,['website','mobile'],true) || !in_array($scope,['all','website','mobile'],true)) throw new RuntimeException('Invalid channel');
$_SERVER['REQUEST_URI']='/wp-json/wc/store/v1/cart';
unset($_SERVER['HTTP_X_MOBISHOP_CHANNEL'], $_SERVER['HTTP_X_MOBISHOP_SESSION']);
if ($channel==='mobile') $_SERVER['HTTP_X_MOBISHOP_CHANNEL']='mobile';
$eligible = $scope==='all' || $scope===$channel;
if ($quantity < 1 || $quantity > 4) throw new RuntimeException('Fixture quantity must be 1..4');
if ( ! in_array( $case, array('simple','zero','bulk','cart','set','bxgx','bxgy','none'), true ) ) { throw new RuntimeException('Unknown fixture'); }
$created = array();
$results = array();
global $wpdb;
foreach ([$wpdb->posts,$wpdb->postmeta] as $table) {
    $engine=$wpdb->get_var($wpdb->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s',$table));
    if(strtoupper((string)$engine)!=='INNODB') throw new RuntimeException('Transactional fixtures required');
}
if($wpdb->query('START TRANSACTION')===false) throw new RuntimeException('Cannot begin fixture transaction');
try {
	// Create disposable database fixtures directly to avoid product-save webhooks.
	$make = static function($price) use ($wpdb, &$created) {
		$now = current_time('mysql');
		$wpdb->insert($wpdb->posts, array('post_author'=>0,'post_date'=>$now,'post_date_gmt'=>gmdate('Y-m-d H:i:s'),'post_modified'=>$now,'post_modified_gmt'=>gmdate('Y-m-d H:i:s'),'post_title'=>'WooMobile discount QA fixture','post_name'=>'woomobile-discount-qa-'.wp_generate_uuid4(),'post_status'=>'publish','post_type'=>'product','post_content'=>'','post_excerpt'=>'','comment_status'=>'closed','ping_status'=>'closed','to_ping'=>'','pinged'=>'','post_content_filtered'=>''));
		$id=(int)$wpdb->insert_id;
		if(!$id) throw new RuntimeException('Fixture creation failed');
		$created[]=$id;
		foreach(array('_price'=>(string)$price,'_regular_price'=>(string)$price,'_virtual'=>'yes','_stock_status'=>'instock','_manage_stock'=>'no','_tax_status'=>'none') as $key=>$value) $wpdb->insert($wpdb->postmeta,array('post_id'=>$id,'meta_key'=>$key,'meta_value'=>$value));
		clean_post_cache($id);
		return $id;
	};
	$a=$make(100); $g=$make(60);
	$rule = (object) array('id'=>-104,'enabled'=>1,'deleted'=>0,'exclusive'=>0,'priority'=>1,'title'=>'WooMobile isolated test','apply_to'=>'','filters'=>json_encode(array('1'=>array('type'=>'products','method'=>'in_list','value'=>array($a)))),'conditions'=>'[]','additional'=>'[]','date_from'=>null,'date_to'=>null,'usage_limits'=>0,'used_limits'=>0,'product_adjustments'=>'[]','cart_adjustments'=>'[]','bulk_adjustments'=>'[]','set_adjustments'=>'[]','buy_x_get_x_adjustments'=>'[]','buy_x_get_y_adjustments'=>'[]');
	$range = static fn($data) => array('ranges'=>array('1'=>$data));
	$definitions=array(
		'simple'=>array('wdr_simple_discount','product_adjustments',array('type'=>'percentage','value'=>'10','apply_as_cart_rule'=>'0')),
		'zero'=>array('wdr_simple_discount','product_adjustments',array('type'=>'percentage','value'=>'100','apply_as_cart_rule'=>'0')),
		'bulk'=>array('wdr_bulk_discount','bulk_adjustments',array_merge(array('operator'=>'product','apply_as_cart_rule'=>'0'),$range(array('from'=>'3','to'=>'','type'=>'percentage','value'=>'10','label'=>'')))),
		'cart'=>array('wdr_cart_discount','cart_adjustments',array('type'=>'flat_in_subtotal','value'=>'20','label'=>'QA cart 20')),
		'set'=>array('wdr_set_discount','set_adjustments',array_merge(array('operator'=>'product','apply_as_cart_rule'=>'0'),$range(array('from'=>'2','type'=>'fixed_set_price','value'=>'150','recursive'=>'1','label'=>'')))),
		'bxgx'=>array('wdr_buy_x_get_x_discount','buy_x_get_x_adjustments',$range(array('from'=>'2','to'=>'','free_qty'=>'1','free_type'=>'free_product','free_value'=>'0','recursive'=>'1'))),
		'bxgy'=>array('wdr_buy_x_get_y_discount','buy_x_get_y_adjustments',array_merge(array('type'=>'bxgy_product','mode'=>'auto_add','operator'=>'product_cumulative'),$range(array('from'=>'2','to'=>'','free_qty'=>'1','free_type'=>'free_product','free_value'=>'0','recursive'=>'1','products'=>array($g)))))
	);
	$rule->additional=json_encode(['mobishop_channel'=>$scope]);
	$manager=new \Wdr\App\Controllers\ManageDiscount();
	$rules=array();
	if($case!=='none') {
		[$rule->discount_type,$column,$config]=$definitions[$case];
		$rule->$column=json_encode($config);
		$rules=array(-104=>new \Wdr\App\Helpers\Rule($rule,$manager->getAvailableConditions()));
	}
	// In-memory rules only: no database rule is updated, activated or inserted.
	\Wdr\App\Controllers\ManageDiscount::$available_rules=$rules;
	\Wdr\App\Controllers\ManageDiscount::$calculator=new \Wdr\App\Controllers\DiscountCalculator($rules);
	if(!WC()->session) { WC()->initialize_session(); }
	WC()->customer = new WC_Customer(0, true);
	WC()->cart = new WC_Cart();
	$product=wc_get_product($a);
	$prices=array('price'=>'10000','regular_price'=>'10000','sale_price'=>'10000','currency_minor_unit'=>2);
	$quote=MobiShop_Discount_Rules_Prices::prices($product,$prices);
	$expected_quote=$case==='simple'?'9000':($case==='zero'?'0':'10000');
	if (!$eligible) $expected_quote='10000';
	if($quote['price']!==$expected_quote) throw new RuntimeException('Quote mismatch '.json_encode($quote));
	$expected=array('simple'=>array(1=>90,2=>180,3=>270,4=>360),'zero'=>array(1=>0,2=>0,3=>0,4=>0),'bulk'=>array(1=>100,2=>200,3=>270,4=>360),'cart'=>array(1=>80,2=>180,3=>280,4=>380),'set'=>array(1=>100,2=>150,3=>250,4=>300),'bxgx'=>array(1=>100,2=>200,3=>300,4=>400),'bxgy'=>array(1=>100,2=>200,3=>300,4=>400),'none'=>array(1=>100,2=>200,3=>300,4=>400));
	if (!$eligible) $expected[$case]=$expected['none'];
	$key=WC()->cart->add_to_cart($a,1);
	if(!$key) throw new RuntimeException('Could not add fixture to cart');
	foreach(array($quantity) as $quantity) {
		WC()->cart->set_quantity($key,$quantity,true);
		$first=(float)WC()->cart->get_total('edit');
		for($repeat=0;$repeat<2;$repeat++) WC()->cart->calculate_totals();
		$total=(float)WC()->cart->get_total('edit');
		if(abs($first-$total)>0.005 || abs($total-$expected[$case][$quantity])>0.005) throw new RuntimeException("Cart mismatch q=$quantity first=$first repeat=$total expected=".$expected[$case][$quantity]);
		$gifts=0;
		foreach(WC()->cart->get_cart() as $item) if(\WDRPro\App\Rules\BOGO::isFreeProduct($item)) $gifts+=(int)$item['quantity'];
		if(in_array($case,array('bxgx','bxgy'),true) && $gifts!==($eligible ? intdiv($quantity,2) : 0)) throw new RuntimeException("Gift mismatch q=$quantity gifts=$gifts");
		// Compare the same Woo cart through the real Store API schema used by the app.
		$schema=\Automattic\WooCommerce\StoreApi\StoreApi::container()->get(\Automattic\WooCommerce\StoreApi\SchemaController::class)->get('cart');
		$data=$schema->get_item_response(WC()->cart);
		$api_total=(int)$data['totals']->total_price;
		if($api_total!==(int)round($total*(10**$data['totals']->currency_minor_unit))) throw new RuntimeException('Store API total mismatch '.json_encode(array('api'=>$data['totals'],'wc'=>$total)));
		$response=new WP_REST_Response($data);
		$request=new WP_REST_Request('GET','/wc/store/v1/cart');
		MobiShop_Discount_Rules_Prices::cart_response($response,null,$request);
		foreach($response->get_data()['items'] as $item) {
			$raw=WC()->cart->get_cart_item($item['key']);
			if(\WDRPro\App\Rules\BOGO::isFreeProduct($raw) && ((array)$item['quantity_limits'])['editable']!==false) throw new RuntimeException('Gift quantity unlocked in app');
		}
		$results[]=array('quantity'=>$quantity,'website'=>$total,'app_minor'=>$api_total,'gifts'=>$gifts);
	}
} finally {
	if ( WC()->session ) { remove_action('shutdown',array(WC()->session,'save_data'),20); }
	if($wpdb->query('ROLLBACK')===false) throw new RuntimeException('Fixture rollback failed');
	foreach($created as $id) { clean_post_cache($id); wp_cache_delete($id,'post_meta'); }
	$remaining=(int)$wpdb->get_var('SELECT COUNT(*) FROM '.$wpdb->posts.' WHERE ID IN ('.implode(',',array_map('intval',$created?:array(0))).')');
	if($remaining!==0) throw new RuntimeException('Fixture records remain');
}
print("DISCOUNT_QA ".json_encode(array('case'=>$case,'channel'=>$channel,'scope'=>$scope,'quote'=>$quote['price'],'checks'=>$results,'fixture_posts_remaining'=>0,'passed'=>true))."\n");
