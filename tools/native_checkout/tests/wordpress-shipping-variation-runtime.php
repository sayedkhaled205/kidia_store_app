<?php
/** Real shipping/variation extension of the guarded WP checkout harness.
 * Include from the harness. Never invoke standalone or expose through a web route.
 * All worker calls below occur after the existing cq_worker disposable guards.
 */
declare(strict_types=1);

function cq_sv_seed(): array {
    cq_assert(defined('ABSPATH') && getenv('CI')==='true' && getenv('KIDIA_CHECKOUT_RUNTIME_TEST')==='1'
        && DB_NAME==='kidia_identity_ci' && WP_ENVIRONMENT_TYPE==='local','Shipping fixture inherits disposable guard');
    // Refuse unexpected pre-existing shipping configuration; do not delete it.
    cq_assert(WC_Shipping_Zones::get_zones()===[] && (new WC_Shipping_Zone(0))->get_shipping_methods()===[],
        'Shipping fixture starts with no configured zones or fallback methods');
    update_option('woocommerce_ship_to_countries','');
    update_option('woocommerce_shipping_cost_requires_address','yes');
    update_option('woocommerce_shipping_tax_class','');
    $customer=wp_insert_user(['user_login'=>'ci-checkout-shipping','user_email'=>'checkout-shipping@example.invalid',
        'user_pass'=>'ci-checkout-fixture-only','role'=>'customer']);
    cq_assert(!is_wp_error($customer),'Create isolated shipping fixture customer');
    $attribute=new WC_Product_Attribute(); $attribute->set_id(0); $attribute->set_name('Color');
    $attribute->set_options(['blue','red']); $attribute->set_visible(true); $attribute->set_variation(true);
    $parent=new WC_Product_Variable(); $parent->set_name('Disposable physical color variation');
    $parent->set_status('publish'); $parent->set_virtual(false); $parent->set_manage_stock(false);
    $parent->set_attributes([$attribute]); $parent->save();
    $ids=[];
    foreach([['blue','20',4],['red','25',0]] as [$color,$price,$stock]) {
        $child=new WC_Product_Variation(); $child->set_parent_id($parent->get_id());
        $child->set_status('publish'); $child->set_attributes(['color'=>$color]);
        $child->set_virtual(false); $child->set_weight('1'); $child->set_regular_price($price);
        $child->set_manage_stock(true); $child->set_stock_quantity($stock); $child->set_backorders('no');
        $child->set_stock_status($stock>0?'instock':'outofstock'); $child->save(); $ids[$color]=$child->get_id();
    }
    WC_Product_Variable::sync($parent->get_id()); wc_delete_product_transients($parent->get_id());
    $rates=[];
    foreach(['CA'=>['ca_paid'=>'5','ca_zero'=>'0'],'NY'=>['ny_paid'=>'9']] as $state=>$methods) {
        $zone=new WC_Shipping_Zone(); $zone->set_zone_name('CI '.$state); $zone->set_zone_order(1);
        $zone->add_location('US:'.$state,'state'); $zone->save();
        foreach($methods as $name=>$cost) {
            $instance=$zone->add_shipping_method('flat_rate');
            cq_assert(is_int($instance) && $instance>0,'Create real flat-rate shipping instance');
            update_option('woocommerce_flat_rate_'.$instance.'_settings',[
                'title'=>'CI '.$name,'tax_status'=>'none','cost'=>$cost,'type'=>'order']);
            $rates[$name]='flat_rate:'.$instance;
        }
    }
    WC_Cache_Helper::get_transient_version('shipping',true);
    return ['sv_customer'=>(int)$customer,'sv_parent'=>$parent->get_id(),'sv_blue'=>$ids['blue'],
        'sv_red'=>$ids['red'],'sv_rates'=>$rates];
}

function cq_sv_snapshot(array $seed,int $orderId=0): array {
    // Called only after cq_worker's existing complete environment/source guard.
    $data=['blue'=>(int)(new WC_Product_Variation($seed['sv_blue']))->get_stock_quantity(),
        'red'=>(int)(new WC_Product_Variation($seed['sv_red']))->get_stock_quantity()];
    $orders=wc_get_orders(['customer_id'=>$seed['sv_customer'],'limit'=>-1,'return'=>'ids',
        'status'=>array_unique(array_merge(array_keys(wc_get_order_statuses()),['wc-checkout-draft']))]);
    sort($orders); $data['orders']=$orders;
    if($orderId===0) return $data;
    $order=new WC_Order($orderId);
    cq_assert($order->get_customer_id()===$seed['sv_customer'],'Inspect only synthetic shipping owner order');
    $data['lines']=array_values(array_map(static fn($item)=>[
        'parent'=>$item->get_product_id(),'variation'=>$item->get_variation_id(),'quantity'=>$item->get_quantity()
    ],$order->get_items()));
    $data['shipping']=array_values(array_map(static fn($item)=>[
        'rate_id'=>$item->get_method_id().':'.$item->get_instance_id(),'total'=>$item->get_total()
    ],$order->get_items('shipping')));
    $data['state']=$order->get_shipping_state(); $data['total']=$order->get_total();
    return $data;
}

