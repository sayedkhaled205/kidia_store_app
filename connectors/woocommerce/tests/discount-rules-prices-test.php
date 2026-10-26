<?php
/** Standalone price boundary tests. Run with PHP; real FlyCart cart tests run on staging. */
define( 'ABSPATH', __DIR__ );
$active = true; $quotes = array(); $products = array(); $tax = 'excl'; $calls = 0;
function has_filter( $name ) { return $GLOBALS['active'] ? 100 : false; }
function add_filter( ...$args ) {}
function apply_filters( $name, $initial, $product, $quantity, $custom ) {
	++$GLOBALS['calls'];
	check( $quantity === 1 && $custom === 0, 'quote context is quantity one, no custom override' );
	$value = $GLOBALS['quotes'][$product->id] ?? false;
	if ( $value instanceof Throwable ) { throw $value; }
	return $value;
}
function get_option( $key ) { return $GLOBALS['tax']; }
function wc_get_price_including_tax( $p, $args ) { return $args['price'] * 1.2; }
function wc_get_price_excluding_tax( $p, $args ) { return $args['price']; }
function wc_format_decimal( $value, $decimals ) { return number_format( (float) $value, $decimals, '.', '' ); }
function wc_get_product( $id ) { return $GLOBALS['products'][$id] ?? null; }
function check( $ok, $message ) { if ( ! $ok ) { throw new RuntimeException( $message ); } }
class Product {
	function __construct( public $id, public $type = 'simple', public $regular = 100, public $current = 100, public $parent = 0, public $children = array() ) {}
	function is_type( $type ) { return in_array( $this->type, (array) $type, true ); }
	function get_regular_price() { return $this->regular; }
	function get_price() { return $this->current; }
	function get_id() { return $this->id; }
	function get_parent_id() { return $this->parent; }
	function get_variation_prices( $tax ) { return array( 'price' => array_fill_keys( $this->children, 100 ) ); }
}
class WP_REST_Response {
	public $headers = array();
	function __construct( public $data, public $status = 200 ) {}
	function get_data() { return $this->data; }
	function set_data( $value ) { $this->data = $value; }
	function get_status() { return $this->status; }
	function header( $key, $value ) { $this->headers[$key] = $value; }
}
class Request {
	function __construct( public $route = '/wc/store/v1/products', public $method = 'GET', public $channel = 'mobile' ) {}
	function get_route() { return $this->route; }
	function get_method() { return $this->method; }
	function get_header( $name ) { return $this->channel; }
}
$root = getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: __DIR__ . '/../source';
require $root . '/api/class-discount-rules-prices.php';
$prices = array( 'price' => '10000', 'regular_price' => '10000', 'sale_price' => '10000', 'currency_minor_unit' => 2, 'currency_code' => 'EGP' );
$products[1] = new Product(1);
$p = $products[1];
check(MobiShop_Discount_Rules_Prices::prices($p,$prices) === $prices, 'no eligible offer preserves response');
$quotes[1] = 75;
$result = MobiShop_Discount_Rules_Prices::prices($p,$prices);
check($result['price'] === '7500' && $result['regular_price'] === '10000' && $result['sale_price'] === '7500', 'price/badge currency contract');
check($p->current === 100, 'product object must not be mutated');
$tax='incl';
check(MobiShop_Discount_Rules_Prices::prices($p,$prices)['price'] === '9000', 'shop tax basis preserved');
check(MobiShop_Discount_Rules_Prices::prices($p,$prices,false)['price'] === '7500', 'variation raw basis preserved');
$tax='excl';
$quotes[1]=0;
check(MobiShop_Discount_Rules_Prices::prices($p,$prices)['price'] === '0', 'zero quote not dropped');
foreach (array(false, null, '', 'bad', -5, INF, new RuntimeException('engine failure')) as $value) {
	$quotes[1]=$value;
	check(MobiShop_Discount_Rules_Prices::prices($p,$prices) === $prices, 'invalid/failed quote falls back intact');
}
$quotes[1]=90; $p->current=80;
check(MobiShop_Discount_Rules_Prices::prices($p,$prices)['price'] === '9000', 'engine quote is not clamped to stored sale');
$quotes[1]=1.2345;
foreach (array(0=>'1',2=>'123',3=>'1235') as $decimals=>$expected) {
	check(MobiShop_Discount_Rules_Prices::prices($p,array_merge($prices,array('currency_minor_unit'=>$decimals)))['price'] === $expected,'currency precision');
}
$products[2]=new Product(2,'variable',100,100,0,array(3,4,5));
$products[3]=new Product(3,'variation',200,200,2);
$products[4]=new Product(4,'variation',100,100,2);
$products[5]=new Product(5,'variation',1,1,99); // An unrelated variation cannot alter this parent.
$quotes[3]=180; $quotes[4]=70; $quotes[5]=0;
$result=MobiShop_Discount_Rules_Prices::prices($products[2],$prices);
check($result['price']==='7000' && $result['regular_price']==='10000','variable chooses actual cheapest child and matching regular price');
check($result['price_range']->max_amount==='18000','variable range not first-child quote');
$quotes[4]=new RuntimeException('later child failed');
check(MobiShop_Discount_Rules_Prices::prices($products[2],$prices)===$prices,'failed range leaves all original fields');
$active=false;
check(MobiShop_Discount_Rules_Prices::prices($p,$prices)===$prices,'missing plugin leaves catalogue unchanged');
$active=true;$quotes[1]=50;
$item=array('id'=>1,'prices'=>(object)$prices,'on_sale'=>false,'name'=>'Public product');
foreach (array(new Request('/wc/store/v1/cart'),new Request('/wc/store/v1/checkout'),new Request('/wc/store/v1/products/collection-data'),new Request('/wc/v3/products'),new Request('/wc/store/v1/products','POST'),new Request('/wc/store/v1/products','GET','website')) as $request) {
	$before=$calls;$response=new WP_REST_Response($item);
	MobiShop_Discount_Rules_Prices::catalogue_response($response,null,$request);
	check($response->get_data()===$item && $calls===$before,'unrelated requests never invoke engine');
}
$response=new WP_REST_Response(array($item));
MobiShop_Discount_Rules_Prices::catalogue_response($response,null,new Request());
check($response->data[0]['prices']->price==='5000' && $response->data[0]['on_sale']===true,'object-shaped Store API prices supported');
check($response->headers['Cache-Control']==='no-store, private','context-sensitive quote not shared-cached');
check(array_keys($response->data[0])===array_keys($item),'no private rule payload exposed');
echo "PASS: discount display price boundaries, currency, range, isolation and failure fallback\n";
