<?php
/** Protocol orchestration fixtures; signed Apple proof has its separate real-JWT contract test. */
require __DIR__.'/account-deletion-test.php';
require __DIR__.'/../source/api/class-customer-identity-guard.php';
class MobiShop_Customer_Identity_Links {
 public static function inventory($id) { return $GLOBALS['intent_links'][$id]??array(); }
 public static function shared($id,$link) { return !empty($GLOBALS['intent_shared']); }
}
class MobiShop_Customer_Identity_Client {
 public static function capabilities(){if(!empty($GLOBALS['intent_outage']))throw new RuntimeException('fixture outage');return array('available'=>true,'project_id'=>'fixture-project');}
 public static function lookup($project,$uid){if(!empty($GLOBALS['intent_outage']))throw new RuntimeException('fixture outage');return !empty($GLOBALS['intent_absent'])?array('status'=>'absent'):array('status'=>'present','created_at'=>'12345');}
 public static function erase($project,$uid,$created){if(!empty($GLOBALS['intent_outage']))throw new RuntimeException('fixture outage');$GLOBALS['intent_advanced']=true;return array('status'=>'absent');}
}
require __DIR__.'/../source/api/class-customer-identity-erasure-stage.php';
class MobiShop_Native_Customer_Auth_Endpoint {
 public function __construct(...$args){}
 public function validate_deletion_apple_proof($request,$id) {return $request->get_param('id_token')==='fixture-valid-proof'&&$id===7&&empty($GLOBALS['intent_shared']);}
}
class IntentRequest extends DeletionRequest {
 public function get_json_params(){return array('confirmation'=>$this->get_param('confirmation'),'receipt'=>$this->get_param('receipt'),'apple_revoked'=>$this->get_param('apple_revoked'));}
}
function intent_request($login,$params=array()) {return new IntentRequest(array_merge(array('confirmation'=>'delete-my-account','receipt'=>str_repeat('d',64),'platform'=>'ios'),$params),array('X-MobiShop-Session'=>$login->data['token']));}
function intent_reset() {deletion_reset();foreach(array('intent_links','intent_shared','intent_absent','intent_outage','intent_advanced')as $key)unset($GLOBALS[$key]);}
intent_reset(); $login=deletion_login();$request=intent_request($login,array('user_id'=>8));
$r=$deletion->prepare_deletion($request);
mobishop_auth_assert($r->data===array('status'=>'prepared','intent_id'=>$r->data['intent_id'],'user_id'=>7,'apple_revocation_required'=>false)&&preg_match('/^[a-f0-9]{64}$/D',$r->data['intent_id'])===1,'Prepare binds authenticated account, never body user_id');
mobishop_auth_assert(!MobiShop_Customer_Account_Deletion::is_pending(7)&&!is_wp_error($endpoint->authenticate_route($request)),'Prepare keeps sessions and does not mark deletion pending');
$restart=new MobiShop_Customer_Account_Deletion();
mobishop_auth_assert($restart->prepare_deletion($request)->data===$r->data,'Prepared intent survives process restart');
mobishop_auth_assert($restart->deletion_status($request)->data['status']==='prepared','Receipt recovers known prepared state');
$intentKey='';foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_'))$intentKey=$key;
$savedIntent=$GLOBALS['delete_options'][$intentKey];$tampered=unserialize($savedIntent);$tampered['userId']=8;$GLOBALS['delete_options'][$intentKey]=serialize($tampered);
mobishop_auth_assert(is_wp_error($restart->prepare_deletion($request))&&is_wp_error($restart->finalize_deletion($request)),'Receipt cross-owner reuse denied');
$GLOBALS['delete_options'][$intentKey]=$savedIntent;
$tampered=unserialize($savedIntent);$tampered['expires']=time()-1;$GLOBALS['delete_options'][$intentKey]=serialize($tampered);
mobishop_auth_assert(is_wp_error($restart->finalize_deletion($request)),'Expired intent denied even if session remains fresh');
$GLOBALS['delete_options'][$intentKey]=$savedIntent;
$otherSession=deletion_login();
mobishop_auth_assert(is_wp_error($restart->finalize_deletion(intent_request($otherSession))),'Different session cannot finalize captured intent');
mobishop_auth_assert($restart->finalize_deletion($request)->status===202,'Non-Apple intent accepted only by original fresh session');
mobishop_auth_assert(!isset($GLOBALS['delete_options'][$intentKey]),'Accepted intent snapshot removed after durable job capture');
$job=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);
mobishop_auth_assert(isset($job['identityStage'])&&$job['identityStage']['user_id']===7,'Accepted job durably contains captured identity stage');
deletion_tick();mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Identity stage completes and the empty account finishes deletion in one bounded callback');
intent_reset();$login=deletion_login();$GLOBALS['intent_outage']=true;
mobishop_auth_assert(is_wp_error($deletion->prepare_deletion(intent_request($login)))&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Identity snapshot outage retains account and session');
unset($GLOBALS['intent_outage']);
$apple=array('project'=>'fixture-project','uid'=>'fixture-apple-uid','provider'=>'apple','key'=>'_mobishop_apple_identity');
$GLOBALS['intent_links'][7]=array($apple);$request=intent_request($login,array('apple_revoked'=>true));
mobishop_auth_assert($deletion->prepare_deletion($request)->data['apple_revocation_required']===true,'Apple identity captured before client SDK');
mobishop_auth_assert(is_wp_error($deletion->finalize_deletion($request)),'Forged Apple acknowledgement without proof denied');
mobishop_auth_assert(is_wp_error($deletion->approve_apple(intent_request($login,array('id_token'=>'wrong-proof')))),'Wrong proof never approves intent');
$proof=intent_request($login,array('id_token'=>'fixture-valid-proof'));
mobishop_auth_assert($deletion->approve_apple($proof)->data['approved']===true,'Correct captured account proof approves without revocation');
mobishop_auth_assert(!is_wp_error($endpoint->authenticate_route($request)),'Proof approval keeps session');
mobishop_auth_assert(is_wp_error($deletion->finalize_deletion($request)),'Client acknowledgement and proof cannot replace authoritative Firebase absence');
$GLOBALS['intent_absent']=true;$GLOBALS['intent_shared']=true;
mobishop_auth_assert(is_wp_error($deletion->finalize_deletion($request)),'Shared identity blocks Apple finalization');
unset($GLOBALS['intent_shared']);
$GLOBALS['intent_links'][7][0]['uid']='changed-uid';
mobishop_auth_assert(is_wp_error($deletion->finalize_deletion($request)),'Changed captured identity blocks finalization');
$GLOBALS['intent_links'][7]=array($apple);
mobishop_auth_assert($deletion->finalize_deletion($request)->status===202,'Proof, acknowledgement and exact authoritative absence permit pending request');
$accepted=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);
mobishop_auth_assert($accepted['identityStage']['entries'][0]['apple_revoked']===true,'Revocation acknowledgement reaches snapshot only after proof and authoritative absence');
intent_reset();$login=deletion_login();
$GLOBALS['intent_links'][7]=array(array('project'=>'fixture-project','uid'=>'phone-one','provider'=>'phone','key'=>'fixture-one'),array('project'=>'fixture-project','uid'=>'phone-two','provider'=>'phone','key'=>'fixture-two'));
$request=intent_request($login);$deletion->prepare_deletion($request);$deletion->finalize_deletion($request);
$GLOBALS['intent_outage']=true;deletion_tick();
mobishop_auth_assert(phase()===0&&isset($GLOBALS['mobishop_users'][7]),'Provider outage cannot erase WP data');
unset($GLOBALS['intent_outage']);deletion_tick();
$partial=maybe_unserialize($GLOBALS['delete_options']['mobishop_account_deletion_v1_7']);
mobishop_auth_assert($partial['identityStage']['cursor']===1&&phase()===0,'One identity step persisted without advancing merchant phase');
deletion_tick();mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Merchant phase opens and the empty account completes in the same bounded callback once identity steps persist');
intent_reset();$login=deletion_login();$request=intent_request($login);$deletion->prepare_deletion($request);
foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_')){$expiredIntentKey=$key;$expiredIntent=unserialize($GLOBALS['delete_options'][$key]);$expiredIntent['expires']=time()-1;$GLOBALS['delete_options'][$key]=serialize($expiredIntent);}
MobiShop_Customer_Account_Deletion::cleanup_receipts();
mobishop_auth_assert(!isset($GLOBALS['delete_options'][$expiredIntentKey]),'Expired pre-SDK intent snapshot is cleaned without pending job');
// Approved pre-SDK evidence outlives the short session-bound finalize window.
intent_reset();$login=deletion_login();$GLOBALS['intent_links'][7]=array($apple);
$original=intent_request($login,array('id_token'=>'fixture-valid-proof','apple_revoked'=>true));
$deletion->prepare_deletion($original);$deletion->approve_apple($original);
foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_'))$approvedKey=$key;
$approved=unserialize($GLOBALS['delete_options'][$approvedKey]);$approvedAt=$approved['approvedAt'];$approved['expires']=time()-1;$GLOBALS['delete_options'][$approvedKey]=serialize($approved);
MobiShop_Customer_Account_Deletion::cleanup_receipts();
mobishop_auth_assert(isset($GLOBALS['delete_options'][$approvedKey]),'Cleanup preserves approved snapshot after SDK/finalize window expires');
$guardRows=array_filter(array_keys($GLOBALS['delete_options']),static fn($key)=>str_starts_with($key,'mobishop_identity_guard_v1_'));
mobishop_auth_assert(count($guardRows)===2,'Approved snapshot retains both owner and UID reservation across cleanup');
mobishop_auth_assert($deletion->deletion_status($original)->data['status']==='prepared','Receipt still recovers approved known state after short expiry');
$freshLogin=deletion_login();$resume=intent_request($freshLogin,array('apple_revoked'=>true));
$restart=new MobiShop_Customer_Account_Deletion();
mobishop_auth_assert($restart->prepare_deletion($resume)->data['apple_revocation_required']===true,'Fresh same-owner merchant authentication securely rebinds approved intent');
$rebound=unserialize($GLOBALS['delete_options'][$approvedKey]);
mobishop_auth_assert($rebound['appleApproved']===true&&$rebound['approvedAt']===$approvedAt&&$rebound['identityStage']===$approved['identityStage'],'Rebind preserves original approval and snapshot');
mobishop_auth_assert($rebound['intentId']===$approved['intentId'],'Rebind preserves frozen intent ID for SDK checkpoint');
mobishop_auth_assert(is_wp_error($restart->finalize_deletion($original)),'Rebind revokes old intent binding even when old merchant token remains valid');
$GLOBALS['intent_outage']=true;
mobishop_auth_assert(is_wp_error($restart->finalize_deletion($resume))&&isset($GLOBALS['delete_options'][$approvedKey]),'Finalize lookup outage preserves approved evidence for retry');
unset($GLOBALS['intent_outage']);$GLOBALS['intent_absent']=true;
mobishop_auth_assert($restart->finalize_deletion($resume)->status===202,'After outage, same-owner reauth resumes without impossible replacement Firebase proof');
// SDK capability cannot be withdrawn by server wall-clock expiry: never release its snapshot.
intent_reset();$login=deletion_login();$GLOBALS['intent_links'][7]=array($apple);$request=intent_request($login,array('id_token'=>'fixture-valid-proof'));
$deletion->prepare_deletion($request);$deletion->approve_apple($request);
foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_'))$approvedKey=$key;
$aged=unserialize($GLOBALS['delete_options'][$approvedKey]);$aged['approvedAt']=time()-40*86400;$aged['expires']=time()-1;$GLOBALS['delete_options'][$approvedKey]=serialize($aged);
MobiShop_Customer_Account_Deletion::cleanup_receipts();
mobishop_auth_assert(isset($GLOBALS['delete_options'][$approvedKey]),'Even aged approved SDK capability retains durable reconciliation snapshot');
$blocked=false;try{MobiShop_Customer_Identity_Guard::writer(9,$apple,static fn()=>true);}catch(RuntimeException $e){$blocked=true;}
mobishop_auth_assert($blocked,'Approved old SDK capability still reserves exact UID against another owner');
mobishop_auth_assert(is_wp_error($deletion->finalize_deletion($request)),'Expired finalize permission is rejected without deleting approved snapshot');
$fresh=intent_request(deletion_login(),array('apple_revoked'=>true));
mobishop_auth_assert($deletion->prepare_deletion($fresh)->data['status']==='prepared','Fresh same-owner reauthentication resumes aged approved intent');
$agedRebound=unserialize($GLOBALS['delete_options'][$approvedKey]);
mobishop_auth_assert($agedRebound['approvedAt']===$aged['approvedAt']&&$agedRebound['identityStage']===$aged['identityStage'],'Reauthentication preserves aged SDK evidence instead of releasing/reusing it');
mobishop_auth_assert($agedRebound['intentId']===$aged['intentId'],'Stable opaque intent ID survives aged same-owner reauthentication');
$GLOBALS['intent_absent']=true;
mobishop_auth_assert($deletion->finalize_deletion($fresh)->status===202,'Aged approved intent reconciles only after fresh same-owner permission and authoritative absence');
// Pre-SDK rotation is allowed only through fresh authentication for that exact owner.
intent_reset();$oldLogin=deletion_login();$oldRequest=intent_request($oldLogin);$deletion->prepare_deletion($oldRequest);
$newLogin=deletion_login();$newRequest=intent_request($newLogin);
mobishop_auth_assert($deletion->prepare_deletion($newRequest)->data['user_id']===7,'Fresh same-owner session can rotate an unapproved pre-SDK intent');
mobishop_auth_assert(is_wp_error($deletion->finalize_deletion($oldRequest)),'Pre-SDK rotation rejects the previous intent binding');
mobishop_auth_assert($deletion->finalize_deletion($newRequest)->status===202,'Rotated unapproved intent accepts only its new fresh binding');

