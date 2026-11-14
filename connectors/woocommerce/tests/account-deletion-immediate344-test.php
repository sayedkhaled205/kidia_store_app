<?php
/** Synthetic lifecycle: complete ordinary deletion before replying, then allow a new identity owner. */
require __DIR__.'/account-deletion-intent-test.php';

intent_reset();$GLOBALS['delete_pause_worker']=false;$login=deletion_login();$request=intent_request($login);
$GLOBALS['delete_orders']=[new DeletionOrder(7),new DeletionOrder(8)];
$GLOBALS['delete_tables']['wp_mobishop_carts']=[['user_id'=>7],['user_id'=>8]];
$GLOBALS['delete_options']['mobishop_push_devices_v1']=serialize(['old'=>['user_id'=>7],'other'=>['user_id'=>8]]);
$GLOBALS['delete_comments']=[71=>(object)['comment_ID'=>71,'user_id'=>7],81=>(object)['comment_ID'=>81,'user_id'=>8]];
$deletion->prepare_deletion($request);
$result=$deletion->finalize_deletion($request);
mobishop_auth_assert($result->status===200&&$result->data===['status'=>'completed','user_id'=>7],'Ordinary deletion must complete inside finalize, without a cron tick.');
mobishop_auth_assert(!isset($GLOBALS['mobishop_users'][7])&&!MobiShop_Customer_Account_Deletion::is_pending(7),'Completed response releases the deleted account.');
mobishop_auth_assert($deletion->deletion_status($request)->data['status']==='completed','Lost synchronous response recovers durable completion.');
mobishop_auth_assert($GLOBALS['delete_orders'][0]->owner===0&&$GLOBALS['delete_orders'][1]->owner===8,'Orders retain records without retaining the deleted account owner.');
mobishop_auth_assert(count($GLOBALS['delete_tables']['wp_mobishop_carts'])===1&&!isset($GLOBALS['delete_comments'][71])&&isset($GLOBALS['delete_comments'][81]),'Owned rows are erased while another customer remains intact.');
mobishop_auth_assert(array_keys(unserialize($GLOBALS['delete_options']['mobishop_push_devices_v1']))===['other'],'Owned push registration is erased.');

intent_reset();$GLOBALS['delete_pause_worker']=false;$login=deletion_login();
$GLOBALS['intent_links'][7]=[$apple];$request=intent_request($login,['id_token'=>'fixture-valid-proof','apple_revoked'=>true]);
$deletion->prepare_deletion($request);$deletion->approve_apple($request);$GLOBALS['intent_absent']=true;
$GLOBALS['intent_fail_after_lookup']=true;
$result=$deletion->finalize_deletion($request);
mobishop_auth_assert($result->status===200&&!isset($GLOBALS['mobishop_users'][7]),'Confirmed Apple absence must not call provider erasure again, even if the service goes offline immediately.');
mobishop_auth_assert(empty($GLOBALS['intent_advanced']),'Apple SDK-erased UID is not erased twice.');
$newOwner=new WP_User(9,['roles'=>['customer'],'allcaps'=>['read'=>true],'email'=>'new@example.invalid','display_name'=>'New synthetic customer']);$GLOBALS['mobishop_users'][9]=$newOwner;
$linked=MobiShop_Customer_Identity_Guard::writer(9,$apple,static fn()=>true);
mobishop_auth_assert($linked===true,'The same provider identity can be assigned to a new owner immediately after completion.');
$before=$GLOBALS['mobishop_users'][9];MobiShop_Customer_Account_Deletion::run_worker(7,true);
mobishop_auth_assert($GLOBALS['mobishop_users'][9]===$before&&empty($GLOBALS['intent_advanced']),'A late old callback does not erase a newly registered owner or replay provider erasure.');

intent_reset();$GLOBALS['delete_pause_worker']=false;$login=deletion_login();
$GLOBALS['intent_links'][7]=[['project'=>'fixture-project','uid'=>'fixture-phone','provider'=>'phone','key'=>'fixture']];
$request=intent_request($login);$deletion->prepare_deletion($request);$GLOBALS['intent_outage']=true;
$result=$deletion->finalize_deletion($request);
mobishop_auth_assert($result->status===202&&$result->data['status']==='pending'&&isset($GLOBALS['mobishop_users'][7]),'Provider outage preserves pending status and the account; never false completion.');
mobishop_auth_assert(wp_next_scheduled('mobishop_delete_customer_batch',[7])!==false,'Provider outage retains its durable retry.');
$blocked=false;try{MobiShop_Customer_Identity_Guard::writer(9,$GLOBALS['intent_links'][7][0],static fn()=>true);}catch(RuntimeException $e){$blocked=true;}
mobishop_auth_assert($blocked,'Pending identity remains reserved until erasure has actually completed.');
unset($GLOBALS['intent_outage']);deletion_tick();
mobishop_auth_assert($deletion->deletion_status($request)->data['status']==='completed','Provider recovery completes the same deletion without a duplicate request.');

intent_reset();$GLOBALS['delete_pause_worker']=false;$login=deletion_login();$request=intent_request($login);
for($i=0;$i<2100;$i++)$GLOBALS['delete_orders'][]=new DeletionOrder(7);
$deletion->prepare_deletion($request);$result=$deletion->finalize_deletion($request);
mobishop_auth_assert($result->status===202&&isset($GLOBALS['mobishop_users'][7]),'Large accounts yield at the inline work limit.');
mobishop_auth_assert(count(array_filter($GLOBALS['delete_orders'],fn($o)=>$o->owner===7))>=100,'Inline work is bounded to at most forty fifty-row batches.');
mobishop_auth_assert(wp_next_scheduled('mobishop_delete_customer_batch',[7])!==false,'Large-account cleanup retains its retry.');

echo "Immediate deletion344 lifecycle checks passed.\n";
