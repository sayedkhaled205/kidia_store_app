<?php
/** Executes real aggregation/deduplication queries in an isolated in-memory DB. */
define('ABSPATH',__DIR__.'/'); define('ARRAY_A','ARRAY_A'); define('DAY_IN_SECONDS',86400);
function get_option($key,$default=false){return $key==='mobishop_push_analytics_schema'?'1':$default;}
function add_action(...$args){}
function rest_ensure_response($value){return $value;}
class WP_Error {public function __construct(public $code,public $message,public $data){}}
class WP_REST_Request {
 public function __construct(public array $params=[],public array $headers=[]){}
 public function get_param($key){return $this->params[$key]??null;}
 public function get_header($key){return $this->headers[$key]??'';}
}
class PushTestDb {
 public $prefix='test_'; public PDO $db;
 public function __construct(){ $this->db=new PDO('sqlite::memory:');$this->db->setAttribute(PDO::ATTR_ERRMODE,PDO::ERRMODE_EXCEPTION); }
 public function prepare($query,...$args){$i=0;return preg_replace_callback('/%[sd]/',function($m)use(&$i,$args){$v=$args[$i++];return $m[0]==='%d'?(string)(int)$v:$this->db->quote((string)$v);},$query);}
 public function query($sql){return $this->db->exec(str_replace('INSERT IGNORE','INSERT OR IGNORE',$sql));}
 public function get_row($sql,$mode=null){return $this->db->query($sql)->fetch(PDO::FETCH_ASSOC)?:null;}
 public function get_var($sql){return $this->db->query($sql)->fetchColumn();}
 public function get_results($sql,$mode=null){return $this->db->query($sql)->fetchAll(PDO::FETCH_ASSOC);}
 public function update($table,$data,$where){$sets=[];$filters=[];foreach($data as $k=>$v)$sets[]="$k=".$this->db->quote((string)$v);foreach($where as $k=>$v)$filters[]="$k=".$this->db->quote((string)$v);return $this->query("UPDATE $table SET ".implode(',',$sets).' WHERE '.implode(' AND ',$filters));}
 public function replace($table,$data){return $this->query("INSERT OR REPLACE INTO $table (".implode(',',array_keys($data)).') VALUES ('.implode(',',array_map(fn($v)=>$this->db->quote((string)$v),$data)).')');}
}
class WC_Order {
 public array $meta=['_mobishop_order_source'=>'mobile']; public string $status='processing'; public float $refund=0; public bool $paid=false;
 public function __construct(public int $id=10,public int $customer=5,public string $currency='EGP',public string $total='150.50'){}
 public function get_id(){return $this->id;} public function get_meta($key){return $this->meta[$key]??'';}
 public function update_meta_data($key,$value){$this->meta[$key]=$value;} public function get_date_created(){return new DateTimeImmutable();}
 public function get_customer_id(){return $this->customer;} public function get_currency(){return $this->currency;}
 public function get_total(){return $this->total;} public function get_total_refunded(){return $this->refund;}
 public function get_status(){return $this->status;} public function get_date_paid(){return $this->paid?new DateTimeImmutable():null;}
}
require __DIR__.'/../source/includes/class-mobishop-push-analytics.php';
$wpdb=new PushTestDb();
$wpdb->query('CREATE TABLE test_mobishop_push_campaigns_v2 (id TEXT PRIMARY KEY,title TEXT,message TEXT,status TEXT,audience TEXT,sent INTEGER DEFAULT 0,failed INTEGER DEFAULT 0,created_at INTEGER)');
$wpdb->query('CREATE TABLE test_mobishop_push_events_v2 (id INTEGER PRIMARY KEY AUTOINCREMENT,campaign TEXT,event TEXT,client_hash TEXT,platform TEXT,occurred_at TEXT,UNIQUE(campaign,event,client_hash))');
$wpdb->query('CREATE TABLE test_mobishop_push_orders_v2 (order_id INTEGER PRIMARY KEY,campaign TEXT,client_hash TEXT,buyer_hash TEXT,currency TEXT,amount DECIMAL,status TEXT,paid INTEGER,created_at TEXT,updated_at TEXT)');
function check($value,$message){if(!$value)throw new RuntimeException($message);}
function campaign($id){MobiShop_Push_Analytics::begin(['id'=>$id,'title'=>'QA','message'=>'Fixture','audience'=>'test'],[['client_id'=>'device-test-123','platform'=>'android'],['client_id'=>'device-test-123','platform'=>'android']]);}
function event($id,$event='opened',$client='device-test-123'){return MobiShop_Push_Analytics::record(new WP_REST_Request(['notification_id'=>$id,'event'=>$event,'client_id'=>$client]));}
function report(){return MobiShop_Push_Analytics::report()['campaigns'][0];}
campaign('campaign-test-1');
check(event('campaign-test-1')['recorded']===true,'First open accepted');
for($i=0;$i<100;$i++)check(event('campaign-test-1')['deduplicated']===true,'Repeated opens deduplicated');
check(event('campaign-test-1','delivered')['deduplicated']===true,'Open already proves receipt');
check(event('unknown-campaign') instanceof WP_Error,'Unknown campaign rejected');
check(event('campaign-test-1','opened','unrelated-device') instanceof WP_Error,'Wrong audience rejected');
check(event('campaign-test-1','converted') instanceof WP_Error,'Unverified client purchases rejected');
$row=report();check($row['targeted']===1&&$row['received']===1&&$row['opened']===1,'Unique audience and receipt totals');
MobiShop_Push_Analytics::finish(['id'=>'campaign-test-1','status'=>'sent','delivery'=>['sent'=>2,'failed'=>1]]);
check(report()['opened']===1&&report()['sent']===2,'Finishing transport cannot reset early receipts');
$order=new WC_Order();$request=new WP_REST_Request([],['X-MobiShop-Push-Client'=>'device-test-123']);
MobiShop_Push_Analytics::attribute_order($order,$request);check($order->get_meta('_mobishop_push_campaign')==='campaign-test-1','Recent click attributed');
MobiShop_Push_Analytics::sync_order($order);MobiShop_Push_Analytics::sync_order($order);
check(report()['orders']===1&&report()['buyers']===1&&report()['paid_orders']===0,'Unpaid accepted order is deduplicated and distinguished');
$order->paid=true;$order->refund=50;MobiShop_Push_Analytics::sync_order($order);
check(report()['paid_orders']===1&&(float)report()['revenue']['EGP']===100.5,'Server payment and partial refund update revenue');
$second=new WC_Order(11,5,'USD','5.25');$second->meta=$order->meta;MobiShop_Push_Analytics::sync_order($second);
check(report()['orders']===2&&report()['buyers']===1&&count(report()['revenue'])===2,'Currencies stay separate and buyer is unique');
$order->status='cancelled';MobiShop_Push_Analytics::sync_order($order);check(report()['orders']===1&&!isset(report()['revenue']['EGP']),'Cancelled order removed from conversion');
$second->status='refunded';MobiShop_Push_Analytics::sync_order($second);check(report()['orders']===0,'Fully refunded order excluded');
$wpdb->query("UPDATE test_mobishop_push_events_v2 SET occurred_at='2000-01-01 00:00:00' WHERE event='opened'");
$expired=new WC_Order(12);MobiShop_Push_Analytics::attribute_order($expired,$request);check(!$expired->get_meta('_mobishop_push_campaign'),'Expired click not attributed');
$website=new WC_Order(13);$website->meta=[];MobiShop_Push_Analytics::attribute_order($website,$request);check(!$website->get_meta('_mobishop_push_campaign'),'Website order not misclassified');
check(!str_contains(json_encode(MobiShop_Push_Analytics::report()),hash('sha256','device-test-123')),'No device hashes exposed');
echo "Push analytics SQL contracts passed: deduplication, audience isolation, verified orders, refunds, currencies and expiry.\n";
