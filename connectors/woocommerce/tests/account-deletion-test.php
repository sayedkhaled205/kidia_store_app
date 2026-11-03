<?php
/** Deterministic deletion/lifecycle tests; never calls a real store. */
require __DIR__ . '/auth-endpoint-contract-test.php';

$GLOBALS['delete_options'] = array();
$GLOBALS['delete_tables'] = array();
$GLOBALS['delete_cron'] = array();
$GLOBALS['delete_orders'] = array();
$GLOBALS['delete_posts'] = array();
$GLOBALS['delete_comments'] = array();
$GLOBALS['delete_flags'] = array();
$GLOBALS['delete_count'] = 0;
function maybe_serialize( $value ) { return is_array( $value ) ? serialize( $value ) : $value; }
function is_ssl() { return empty($GLOBALS['delete_flags']['http']); }
class DeletionRequest extends WP_REST_Request {
  public function get_json_params() { return array('confirmation'=>$this->get_param('confirmation'),'receipt'=>$this->get_param('receipt')); }
}
class QueryOnlyDeletionRequest extends DeletionRequest { public function get_json_params(){return null;} }
function get_current_user_id(){return 7;}
function rest_sanitize_boolean($v){return (bool)$v;}
function rest_ensure_response($v){return new WP_REST_Response($v);}
function is_multisite() { return ! empty( $GLOBALS['delete_flags']['multisite'] ); }
function add_option( $key, $value, $deprecated = '', $autoload = false ) {
	if(isset($GLOBALS['delete_claim_race']) && str_starts_with($key,'mobishop_deletion_receipt_v1_')) { $f=$GLOBALS['delete_claim_race'];unset($GLOBALS['delete_claim_race']);$f($key); }
	if ( isset( $GLOBALS['delete_options'][$key] ) || ! empty( $GLOBALS['delete_flags']['save'] ) ) return false;
	$GLOBALS['delete_options'][$key] = maybe_serialize( $value ); return true;
}
function wp_next_scheduled( $hook, $args ) {
	foreach ( $GLOBALS['delete_cron'] as $t => $hooks ) foreach ( $hooks[$hook] ?? array() as $e ) if ( $args === $e['args'] ) return $t;
	return false;
}
function wp_schedule_single_event( $t, $hook, $args, $wp_error = false ) {
	if ( ! empty( $GLOBALS['delete_flags']['schedule'] ) ) return new WP_Error('test', 'Synthetic schedule failure');
	$GLOBALS['delete_cron'][$t][$hook][md5(serialize($args))] = array('args'=>$args); return true;
}
function wp_schedule_event($t,$recurrence,$hook,$args,$wp_error=false) {return wp_schedule_single_event($t,$hook,$args,$wp_error);}
function wp_clear_scheduled_hook($hook,$args){foreach($GLOBALS['delete_cron'] as $t=>&$hooks)unset($hooks[$hook][md5(serialize($args))]);return 1;}
function _get_cron_array() { return $GLOBALS['delete_cron']; }
function wp_unschedule_event( $t, $hook, $args, $wp_error = false ) {
	if (!empty($GLOBALS['delete_flags']['unschedule'])) return false;
	unset($GLOBALS['delete_cron'][$t][$hook][md5(serialize($args))]); return true;
}
function wc_get_orders( $args ) {
	if (!empty($GLOBALS['delete_flags']['orders'])) throw new RuntimeException('Synthetic order failure');
	return array_slice(array_values(array_filter($GLOBALS['delete_orders'], fn($o) => $o->owner === $args['customer_id'])),0,$args['limit']);
}
function wp_delete_user( $id, $reassign ) {
	if (!empty($GLOBALS['delete_flags']['user-delete'])) return false;
	mobishop_auth_assert($reassign === 0, 'Retain order posts.');
	unset($GLOBALS['mobishop_users'][$id],$GLOBALS['mobishop_user_meta_store'][$id]); $GLOBALS['delete_count']++; return true;
}
function get_post( $id ) { return $GLOBALS['delete_posts'][$id] ?? null; }
function get_comments( $args ) {
	if (!empty($GLOBALS['delete_flags']['comment-read'])) { $GLOBALS['wpdb']->last_error='Synthetic comment failure'; return array(); }
	return array_slice(array_values(array_filter($GLOBALS['delete_comments'],fn($c)=>(int)$c->user_id===$args['user_id'])),0,$args['number']);
}
function get_comment($id){return $GLOBALS['delete_comments'][$id]??null;}
function wp_delete_comment($id,$force){
	if(!empty($GLOBALS['delete_flags']['comment-delete']))return false;
	mobishop_auth_assert($force===true,'Remove owned comment metadata with the comment.');
	unset($GLOBALS['delete_comments'][$id]);return true;
}
function wp_delete_post( $id, $force ) {
	if (!empty($GLOBALS['delete_flags']['coupon'])) return false;
	$old=get_post($id); unset($GLOBALS['delete_posts'][$id]); return $old;
}
class DeletionOrder {
	public $owner; public $meta=array('_mobishop_push_campaign'=>'fixture'); public $total=123;
	function __construct($owner) {$this->owner=$owner;}
	function get_customer_id(){return $this->owner;}
	function set_customer_id($id){$this->owner=$id;}
	function delete_meta_data($key){unset($this->meta[$key]);}
	function save(){return 1;}
}
class DeletionDb extends Mobishop_WPDB_Stub {
	public $options='wp_options'; public $users='wp_users'; public $prefix='wp_'; public $prepared=array();
	function prepare(string $sql,...$args):string {
		$q=parent::prepare($sql,...$args); $this->prepared[$q]=array($sql,$args); return $q;
	}
	function esc_like($v){return addcslashes($v,'_%');}
	function get_var(string $q) {
		$this->last_error=''; [$sql,$a]=$this->prepared[$q]??array($q,array());
		if(str_starts_with($sql,'SELECT option_value')) {
			if(isset($GLOBALS['delete_before_option_read'])) { $f=$GLOBALS['delete_before_option_read'];$f($a[0]); }
			if(!empty($GLOBALS['delete_flags']['receipt-read-once'])&&str_starts_with($a[0],'mobishop_deletion_receipt_v1_')) {unset($GLOBALS['delete_flags']['receipt-read-once']);$this->last_error='Synthetic one-time receipt read failure';return null;}
			if(!empty($GLOBALS['delete_flags']['read'])) {$this->last_error='Synthetic option failure'; return null;}
			return $GLOBALS['delete_options'][$a[0]]??null;
		}
		if(str_starts_with($sql,'SHOW TABLES')) {
			if(!empty($GLOBALS['delete_flags']['table-read'])) {$this->last_error='Synthetic table failure'; return null;}
			$t=stripslashes($a[0]); return isset($GLOBALS['delete_tables'][$t])?$t:null;
		}
		if(str_starts_with($sql,'SELECT active_attempt')) return !empty($GLOBALS['delete_flags']['payment'])?'attempt':null;
		if(str_starts_with($sql,'SELECT ID FROM wp_users')) return isset($GLOBALS['mobishop_users'][$a[0]])?$a[0]:null;
		return parent::get_var($q);
	}
	function get_results(string $q,$output) {
		$this->last_error=''; [$sql,$a]=$this->prepared[$q]??array($q,array());
		if(str_starts_with($sql,'SELECT option_name, option_value')) {
			$rows=array();$options=$GLOBALS['delete_options'];ksort($options);
			foreach($options as $key=>$value) if(str_starts_with($key,'mobishop_deletion_receipt_v1_')&&$key>$a[1]) $rows[]=array('option_name'=>$key,'option_value'=>$value);
			return array_slice($rows,0,20);
		}
		if(str_starts_with($sql,'SELECT id, coupon_id')) {
			if(!empty($GLOBALS['delete_flags']['campaign-read'])) {$this->last_error='Synthetic read failure'; return null;}
			return array_slice(array_values(array_filter($GLOBALS['delete_tables']['wp_mobishop_recovery_campaigns'],fn($r)=>$r['user_id']===$a[0])),0,50);
		}
		return parent::get_results($q,$output);
	}
	function query(string $q) {
		[$sql,$a]=$this->prepared[$q]??array($q,array());
		if(str_starts_with($sql,'UPDATE wp_options')) {
			if(isset($GLOBALS['delete_cas_race'])) { $f=$GLOBALS['delete_cas_race'];unset($GLOBALS['delete_cas_race']);$f(); }
			if(!empty($GLOBALS['delete_flags']['save'])) return false;
			mobishop_auth_assert(str_contains($sql,'BINARY option_value'), 'CAS must be byte exact.');
			if(($GLOBALS['delete_options'][$a[1]]??null)!==$a[2]) return 0;
			$GLOBALS['delete_options'][$a[1]]=$a[0]; return 1;
		}
		if(str_starts_with($sql,'DELETE FROM wp_options')) {
			if(($GLOBALS['delete_options'][$a[0]]??null)!==$a[1]) return 0;
			unset($GLOBALS['delete_options'][$a[0]]);return 1;
		}
		if(preg_match('/DELETE FROM (wp_mobishop_\w+) WHERE (user_id|buyer_hash) = (.+) LIMIT 50/',$q,$m)) {
			if(!empty($GLOBALS['delete_flags']['delete'])) return false;
			$value=trim($m[3],"'");$n=0;
			foreach($GLOBALS['delete_tables'][$m[1]] as $i=>$row) if((string)$row[$m[2]]===$value && $n<50){unset($GLOBALS['delete_tables'][$m[1]][$i]);$n++;}
			return $n;
		}
		return parent::query($q);
	}
	function delete($table,$where,$format) {
		if(!empty($GLOBALS['delete_flags']['delete'])) return false;
		foreach($GLOBALS['delete_tables'][$table] as $i=>$r) if($r['id']===$where['id']&&$r['user_id']===$where['user_id']) {unset($GLOBALS['delete_tables'][$table][$i]);return 1;}
		return 0;
	}
}
$GLOBALS['wpdb']=new DeletionDb();
require dirname(__DIR__).'/source/api/class-customer-account-deletion.php';
$deletion=new MobiShop_Customer_Account_Deletion();
$saved_users=$GLOBALS['mobishop_users'];
function deletion_reset() {
	global $saved_users;
	$GLOBALS['mobishop_users']=$saved_users;
	foreach(array('delete_options','delete_flags','delete_tables','delete_orders','delete_posts','delete_comments','delete_cron','mobishop_transients','mobishop_user_meta_store','mobishop_user_meta_cache') as $key) $GLOBALS[$key]=array();
	$GLOBALS['mobishop_force_meta_write_failure']=false;
	$GLOBALS['delete_count']=0;
	$GLOBALS['wpdb']->last_error='';
}
function deletion_login() {
	$GLOBALS['mobishop_transients']=array();
	return $GLOBALS['endpoint']->login(new DeletionRequest(array('email'=>'customer@example.com','password'=>'correct-password')));
}
function deletion_request($login,$params=array()) {
	return new DeletionRequest(array_merge(array('confirmation'=>'delete-my-account','receipt'=>str_repeat('a',64)),$params),array('X-MobiShop-Session'=>$login->data['token']));
}
function deletion_tick() {
	foreach($GLOBALS['delete_cron'] as $t=>&$hooks) unset($hooks['mobishop_delete_customer_batch']);
	// WordPress reschedules recurring jobs before invoking their callbacks.
	wp_schedule_event(time()+60,'mobishop_deletion_minute','mobishop_delete_customer_batch',array(7));
	MobiShop_Customer_Account_Deletion::run_worker(7);
	mobishop_auth_assert(empty($GLOBALS['mobishop_held_locks']),'Worker must release locks.');
}
function phase() {return maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7'])['phase'];}

deletion_reset();
// The audited feature must not roll out until external erasure is complete.
$gate_login=deletion_login();
mobishop_auth_assert($deletion->availability(deletion_request($gate_login))->data['available']===false,'Unfinished erasure rollout is unavailable by default.');
mobishop_auth_assert(is_wp_error($deletion->request_deletion(deletion_request($gate_login))),'Disabled rollout rejects POST.');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(deletion_request($gate_login))),'Disabled rollout retains login.');
foreach (array(0, 9) as $paused_phase) {
	deletion_reset();
	$paused_job = serialize(array('userId'=>7,'phase'=>$paused_phase,'cursor'=>0,'receiptHash'=>str_repeat('b',64)));
	$GLOBALS['delete_options']['mobishop_account_deletion_v1_7'] = $paused_job;
	$paused_order = new DeletionOrder(7); $GLOBALS['delete_orders'][] = $paused_order;
	deletion_tick();
	mobishop_auth_assert($GLOBALS['delete_options']['mobishop_account_deletion_v1_7'] === $paused_job, 'Disabled rollout cannot advance an already accepted job.');
	mobishop_auth_assert($paused_order->owner === 7 && isset($GLOBALS['mobishop_users'][7]) && $GLOBALS['delete_count'] === 0, 'Disabled worker must retain all customer data.');
	mobishop_auth_assert(wp_next_scheduled('mobishop_delete_customer_batch',array(7)) !== false, 'Disabled worker preserves the pending retry.');
}
define('MOBISHOP_ACCOUNT_DELETION_ENABLED',true); // Synthetic fixture only.
deletion_reset();
mobishop_auth_assert(is_wp_error($deletion->request_deletion(new DeletionRequest(array('confirmation'=>'delete-my-account')))),'Unauthenticated deletion denied.');
foreach(array('confirmation','multisite','schedule','save','revocation','stale','future','revoked-before-lock','promoted-before-lock') as $case) {
	deletion_reset();$login=deletion_login();$params=array();
	if($case==='confirmation')$params['confirmation']='anything';
	if(in_array($case,array('multisite','schedule','save'),true))$GLOBALS['delete_flags'][$case]=true;
	if($case==='revocation')$GLOBALS['mobishop_force_meta_write_failure']=true;
	if($case==='stale'||$case==='future')$GLOBALS['mobishop_user_meta_store'][7]['_mobishop_customer_sessions_v1'][0]['created']=time()+($case==='future'?600:-601);
	if($case==='revoked-before-lock')$GLOBALS['mobishop_before_lock']=function(){$GLOBALS['mobishop_user_meta_store'][7]['_mobishop_customer_sessions_v1']=array();};
	if($case==='promoted-before-lock')$GLOBALS['mobishop_before_lock']=function(){$GLOBALS['mobishop_users'][7]['roles']=array('administrator');};
	$r=$deletion->request_deletion(deletion_request($login,$params));
	mobishop_auth_assert(is_wp_error($r),"Denied unsafe request: $case");
	if($case==='stale'||$case==='future')mobishop_auth_assert($r->get_error_code()==='mobishop_account_deletion_reauth','Fresh proof required.');
	mobishop_auth_assert(empty($GLOBALS['delete_options']),"Rejected request cannot queue deletion: $case");
	mobishop_auth_assert(isset($GLOBALS['mobishop_users'][7]),'Rejected request retains user.');
}

