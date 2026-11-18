<?php
/** Disposable, order-free catalogue fixtures for the explicitly authorized audit. */
if (!defined('WP_CLI') || !WP_CLI || !in_array(wp_parse_url(home_url(), PHP_URL_HOST), ['kidiastore.com','staging.kidiastore.com'], true)) throw new RuntimeException('Audit store only');
global $wpdb;
$run='20261118'; $key='mobishop_discount_audit_'.$run; $mode=$args[0]??'status';
$journal=get_option($key, []);
if ($mode==='create' && !$journal) {
    foreach ([$wpdb->posts,$wpdb->postmeta,$wpdb->options,$wpdb->prefix.'wc_product_meta_lookup',$wpdb->term_relationships] as $table) {
        if (strtoupper((string)$wpdb->get_var($wpdb->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s',$table)))!=='INNODB') throw new RuntimeException('Transactional fixtures required');
    }
    $wpdb->query('START TRANSACTION'); $created=[];
    try {
        $make=static function($name,$price,$type='simple',$parent=0) use($wpdb,$run,&$created) {
            $now=current_time('mysql'); $sku='QA-DISCOUNT-'.$run.'-'.$name;
            $data=['post_author'=>0,'post_date'=>$now,'post_date_gmt'=>gmdate('Y-m-d H:i:s'),'post_modified'=>$now,'post_modified_gmt'=>gmdate('Y-m-d H:i:s'),'post_title'=>$sku,'post_name'=>strtolower($sku),'post_status'=>'publish','post_type'=>$parent?'product_variation':'product','post_parent'=>$parent,'post_content'=>'Temporary discount test product.','post_excerpt'=>'','comment_status'=>'closed','ping_status'=>'closed','to_ping'=>'','pinged'=>'','post_content_filtered'=>''];
            if (!$wpdb->insert($wpdb->posts,$data)) throw new RuntimeException('Fixture insert failed');
            $id=(int)$wpdb->insert_id; $created[]=$id;
            $meta=['_price'=>(string)$price,'_regular_price'=>(string)$price,'_virtual'=>'yes','_stock_status'=>'instock','_manage_stock'=>'no','_tax_status'=>'none','_sku'=>$sku,'_mobishop_discount_audit_run'=>$run];
            if ($parent) $meta['attribute_test-size']=$price===100?'Large':'Small';
            if ($type==='variable') $meta['_product_attributes']=serialize(['test-size'=>['name'=>'Test size','value'=>'Large | Small','position'=>0,'is_visible'=>1,'is_variation'=>1,'is_taxonomy'=>0]]);
            foreach($meta as $k=>$v) if(!$wpdb->insert($wpdb->postmeta,['post_id'=>$id,'meta_key'=>$k,'meta_value'=>$v])) throw new RuntimeException('Fixture metadata failed');
            if (!$parent) {
                $tt=(int)$wpdb->get_var($wpdb->prepare("SELECT tt.term_taxonomy_id FROM {$wpdb->term_taxonomy} tt JOIN {$wpdb->terms} t ON t.term_id=tt.term_id WHERE tt.taxonomy='product_type' AND t.slug=%s",$type));
                if(!$tt || !$wpdb->insert($wpdb->term_relationships,['object_id'=>$id,'term_taxonomy_id'=>$tt,'term_order'=>0])) throw new RuntimeException('Product type missing');
            }
            if(!$wpdb->insert($wpdb->prefix.'wc_product_meta_lookup',['product_id'=>$id,'sku'=>$sku,'virtual'=>1,'downloadable'=>0,'min_price'=>$price,'max_price'=>$type==='variable'?100:$price,'onsale'=>0,'stock_status'=>'instock','tax_status'=>'none','tax_class'=>''])) throw new RuntimeException('Lookup insert failed');
            clean_post_cache($id); return $id;
        };
        $journal=['run'=>$run,'simple'=>$make('A',100),'gift'=>$make('B',60)];
        $journal['variable']=$make('VARIABLE',60,'variable');
        $journal['large']=$make('LARGE',100,'variation',$journal['variable']);
        $journal['small']=$make('SMALL',60,'variation',$journal['variable']);
        $journal['products']=$created; $journal['rules']=[]; $journal['coupons']=[];
        if(!add_option($key,$journal,'','no')) throw new RuntimeException('Audit journal already exists');
        $wpdb->query('COMMIT');
    } catch(Throwable $e) { $wpdb->query('ROLLBACK'); foreach($created as $id) clean_post_cache($id); throw $e; }
}
if($mode==='track-rule') {
    $id=(int)($args[1]??0); $row=$wpdb->get_row($wpdb->prepare("SELECT id,title FROM {$wpdb->prefix}wdr_rules WHERE id=%d",$id),ARRAY_A);
    if(!$journal || !$row || !str_starts_with($row['title'],'QA-DISCOUNT-'.$run.'-')) throw new RuntimeException('Not an audit rule');
    $journal['rules']=array_values(array_unique(array_merge($journal['rules'],[$id]))); update_option($key,$journal,false);
}
if($mode==='cleanup' && $journal) {
    foreach($journal['products'] as $id) {
        if(get_post_meta($id,'_mobishop_discount_audit_run',true)!==$run) throw new RuntimeException('Fixture ownership changed');
    }
    foreach($journal['rules'] as $id) {
        $title=$wpdb->get_var($wpdb->prepare("SELECT title FROM {$wpdb->prefix}wdr_rules WHERE id=%d",$id));
        if(!str_starts_with((string)$title,'QA-DISCOUNT-'.$run.'-')) throw new RuntimeException('Rule ownership changed');
    }
    // Recoverable trash/soft-delete only; existing catalogue and campaigns stay intact.
    foreach($journal['rules'] as $id) $wpdb->update($wpdb->prefix.'wdr_rules',['enabled'=>0,'deleted'=>1],['id'=>$id]);
    foreach($journal['products'] as $id) {
        wp_trash_post($id); clean_post_cache($id);
        if(get_post_status($id)!=='trash') throw new RuntimeException('Fixture was not trashed');
    }
    $journal['cleaned']=gmdate('c'); update_option($key,$journal,false);
}
echo 'AUDIT_FIXTURES '.wp_json_encode($journal).PHP_EOL;
