<?php
define('ABSPATH', __DIR__);
$root = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: __DIR__.'/../source';
require $root.'/includes/class-mobishop-order-source98.php';
require $root.'/includes/class-mobishop-customer-source.php';
function __($v,$domain){return $v;}
function sanitize_key($v){return preg_replace('/[^a-z0-9_]/','',$v);}
function wp_unslash($v){return stripslashes($v);}
function check($ok,$label){if(!$ok)throw new RuntimeException($label); echo "PASS $label\n";}
function determine_locale(){return $GLOBALS['locale']??'ar';}
function esc_attr($v){return htmlspecialchars((string)$v,ENT_QUOTES,'UTF-8');}
function wp_kses_post($v){return strip_tags($v,'<span>');}
function esc_html($v){return esc_attr($v);}
function is_admin(){return $GLOBALS['admin']??true;}
function wp_doing_ajax(){return $GLOBALS['ajax']??false;}
function is_multisite(){return $GLOBALS['multisite']??false;}
function get_current_blog_id(){return $GLOBALS['blog_id']??1;}
function update_user_meta($id,$key,$value){$GLOBALS['users'][$id][$key]=$value;}
function add_action($hook,$callback,...$options){$GLOBALS['hooks'][$hook][]=$callback;}
function add_filter($hook,$callback,...$options){add_action($hook,$callback,...$options);}
function current_user_can($cap,...$args){return $GLOBALS['allowed']??true;}
function get_user_meta($id,$key,$single=true){return $GLOBALS['users'][$id][$key]??'';}
function metadata_exists($kind,$id,$key){return array_key_exists($key,$GLOBALS['users'][$id]??[]);}
class WC_Order {function __construct(public string $source=''){} function get_meta($key){return $key==='_mobishop_order_source'?$this->source:'';}}
function wc_get_order($id){return $GLOBALS['orders'][$id]??false;}
class Query {public string $query_where='WHERE 1=1 AND ID > 0'; function __construct(public array $args=[]){} function get($key){return $this->args[$key]??null;} function set($key,$value){$this->args[$key]=$value;}}
function capture($cb){ob_start();$cb();return ob_get_clean();}
$filter=new MobiShop_Order_Source98;
$filter->register();
MobiShop_Customer_Source::register();
check(isset($GLOBALS['hooks']['manage_woocommerce_page_wc-orders_custom_column'], $GLOBALS['hooks']['manage_shop_order_posts_custom_column'], $GLOBALS['hooks']['woocommerce_admin_order_data_after_billing_address'], $GLOBALS['hooks']['woocommerce_email_order_meta_fields']), 'registers HPOS, legacy order columns, details and admin email hooks');
check(!isset($GLOBALS['hooks']['added_user_meta'], $GLOBALS['hooks']['updated_user_meta']), 'single-site stores use existing metadata directly');
$columns=['cb'=>'check','order_number'=>'Order','order_status'=>'Status'];
$got=$filter->order_columns($columns);
check(array_keys($got)===['cb','order_number','mobishop_app_source','order_status'],'source is adjacent to order number; existing columns preserved');
$app=new WC_Order('mobile'); $web=new WC_Order();
$GLOBALS['orders']=[7=>$app];
check(str_contains(capture(fn()=>$filter->order_cell('mobishop_app_source',$app)),'mobishop-app-badge98'),'HPOS mobile order displays badge');
check(str_contains(capture(fn()=>$filter->order_cell('mobishop_app_source',7)),'mobishop-app-badge98'),'legacy order id displays same badge');
check(capture(fn()=>$filter->order_cell('mobishop_app_source',$web))==='&mdash;','unattributed order never claims mobile source');
check(capture(fn()=>$filter->order_cell('order_status',$app))==='','unrelated columns untouched');
check(capture(fn()=>$filter->order_detail($web))==='','website order details unchanged');
$fields=['warehouse'=>['label'=>'Warehouse','value'=>'one']];
check($filter->email_source($fields,false,$app)===$fields,'customer emails unchanged');
check($filter->email_source($fields,true,$web)===$fields,'website admin emails unchanged');
$got=$filter->email_source($fields,true,$app);
check(isset($got['warehouse'])&&$got['mobishop_app_source']['value']==='التطبيق','admin mobile email adds source preserving fields');
$GLOBALS['users']=[1=>['_mobishop_customer'=>'1','_mobishop_customer_origin'=>'website'],2=>['_mobishop_customer_sessions_v1'=>[]],3=>['_mobishop_customer'=>'0'],4=>['_mobishop_customer_origin'=>'mobile']];
check(str_contains(MobiShop_Customer_Source::cell('','mobishop_app_customer',1),'استخدم التطبيق'),'existing website member gets app-usage badge without registration claim');
check(str_contains(MobiShop_Customer_Source::cell('','mobishop_app_customer',2),'mobishop-app-badge98'),'historic app session uses existing Store Data attribution');
check(MobiShop_Customer_Source::cell('','mobishop_app_customer',3)==='—','unmarked user stays unmarked');
check(MobiShop_Customer_Source::cell('existing','email',1)==='existing','other user columns unchanged');
$pagenow='users.php'; $_GET=['mobishop_customer_channel'=>'mobile'];
$existing=['relation'=>'OR',['key'=>'region','value'=>'north'],['key'=>'region','value'=>'south']];
$q=new Query(['meta_query'=>$existing,'role'=>'customer','search'=>'*test*']);MobiShop_Customer_Source::filter_query($q);
check($q->args['meta_query']===$existing&&$q->get('mobishop_app_usage_filter')===true,'user source preserves existing filters without extra joins');
check($q->args['role']==='customer'&&$q->args['search']==='*test*','user role and search preserved');
$wpdb=new class {public string $users='wp_users';public string $usermeta='wp_usermeta';function prepare($sql,...$args){foreach($args as $arg)$sql=preg_replace('/%s/',"'".$arg."'",$sql,1);return $sql;}};
MobiShop_Customer_Source::filter_usage_sql($q);
check(str_starts_with($q->query_where,'WHERE 1=1 AND ID > 0 AND EXISTS')&&str_contains($q->query_where,'mobishop_app_usage.user_id = wp_users.ID'),'usage filter keeps original SQL and correlates by user');
check(str_contains($q->query_where,"meta_value = '1'")&&str_contains($q->query_where,'_mobishop_customer_sessions_v1'),'SQL matches flag and historical-session badge semantics');
$unfiltered=new Query;MobiShop_Customer_Source::filter_usage_sql($unfiltered);check($unfiltered->query_where==='WHERE 1=1 AND ID > 0','ordinary user SQL unchanged');
$_GET=['mobishop_customer_channel'=>'registered'];$registered=new Query(['meta_query'=>$existing]);MobiShop_Customer_Source::filter_query($registered);check($registered->args['meta_query'][0]===$existing&&$registered->args['meta_query'][1]['key']==='_mobishop_app_registered_at','existing registration filter preserved');

