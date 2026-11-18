<?php
/** Real Store API pagination/filter integration; transactional staging fixtures only. */
if (!defined('WP_CLI') || !WP_CLI || wp_parse_url(home_url(), PHP_URL_HOST) !== 'staging.kidiastore.com') throw new RuntimeException('Staging WP-CLI only');
if (!class_exists('MobiShop_Discount_Rules_Catalogue_Query')) throw new RuntimeException('Candidate query module required');
$case = $args[0] ?? 'simple';
if (!in_array($case, ['simple','zero','bulk','website','expired','future','unknown'], true)) throw new RuntimeException('Unknown case');
global $wpdb;
$created=[]; $checks=[];
foreach ([$wpdb->posts,$wpdb->postmeta,$wpdb->prefix.'wc_product_meta_lookup',$wpdb->term_relationships,$wpdb->options,$wpdb->prefix.'wdr_rules'] as $table) {
    if (strtoupper((string)$wpdb->get_var($wpdb->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s',$table))) !== 'INNODB') throw new RuntimeException('Transactional fixtures required');
}
if($wpdb->query('START TRANSACTION')===false) throw new RuntimeException('Transaction could not start');
$rule_fixture_id=0;
try {
    $make=static function($name,$price,$type='simple',$parent=0,$sale=null,$stock='instock') use($wpdb,&$created) {
        $now=current_time('mysql');
        $wpdb->insert($wpdb->posts,['post_author'=>0,'post_date'=>$now,'post_date_gmt'=>gmdate('Y-m-d H:i:s'),'post_modified'=>$now,'post_modified_gmt'=>gmdate('Y-m-d H:i:s'),'post_title'=>'QA-SALEQUERY-'.$name,'post_name'=>'qa-salequery-'.wp_generate_uuid4(),'post_status'=>'publish','post_type'=>$parent?'product_variation':'product','post_parent'=>$parent,'post_content'=>'','post_excerpt'=>'','comment_status'=>'closed','ping_status'=>'closed','to_ping'=>'','pinged'=>'','post_content_filtered'=>'']);
        $id=(int)$wpdb->insert_id; if(!$id) throw new RuntimeException('Fixture insert failed'); $created[]=$id;
        $meta=['_price'=>(string)($sale??$price),'_regular_price'=>(string)$price,'_sale_price'=>$sale===null?'':(string)$sale,'_virtual'=>'yes','_stock_status'=>$stock,'_manage_stock'=>'no','_tax_status'=>'none'];
        if($parent) $meta['attribute_test-size']=$price===100?'Large':'Small';
        if($type==='variable') $meta['_product_attributes']=serialize(['test-size'=>['name'=>'Test size','value'=>'Large | Small','position'=>0,'is_visible'=>1,'is_variation'=>1,'is_taxonomy'=>0]]);
        foreach($meta as $k=>$v) $wpdb->insert($wpdb->postmeta,['post_id'=>$id,'meta_key'=>$k,'meta_value'=>$v]);
        if(!$parent) {
            $tt=(int)$wpdb->get_var($wpdb->prepare("SELECT tt.term_taxonomy_id FROM {$wpdb->term_taxonomy} tt JOIN {$wpdb->terms} t ON t.term_id=tt.term_id WHERE tt.taxonomy='product_type' AND t.slug=%s",$type));
            if(!$tt) throw new RuntimeException('Missing product type');
            $wpdb->insert($wpdb->term_relationships,['object_id'=>$id,'term_taxonomy_id'=>$tt,'term_order'=>0]);
        }
        $wpdb->insert($wpdb->prefix.'wc_product_meta_lookup',['product_id'=>$id,'virtual'=>1,'downloadable'=>0,'min_price'=>$sale??$price,'max_price'=>$type==='variable'?100:($sale??$price),'onsale'=>$sale===null?0:1,'stock_status'=>$stock,'tax_status'=>'none','tax_class'=>'']);
        clean_post_cache($id); return $id;
    };
    $a=$make('A',100); $b=$make('STORED',100,'simple',0,80); $plain=$make('PLAIN',60);
    $variable=$make('VARIABLE',60,'variable'); $large=$make('LARGE',100,'variation',$variable); $small=$make('SMALL',60,'variation',$variable);
    $sold=$make('OUTOFSTOCK',100,'simple',0,null,'outofstock');
    $fixture_ids=[$a,$b,$plain,$variable];
    // Prevent the global Woo sale transient being populated with transactional IDs.
    $stored_filter=static fn()=>[$b]; add_filter('pre_transient_wc_products_onsale',$stored_filter);
    $manager=new \Wdr\App\Controllers\ManageDiscount();
    $row=(object)['id'=>-8104,'enabled'=>1,'deleted'=>0,'exclusive'=>0,'priority'=>1,'title'=>'Isolated sale query QA','apply_to'=>'','filters'=>json_encode(['1'=>['type'=>'products','method'=>'in_list','value'=>[$a,$variable,$sold]]]),'conditions'=>'[]','additional'=>json_encode(['mobishop_channel'=>$case==='website'?'website':'mobile']),'date_from'=>null,'date_to'=>null,'usage_limits'=>0,'used_limits'=>0,'discount_type'=>'wdr_simple_discount','product_adjustments'=>json_encode(['type'=>'percentage','value'=>$case==='zero'?'100':'10','apply_as_cart_rule'=>'0']),'cart_adjustments'=>'[]','bulk_adjustments'=>'[]','set_adjustments'=>'[]','buy_x_get_x_adjustments'=>'[]','buy_x_get_y_adjustments'=>'[]'];
    if($case==='bulk') { $row->discount_type='wdr_bulk_discount'; $row->product_adjustments='[]'; $row->bulk_adjustments=json_encode(['operator'=>'product','apply_as_cart_rule'=>'0','ranges'=>['1'=>['from'=>'3','to'=>'','type'=>'percentage','value'=>'10','label'=>'']]]); }
    if($case==='expired') $row->date_to=current_time('timestamp')-3600;
    if($case==='future') $row->date_from=current_time('timestamp')+3600;
    if($case==='unknown') $row->filters=json_encode(['1'=>['type'=>'qa_unknown_filter','method'=>'in_list','value'=>[]]]);
    // Stage-only transactional isolation lets FlyCart's real SQL enforce dates and enabled state.
    // Other connections continue seeing the committed original rules; every write rolls back.
    $wpdb->update($wpdb->prefix.'wdr_rules',['enabled'=>0],['enabled'=>1]);
    $row_data=(array)$row; unset($row_data['id']);
    if(!$wpdb->insert($wpdb->prefix.'wdr_rules',$row_data)) throw new RuntimeException('Rule fixture insert failed');
    $rule_fixture_id=(int)$wpdb->insert_id;
    \Wdr\App\Controllers\ManageDiscount::$available_rules=[];
    \Wdr\App\Models\DBTable::getRules(null,null,null,false);
    $rules=$manager->getDiscountRules();
    \Wdr\App\Controllers\ManageDiscount::$calculator=new \Wdr\App\Controllers\DiscountCalculator($rules);
    $_SERVER['HTTP_X_MOBISHOP_CHANNEL']='mobile'; $_SERVER['REQUEST_URI']='/wp-json/wc/store/v1/products';
    $server=rest_get_server();
    $request=static function(array $params,bool $mobile=true) use($server) {
        $r=new WP_REST_Request('GET','/wc/store/v1/products');
        foreach($params as $key=>$value) $r->set_param($key,$value);
        if($mobile) $r->set_header('X-MobiShop-Channel','mobile');
        $start=microtime(true); $response=$server->dispatch($r);
        $response=apply_filters('rest_post_dispatch',rest_ensure_response($response),$server,$r);
        return [$response,microtime(true)-$start];
    };
    $assert=static function($ok,$message) use(&$checks) { if(!$ok) throw new RuntimeException($message); $checks[]=$message; };
    // The unfiltered actual display response is the ground truth, including variable semantics.
    [$base]=$request(['include'=>$fixture_ids,'orderby'=>'include','per_page'=>10]);
    $assert($base->get_status()===200,'Unfiltered status');
    $display=$base->get_data(); $on=[]; $off=[];
    foreach($display as $item) { if($item['on_sale']) $on[]=(int)$item['id']; else $off[]=(int)$item['id']; }
    $assert(count($on)+count($off)===4,'Baseline includes all four fixtures');
    if(in_array($case,['simple','zero'],true)) $assert(in_array($a,$on,true)&&in_array($variable,$on,true)&&in_array($b,$on,true)&&in_array($plain,$off,true),'Real dynamic/stored/plain membership');
    if(in_array($case,['bulk','website','expired','future'],true)) $assert($on===[$b],'Ineligible quantity/channel/date does not discount fixtures');
    $timings=[];
    foreach([true,false] as $sale) {
        $expected=$sale?$on:$off;
        [$res,$elapsed]=$request(['include'=>$fixture_ids,'orderby'=>'include','per_page'=>10,'on_sale'=>$sale]);
        $timings[$sale?'sale':'not_sale']=$elapsed;
        $assert($res->get_status()===200,'Filtered status '.(int)$sale);
        $ids=array_map('intval',array_column($res->get_data(),'id'));
        $assert($ids===$expected,'Exact include/order/membership '.(int)$sale.' '.json_encode($ids));
        $headers=$res->get_headers();
        $assert((int)($headers['X-WP-Total']??-1)===count($expected),'Exact total '.(int)$sale);
        [$excluded]=$request(['include'=>$fixture_ids,'exclude'=>[$a,$b],'orderby'=>'include','per_page'=>10,'on_sale'=>$sale]);
        $assert(array_map('intval',array_column($excluded->get_data(),'id'))===array_values(array_diff($expected,[$a,$b])),'Include/exclude intersection '.(int)$sale);
        [$all_excluded]=$request(['include'=>$fixture_ids,'exclude'=>$fixture_ids,'on_sale'=>$sale]);
        $assert($all_excluded->get_status()===200 && $all_excluded->get_data()===[],'Fully excluded include cannot broaden '.(int)$sale);
        [$none]=$request(['search'=>'QA-NONEXISTENT-SALEQUERY','on_sale'=>$sale]);
        $assert($none->get_status()===200 && $none->get_data()===[],'Empty search stays empty '.(int)$sale);
        if(count($expected)>1) {
            [$page]=$request(['include'=>$fixture_ids,'orderby'=>'include','per_page'=>1,'page'=>2,'on_sale'=>$sale]);
            $assert(array_map('intval',array_column($page->get_data(),'id'))===[$expected[1]],'Pagination second result '.(int)$sale);
            $assert((int)$page->get_headers()['X-WP-Total']===count($expected),'Pagination total '.(int)$sale);
            [$bad]=$request(['include'=>$fixture_ids,'orderby'=>'include','per_page'=>1,'page'=>count($expected)+1,'on_sale'=>$sale]);
            $assert($bad->get_status()===400,'Out-of-range page '.(int)$sale);
        }
    }
    // Filter hooks must be removed: a normal follow-up retains every fixture.
    [$after]=$request(['include'=>$fixture_ids,'orderby'=>'include','per_page'=>10]);
    $assert(array_map('intval',array_column($after->get_data(),'id'))===$fixture_ids,'No leaked filter after requests');
    if(in_array($case,['simple','zero'],true)) {
        [$stock]=$request(['include'=>[$a,$sold],'stock_status'=>['instock'],'on_sale'=>true]);
        $assert($stock->get_status()===200 && array_map('intval',array_column($stock->get_data(),'id'))===[$a],'In-stock filter preserved');
        [$sold_response]=$request(['include'=>[$a,$sold],'stock_status'=>['outofstock'],'on_sale'=>true]);
        $assert($sold_response->get_status()===200 && array_map('intval',array_column($sold_response->get_data(),'id'))===[$sold],'Explicit out-of-stock filter preserved');
        [$children]=$request(['include'=>[$large,$small],'type'=>'variation','orderby'=>'include','on_sale'=>true]);
        $assert($children->get_status()===200 && array_map('intval',array_column($children->get_data(),'id'))===[$large,$small],'Parent rule includes directly queried variations');
        [$slug]=$request(['slug'=>get_post($small)->post_name,'on_sale'=>true]);
        $assert($slug->get_status()===200 && array_map('intval',array_column($slug->get_data(),'id'))===[$small],'Variation slug uses parent rule');
    }
    $result=['case'=>$case,'checks'=>count($checks),'on'=>$on,'off'=>$off,'seconds'=>$timings,'passed'=>true];
} finally {
    if(isset($stored_filter)) remove_filter('pre_transient_wc_products_onsale',$stored_filter);
    if(WC()->session) remove_action('shutdown',[WC()->session,'save_data'],20);
    if($wpdb->query('ROLLBACK')===false) throw new RuntimeException('Rollback failed');
    foreach($created as $id) {
        clean_post_cache($id); wp_cache_delete($id,'post_meta');
        delete_transient('wc_var_prices_'.$id); delete_transient('wc_product_children_'.$id);
        foreach(['wc_var_prices_','wc_product_children_'] as $prefix) {
            wp_cache_delete('_transient_'.$prefix.$id,'options');
            wp_cache_delete('_transient_timeout_'.$prefix.$id,'options');
        }
        WC_Cache_Helper::invalidate_cache_group('product_'.$id);
        if(false!==get_transient('wc_var_prices_'.$id)||false!==get_transient('wc_product_children_'.$id)) throw new RuntimeException('Fixture transient remains');
    }
    $remaining=(int)$wpdb->get_var('SELECT COUNT(*) FROM '.$wpdb->posts.' WHERE ID IN ('.implode(',',array_map('intval',$created?:[0])).')');
    if($remaining) throw new RuntimeException('Fixture rows remain');
    if($rule_fixture_id && $wpdb->get_var($wpdb->prepare("SELECT id FROM {$wpdb->prefix}wdr_rules WHERE id=%d",$rule_fixture_id))) throw new RuntimeException('Rule fixture remains');
}
echo 'SALE_QUERY_QA '.wp_json_encode($result).PHP_EOL;
