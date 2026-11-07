<?php
/** Real Links + Guard + Stage; only DB transport/cache and remote provider are synthetic. */
define('MOBISHOP_IDENTITY_LINKS_FIXTURES_ONLY',true);
require __DIR__.'/customer-identity-links-test.php';
require __DIR__.'/../connector/class-customer-identity-links.php';
class SnapshotDb extends FakeWpdb {
 public $options='wp_options', $option_rows=array(), $locks=array(), $inventory_reads=0;
 public function get_var($sql) {
  if(str_contains($sql,'GET_LOCK')){$this->locks[$this->args[0]]=true;return '1';}
  if(str_contains($sql,'SELECT option_value'))return $this->option_rows[$this->args[0]]??null;
  throw new RuntimeException('Unexpected snapshot DB read');
 }
 public function query($sql) {
  if(str_contains($sql,'RELEASE_LOCK')){unset($this->locks[$this->args[0]]);return 1;}
  throw new RuntimeException('Unexpected snapshot DB mutation');
 }
 public function get_results($sql,$format) {
  $owner='mobishop_id_'.md5($this->options.'|mobishop_identity_guard_v1_owner_7');
  check(isset($this->locks[$owner]),'Fresh SQL inventory runs inside actual owner guard');
  $this->inventory_reads++;return parent::get_results($sql,$format);
 }
}
function wp_cache_delete($key,$group) {} // Cache intentionally stays stale.
function add_option($key,$value,$unused='',$autoload=false) {
 global $wpdb;if(isset($wpdb->option_rows[$key]))return false;
 $wpdb->option_rows[$key]=maybe_serialize($value);return true;
}
final class MobiShop_Customer_Identity_Client {
 public static $lookups=array();
 public static function capabilities(){return array('available'=>true,'project_id'=>'test-project');}
 public static function lookup($project,$uid){
  global $wpdb;
  $owner='mobishop_id_'.md5($wpdb->options.'|mobishop_identity_guard_v1_owner_7');
  $identity='mobishop_id_'.md5($wpdb->options.'|mobishop_identity_guard_v1_uid_'.hash('sha256',$project.'|'.$uid));
  check(isset($wpdb->locks[$owner],$wpdb->locks[$identity]),'Real stage provider snapshot holds actual owner and exact UID locks');
  self::$lookups[]=$uid;return array('status'=>'present','created_at'=>'12345');
 }
}
require __DIR__.'/../connector/class-customer-identity-guard.php';
require __DIR__.'/../connector/class-customer-identity-erasure-stage.php';
$wpdb=new SnapshotDb();$GLOBALS['meta']=array();$GLOBALS['stale_cache']=array();
$first=array('project'=>'test-project','uid'=>'first-uid');$added=array('project'=>'test-project','uid'=>'committed-new-uid');
$phoneKey=static fn($link)=>'_mobishop_phone_firebase_identity_'.hash('sha256',$link['project'].'|'.$link['uid']);
$GLOBALS['meta'][7]=array($phoneKey($first)=>array(serialize($first)));
$GLOBALS['stale_cache'][7]=$GLOBALS['meta'][7];
MobiShop_Customer_Identity_Guard::writer(7,$added,static function()use($added,$phoneKey){
 $GLOBALS['meta'][7][$phoneKey($added)]=array(serialize($added));
});
check(count(get_user_meta(7))===1,'Concurrent committed writer leaves primed WP cache stale');
$receipt=str_repeat('a',64);
$frozen=MobiShop_Customer_Identity_Guard::with_owner(7,static function()use($receipt){
 $links=MobiShop_Customer_Identity_Links::inventory(7);
 return MobiShop_Customer_Identity_Guard::with_links($links,static function()use($links,$receipt){
  $state=MobiShop_Customer_Identity_Erasure_Stage::prepare(7);
  check(array_column($state['entries'],'uid')===array('first-uid','committed-new-uid'),'Actual stage snapshot contains newly committed identity despite stale WP cache');
  MobiShop_Customer_Identity_Guard::reserve(7,$receipt,$links,time()+600);
  check(add_option('fixture_frozen_intent',array('userId'=>7,'identityStage'=>$state,'inventory'=>$links)),'Freeze snapshot after actual reservation succeeds');
  return $state;
 });
});
$saved=maybe_unserialize($wpdb->option_rows['fixture_frozen_intent']);
check($saved['identityStage']===$frozen&&count($saved['inventory'])===2,'Persisted frozen snapshot includes both committed UIDs');
check(MobiShop_Customer_Identity_Client::$lookups===array('first-uid','committed-new-uid'),'Stage obtains provider generation for every frozen UID');
check($wpdb->inventory_reads===2&&$wpdb->locks===array(),'Capture and stage both use fresh SQL and release all short locks');
$blocked=false;try{MobiShop_Customer_Identity_Guard::writer(9,$added,static fn()=>true);}catch(RuntimeException $error){$blocked=true;}
check($blocked,'Real reservation protects newly captured UID against another owner');
echo "Fresh inventory guarded stage: $checks checks passed.\n";