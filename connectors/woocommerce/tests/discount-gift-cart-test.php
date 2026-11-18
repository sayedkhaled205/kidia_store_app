<?php
namespace WDRPro\App\Rules {
    class BOGO { public static function isFreeProduct($item) { return !empty($item['gift']); } }
}
namespace {
    define('ABSPATH', __DIR__);
    function add_filter(...$args) {}
    function WC() { return $GLOBALS['wc']; }
    class WP_REST_Response {
        public function __construct(private $data, private $status=200) {}
        public function get_data() { return $this->data; }
        public function set_data($value) { $this->data=$value; }
        public function get_status() { return $this->status; }
    }
    class Request { public function get_route() { return '/wc/store/v1/cart'; } }
    $cart=new class {
        public function get_cart_item($key) { return ['gift'=>$key==='gift']; }
    };
    $wc=(object)['cart'=>$cart];
    $root=getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__.'/../source';
    require $root.'/api/class-discount-rules-prices.php';
    $marker=['attribute'=>'wdr_free_product','value'=>'Free'];
    $size=['attribute'=>'Size','value'=>'Large'];
    $colour=(object)['attribute'=>'Color','value'=>'Blue'];
    $data=['items'=>[
        ['key'=>'gift','quantity'=>1,'quantity_limits'=>(object)['editable'=>true,'minimum'=>1],
            'variation'=>[$marker,$size,$colour,['value'=>'retained']], 'totals'=>['line_total'=>'0']],
        ['key'=>'paid','variation'=>[$marker,$size], 'quantity'=>2,'totals'=>['line_total'=>'200']],
    ],'totals'=>['total_price'=>'200']];
    $response=new WP_REST_Response($data);
    MobiShop_Discount_Rules_Prices::cart_response($response,null,new Request());
    $after=$response->get_data();
    $checks=[
        'gift storage key hidden'=>$after['items'][0]['variation']===[$size,$colour,['value'=>'retained']],
        'gift quantity remains locked'=>$after['items'][0]['quantity_limits']->editable===false,
        'existing minimum preserved'=>$after['items'][0]['quantity_limits']->minimum===1,
        'paid item untouched'=>$after['items'][1]===$data['items'][1],
        'gift quantity untouched'=>$after['items'][0]['quantity']===1,
        'gift price untouched'=>$after['items'][0]['totals']===$data['items'][0]['totals'],
        'cart totals untouched'=>$after['totals']===$data['totals'],
    ];
    foreach($checks as $label=>$passed) if(!$passed) throw new \RuntimeException($label);
    echo 'PASS: '.count($checks)." gift cart display and price invariants\n";
}