deletion_reset();$login=deletion_login();
$GLOBALS['mobishop_before_lock']=function() use($deletion,$login){
	$r=$deletion->request_deletion(deletion_request($login));
	mobishop_auth_assert($r instanceof WP_REST_Response,'Concurrent deletion accepted.');
};
mobishop_auth_assert(is_wp_error(deletion_login()),'Login already waiting on lock cannot resurrect deleted-account session.');
mobishop_auth_assert(is_wp_error($endpoint->authenticate_route(deletion_request($login))),'Existing token revoked.');
mobishop_auth_assert(is_wp_error(MobiShop_Customer_Account_Deletion::deny_pending_login(get_user_by('id',7))),'Website login blocked while pending.');
mobishop_auth_assert(MobiShop_Customer_Account_Deletion::deny_pending_cookie(7)===0,'Website sessions blocked while pending.');

deletion_reset();$login=deletion_login();
$r=$deletion->request_deletion(deletion_request($login,array('user_id'=>8,'email'=>'manager@example.com')));
mobishop_auth_assert($r->status===202&&$r->data['user_id']===7,'Only authenticated self is selected.');
mobishop_auth_assert(str_contains($r->headers['Cache-Control'],'no-store'),'Deletion response cannot be cached.');
mobishop_auth_assert(is_wp_error($deletion->request_deletion(deletion_request($login))),'Repeat revoked token cannot initiate another deletion.');
for($i=0;$i<51;$i++)$GLOBALS['delete_orders'][]=new DeletionOrder(7);
$other=new DeletionOrder(8);$guest=new DeletionOrder(0);$GLOBALS['delete_orders'][]=$other;$GLOBALS['delete_orders'][]=$guest;
$GLOBALS['delete_tables']['wp_mobishop_events']=array_fill(0,51,array('user_id'=>7));
$GLOBALS['delete_tables']['wp_mobishop_events'][]=array('user_id'=>8);
$GLOBALS['delete_tables']['wp_mobishop_recovery_campaigns']=array(array('id'=>1,'coupon_id'=>20,'user_id'=>7),array('id'=>2,'coupon_id'=>21,'user_id'=>8));
$GLOBALS['delete_posts'][20]=(object)array('post_type'=>'shop_coupon');$GLOBALS['delete_posts'][21]=(object)array('post_type'=>'shop_coupon');
for($i=1;$i<=51;$i++)$GLOBALS['delete_comments'][$i]=(object)array('comment_ID'=>$i,'user_id'=>7);
$GLOBALS['delete_comments'][52]=(object)array('comment_ID'=>52,'user_id'=>8);
$GLOBALS['delete_comments'][53]=(object)array('comment_ID'=>53,'user_id'=>0);
$GLOBALS['delete_options']['mobishop_push_devices_v1']=serialize(array('mine'=>array('user_id'=>7),'other'=>array('user_id'=>8),'guest'=>array('client_id'=>'anonymous')));
$GLOBALS['delete_options']['mobishop_push_automation_log_v1']=serialize(array('x:user:7'=>123,'x:user:17'=>456));
wp_schedule_single_event(time()+100,'mobishop_dispatch_recovery_push',array(1,array('target_user_id'=>7)));
wp_schedule_single_event(time()+100,'mobishop_dispatch_automation_push',array(array('target_user_id'=>7),'x:user:7'));
wp_schedule_single_event(time()+100,'mobishop_dispatch_automation_push',array(array('target_user_id'=>8),'x:user:8'));
deletion_tick();
mobishop_auth_assert(count(array_filter($GLOBALS['delete_orders'],fn($o)=>$o->owner===7))===1,'At most 50 orders per batch.');
for($i=0;$i<40&&MobiShop_Customer_Account_Deletion::is_pending(7);$i++)deletion_tick();
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&$GLOBALS['delete_count']===1,'Account fully deleted once.');
mobishop_auth_assert($other->owner===8&&$guest->owner===0&&isset($other->meta['_mobishop_push_campaign']),'Other customer and guest orders untouched.');
mobishop_auth_assert($GLOBALS['delete_orders'][0]->total===123,'Order accounting data retained.');
mobishop_auth_assert(!get_post(20)&&get_post(21),'Only owned coupon removed, never made public.');
mobishop_auth_assert(array_keys($GLOBALS['delete_comments'])===array(52,53),'Delete owned reviews; retain another customer and anonymous reviews.');
mobishop_auth_assert(count($GLOBALS['delete_tables']['wp_mobishop_events'])===1,'Only owned event records removed.');
$devices=unserialize($GLOBALS['delete_options']['mobishop_push_devices_v1']);
mobishop_auth_assert(!isset($devices['mine'])&&isset($devices['other'],$devices['guest']),'Other devices retained.');
mobishop_auth_assert(unserialize($GLOBALS['delete_options']['mobishop_push_automation_log_v1'])===array('x:user:17'=>456),'Exact automation suffix only.');
deletion_tick();mobishop_auth_assert($GLOBALS['delete_count']===1,'Late watchdog is a no-op.');

