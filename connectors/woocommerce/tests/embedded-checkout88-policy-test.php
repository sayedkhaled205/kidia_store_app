<?php
define('ABSPATH', __DIR__);
require __DIR__.'/../source/api/class-embedded-checkout88.php';
$count=0;
function check88($condition, $label) { global $count; if (!$condition) throw new RuntimeException($label); ++$count; }
$hash=str_repeat('a',64);
$scope=['user_id'=>10,'session_hash'=>$hash,'expires'=>200,'origin'=>'https://merchant.example/shop'];
$sessions=[['hash'=>$hash,'expires'=>300]];
check88(MobiShop_Embedded_Checkout88::valid_scope($scope,$sessions,$scope['origin'],100),'active session');
foreach ([['user_id'=>0],['expires'=>100],['origin'=>'https://other.example'],['session_hash'=>str_repeat('b',64)],['session_hash'=>'']] as $change) check88(!MobiShop_Embedded_Checkout88::valid_scope(array_merge($scope,$change),$sessions,$scope['origin'],100),'reject invalid scope');
check88(!MobiShop_Embedded_Checkout88::valid_scope($scope,[],$scope['origin'],100),'revocation');
check88(!MobiShop_Embedded_Checkout88::valid_scope($scope,[['hash'=>$hash,'expires'=>100]],$scope['origin'],100),'mobile expiry');
foreach (['/shop/checkout/','/shop/checkout','/shop/checkout/order-pay/123/','/shop/checkout/order-received/123/'] as $path) check88(MobiShop_Embedded_Checkout88::allowed_path($path,'/shop/checkout/','/shop/',[]),'checkout path');
foreach (['/wp-admin/','/shop/my-account/','/shop/wp-json/wp/v2/users','/shop/checkout-fake','/shop/checkout/../wp-admin/','/shop/checkout/%2e%2e/wp-admin/','/shop/checkout/\\evil','/'] as $path) check88(!MobiShop_Embedded_Checkout88::allowed_path($path,'/shop/checkout/','/shop/',[]),'blocked path');
check88(MobiShop_Embedded_Checkout88::allowed_path('/shop/','/shop/checkout/','/shop/',['wc-ajax'=>'checkout']),'Woo checkout ajax');
check88(MobiShop_Embedded_Checkout88::allowed_path('/shop/','/shop/checkout/','/shop/',['wc-ajax'=>'kidia_inline_status']),'merchant gateway ajax');
check88(!MobiShop_Embedded_Checkout88::allowed_path('/shop/','/shop/checkout/','/shop/',['wc-ajax'=>['checkout']]),'array rejected');
check88(!MobiShop_Embedded_Checkout88::allowed_path('/shop/','/shop/checkout/','/shop/',['wc-ajax'=>'../../wp-admin']),'path rejected');
check88(!MobiShop_Embedded_Checkout88::allowed_path('/shop/','/shop/','/shop/',[]),'invalid checkout root');
check88(MobiShop_Embedded_Checkout88::allowed_path('/shop/%D8%AF%D9%81%D8%B9/','/shop/دفع/','/shop/',[]),'localized checkout');
check88(!MobiShop_Embedded_Checkout88::allowed_path('/shop/checkout/%252e%252e/wp-admin/','/shop/checkout/','/shop/',[]),'double encoded traversal');
echo "$count embedded checkout policy checks passed\n";