function cq_sv_rates(array $cart): array {
    $rates=[];
    foreach($cart['shipping_rates']??[] as $package) foreach($package['shipping_rates']??[] as $rate) {
        $rates[$rate['rate_id']]=$rate+['package_id'=>$package['package_id']];
    }
    return $rates;
}
function cq_sv_assert_shipping(array $cart,array $offered,string $selected,string $shipping,string $total,string $label): void {
    $rates=cq_sv_rates($cart); $actual=array_keys($rates); sort($actual); sort($offered);
    $chosen=array_keys(array_filter($rates,static fn($rate)=>$rate['selected']===true));
    cq_assert($actual===$offered && $chosen===[$selected]
        && $cart['totals']['total_shipping']===$shipping && $cart['totals']['total_price']===$total,$label);
}
function cq_sv_address(string $state): array {
    [$city,$postcode]=match($state){'CA'=>['San Francisco','94105'],'NY'=>['New York','10001'],'NV'=>['Las Vegas','89101']};
    return ['first_name'=>'Synthetic','last_name'=>'Fixture','company'=>'','address_1'=>'1 Fixture Street','address_2'=>'',
        'city'=>$city,'state'=>$state,'postcode'=>$postcode,'country'=>'US'];
}

function cq_sv_parent(array $seed): void {
    cq_assert(getenv('CI')==='true' && getenv('KIDIA_CHECKOUT_RUNTIME_TEST')==='1','Shipping parent inherits CI opt-in');
    $login=cq_request('POST','/mobishop/v1/auth/login',['email'=>'checkout-shipping@example.invalid','password'=>'ci-checkout-fixture-only']);
    cq_assert($login['status']===200,'Synthetic shipping customer authenticates'); $session=$login['data']['token'];
    $cart=cq_cart_header(cq_request('GET','/wc/store/v1/cart',[],$session));
    $blue=[['attribute'=>'Color','value'=>'blue']]; $red=[['attribute'=>'Color','value'=>'red']];
    $invalid=[
        ['id'=>$seed['sv_parent'],'quantity'=>1,'variation'=>[]],
        ['id'=>$seed['sv_parent'],'quantity'=>1,'variation'=>[['attribute'=>'Color','value'=>'green']]],
        ['id'=>$seed['sv_blue'],'quantity'=>1,'variation'=>$red],
        ['id'=>$seed['sv_parent'],'quantity'=>1,'variation'=>$red],
    ];
    foreach($invalid as $index=>$body) {
        $response=cq_request('POST','/wc/store/v1/cart/add-item',$body,$session,$cart);
        cq_assert($response['status']>=400 && $response['status']<500,'Reject invalid or sold-out variation case '.($index+1));
        $after=cq_request('GET','/wc/store/v1/cart',[],$session,$cart);
        cq_assert($after['status']===200 && count($after['data']['items'])===0,'Rejected variation leaves real basket empty');
    }
    $added=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['sv_parent'],'quantity'=>2,'variation'=>$blue],$session,$cart);
    cq_assert($added['status']===201 && count($added['data']['items'])===1
        && $added['data']['items'][0]['id']===$seed['sv_blue'] && $added['data']['items'][0]['quantity']===2
        && $added['data']['items'][0]['prices']['price']==='2000' && $added['data']['needs_shipping']===true,
        'Parent and selected attributes resolve to exact physical child and child price');
    $lineKey=$added['data']['items'][0]['key'];
    $excess=cq_request('POST','/wc/store/v1/cart/update-item',['key'=>$lineKey,'quantity'=>5],$session,$cart);
    cq_assert($excess['status']>=400 && $excess['status']<500,'Quantity update cannot exceed selected child stock');
    $after=cq_request('GET','/wc/store/v1/cart',[],$session,$cart);
    cq_assert(($after['data']['items'][0]['quantity']??0)===2,'Failed variation update preserves prior quantity');
    $rates=$seed['sv_rates'];
    $update=static fn(string $state)=>cq_request('POST','/wc/store/v1/cart/update-customer',[
        'shipping_address'=>cq_sv_address($state),'billing_address'=>cq_sv_address($state)+['email'=>'checkout-shipping@example.invalid','phone'=>'2025550100']
    ],$session,$cart);
    $ca=$update('CA'); cq_assert($ca['status']===200,'California address recalculates actual shipping');
    $offered=cq_sv_rates($ca['data']); cq_assert(isset($offered[$rates['ca_paid']],$offered[$rates['ca_zero']]),'Only configured California rates are available');
    $package=$offered[$rates['ca_paid']]['package_id'];
    $selected=cq_request('POST','/wc/store/v1/cart/select-shipping-rate',['package_id'=>$package,'rate_id'=>$rates['ca_paid']],$session,$cart);
    cq_assert($selected['status']===200,'Select actual California paid rate');
    cq_sv_assert_shipping($selected['data'],[$rates['ca_paid'],$rates['ca_zero']],$rates['ca_paid'],'500','4500','Selected California rate and total agree');
    $ny=$update('NY'); cq_assert($ny['status']===200,'Changing address returns new-zone quote');
    cq_sv_assert_shipping($ny['data'],[$rates['ny_paid']],$rates['ny_paid'],'900','4900','New York drops California rate and updates total');
    // Woo can normalize a stale selection and return 200, rather than reject it.
    // Test authoritative state, not an invented requirement for an HTTP error.
    $stale=cq_request('POST','/wc/store/v1/cart/select-shipping-rate',['package_id'=>$package,'rate_id'=>$rates['ca_paid']],$session,$cart);
    cq_assert($stale['status']===200 || ($stale['status']>=400 && $stale['status']<500),'Stale rate request completes without a server error');
    $fresh=cq_request('GET','/wc/store/v1/cart',[],$session,$cart);
    cq_sv_assert_shipping($fresh['data'],[$rates['ny_paid']],$rates['ny_paid'],'900','4900','Old rate cannot survive authoritative new-zone calculation');
    $invalidAddress=cq_sv_address('NY'); $invalidAddress['state']='XX';
    $bad=cq_request('POST','/wc/store/v1/cart/update-customer',['shipping_address'=>$invalidAddress],$session,$cart);
    cq_assert($bad['status']>=400 && $bad['status']<500,'Invalid address state is rejected');
    $fresh=cq_request('GET','/wc/store/v1/cart',[],$session,$cart);
    cq_assert(($fresh['data']['shipping_address']['state']??'')==='NY','Rejected address does not partially replace valid destination');
    $nv=$update('NV'); cq_assert($nv['status']===200 && cq_sv_rates($nv['data'])===[],'Unserved destination offers no stale or invented shipping method');
    $ca=$update('CA'); $offered=cq_sv_rates($ca['data']);
    $zero=cq_request('POST','/wc/store/v1/cart/select-shipping-rate',[
        'package_id'=>$offered[$rates['ca_zero']]['package_id'],'rate_id'=>$rates['ca_zero']],$session,$cart);
    cq_assert($zero['status']===200,'Explicitly choose actual zero-cost physical shipping');
    $discount=cq_request('POST','/wc/store/v1/cart/apply-coupon',['code'=>'ci-checkout-free'],$session,$cart);
    cq_assert($discount['status']===200 && $discount['data']['totals']['total_price']==='0','Actual coupon and zero-cost shipping require no payment');
    $body=cq_checkout_body('checkout-shipping@example.invalid'); $body['shipping_address']=cq_sv_address('CA');
    $checkout=cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,'ci-physical-variation');
    $order=(int)($checkout['data']['order_id']??0); cq_assert($checkout['status']===200 && $order>0,'Real physical variation checkout creates owned order');
    $proof=cq_child(['phase'=>'sv_snapshot','order_id'=>$order]);
    cq_assert($proof['blue']===2 && $proof['red']===0 && $proof['lines']===[['parent'=>$seed['sv_parent'],'variation'=>$seed['sv_blue'],'quantity'=>2]],
        'Order owns exact parent/child/quantity and only purchased child stock decreases');
    cq_assert(count($proof['shipping'])===1 && $proof['shipping'][0]['rate_id']===$rates['ca_zero']
        && (float)$proof['shipping'][0]['total']===0.0 && $proof['state']==='CA' && (float)$proof['total']===0.0,
        'Persisted order uses final address and chosen real zero-cost shipping instance');
    $repeat=cq_request('POST','/wc/store/v1/checkout',$body,$session,$cart,'ci-physical-variation');
    cq_assert($repeat['status']===200 && ($repeat['data']['order']['id']??0)===$order,'Physical order duplicate request recovers same order');
    $again=cq_child(['phase'=>'sv_snapshot','order_id'=>$order]); cq_assert($again===$proof,'Duplicate physical checkout changes neither order nor child stock');
    $excess=cq_request('POST','/wc/store/v1/cart/add-item',['id'=>$seed['sv_parent'],'quantity'=>3,'variation'=>$blue],$session,$cart);
    cq_assert($excess['status']>=400 && $excess['status']<500,'New basket respects remaining child stock after purchase');
    echo 'Real shipping/variation proposal passed its assertions.'.PHP_EOL;
}