foreach(array('read'=>0,'table-read'=>0,'orders'=>0,'delete'=>1,'campaign-read'=>4,'coupon'=>4,'comment-read'=>9,'comment-delete'=>9,'user-delete'=>9,'schedule'=>0) as $flag=>$p) {
	deletion_reset();$r=$deletion->request_deletion(deletion_request(deletion_login()));
	$job=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);$job['phase']=$p;
	$GLOBALS['delete_options']['mobishop_account_deletion_v1_7']=serialize($job);
	$GLOBALS['delete_tables']['wp_mobishop_events']=array(array('user_id'=>7));
	$GLOBALS['delete_tables']['wp_mobishop_recovery_campaigns']=array(array('id'=>1,'coupon_id'=>20,'user_id'=>7));
	$GLOBALS['delete_posts'][20]=(object)array('post_type'=>'shop_coupon');
	if($flag==='comment-delete')$GLOBALS['delete_comments'][1]=(object)array('comment_ID'=>1,'user_id'=>7);
	$GLOBALS['delete_flags'][$flag]=true;deletion_tick();
	mobishop_auth_assert(phase()===$p&&isset($GLOBALS['mobishop_users'][7]),"Failure cannot advance or delete user: $flag");
	if($flag!=='schedule')mobishop_auth_assert((bool)wp_next_scheduled('mobishop_delete_customer_batch',array(7)),"Future retry survives: $flag");
}
// CAS loses a race to a concurrent device registration; retry preserves its data.
deletion_reset();$deletion->request_deletion(deletion_request(deletion_login()));
$job=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);$job['phase']=5;$GLOBALS['delete_options']['mobishop_account_deletion_v1_7']=serialize($job);
$GLOBALS['delete_options']['mobishop_push_devices_v1']=serialize(array('a'=>array('user_id'=>7),'b'=>array('user_id'=>8)));
$GLOBALS['delete_cas_race']=function(){$GLOBALS['delete_options']['mobishop_push_devices_v1']=serialize(array('a'=>array('user_id'=>7),'b'=>array('user_id'=>8),'new'=>array('user_id'=>9)));};
deletion_tick();deletion_tick();deletion_tick();
mobishop_auth_assert(unserialize($GLOBALS['delete_options']['mobishop_push_devices_v1'])===array('b'=>array('user_id'=>8),'new'=>array('user_id'=>9)),'Concurrent unrelated registration preserved.');

