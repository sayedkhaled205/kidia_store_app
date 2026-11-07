<?php
define('ABSPATH', __DIR__);
final class GuardDb {
    public $options='wp_options', $last_error='', $rows=[], $locks=[], $events=[], $failKey=null;
    public function prepare($sql,...$args) { return [$sql,$args]; }
    public function get_var($query) {
        [$sql,$args]=$query;
        if (str_contains($sql,'GET_LOCK')) { $this->events[]='lock:'.$args[0]; $this->locks[$args[0]]=true; return '1'; }
        if (str_contains($sql,'SELECT option_value')) return $this->rows[$args[0]]??null;
        throw new RuntimeException('Unexpected read');
    }
    public function query($query) {
        [$sql,$args]=$query;
        if (str_contains($sql,'RELEASE_LOCK')) { $this->events[]='unlock:'.$args[0]; unset($this->locks[$args[0]]); return 1; }
        if (str_starts_with($sql,'UPDATE')) { [$new,$key,$old]=$args; if (($this->rows[$key]??null)!==$old) return 0; $this->rows[$key]=$new; return 1; }
        if (str_starts_with($sql,'DELETE')) { [$key,$old]=$args; if (($this->rows[$key]??null)!==$old) return 0; unset($this->rows[$key]); return 1; }
        throw new RuntimeException('Unexpected write');
    }
}
$wpdb=new GuardDb();
function maybe_serialize($value) { return serialize($value); }
function maybe_unserialize($value) { return @unserialize($value); }
function wp_cache_delete($key,$group) {}
function add_option($key,$row,$unused='',$autoload=false) { global $wpdb; if ($key===$wpdb->failKey || isset($wpdb->rows[$key])) return false; $wpdb->rows[$key]=serialize($row); return true; }
require __DIR__.'/../connector/class-customer-identity-guard.php';
$checks=0;
function check($yes,$label) { global $checks; if (!$yes) throw new RuntimeException('FAIL '.$label); $checks++; }
function denied($action) { try {$action();} catch (RuntimeException $e) { return true; } return false; }
$a=['project'=>'synthetic-auth-project','uid'=>'identity-a']; $b=['project'=>'synthetic-auth-project','uid'=>'identity-b']; $receipt=str_repeat('a',64);
MobiShop_Customer_Identity_Guard::writer(1,$a, function() use($wpdb) { check(count($wpdb->locks)===2,'Writer holds owner and UID locks'); });
check($wpdb->locks===[],'Writer releases before caller issues session');
$events=$wpdb->events; check(str_contains($events[0],md5('wp_options|mobishop_identity_guard_v1_owner_1')),'Owner acquired before UID');
MobiShop_Customer_Identity_Guard::reserve(1,$receipt,[$a],1);
check(denied(fn()=>MobiShop_Customer_Identity_Guard::writer(2,$a,fn()=>null)),'Expired prepared reservation still blocks unrelated writer');
check(denied(fn()=>MobiShop_Customer_Identity_Guard::writer(1,$b,fn()=>null)),'Owner reservation blocks newly added UID');
check(denied(fn()=>MobiShop_Customer_Identity_Guard::reserve(1,str_repeat('b',64),[$a],1)),'Second owner receipt denied');
check(denied(fn()=>MobiShop_Customer_Identity_Guard::new_identity($a,fn()=>null)),'New Apple registration blocked');
MobiShop_Customer_Identity_Guard::release(1,$receipt,[$a]); check($wpdb->rows===[],'Explicit prepared rollback clears reservations');
$wpdb->failKey='mobishop_identity_guard_v1_uid_'.hash('sha256',$a['project'].'|'.$a['uid']);
check(denied(fn()=>MobiShop_Customer_Identity_Guard::reserve(1,$receipt,[$a],1)),'Partial provisional save fails closed');
check(count($wpdb->rows)===1,'Provisional owner survives failed UID write');
$wpdb->failKey=null; MobiShop_Customer_Identity_Guard::release(1,$receipt,[$a]); check($wpdb->rows===[],'Partial provisional rollback succeeds');
MobiShop_Customer_Identity_Guard::reserve(1,$receipt,[$a],1);
MobiShop_Customer_Identity_Guard::approve(1,$receipt,[$a]);
check(denied(fn()=>MobiShop_Customer_Identity_Guard::release(1,$receipt,[$a])),'Approved reservation never auto-expires or prepared-releases');
check(denied(fn()=>MobiShop_Customer_Identity_Guard::writer(2,$a,fn()=>null)),'Approved reservation protects asynchronous SDK');
$mutated=false;
check(MobiShop_Customer_Identity_Guard::writer(1,$a,function() use (&$mutated) {$mutated=true;},fn()=>true)===true && !$mutated,'Existing verified identity reauth makes no mutation while reserved');
MobiShop_Customer_Identity_Guard::accept(1,$receipt,[$a]);
check(denied(fn()=>MobiShop_Customer_Identity_Guard::approve(1,$receipt,[$a])),'Accepted reservation cannot regress');
MobiShop_Customer_Identity_Guard::release(1,$receipt,[$a],true); check($wpdb->rows===[],'Explicit verified completion clears reservation');
MobiShop_Customer_Identity_Guard::reserve(2,str_repeat('b',64),[$a],1);
$replacement=$wpdb->rows;
MobiShop_Customer_Identity_Guard::release(1,$receipt,[$a],true);
check($wpdb->rows===$replacement,'Completed cleanup never removes a later owner reservation');
MobiShop_Customer_Identity_Guard::release(2,str_repeat('b',64),[$a]);
MobiShop_Customer_Identity_Guard::with_owner(1,fn()=>MobiShop_Customer_Identity_Guard::reserve(1,$receipt,[$a,$b],1));
check($wpdb->locks===[],'Reentrant owner lock releases once');
$owner='mobishop_identity_guard_v1_owner_1'; $wpdb->rows[$owner]='corrupt';
check(denied(fn()=>MobiShop_Customer_Identity_Guard::writer(1,$a,fn()=>null)),'Corruption blocks identity writes');
check($wpdb->locks===[],'Failure releases all advisory locks');
echo "$checks identity guard checks passed.\n";
