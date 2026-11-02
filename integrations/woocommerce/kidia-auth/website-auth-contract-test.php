<?php
/** Fixtures only: exercise the real website class without loading WordPress hooks. */
define('HOUR_IN_SECONDS',3600);define('MINUTE_IN_SECONDS',60);define('ABSPATH',__DIR__);
class Redirected extends Exception {}
$GLOBALS['meta']=[];$GLOBALS['users']=[];$GLOBALS['creates']=0;$GLOBALS['current']=0;
function wp_doing_ajax(){return true;}
function sanitize_key($s){return preg_replace('/[^a-z0-9_-]/','',strtolower($s));}
function absint($s){return abs((int)$s);}function sanitize_text_field($s){return strip_tags($s);}function sanitize_email($s){return $s;}function is_email($s){return filter_var($s,FILTER_VALIDATE_EMAIL)!==false;}function wp_unslash($s){return $s;}
function get_option($k){return 1;}function get_post_type($id){return 'page';}function get_post_status($id){return 'publish';}function get_permalink($id=0){return 'https://example.test/login-register/';}
function add_query_arg($args,$url){return $url.'?'.http_build_query($args);}function wp_safe_redirect($url){throw new Redirected($url);}function wc_add_notice(...$a){}
function is_wp_error($s){return false;}function wc_create_new_customer($email,$login,$password){$GLOBALS['creates']++;$GLOBALS['users'][50]=(object)['ID'=>50,'user_email'=>$email,'display_name'=>'','password'=>$password];return 50;}
function wp_update_user($data){$id=$data['ID'];foreach($data as $k=>$v)$GLOBALS['users'][$id]->$k=$v;return $id;}
function wp_set_current_user($id){$GLOBALS['current']=$id;}function wp_set_auth_cookie(...$a){}function is_ssl(){return true;}function is_user_logged_in(){return $GLOBALS['current']>0;}function get_current_user_id(){return $GLOBALS['current'];}
function current_user_can(...$a){return false;}function user_can($user,$cap){return !empty($user->caps[$cap]);}
function get_user_meta($id,$key,$single=true){return $GLOBALS['meta'][$id][$key]??'';}function update_user_meta($id,$key,$value){$GLOBALS['meta'][$id][$key]=$value;}function delete_user_meta($id,$key){unset($GLOBALS['meta'][$id][$key]);}
function get_user_by($kind,$value){foreach($GLOBALS['users'] as $id=>$user){if(($kind==='id' && $id===$value)||($kind==='email'&&$user->user_email===$value))return $user;}return false;}
function get_users($args){if(isset($args['meta_key']))return []; $result=[];foreach($GLOBALS['users'] as $id=>$user){foreach($args['meta_query'] as $clause){if(is_array($clause)&&in_array($GLOBALS['meta'][$id][$clause['key']]??'', $clause['value'],true)){$result[]=$id;break;}}}return array_slice($result,0,$args['number']);}
function esc_attr($s){return htmlspecialchars($s,ENT_QUOTES,'UTF-8');}function esc_html($s){return esc_attr($s);}function wp_verify_nonce($a,$b){return $a==='fixture';}
class Kidia_Firebase_OTP_265 {static function matching_users($phone){return [];}static function eligible_customer($u,$p){return false;}}
$source=file_get_contents(__DIR__.'/website/kidia-login-page.php');$offset=strpos($source,'final class Kidia_Store_Custom_Login_Page_V020');eval(substr($source,$offset));
$instance=Kidia_Store_Custom_Login_Page_V020::instance();$checks=0;function check($v,$label){global $checks;if(!$v)throw new Exception($label);$checks++;}
function invoke($method,...$args){global $instance;$m=new ReflectionMethod($instance,$method);return $m->invoke($instance,...$args);}
foreach([['','password-fixture','password-fixture'],['Name','short','short'],['Name','password-fixture','different']] as [$name,$password,$confirm]){try{invoke('register_email_customer','fixture@example.test',$password,$name,$confirm);}catch(Redirected $r){}check($GLOBALS['creates']===0,'Invalid profile never creates account');}
try{invoke('register_email_customer','fixture@example.test','password-fixture','Fixture Name','password-fixture');}catch(Redirected $r){}
check($GLOBALS['creates']===1,'Valid email creates one account');check($GLOBALS['users'][50]->display_name==='Fixture Name','Chosen name saved');check(get_user_meta(50,'kidia_profile_details_collected',true)==='1','Credentials not requested twice');
$GLOBALS['meta'][50]['kidia_unverified_phone']='+201000000001';$GLOBALS['meta'][50]['billing_phone']='01000000001';$GLOBALS['meta'][50]['fme_billing_phone']='+201000000001';$before=$GLOBALS['meta'];ob_start();$instance->render_account_login_phone();$html=ob_get_clean();check(str_contains($html,'01000000001')&&str_contains($html,'readonly'),'Unverified phone is visible read-only');check($before===$GLOBALS['meta'],'Profile display never promotes phone');
$_SERVER['REQUEST_METHOD']='POST';$_POST=['action'=>'fme_lwp_process_otp_validation','phone_number'=>'+201000000001'];$before=$GLOBALS['meta'];$instance->prepare_phone_account_match();check($GLOBALS['meta']===$before,'OTP migration never promotes a shipping/contact-only number');
$c=invoke('phone_password_candidates','01000000001');check(count($c)===1&&$c[0]->ID===50,'Password candidate sees unverified contact');
$GLOBALS['meta'][50]['kidia_login_phone']='+201000000002';check(invoke('phone_password_candidates','01000000001')===[],'Stale contact cannot override another primary identity');unset($GLOBALS['meta'][50]['kidia_login_phone']);
$GLOBALS['users'][50]->caps=['edit_users'=>true];check(invoke('phone_password_candidates','01000000001')===[],'Privileged contact excluded');$GLOBALS['users'][50]->caps=[];
$_POST=['kidia_phone_setup_nonce'=>'fixture','kidia_setup_phone'=>'01000000001','kidia_phone_new_password'=>'password-fixture','kidia_phone_new_password_confirm'=>'password-fixture','kidia_phone_username'=>'Fixture Name'];$before=$GLOBALS['meta'];try{invoke('handle_phone_account_setup');}catch(Redirected $r){}check($before===$GLOBALS['meta'],'Non-OTP POST cannot bypass shared phone completion');
echo "Website auth PHP: $checks checks passed.\n";
