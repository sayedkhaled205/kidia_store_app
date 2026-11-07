<?php
/** Synthetic WP raw metadata/serialization fixtures; no WordPress or network. */
define('ABSPATH',__DIR__);
$GLOBALS['meta']=array(); $checks=0;
function get_user_meta($id) { return $GLOBALS['meta'][$id] ?? array(); }
function maybe_unserialize($v) { if (!is_string($v)) return $v; $r=@unserialize($v,array('allowed_classes'=>false)); return $r === false && $v !== 'b:0;' ? $v : $r; }
function maybe_serialize($v) { return is_array($v) || is_object($v) || (is_string($v) && ($v === 'a:0:{}' || $v === 'b:0;')) ? serialize($v) : $v; }
function check($ok,$label) { global $checks; ++$checks; if(!$ok) throw new RuntimeException($label); }
function rejects($fn,$label) { try {$fn();} catch(RuntimeException $e) {check(true,$label); return;} check(false,$label); }
class FakeWpdb {
 public $usermeta='wp_usermeta', $last_error='', $args=array(), $sql='';
 public function prepare($sql,...$args) {$this->sql=$sql;$this->args=$args;return $sql;}
 public function get_col($sql) {
  if(!empty($GLOBALS['db_throw'])) throw new RuntimeException('fixture DB exception');
  if($this->last_error !== '') return null;
  [$id,$phoneKey,$projectKey,$project,$uidKey,$uid]=$this->args;
  $out=array(); foreach($GLOBALS['meta'] as $owner=>$meta) {
   if($owner===$id) continue;
   $phone=array_key_exists($phoneKey,$meta);
   $apple=in_array($project,$meta[$projectKey]??array(),true)&&in_array($uid,$meta[$uidKey]??array(),true);
   if($phone||$apple)$out[]=$owner;
  } return $out;
 }
}
$wpdb=new FakeWpdb();
require __DIR__.'/../connector/class-customer-identity-links.php';
$class='MobiShop_Customer_Identity_Links';
$identity=array('project'=>'test-project','uid'=>'uid-one');
$key='_mobishop_phone_firebase_identity_'.hash('sha256','test-project|uid-one');
check($class::inventory(7)===array(),'Empty exact user inventory');
$GLOBALS['meta'][7]=array($key=>array(serialize($identity)));
$link=$class::inventory(7)[0];
check($link===array('project'=>'test-project','uid'=>'uid-one','provider'=>'phone','key'=>$key),'Real PHP serialized phone row');
$GLOBALS['meta'][8]=$GLOBALS['meta'][7];
check($class::shared(7,$link),'Other exact phone identity protects deletion');
check(str_contains($wpdb->sql,'SELECT DISTINCT')&&!str_contains($wpdb->sql,'LIMIT')&&substr_count($wpdb->sql,'BINARY')===10,'SQL exact binary comparisons and no truncation');
$GLOBALS['meta'][8]=array($key=>array(serialize(array('uid'=>'uid-one','project'=>'test-project'))));
check($class::shared(7,$link),'Reordered serialized identity still protects shared owner');
$GLOBALS['meta'][8]=array($key=>array('corrupt'));
check($class::shared(7,$link),'Corrupt matching identity key fails closed');
unset($GLOBALS['meta'][8]); check(!$class::shared(7,$link),'Own row does not count as shared');
$GLOBALS['meta'][8]=array('_mobishop_firebase_project'=>array('test-project'),'_mobishop_firebase_uid'=>array('uid-one'));
check($class::shared(7,$link),'Apple owner protects phone identity even with pending/partial metadata');
$GLOBALS['meta'][8]['_mobishop_firebase_uid']=array('UID-one'); check(!$class::shared(7,$link),'UID matching is case sensitive');
$GLOBALS['meta'][7]+=$GLOBALS['meta'][8];
rejects(fn()=>$class::inventory(7),'Partial Apple identity blocks inventory');
$GLOBALS['meta'][7]['_mobishop_firebase_uid']=array('uid-one');
$GLOBALS['meta'][7]['_mobishop_apple_subject']=array('apple-subject');
$links=$class::inventory(7); check(count($links)===1&&$links[0]['provider']==='apple','Deduplicate pair preferring Apple');
$second=array('project'=>'test-project','uid'=>'uid-two'); $secondKey='_mobishop_phone_firebase_identity_'.hash('sha256','test-project|uid-two');
$GLOBALS['meta'][7][$secondKey]=array(serialize($second)); check(count($class::inventory(7))===2,'Multiple UIDs preserved');
$good=$GLOBALS['meta'][7];
foreach(array('',str_repeat('u',129),"bad\nuid","bad\0uid","\xC3\x28") as $bad) {
 $GLOBALS['meta'][7]=$good; $GLOBALS['meta'][7][$key]=array(serialize(array('project'=>'test-project','uid'=>$bad)));
 rejects(fn()=>$class::inventory(7),'Malformed identity blocks inventory');
}
$GLOBALS['meta'][7]=$good; $GLOBALS['meta'][7][$key]=array(serialize($second)); rejects(fn()=>$class::inventory(7),'Forged phone key denied');
$GLOBALS['meta'][7]=$good; $GLOBALS['meta'][7]['_mobishop_apple_subject']=array(''); rejects(fn()=>$class::inventory(7),'Empty Apple subject denied');
$serializedUid='a:0:{}';
$GLOBALS['meta'][8]=array('_mobishop_firebase_project'=>array('test-project'),'_mobishop_firebase_uid'=>array(serialize($serializedUid)),'_mobishop_apple_subject'=>array('subject'));
$serializedLink=$class::inventory(8)[0];
check($serializedLink['uid']===$serializedUid && $class::shared(7,$serializedLink),'WP double-serialized scalar UID matches its actual stored representation');
$GLOBALS['db_throw']=true; check($class::shared(7,$link),'DB exception fails closed'); unset($GLOBALS['db_throw']);
$wpdb->last_error='fixture database failure'; check($class::shared(7,$link),'DB error fails closed');
check($class::shared(7,array('project'=>'bad project','uid'=>'uid-one','provider'=>'phone')),'Invalid shared query input fails closed');
echo "Identity links: $checks checks passed.\n";