// A request resolves its customer before deletion, then reaches the writer late.
$push=new MobiShop_Push_Service();
$late=$push->register_device(new DeletionRequest(array('token'=>str_repeat('x',32),'platform'=>'android','client_id'=>'fixture')));
mobishop_auth_assert(is_wp_error($late),'A pending customer cannot reinsert a device after its cleanup phase.');
MobiShop_Push_Service::append_history(array('id'=>'late-mine','target_user_id'=>7));
MobiShop_Push_Service::append_history(array('id'=>'other-event','target_user_id'=>8));
mobishop_auth_assert(unserialize($GLOBALS['delete_options']['mobishop_push_history'])===array(array('id'=>'other-event','target_user_id'=>8)),'Late personal history is rejected; other customer update survives.');
for($i=0;$i<25&&MobiShop_Customer_Account_Deletion::is_pending(7);$i++)deletion_tick();
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7]),'Deletion completes after race test.');
mobishop_auth_assert(is_wp_error($push->register_device(new DeletionRequest(array('token'=>str_repeat('z',32),'platform'=>'android')))),'A resolved but now deleted customer cannot register again.');
MobiShop_Push_Service::append_history(array('id'=>'after-deletion','target_user_id'=>7));
mobishop_auth_assert(count(unserialize($GLOBALS['delete_options']['mobishop_push_history']))===1,'Removed customer data cannot reappear after job completion.');

