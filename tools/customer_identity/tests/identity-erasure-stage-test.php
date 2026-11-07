<?php
define('ABSPATH', __DIR__);
final class MobiShop_Customer_Identity_Client {
    public static array $calls = [], $snapshot = ['status'=>'present', 'created_at'=>'123'];
    public static bool $available = true, $failure = false;
    public static function capabilities() { return ['available'=>self::$available, 'project_id'=>'synthetic-project']; }
    public static function lookup($project,$uid) { self::$calls[]='lookup'; return self::$snapshot; }
    public static function erase($project,$uid,$created) { self::$calls[]='erase'; if(self::$failure) throw new RuntimeException('fixture unavailable'); return ['status'=>'absent']; }
}
final class MobiShop_Customer_Identity_Links {
    public static array $links = [];
    public static bool $shared = false;
    public static function inventory($id) { return self::$links; }
    public static function shared($id,$link) { return self::$shared; }
}
require __DIR__.'/../connector/class-customer-identity-erasure-stage.php';
$checks=0;
function verify($condition,$label) { global $checks; if(!$condition)throw new RuntimeException($label);$checks++; }
function rejected($call) { try{$call();}catch(RuntimeException){return true;}return false; }
$stage='MobiShop_Customer_Identity_Erasure_Stage';
MobiShop_Customer_Identity_Client::$available=false;
verify(rejected(fn()=>$stage::prepare(7)),'Disabled provider blocks acceptance');
MobiShop_Customer_Identity_Client::$available=true;
$link=['project'=>'synthetic-project','uid'=>'uid','provider'=>'phone','key'=>'fixture'];
MobiShop_Customer_Identity_Links::$links=[$link];
$state=$stage::prepare(7);
verify($state['entries'][0]['created_at']==='123','Persist generation before deletion');
verify(rejected(fn()=>$stage::advance(8,$state)),'Another customer cannot advance intent');
MobiShop_Customer_Identity_Client::$failure=true;
verify(rejected(fn()=>$stage::advance(7,$state)),'Outage cannot advance or complete state');
verify($state['cursor']===0,'Original durable intent retains retry cursor');
MobiShop_Customer_Identity_Client::$failure=false;
$done=$stage::advance(7,$state);
verify($done['cursor']===1&&$done['entries'][0]['action']==='absent','Confirmed provider absence advances once');
$count=count(MobiShop_Customer_Identity_Client::$calls);
verify($stage::advance(7,$done)===$done&&count(MobiShop_Customer_Identity_Client::$calls)===$count,'Completed step never replays provider');
MobiShop_Customer_Identity_Links::$shared=true;
verify($stage::prepare(7)['entries'][0]['action']==='retain_shared','Shared identity is retained');
$count=count(MobiShop_Customer_Identity_Client::$calls);
verify($stage::advance(7,$state)['entries'][0]['action']==='retain_shared'&&count(MobiShop_Customer_Identity_Client::$calls)===$count,'New shared owner before execution prevents erasure');
MobiShop_Customer_Identity_Links::$shared=false;
$link['provider']='apple';MobiShop_Customer_Identity_Links::$links=[$link];
$apple=$stage::prepare(7);
verify(rejected(fn()=>$stage::advance(7,$apple)),'Unrevoked Apple identity cannot complete');
MobiShop_Customer_Identity_Client::$snapshot=['status'=>'absent'];
verify($stage::prepare(7)['entries'][0]['action']==='absent','Existing provider absence is captured');
$absentApple=$stage::prepare(7);
verify(rejected(fn()=>$stage::advance(7,$absentApple)),'Firebase absence does not substitute for Apple authorization revocation');
echo $checks.' identity worker-stage checks passed.'.PHP_EOL;