foreach(['ajax','allowed','admin','page','value'] as $case){
 $GLOBALS['ajax']=$case==='ajax';$GLOBALS['allowed']=$case!=='allowed';$GLOBALS['admin']=$case!=='admin';$pagenow=$case==='page'?'edit.php':'users.php';$_GET=['mobishop_customer_channel'=>$case==='value'?'unsupported':'mobile'];
 $q=new Query(['meta_query'=>$existing]);MobiShop_Customer_Source::filter_query($q);check($q->args===['meta_query'=>$existing],"no source filtering outside permitted users screen: $case");
}
$GLOBALS['allowed']=false;check(capture(fn()=>MobiShop_Customer_Source::profile_source((object)['ID'=>1]))==='','profile badge respects edit-user permission');
$GLOBALS['locale']='en_US';check(str_contains(MobiShop_Customer_Source::cell('','mobishop_app_customer',1),'Has used the app'),'English locale uses clear usage wording');

$GLOBALS['users'][5]=['_mobishop_app_registered_at'=>'2026-11-01'];$GLOBALS['users'][6]=['_mobishop_app_last_login_at'=>'2026-11-02'];
check(str_contains(MobiShop_Customer_Source::cell('','mobishop_app_customer',5),'App account'),'keeps new registration attribution');
check(str_contains(MobiShop_Customer_Source::cell('','mobishop_app_customer',6),'App sign-in'),'keeps existing member sign-in attribution');

$website = new WC_Order('website');
check(capture(fn() => $filter->order_cell('mobishop_app_source', $website)) === '&mdash;', 'explicit website order has no app badge');
check(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 4) === '—', 'unverified origin string alone does not establish app registration or use');
check(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 77) === '—', 'unmarked website member has no app badge');
$GLOBALS['multisite'] = true;
$GLOBALS['blog_id'] = 12;
MobiShop_Customer_Source::register();
check(in_array(['MobiShop_Customer_Source', 'remember_site_activity'], $GLOBALS['hooks']['added_user_meta'], true) && in_array(['MobiShop_Customer_Source', 'remember_site_activity'], $GLOBALS['hooks']['updated_user_meta'], true), 'network attribution listens to confirmed added or updated metadata');
check(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 5) === '—', 'network-wide legacy registration does not identify a store');
MobiShop_Customer_Source::remember_site_activity(1, 5, '_mobishop_app_last_login_at', '2026-11-05T01:03:50Z');
check(str_contains(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 5), 'App sign-in'), 'new app login is attributed to its own site');
$GLOBALS['blog_id'] = 13;
check(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 5) === '—', 'same network user has no app activity on the other store');
MobiShop_Customer_Source::remember_site_activity(1, 5, '_mobishop_website_customer', '1');
MobiShop_Customer_Source::remember_site_activity(1, 5, '_mobishop_customer', '0');
MobiShop_Customer_Source::remember_site_activity(1, 5, '_mobishop_customer_sessions_v1', []);
check(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 5) === '—', 'website, negative flag and shared session updates never claim current store');
MobiShop_Customer_Source::remember_site_activity(1, 5, '_mobishop_app_registered_at', '2026-11-05T01:04:50Z');
check(str_contains(MobiShop_Customer_Source::cell('', 'mobishop_app_customer', 5), 'App account'), 'confirmed new registration is store-scoped');
$GLOBALS['blog_id'] = 12;
$q = new Query(['mobishop_app_usage_filter'=>true]);
MobiShop_Customer_Source::filter_usage_sql($q);
check(str_contains($q->query_where, '12_mobishop_app_last_login_at') && !str_contains($q->query_where, "'_mobishop_app_registered_at'"), 'network query tests only keys attributed to its own site');
check(!str_contains($q->query_where, "'_mobishop_customer_sessions_v1'"), 'shared sessions cannot qualify a different store in SQL');
