<?php
define('ABSPATH',__DIR__); $options=[];
class WP_REST_Request { public function __construct(public $data){} public function get_param($key){return $this->data[$key]??null;} }
class WP_Error { public function __construct(public $code, public $message='',public $data=[]){} }
function add_action(...$args){}
function add_filter(...$args){}
function sanitize_text_field($s){return trim($s);}
function sanitize_key($s){return $s;}
function rest_sanitize_boolean($s){return (bool)$s;}
function get_current_user_id(){return 0;}
function get_option($key,$default=[]){global $options;return $options[$key]??$default;}
function update_option($key,$value,$autoload=false){global $options;$options[$key]=$value;}
function rest_ensure_response($r){return $r;}
require __DIR__.'/../source/includes/class-mobishop-push-service.php';
function check($ok,$message){if(!$ok)throw new RuntimeException($message);}
$service=new MobiShop_Push_Service();
$register=fn($token,$client,$platform='android')=>$service->register_device(new WP_REST_Request(['token'=>$token,'client_id'=>$client,'platform'=>$platform]));
$a=str_repeat('a',20);$b=str_repeat('b',20);$c=str_repeat('c',20);
$register($a,'phone-one');$register($b,'phone-two');$register($c,'phone-one');
$rows=get_option('mobishop_push_devices_v1');
check(count($rows)===3,'History must remain recoverable');
check(!$rows[hash('sha256',$a)]['enabled']&&$rows[hash('sha256',$c)]['enabled'],'Only previous token for same installation retired');
check($rows[hash('sha256',$b)]['enabled'],'Other phone remains enabled');
MobiShop_Push_Service::retire_expired_token($a);
check(get_option('mobishop_push_devices_v1')[hash('sha256',$c)]['enabled'],'Old request cannot retire renewed token');
MobiShop_Push_Service::retire_expired_token($b);
check(!get_option('mobishop_push_devices_v1')[hash('sha256',$b)]['enabled'],'Explicit expired token disabled');
$register($b,'phone-two');
check(get_option('mobishop_push_devices_v1')[hash('sha256',$b)]['enabled'],'Fresh device registration re-enables delivery');
echo "Device registration rotation, isolation and recovery passed.\n";
