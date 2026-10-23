<?php
define('ABSPATH', __DIR__);
$options=[]; $calls=[]; $routes=[]; $admin=true; $site='https://shop.example';
$response=['status'=>200,'body'=>json_encode(['ok'=>true,'firebase_project'=>['status'=>'ready','messaging_ready'=>true]])];
class WP_Error { public function __construct(public $code, public $message='', public $data=[]) {} }
class WP_REST_Response { public function __construct(public $data, public $status=200, public $headers=[]) {} }
class WP_REST_Request { public function __construct(public $body) {} public function get_json_params(){return $this->body;} }
function add_action($hook,$callback,$priority=10){$callback();}
function register_rest_route($namespace,$path,$route){global $routes;$routes[$path]=$route;}
function current_user_can($cap){global $admin;return $admin;}
function get_option($key,$fallback=[]){global $options;return $options[$key]??$fallback;}
function update_option($key,$value,$autoload){global $options;if($autoload!==false)throw new RuntimeException('secret autoloaded');$options[$key]=$value;}
function delete_transient($key){}
function home_url(){global $site;return $site;}
function untrailingslashit($s){return rtrim($s,'/');}
function wp_parse_url($s,$part){return parse_url($s,$part);}
function wp_json_encode($s){return json_encode($s);}
function is_wp_error($v){return $v instanceof WP_Error;}
function wp_remote_request($url,$args){global $calls,$response;$calls[]=[$url,$args];return $response;}
function wp_remote_retrieve_response_code($r){return $r['status'];}
function wp_remote_retrieve_body($r){return $r['body'];}
function check($ok,$label){if(!$ok)throw new RuntimeException($label);echo "PASS $label\n";}
$root=getenv('MOBISHOP_CONNECTOR_TEST_ROOT')?:__DIR__.'/../source';
require $root.'/includes/central/store-notifications.php';
$body=['store_id'=>'11111111-2222-3333-4444-555555555555','token'=>str_repeat('a',80)];
$admin=false;
check(!$routes['/central/notifications-connection']['permission_callback'](),'unprivileged route denied');
check(is_wp_error(MobiShop_Store_Notifications::connect(new WP_REST_Request($body)))&&!$calls&&!$options,'callback independently denies unprivileged writes');
$admin=true;
foreach ([null,['store_id'=>'../../other','token'=>str_repeat('a',80)],array_merge($body,['token'=>"bad\r\nheader"])] as $invalid) {
 check(is_wp_error(MobiShop_Store_Notifications::connect(new WP_REST_Request($invalid)))&&!$calls,'invalid connection rejected before network');
}
$response['status']=302;
check(is_wp_error(MobiShop_Store_Notifications::connect(new WP_REST_Request($body)))&&!$options,'redirect cannot install credentials');
check($calls[0][1]['redirection']===0 && str_starts_with($calls[0][0],'https://api.woomobile.app/v1/stores/'.$body['store_id'].'/notifications/'),'fixed central origin and exact store');
$response['status']=200;$response['body']='{"ok":true,"firebase_project":{"status":"processing"}}';
check(is_wp_error(MobiShop_Store_Notifications::connect(new WP_REST_Request($body)))&&!$options,'unready project cannot be announced ready');
$response['body']='{"ok":true,"firebase_project":{"status":"ready","messaging_ready":true}}';
$result=MobiShop_Store_Notifications::connect(new WP_REST_Request($body));
check($result instanceof WP_REST_Response && $result->data===['ok'=>true,'store_id'=>$body['store_id']],'connection response never exposes token');
check(MobiShop_Store_Notifications::connection()['store_id']===$body['store_id'],'verified connection persisted');
$other=array_merge($body,['store_id'=>'99999999-2222-3333-4444-555555555555']);
check(is_wp_error(MobiShop_Store_Notifications::connect(new WP_REST_Request($other))),'different store cannot replace existing binding');
$count=count($calls);
check(is_wp_error(MobiShop_Store_Notifications::request('../messages'))&&count($calls)===$count,'path traversal rejected');
check(is_wp_error(MobiShop_Store_Notifications::request('messages','GET'))&&count($calls)===$count,'invalid method rejected');
$site='https://cloned.example';
check(MobiShop_Store_Notifications::connection()===[],'copied database cannot reuse another origin binding');
$site='https://shop.example';$response=['status'=>200,'body'=>'{"project_info":{"project_id":"test-project"}}'];
check(is_string(MobiShop_Store_Notifications::request('project/android-config','GET',[],true)),'native config uses verified store transport');
$license=file_get_contents($root.'/includes/class-mobishop-license-manager.php');
check(substr_count($license,'MobiShop_Store_Notifications::request')===2,'both existing Firebase entry points use store transport');
