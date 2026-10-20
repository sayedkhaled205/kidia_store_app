<?php
/** Isolated stub contracts against packaged setup code. No WordPress/network/order calls. */
declare(strict_types=1);

$cases=['fresh_and_repeat','readonly_unprepared','unauthorized_options','unauthorized_commerce','unlicensed','disabled','old_unknown_key','old_partial','old_valid','old_wrong_key','resume_owned','owned_active_partial','wrong_engine','busy','transaction','bad_record','rotated_key','old_woo','routes_unprepared','central_permissions'];
if (!isset($argv[1])) {
    foreach($cases as $case) {
        $pipes=[];
        $process=proc_open([PHP_BINARY,__FILE__,$case],[1=>['pipe','w'],2=>['pipe','w']],$pipes);
        if (!is_resource($process)) throw new RuntimeException('Cannot start isolated fixture.');
        $out=stream_get_contents($pipes[1]);$error=stream_get_contents($pipes[2]);
        fclose($pipes[1]);fclose($pipes[2]);
        if (proc_close($process)!==0) throw new RuntimeException($case.': '.$out.$error);
        echo $out;
    }
    echo 'NATIVE_SETUP50_CONTRACT_OK '.count($cases)." isolated cases; no external effects.\n";
    exit;
}
$case=$argv[1];
if (!in_array($case,$cases,true)) throw new RuntimeException('Unknown fixture.');
define('ABSPATH',__DIR__);
define('ARRAY_A','ARRAY_A');
define('WC_VERSION',$case==='old_woo'?'9.8.0':'10.0.0');
define('MOBISHOP_VERSION','1.46.76');
define('MOBISHOP_PATH',rtrim(getenv('MOBISHOP_CONNECTOR_TEST_ROOT')?:dirname(__DIR__).'/source','/\\').'/');
$GLOBALS['options']=[];$GLOBALS['autoload']=[];$GLOBALS['actions']=[];$GLOBALS['routes']=[];
$GLOBALS['caps']=['manage_options'=>true,'manage_woocommerce'=>true];$GLOBALS['license']=true;
class WP_Error { public function __construct(public string $code,public string $message,public array $data=[]){} }
class WP_REST_Response { public array $headers=[];public function __construct(public $data,public int $status=200,array $headers=[]){$this->headers=$headers;}public function header($k,$v){$this->headers[$k]=$v;} }
class WP_REST_Request { public function get_json_params(){return ['license_key'=>'fixture'];}public function get_route(){return '/wc/store/v1/checkout';}public function get_method(){return 'POST';}public function get_param($k){return $k==='extensions'?['mobishop_native_checkout50'=>['protocol'=>50]]:null;} }
class MobiShop_License_Manager { public function is_active(){return $GLOBALS['license'];}public function verify(){return true;}public function activate($key){return true;} }
function current_user_can($cap){return $GLOBALS['caps'][$cap]??false;}
function get_option($key,$default=false){return $GLOBALS['options'][$key]??$default;}
function add_option($key,$value,$deprecated='',$autoload=null){if(array_key_exists($key,$GLOBALS['options']))return false;$GLOBALS['options'][$key]=$value;$GLOBALS['autoload'][$key]=$autoload;return true;}
function update_option($key,$value,$autoload=null){$GLOBALS['options'][$key]=$value;$GLOBALS['autoload'][$key]=$autoload;return true;}
function is_wp_error($v){return $v instanceof WP_Error;}
function add_action($hook,$callback,$priority=10,$args=1){$GLOBALS['actions'][$hook][]=$callback;}
function add_filter($hook,$callback,$priority=10,$args=1){add_action($hook,$callback,$priority,$args);}
function register_rest_route($namespace,$route,$args,$override=false){$GLOBALS['routes'][$namespace.$route]=$args;}
function did_action($hook){return 0;}
function check50setup($ok,$label){if(!$ok)throw new RuntimeException($label);}