// Ledger uncertainty or a pending checkout must fail BEFORE session revocation.
foreach(array('missing-key','active-payment') as $case){
	deletion_reset();$login=deletion_login();
	$GLOBALS['delete_tables']['wp_mobishop_native_checkout50_buyers']=array();
	if($case==='active-payment'){define('MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY',str_repeat('a',64));$GLOBALS['delete_flags']['payment']=true;}
	$r=$deletion->request_deletion(deletion_request($login));
	mobishop_auth_assert(is_wp_error($r),"Unsafe payment state rejects deletion: $case");
	mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(deletion_request($login))),"Customer can resolve checkout: $case");
	mobishop_auth_assert(empty($GLOBALS['delete_options']),"No accepted/pending deletion: $case");
}
function deletion_status($receipt=null){global $deletion;return $deletion->deletion_status(new DeletionRequest(array('receipt'=>$receipt??str_repeat('a',64))));}
function receipt_key(){return 'mobishop_deletion_receipt_v1_'.hash_hmac('sha256',home_url('/').'|wp_options|'.str_repeat('a',64),wp_salt('auth'));}
deletion_reset();$login=deletion_login();
$r=$deletion->request_deletion(deletion_request($login));
mobishop_auth_assert($r->status===202 && deletion_status()->data===array('status'=>'pending'),'Lost acceptance response recovers without a session or customer data.');
mobishop_auth_assert(str_contains(deletion_status()->headers['Cache-Control'],'no-store'),'Receipt response is not cached.');
$job=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);$job['phase']=9;
$GLOBALS['delete_options']['mobishop_account_deletion_v1_7']=serialize($job);
$GLOBALS['delete_flags']['save']=true;deletion_tick();
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&MobiShop_Customer_Account_Deletion::is_pending(7),'Lost completion write keeps retry job after user erasure.');
mobishop_auth_assert(deletion_status()->data['status']==='pending','Incomplete receipt never reports success.');
unset($GLOBALS['delete_flags']['save']);deletion_tick();
mobishop_auth_assert(deletion_status()->data===array('status'=>'completed')&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Completion is durable before job removal.');
mobishop_auth_assert(deletion_status(str_repeat('b',64))->data['status']==='unknown','Unrelated capability learns nothing.');
$GLOBALS['delete_flags']['read']=true;
mobishop_auth_assert(deletion_status()->get_error_data()['status']===503,'Database errors are not a false unknown result.');
unset($GLOBALS['delete_flags']['read']);$GLOBALS['delete_flags']['http']=true;
mobishop_auth_assert(is_wp_error(deletion_status()),'Receipt bearer must use HTTPS.');unset($GLOBALS['delete_flags']['http']);
mobishop_auth_assert($deletion->deletion_status(new QueryOnlyDeletionRequest(array('receipt'=>str_repeat('a',64))))->data['status']==='unknown','Query-string receipt is ignored.');
deletion_reset();$login=deletion_login();
$GLOBALS['delete_claim_race']=function($key){$GLOBALS['delete_options'][$key]=serialize(array('userId'=>8,'status'=>'completed','expires'=>time()-1));};
mobishop_auth_assert(is_wp_error($deletion->request_deletion(deletion_request($login))),'Atomic capability claim cannot overwrite another owner, including expired completion.');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route(deletion_request($login))),'Claim collision preserves session.');
mobishop_auth_assert(maybe_unserialize($GLOBALS['delete_options'][receipt_key()])['userId']===8,'Concurrent owner remains unchanged.');
deletion_reset();$login=deletion_login();$GLOBALS['delete_flags']['schedule']=true;
mobishop_auth_assert(is_wp_error($deletion->request_deletion(deletion_request($login)))&&deletion_status()->data['status']==='unknown','Failed preparation is not accepted and can be retried.');
deletion_reset();
$login=deletion_login();$GLOBALS['delete_flags']['receipt-read-once']=true;
mobishop_auth_assert(is_wp_error($deletion->request_deletion(deletion_request($login))),'Transient receipt verification failure rejects preparation.');
mobishop_auth_assert(empty($GLOBALS['delete_options']),'Failed receipt verification cleans its own atomic claim.');
mobishop_auth_assert($deletion->request_deletion(deletion_request($login))->status===202,'Same receipt can retry after failed preparation.');
$GLOBALS['delete_before_option_read']=function($key){
	if($key!=='mobishop_account_deletion_v1_7')return;
	unset($GLOBALS['delete_before_option_read']);
	$job=maybe_unserialize($GLOBALS['delete_options'][$key]);$job['phase']=9;$GLOBALS['delete_options'][$key]=serialize($job);
	deletion_tick();
};
mobishop_auth_assert(deletion_status()->data['status']==='completed','Completion between receipt and job reads cannot become unknown.');

deletion_reset();
for($i=0;$i<25;$i++) $GLOBALS['delete_options']['mobishop_deletion_receipt_v1_'.sprintf('%064x',$i)]=serialize(array('userId'=>7,'status'=>'completed','expires'=>time()+100));
$expired='mobishop_deletion_receipt_v1_'.str_repeat('f',64);$GLOBALS['delete_options'][$expired]=serialize(array('userId'=>7,'status'=>'completed','expires'=>time()-1));
MobiShop_Customer_Account_Deletion::cleanup_receipts();
mobishop_auth_assert(isset($GLOBALS['delete_options'][$expired]),'Cleanup first batch is bounded.');
MobiShop_Customer_Account_Deletion::cleanup_receipts();
mobishop_auth_assert(!isset($GLOBALS['delete_options'][$expired]),'Keyset cursor reaches expiry past first 20 live receipts.');
fwrite(STDOUT,"Self-deletion ownership, recovery receipts, race protection, completion failure, cleanup, revocation and rollout tests passed.\n");
