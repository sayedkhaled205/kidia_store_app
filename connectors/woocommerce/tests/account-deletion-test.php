<?php
/** Deterministic deletion/lifecycle tests; never calls a real store. */
require __DIR__ . '/auth-endpoint-contract-test.php';

$GLOBALS['delete_options'] = array();
$GLOBALS['delete_tables'] = array();
$GLOBALS['delete_cron'] = array();
$GLOBALS['delete_orders'] = array();
$GLOBALS['delete_posts'] = array();
$GLOBALS['delete_flags'] = array();
$GLOBALS['delete_count'] = 0;
function maybe_serialize( $value ) { return is_array( $value ) ? serialize( $value ) : $value; }
function get_current_user_id(){return 7;}
function rest_sanitize_boolean($v){return (bool)$v;}
function rest_ensure_response($v){return new WP_REST_Response($v);}
function is_multisite() { return ! empty( $GLOBALS['delete_flags']['multisite'] ); }
function add_option( $key, $value, $deprecated = '', $autoload = false ) {
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
	foreach(array('delete_options','delete_flags','delete_tables','delete_orders','delete_posts','delete_cron','mobishop_transients','mobishop_user_meta_store','mobishop_user_meta_cache') as $key) $GLOBALS[$key]=array();
	$GLOBALS['mobishop_force_meta_write_failure']=false;
	$GLOBALS['delete_count']=0;
	$GLOBALS['wpdb']->last_error='';
}
function deletion_login() {
	$GLOBALS['mobishop_transients']=array();
	return $GLOBALS['endpoint']->login(new WP_REST_Request(array('email'=>'customer@example.com','password'=>'correct-password')));
}
function deletion_request($login,$params=array()) {
	return new WP_REST_Request(array_merge(array('confirmation'=>'delete-my-account'),$params),array('X-MobiShop-Session'=>$login->data['token']));
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
mobishop_auth_assert(is_wp_error($deletion->request_deletion(new WP_REST_Request(array('confirmation'=>'delete-my-account')))),'Unauthenticated deletion denied.');
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
mobishop_auth_assert(count($GLOBALS['delete_tables']['wp_mobishop_events'])===1,'Only owned event records removed.');
$devices=unserialize($GLOBALS['delete_options']['mobishop_push_devices_v1']);
mobishop_auth_assert(!isset($devices['mine'])&&isset($devices['other'],$devices['guest']),'Other devices retained.');
mobishop_auth_assert(unserialize($GLOBALS['delete_options']['mobishop_push_automation_log_v1'])===array('x:user:17'=>456),'Exact automation suffix only.');
deletion_tick();mobishop_auth_assert($GLOBALS['delete_count']===1,'Late watchdog is a no-op.');

foreach(array('read'=>0,'table-read'=>0,'orders'=>0,'delete'=>1,'campaign-read'=>4,'coupon'=>4,'user-delete'=>9,'schedule'=>0) as $flag=>$p) {
	deletion_reset();$r=$deletion->request_deletion(deletion_request(deletion_login()));
	$job=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);$job['phase']=$p;
	$GLOBALS['delete_options']['mobishop_account_deletion_v1_7']=serialize($job);
	$GLOBALS['delete_tables']['wp_mobishop_events']=array(array('user_id'=>7));
	$GLOBALS['delete_tables']['wp_mobishop_recovery_campaigns']=array(array('id'=>1,'coupon_id'=>20,'user_id'=>7));
	$GLOBALS['delete_posts'][20]=(object)array('post_type'=>'shop_coupon');
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
$late=$push->register_device(new WP_REST_Request(array('token'=>str_repeat('x',32),'platform'=>'android','client_id'=>'fixture')));
mobishop_auth_assert(is_wp_error($late),'A pending customer cannot reinsert a device after its cleanup phase.');
MobiShop_Push_Service::append_history(array('id'=>'late-mine','target_user_id'=>7));
MobiShop_Push_Service::append_history(array('id'=>'other-event','target_user_id'=>8));
mobishop_auth_assert(unserialize($GLOBALS['delete_options']['mobishop_push_history'])===array(array('id'=>'other-event','target_user_id'=>8)),'Late personal history is rejected; other customer update survives.');
for($i=0;$i<25&&MobiShop_Customer_Account_Deletion::is_pending(7);$i++)deletion_tick();
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7]),'Deletion completes after race test.');
mobishop_auth_assert(is_wp_error($push->register_device(new WP_REST_Request(array('token'=>str_repeat('z',32),'platform'=>'android')))),'A resolved but now deleted customer cannot register again.');
MobiShop_Push_Service::append_history(array('id'=>'after-deletion','target_user_id'=>7));
mobishop_auth_assert(count(unserialize($GLOBALS['delete_options']['mobishop_push_history']))===1,'Removed customer data cannot reappear after job completion.');

fwrite(STDOUT,"Self-deletion ownership, reauthentication, revocation race, bounded cleanup and failure tests passed.\n");