class SetupDb50 {
    public string $prefix='fixture_';public string $last_error='';public bool $locked=false;public bool $busy=false;public bool $transaction=false;
    public array $tables=[];public array $writes=[];public int $fail_create=0;private int $creates=0;
    public function prepare($sql,...$args){foreach($args as $value)$sql=preg_replace('/%s/',"'".str_replace("'","''",(string)$value)."'",$sql,1);return $sql;}
    public function get_var($sql){
        $this->last_error='';
        if($sql==='SELECT @@in_transaction')return $this->transaction?'1':'0';
        if(str_contains($sql,'GET_LOCK')){if($this->busy)return '0';$this->locked=true;return '1';}
        if(str_contains($sql,'RELEASE_LOCK')){$this->locked=false;return '1';}
        if(preg_match('/SELECT COUNT\(\*\) FROM `([^`]+)`/',$sql,$m))return isset($this->tables[$m[1]])?(string)$this->tables[$m[1]]['count']:null;
        if(preg_match('/SELECT key_fingerprint FROM `([^`]+)`/',$sql,$m))return $this->tables[$m[1]]['fingerprint']??null;
        throw new RuntimeException('Unexpected fixture read.');
    }
    public function get_row($sql,$mode){
        $this->last_error='';
        preg_match("/WHERE Name = '([^']+)'/",$sql,$m);$name=$m[1]??'';
        return isset($this->tables[$name])?['Name'=>$name,'Engine'=>$this->tables[$name]['engine']]:null;
    }
    public function get_results($sql,$mode){
        preg_match('/FROM `([^`]+)`/',$sql,$m);$table=$this->tables[$m[1]]??null;
        if(!$table)return [];
        return str_starts_with($sql,'SHOW FULL COLUMNS')?$table['columns']:$table['indexes'];
    }
    public function query($sql){
        $this->last_error='';
        if(str_starts_with($sql,'CREATE TABLE ')){
            $this->creates++;
            if($this->fail_create===$this->creates){$this->last_error='fixture failure';return false;}
            preg_match('/CREATE TABLE ([a-zA-Z0-9_]+) /',$sql,$m);$name=$m[1];
            if(isset($this->tables[$name]))throw new RuntimeException('Must not recreate a ledger.');
            $cols=[];
            preg_match_all('/([a-z_]+) (char\(\d+\)|varchar\(\d+\)|bigint unsigned|tinyint unsigned|datetime)([^,]*)/',$sql,$matches,PREG_SET_ORDER);
            foreach($matches as $col){
                preg_match("/DEFAULT (NULL|'[^']*'|[0-9]+)/",$col[3],$default);
                $value=$default[1]??null;if($value==='NULL')$value=null;elseif(is_string($value))$value=trim($value,"'");
                $cols[]=['Field'=>$col[1],'Type'=>$col[2],'Collation'=>str_contains($col[3],'ascii_bin')?'ascii_bin':null,'Null'=>str_contains($col[3],'NOT NULL')?'NO':'YES','Default'=>$value];
            }
            preg_match('/PRIMARY KEY \(([^)]+)\)/',$sql,$primary);$indexes=[];
            foreach(explode(',',$primary[1]) as $i=>$field)$indexes[]=['Key_name'=>'PRIMARY','Non_unique'=>0,'Sub_part'=>null,'Seq_in_index'=>$i+1,'Column_name'=>trim($field)];
            $this->tables[$name]=['engine'=>'InnoDB','columns'=>$cols,'indexes'=>$indexes,'count'=>0];$this->writes[]=$sql;return 1;
        }
        if(preg_match("/INSERT INTO ([a-zA-Z0-9_]+) \(id, key_fingerprint\) VALUES \(1, '([a-f0-9]{64})'\)/",$sql,$m)){
            if($this->tables[$m[1]]['count']!==0)throw new RuntimeException('Must not overwrite ledger identity.');
            $this->tables[$m[1]]['count']=1;$this->tables[$m[1]]['fingerprint']=$m[2];$this->writes[]=$sql;return 1;
        }
        throw new RuntimeException('Unexpected fixture write.');
    }
}
$db=$GLOBALS['wpdb']=new SetupDb50();
require_once MOBISHOP_PATH.'includes/class-native-checkout-setup50.php';
require_once MOBISHOP_PATH.'api/class-native-checkout-safety50.php';
$option=MobiShop_Native_Checkout_Setup50::OPTION;
$externalCases=['old_partial','old_valid','old_wrong_key','wrong_engine','owned_active_partial','rotated_key'];
if(in_array($case,$externalCases,true))define('MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY',str_repeat('a',64));
if(in_array($case,['old_partial','old_valid','old_wrong_key','wrong_engine','owned_active_partial'],true)){
    $ddl=(new MobiShop_Native_Checkout_Wpdb50())->installation_sql();
    foreach($case==='old_partial'?array_slice($ddl,0,1):$ddl as $sql)$db->query($sql);
    $db->writes=[];
}
if($case==='old_unknown_key')$db->tables['fixture_mobishop_native_checkout50_buyers']=['engine'=>'InnoDB','columns'=>[],'indexes'=>[],'count'=>0];
if($case==='old_wrong_key')$db->tables['fixture_mobishop_native_checkout50_config']['fingerprint']=str_repeat('0',64);
if($case==='wrong_engine')$db->tables['fixture_mobishop_native_checkout50_buyers']['engine']='MyISAM';
if($case==='owned_active_partial'){
    $GLOBALS['options'][$option]=['schema'=>1,'source'=>'constant','state'=>'preparing','fingerprint'=>hash('sha256',MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY)];
    $db->tables['fixture_mobishop_native_checkout50_attempts']['count']=1;
}
if($case==='rotated_key')$GLOBALS['options'][$option]=['schema'=>1,'source'=>'constant','state'=>'ready','fingerprint'=>str_repeat('0',64)];
if($case==='bad_record')$GLOBALS['options'][$option]=['state'=>'ready'];
if($case==='unauthorized_options')$GLOBALS['caps']['manage_options']=false;
if($case==='unauthorized_commerce')$GLOBALS['caps']['manage_woocommerce']=false;
if($case==='unlicensed')$GLOBALS['license']=false;
if($case==='disabled')define('MOBISHOP_NATIVE_CHECKOUT50_ENABLED',false);
if($case==='busy')$db->busy=true;
if($case==='transaction')$db->transaction=true;
if($case==='resume_owned')$db->fail_create=2;
$initialOptions=$GLOBALS['options'];$initialTables=$db->tables;
if($case==='readonly_unprepared'){
    check50setup(!MobiShop_Native_Checkout_Setup50::runtime_enabled(),'Public request must not prepare a new installation.');
    check50setup($GLOBALS['options']===[] && $db->writes===[],'Read-only bootstrap cannot persist a key or schema.');
}elseif($case==='routes_unprepared'){
    require_once MOBISHOP_PATH.'includes/class-native-checkout-bootstrap50.php';
    MobiShop_Native_Checkout_Bootstrap50::boot();
    foreach($GLOBALS['actions']['rest_api_init'] as $hook)$hook();
    $route=$GLOBALS['routes']['mobishop/v1/native-checkout-capabilities'];
    $result=($route['callback'])();
    check50setup($result->data['enforced']===false && $result->data['protocol']===50,'Unprepared capability must exist and report false.');
    $blocked=MobiShop_Native_Checkout_Bootstrap50::fail_closed(null,null,new WP_REST_Request());
    check50setup($blocked instanceof WP_REST_Response && $blocked->status===503,'Unprepared Native POST must fail closed.');
    check50setup($GLOBALS['options']===[] && $db->writes===[],'Capability discovery cannot install storage.');
}elseif($case==='central_permissions'){
    require MOBISHOP_PATH.'includes/central/bootstrap.php';
    foreach($GLOBALS['actions']['rest_api_init'] as $hook)$hook();
    $route=$GLOBALS['routes']['mobishop/v1/central/bootstrap'];
    foreach(['manage_options','manage_woocommerce'] as $cap){$GLOBALS['caps'][$cap]=false;check50setup(($route['permission_callback'])()===false,'Both existing admin capabilities are required.');$GLOBALS['caps'][$cap]=true;}
    check50setup(($route['permission_callback'])()===true,'Existing authorized admin connection remains supported.');
    $result=($route['callback'])(new WP_REST_Request());
    check50setup($result instanceof WP_REST_Response && $result->data['native_checkout']['prepared']===true,'Authorized central bootstrap must prepare checkout.');
    check50setup(!str_contains(json_encode($result->data),$GLOBALS['options'][$option]['key']),'Setup response cannot expose installation secret.');
}else{
    $result=MobiShop_Native_Checkout_Setup50::prepare();
    if(in_array($case,['fresh_and_repeat','old_valid'],true)){
        check50setup(is_array($result) && $result['prepared']===true,'Legitimate setup must succeed.');
        check50setup(MobiShop_Native_Checkout_Setup50::runtime_enabled(),'Prepared setup must boot next request.');
        $saved=$GLOBALS['options'];$writes=$db->writes;
        check50setup(!is_wp_error(MobiShop_Native_Checkout_Setup50::prepare()),'Repeated setup must succeed.');
        check50setup($saved===$GLOBALS['options'] && $writes===$db->writes,'Repeated setup cannot rewrite identity/schema.');
        check50setup($GLOBALS['autoload'][$option]===false,'Installation material must not autoload.');
        if($case==='fresh_and_repeat'){
            check50setup(count($db->tables)===4 && count($writes)===5,'Fresh setup installs exactly the existing ledger DDL.');
            check50setup(!str_contains(implode("\n",$writes),$GLOBALS['options'][$option]['key']),'DDL contains fingerprint, never key.');
        }else{
            check50setup($writes===[] && !isset($GLOBALS['options'][$option]['key']),'Valid external ledger must remain untouched; external key is not copied.');
        }
    }elseif($case==='resume_owned'){
        check50setup(is_wp_error($result) && $GLOBALS['options'][$option]['state']==='preparing','Interrupted setup keeps ownership and key.');
        $key=$GLOBALS['options'][$option]['key'];$db->fail_create=0;
        check50setup(!is_wp_error(MobiShop_Native_Checkout_Setup50::prepare()),'Owned empty interrupted setup must resume.');
        check50setup($key===$GLOBALS['options'][$option]['key'] && count($db->tables)===4,'Resume cannot rotate identity.');
    }else{
        check50setup(is_wp_error($result),'Unsafe/unauthorized setup must fail.');
        check50setup($GLOBALS['options']===$initialOptions && $db->tables===$initialTables && $db->writes===[],'Rejected setup must preserve all state.');
    }
    check50setup(!$db->locked,'Setup lock must always release.');
}
echo $case." OK\n";
