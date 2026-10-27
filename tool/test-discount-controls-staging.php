<?php
/** Staging-only: real FlyCart writes inside an outer rollback transaction. */
if (!defined('WP_CLI') || !WP_CLI || wp_parse_url(home_url(), PHP_URL_HOST)!=='staging.kidiastore.com') throw new RuntimeException('Staging WP-CLI only');
if (!class_exists('MobiShop_Discount_Rules_Admin')) throw new RuntimeException('Install candidate first');
// Convert the component's transaction boundaries into SAVEPOINTs so its real
// SQL/unique-key/revision behavior runs without committing any fixture records.
final class Discount_QA_DB {
    private $db; private $level=0;
    public function __construct($db) { $this->db=$db; }
    public function &__get($key) { return $this->db->$key; }
    public function __set($key,$value) { $this->db->$key=$value; }
    public function __call($name,$args) { return $this->db->$name(...$args); }
    public function query($sql) {
        if ($sql==='START TRANSACTION') return $this->db->query('SAVEPOINT discount_qa_'.(++$this->level));
        if ($sql==='COMMIT') return $this->db->query('RELEASE SAVEPOINT discount_qa_'.($this->level--));
        if ($sql==='ROLLBACK') return $this->db->query('ROLLBACK TO SAVEPOINT discount_qa_'.($this->level--));
        return $this->db->query($sql);
    }
}
global $wpdb;
$real=$wpdb; $created=[]; $requests=[]; $checks=0;
$assert=static function($ok,$message) use (&$checks) { ++$checks; if(!$ok) throw new RuntimeException($message); };
$admin=get_users(['role'=>'administrator','number'=>1,'fields'=>'ID']);
if(!$admin) throw new RuntimeException('No staging administrator');
wp_set_current_user((int)$admin[0]);
foreach ([$real->prefix.'wdr_rules',$real->options,$real->posts,$real->postmeta] as $table) {
    $engine=$real->get_var($real->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s',$table));
    $assert(strtoupper((string)$engine)==='INNODB','Transactional table required');
}
$assert($real->query('START TRANSACTION')!==false,'Begin outer transaction'); $wpdb=new Discount_QA_DB($real);
try {
    $now=current_time('mysql');
    $real->insert($real->posts,['post_author'=>0,'post_date'=>$now,'post_date_gmt'=>gmdate('Y-m-d H:i:s'),'post_modified'=>$now,'post_modified_gmt'=>gmdate('Y-m-d H:i:s'),'post_title'=>'WooMobile isolated controls fixture','post_name'=>'wm-controls-'.wp_generate_uuid4(),'post_status'=>'publish','post_type'=>'product','post_content'=>'','post_excerpt'=>'','comment_status'=>'closed','ping_status'=>'closed','to_ping'=>'','pinged'=>'','post_content_filtered'=>'']);
    $product=(int)$real->insert_id;
    foreach(['_price'=>'100','_regular_price'=>'100','_virtual'=>'yes','_stock_status'=>'instock','_tax_status'=>'none'] as $key=>$value) $real->insert($real->postmeta,['post_id'=>$product,'meta_key'=>$key,'meta_value'=>$value]);
    clean_post_cache($product);
    $base=['operation'=>'create','request_id'=>wp_generate_uuid4(),'title'=>'WM control QA '.wp_generate_uuid4(),'channel'=>'mobile','enabled'=>false,'type'=>'simple','target'=>'products','ids'=>[$product],'discount_kind'=>'percentage','value'=>'10','min_qty'=>'2','free_qty'=>'1','gift_ids'=>[$product],'date_from'=>'','date_to'=>''];
    $run=static function($input) use (&$requests) { $requests[]='mobishop_discount_request_'.hash('sha256',$input['request_id']); return MobiShop_Discount_Rules_Admin::mutate($input); };
    foreach(['simple','cart','bulk','set','bxgx','bxgy','shipping'] as $type) {
        $input=$base; $input['type']=$type; $input['request_id']=wp_generate_uuid4();
        if($type==='shipping') { $input['target']='all'; $input['ids']=[]; }
        $saved=$run($input); $created[]=$saved['id'];
        $assert($saved['ok'] && !$saved['enabled'] && $saved['channel']==='mobile','Create '.$type);
        $again=$run($input); $assert($again['id']===$saved['id'],'Idempotent '.$type);
        $changed=$input; $changed['title'].=' changed';
        try { $run($changed); throw new RuntimeException('Changed retry accepted'); } catch(DomainException $expected) { ++$checks; }
    }
    $id=$created[0]; $table=$real->prefix.'wdr_rules';
    $read=static fn($id) => $real->get_row($real->prepare("SELECT * FROM {$table} WHERE id=%d",$id),ARRAY_A);
    $old=$read($id);
    foreach(['website','all','mobile'] as $channel) {
        $old=$read($id);
        $input=['operation'=>'update','request_id'=>wp_generate_uuid4(),'id'=>$id,'revision'=>MobiShop_Discount_Rules_Admin::revision($old),'channel'=>$channel,'enabled'=>true];
        $result=$run($input); $new=$read($id);
        $assert($result['channel']===$channel && $new['enabled']==1,'Update channel');
        foreach(['filters','conditions','product_adjustments','date_from','date_to','priority','exclusive'] as $field) $assert($old[$field]===$new[$field],'Preserved '.$field);
        $input['request_id']=wp_generate_uuid4();
        try { $run($input); throw new RuntimeException('Stale revision accepted'); } catch(DomainException $expected) { ++$checks; }
    }
    $real->update($table,['used_coupons'=>'["qa-coupon-condition"]','used_limits'=>5],['id'=>$id]);
    $old=$read($id);
    $copy=$run(['operation'=>'clone','request_id'=>wp_generate_uuid4(),'id'=>$id,'revision'=>MobiShop_Discount_Rules_Admin::revision($old),'title'=>$base['title'].' copy','channel'=>'website','enabled'=>false]); $created[]=$copy['id'];
    $assert($copy['id']!==$id && $read($id)===$old,'Clone leaves original unchanged');
    $assert($read($copy['id'])['filters']===$old['filters'],'Clone preserves targeting');
    $assert($read($copy['id'])['used_coupons']===$old['used_coupons'] && (int)$read($copy['id'])['used_limits']===0,'Clone preserves coupon conditions and resets usage only');
    foreach([null,''] as $metadata) {
        $real->update($table,['additional'=>$metadata],['id'=>$copy['id']]);
        $legacy=$read($copy['id']);
        $saved=$run(['operation'=>'update','request_id'=>wp_generate_uuid4(),'id'=>$copy['id'],'revision'=>MobiShop_Discount_Rules_Admin::revision($legacy),'channel'=>'mobile','enabled'=>false]);
        $assert($saved['channel']==='mobile','Legacy empty metadata accepted');
    }
    $kept=MobiShop_Discount_Channel::preserve_channel(['additional'=>'{"condition_relationship":"or"}'],$id);
    $assert(json_decode($kept['additional'],true)['mobishop_channel']==='mobile','FlyCart editor retains channel');
    $assert(json_decode($kept['additional'],true)['condition_relationship']==='or','FlyCart editor retains own changes');
    $bad=$base; $bad['value']='101';
    try { $run($bad); throw new RuntimeException('Invalid percentage accepted'); } catch(InvalidArgumentException $expected) { ++$checks; }
    foreach(['simple','cart','bulk'] as $type) {
        $bad=$base; $bad['type']=$type; $bad['discount_kind']='fixed_set_price';
        try { $run($bad); throw new RuntimeException('Invalid amount kind accepted'); } catch(InvalidArgumentException $expected) { ++$checks; }
    }
    $bad=$base; $bad['title']='<b></b>';
    try { $run($bad); throw new RuntimeException('Empty sanitized title accepted'); } catch(InvalidArgumentException $expected) { ++$checks; }
    $bad=$base; $bad['date_from']='2026-02-30 12:00';
    try { $run($bad); throw new RuntimeException('Invalid date accepted'); } catch(InvalidArgumentException $expected) { ++$checks; }
    wp_set_current_user(0);
    try { $run($base); throw new RuntimeException('Anonymous write accepted'); } catch(DomainException $expected) { ++$checks; }
    $request=new WP_REST_Request('POST','/mobishop/v1/central/discount-rules');
    $request->set_body_params($base); $response=rest_do_request($request);
    $assert(in_array($response->get_status(),[401,403],true),'Anonymous REST denied');
    wp_set_current_user((int)$admin[0]);
    $search='WM pages QA '.wp_generate_uuid4();
    for($i=0;$i<23;$i++) { $row=$old; unset($row['id']); $row['title']=$search.' '.$i; $row['enabled']=0; $real->insert($table,$row); $created[]=(int)$real->insert_id; }
    $a=MobiShop_Discount_Rules_Summary::query(['search'=>$search,'page'=>1]);
    $b=MobiShop_Discount_Rules_Summary::query(['search'=>$search,'page'=>2]);
    $assert($a['total']===23 && $a['pages']===2 && count($a['rows'])===20 && count($b['rows'])===3,'23 offers paginated 20+3');
    $assert(count(array_unique(array_column(array_merge($a['rows'],$b['rows']),'id')))===23,'No missing or duplicated offers');
} finally {
    $wpdb=$real; $assert($real->query('ROLLBACK')!==false,'Rollback succeeded');
    foreach(array_unique($requests) as $key) wp_cache_delete($key,'options');
    if(isset($product)) { clean_post_cache($product); wp_cache_delete($product,'post_meta'); }
    wp_cache_delete('alloptions','options'); wp_cache_delete('wdr_on_sale_list_attention_required','options');
    $remaining=$created ? (int)$real->get_var('SELECT COUNT(*) FROM '.$real->prefix.'wdr_rules WHERE id IN ('.implode(',',array_map('intval',$created)).')') : 0;
    echo 'DISCOUNT_CONTROLS_ROLLBACK '.json_encode(['fixture_rules_remaining'=>$remaining]).PHP_EOL;
    $assert($remaining===0,'No fixture rules remain');
    if(isset($product)) $assert(!$real->get_var($real->prepare("SELECT ID FROM {$real->posts} WHERE ID=%d",$product)),'No fixture product remains');
}
echo 'DISCOUNT_CONTROLS_QA '.json_encode(['checks'=>$checks,'passed'=>true,'types'=>7,'channels'=>3]).PHP_EOL;
