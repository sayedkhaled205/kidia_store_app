<?php
/** User-source filters must preserve account identity and other admin filters. */
define('ABSPATH', __DIR__);
$GLOBALS['meta'] = [7=>['_mobishop_app_registered_at'=>'now', 'kidia_unverified_phone'=>'+201000000001'],8=>['_mobishop_app_last_login_at'=>'now']];
$GLOBALS['allowed']=true; $GLOBALS['admin']=true; $GLOBALS['pagenow']='users.php';
function __($s,$domain=''){return $s;} function determine_locale(){return 'ar';}
function get_user_meta($id,$key,$single=true){return $GLOBALS['meta'][$id][$key]??'';}
function current_user_can(...$args){return $GLOBALS['allowed'];} function is_admin(){return $GLOBALS['admin'];}
function sanitize_key($s){return preg_replace('/[^a-z0-9_-]/','',strtolower($s));} function wp_unslash($s){return $s;}
function esc_html($s){return htmlspecialchars($s,ENT_QUOTES,'UTF-8');} function esc_attr($s){return esc_html($s);}
function selected($a,$b,$echo=true){return $a===$b?'selected="selected"':'';}
function add_filter(...$a){} function add_action(...$a){}
class Query { public $values=[]; function get($k){return $this->values[$k]??null;} function set($k,$v){$this->values[$k]=$v;} }
require __DIR__.'/../source/includes/class-mobishop-customer-source.php';
$n=0; function check($v,$m){global $n; if(!$v)throw new Exception($m);$n++;}
check(str_contains(MobiShop_Customer_Source::cell('', 'mobishop_app_customer',7),'حساب من التطبيق'),'Registration badge');
check(str_contains(MobiShop_Customer_Source::cell('', 'mobishop_app_customer',8),'دخل من التطبيق'),'Login badge');
check(MobiShop_Customer_Source::cell('prior','other',7)==='prior','Other columns untouched');
$_GET=['mobishop_customer_channel'=>'registered']; $q=new Query; $prior=['relation'=>'OR',['key'=>'customer_group'],['key'=>'other_group']];$q->set('meta_query',$prior);
MobiShop_Customer_Source::filter_query($q);$mq=$q->get('meta_query');
check($mq['relation']==='AND' && $mq[0]===$prior && $mq[1]['key']==='_mobishop_app_registered_at','Preserve existing filter grouping');
$_GET=['mobishop_customer_channel'=>'signed_in'];$q=new Query;MobiShop_Customer_Source::filter_query($q);check($q->get('meta_query')[0]['key']==='_mobishop_app_last_login_at','App login filter');
foreach(['', 'bad', ['registered']] as $input){$_GET=['mobishop_customer_channel'=>$input];$q=new Query;MobiShop_Customer_Source::filter_query($q);check(!$q->values,'Unknown or malformed filter ignored');}
$_GET=['mobishop_customer_channel'=>'registered'];$GLOBALS['allowed']=false;$q=new Query;MobiShop_Customer_Source::filter_query($q);check(!$q->values,'Permission protected');$GLOBALS['allowed']=true;
$GLOBALS['pagenow']='other.php';$q=new Query;MobiShop_Customer_Source::filter_query($q);check(!$q->values,'Only users screen');$GLOBALS['pagenow']='users.php';
ob_start();MobiShop_Customer_Source::filter_control('bottom');check(ob_get_clean()==='','No duplicate controls');
$GLOBALS['meta'][7]['billing_phone']='+201000000003';
ob_start();MobiShop_Customer_Source::contact((object)['ID'=>7]);$html=ob_get_clean();check(str_contains($html,'+201000000001'),'Read-only contact visible');
$GLOBALS['meta'][7]['kidia_login_phone']='+201000000002';ob_start();MobiShop_Customer_Source::contact((object)['ID'=>7]);check(ob_get_clean()==='','Stale contact cannot override verified phone');
check($GLOBALS['meta'][7]['billing_phone']==='+201000000003','Display never changes shipping phone or promotes contact');
echo "Customer-source checks: $n passed.\n";