for($i=0;$i<15&&MobiShop_Customer_Account_Deletion::is_pending(7);$i++){$lastJobRaw=$GLOBALS['delete_options']['mobishop_account_deletion_v1_7'];deletion_tick();}
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Guarded accepted worker completes actual fixture deletion');
$guardRows=array_filter(array_keys($GLOBALS['delete_options']),static fn($key)=>str_starts_with($key,'mobishop_identity_guard_v1_'));
mobishop_auth_assert($guardRows===array(),'Reservations release only after WP deletion and durable completion receipt');


$GLOBALS['delete_options']['mobishop_account_deletion_v1_7']=$lastJobRaw;
$GLOBALS['intent_outage']=true; // Any provider replay would now fail; completion recovery must not call it.
deletion_tick();
mobishop_auth_assert(!MobiShop_Customer_Account_Deletion::is_pending(7),'Crash after reservation release recovers completed job without replaying identities');
unset($GLOBALS['intent_outage']);


// Crash after accepted phase0 can leave the earlier approved intent behind.
intent_reset();$login=deletion_login();$GLOBALS['intent_links'][7]=array($apple);
$request=intent_request($login,array('id_token'=>'fixture-valid-proof','apple_revoked'=>true));
$deletion->prepare_deletion($request);$deletion->approve_apple($request);
foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_'))$leftoverKey=$key;
$leftoverRaw=$GLOBALS['delete_options'][$leftoverKey];$GLOBALS['intent_absent']=true;
$deletion->finalize_deletion($request);$GLOBALS['delete_options'][$leftoverKey]=$leftoverRaw;
$GLOBALS['delete_flags']['intent-cleanup-failure']=true;
for($i=0;$i<12&&isset($GLOBALS['mobishop_users'][7]);$i++)deletion_tick();
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&isset($GLOBALS['delete_options'][$leftoverKey])&&MobiShop_Customer_Account_Deletion::is_pending(7),'Terminal intent cleanup failure preserves durable retry job');
$guardRows=array_filter(array_keys($GLOBALS['delete_options']),static fn($key)=>str_starts_with($key,'mobishop_identity_guard_v1_'));
mobishop_auth_assert(count($guardRows)===2,'Terminal cleanup failure does not release approved identity reservations');
unset($GLOBALS['delete_flags']['intent-cleanup-failure']);$GLOBALS['intent_outage']=true;
deletion_tick();
mobishop_auth_assert(!isset($GLOBALS['delete_options'][$leftoverKey])&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Completed-receipt retry removes matching approved intent before releasing job without provider replay');
unset($GLOBALS['intent_outage']);


// Cleanup may crash after prepared release and before deleting its intent option.
intent_reset();$login=deletion_login();$GLOBALS['intent_links'][7]=array(array('project'=>'fixture-project','uid'=>'cleanup-crash-uid','provider'=>'phone','key'=>'fixture'));
$request=intent_request($login);$before=$deletion->prepare_deletion($request);
foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_'))$releasedKey=$key;
$released=unserialize($GLOBALS['delete_options'][$releasedKey]);$released['expires']=time()-1;$GLOBALS['delete_options'][$releasedKey]=serialize($released);
MobiShop_Customer_Identity_Guard::release(7,substr($releasedKey,strlen('mobishop_deletion_intent_v1_')),$released['inventory']);
$after=$deletion->prepare_deletion($request);
mobishop_auth_assert($after->data['intent_id']===$before->data['intent_id'],'Prepared cleanup crash repairs reservations without replacing intent ID');
$blocked=false;try{MobiShop_Customer_Identity_Guard::writer(9,$released['inventory'][0],static fn()=>true);}catch(RuntimeException $e){$blocked=true;}
mobishop_auth_assert($blocked,'Existing unapproved prepare re-reserves exact UID before response');
mobishop_auth_assert($deletion->finalize_deletion($request)->status===202,'Repaired prepared reservation can finalize without trapping revoked session');


// Finalize can persist its phase-1 barrier after cleanup's outer job read and before owner lock.
intent_reset();$login=deletion_login();$GLOBALS['intent_links'][7]=array(array('project'=>'fixture-project','uid'=>'cleanup-finalize-race','provider'=>'phone','key'=>'fixture'));
$request=intent_request($login);$deletion->prepare_deletion($request);
foreach(array_keys($GLOBALS['delete_options'])as $key)if(str_starts_with($key,'mobishop_deletion_intent_v1_'))$raceIntentKey=$key;
$raceIntent=unserialize($GLOBALS['delete_options'][$raceIntentKey]);$raceIntent['expires']=time()-1;$GLOBALS['delete_options'][$raceIntentKey]=serialize($raceIntent);
$raceHash=substr($raceIntentKey,strlen('mobishop_deletion_intent_v1_'));
$GLOBALS['delete_intent_lock_race']=static function()use($raceHash,$raceIntent){
 $GLOBALS['delete_options']['mobishop_account_deletion_v1_7']=serialize(array('userId'=>7,'phase'=>-1,'cursor'=>time(),'receiptHash'=>$raceHash,'identityStage'=>$raceIntent['identityStage'],'identityLinks'=>$raceIntent['inventory']));
};
MobiShop_Customer_Account_Deletion::cleanup_receipts();
mobishop_auth_assert(!isset($GLOBALS['delete_intent_lock_race']),'Cleanup race fixture reached owner-lock boundary after outer job check');
mobishop_auth_assert(isset($GLOBALS['delete_options'][$raceIntentKey]),'Cleanup rechecks matching newly prepared job under owner lock before removing intent');
$guardRows=array_filter(array_keys($GLOBALS['delete_options']),static fn($key)=>str_starts_with($key,'mobishop_identity_guard_v1_'));
mobishop_auth_assert(count($guardRows)===2,'Cleanup preserves owner and UID reservations for job created before owner lock');

fwrite(STDOUT,"Deletion intent protocol fixture checks passed.\n");