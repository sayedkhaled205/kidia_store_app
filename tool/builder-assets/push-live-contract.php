<?php
/** CLI-only, transactional checks. Never sends a push or creates a commerce order. */
if (PHP_SAPI !== 'cli') exit(1);
function verify_push($condition, $label) { if (!$condition) throw new RuntimeException($label); }
$mode=$argv[1]??''; $root=$argv[2]??'';
$GLOBALS['push_live_contract_stage']='bootstrap';
register_shutdown_function(static function(){
    if($GLOBALS['push_live_contract_stage']!=='complete') {
        fwrite(STDERR,'Push contract incomplete at '.$GLOBALS['push_live_contract_stage'].PHP_EOL);
        exit(1);
    }
});
if ($mode==='wordpress') {
    require $root.'/wp-load.php';
    set_exception_handler(static function(Throwable $error){fwrite(STDERR,'Push contract failed: '.$error->getMessage().PHP_EOL);exit(1);});
    $GLOBALS['push_live_contract_stage']='schema';
    MobiShop_Push_Analytics::install();
    global $wpdb;
    foreach (['campaigns','events','orders'] as $kind) {
        $table=MobiShop_Push_Analytics::table($kind);
        $engine=$wpdb->get_var($wpdb->prepare('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s',$table));
        verify_push(strtolower((string)$engine)==='innodb','Transactional analytics table required');
    }
    $id='qa-'.bin2hex(random_bytes(12)); $client='qa-client-'.bin2hex(random_bytes(12));
    $wpdb->query('START TRANSACTION');
    $GLOBALS['push_live_contract_stage']='receipt';
    try {
        MobiShop_Push_Analytics::begin(['id'=>$id,'title'=>'Transactional QA','message'=>'No push is sent','audience'=>'test'],[['client_id'=>$client,'platform'=>'android']]);
        $event=new WP_REST_Request('POST');
        $event->set_param('notification_id',$id);$event->set_param('client_id',$client);$event->set_param('event','opened');
        for($i=0;$i<25;$i++) {
            $result=MobiShop_Push_Analytics::record($event);
            verify_push(!is_wp_error($result),'Valid targeted receipt');
            verify_push($result->get_data()[$i===0?'recorded':'deduplicated']===true,'Atomic receipt deduplication');
        }
        $event->set_param('client_id','qa-unrelated-client');
        verify_push(is_wp_error(MobiShop_Push_Analytics::record($event)),'Reject unrelated recipient');
        $event->set_param('client_id',$client);$event->set_param('event','converted');
        verify_push(is_wp_error(MobiShop_Push_Analytics::record($event)),'Reject client-claimed purchase');
        MobiShop_Push_Analytics::finish(['id'=>$id,'status'=>'sent','delivery'=>['sent'=>1,'failed'=>0]]);
        $find=static function()use($id){foreach(MobiShop_Push_Analytics::report()['campaigns'] as $row)if($row['id']===$id)return $row;throw new RuntimeException('Campaign absent');};
        $row=$find();verify_push($row['targeted']===1&&$row['received']===1&&$row['opened']===1,'Verified report totals');
        // Unsaved object: sync_order writes only the isolated analytics transaction.
        $GLOBALS['push_live_contract_stage']='order-object';
        $order=new WC_Order();$order->set_id(900000000001);$order->set_date_created(time());$order->set_currency('EGP');$order->set_total('123.45');$order->set_status('processing');
        $order->update_meta_data('_mobishop_order_source','mobile');
        $request=new WP_REST_Request('POST');$request->set_header('X-MobiShop-Push-Client',$client);
        MobiShop_Push_Analytics::attribute_order($order,$request);
        verify_push($order->get_meta('_mobishop_push_campaign')===$id,'Server click attribution');
        MobiShop_Push_Analytics::sync_order($order);MobiShop_Push_Analytics::sync_order($order);
        $row=$find();verify_push($row['orders']===1&&$row['buyers']===1&&(float)($row['revenue']['EGP']??0)===(float)$order->get_total(),'MySQL commerce aggregation respects store currency precision');
        $order->set_status('cancelled');MobiShop_Push_Analytics::sync_order($order);
        verify_push($find()['orders']===0,'Cancellation removes conversion');
    } finally { $wpdb->query('ROLLBACK'); }
    verify_push((int)$wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM '.MobiShop_Push_Analytics::table('campaigns').' WHERE id=%s',$id))===0,'Fixture rolled back');
    echo "WordPress MySQL checks passed: schema, 25 duplicate receipts, recipient isolation, verified order, cancellation and rollback.\n";
} elseif ($mode==='central') {
    require $root.'/vendor/autoload.php';$app=require $root.'/bootstrap/app.php';$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
    $db=Illuminate\Support\Facades\DB::class;
    foreach(['store_push_events','store_push_campaigns'] as $table) {
        $engine=$db::selectOne('SELECT ENGINE AS engine FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?',[$table]);
        verify_push(strtolower($engine->engine??'')==='innodb','Transactional central table required');
    }
    $stores=App\Models\Store::orderBy('id')->limit(2)->get();verify_push(count($stores)===2,'Two stores needed for tenant-isolation check');
    $id=(string)Illuminate\Support\Str::uuid();$client='qa-client-'.bin2hex(random_bytes(12));
    $db::beginTransaction();
    try {
        $db::table('store_push_campaigns')->insert(['id'=>$id,'store_id'=>$stores[0]->id,'request_id'=>$id,'status'=>'sent','payload'=>json_encode(['title'=>'Transactional QA','message'=>'No push is sent']),'sent'=>1,'failed'=>0,'created_at'=>now(),'updated_at'=>now()]);
        $db::table('store_push_events')->insert(['campaign_id'=>$id,'store_id'=>$stores[0]->id,'event'=>'target_v2','client_hash'=>hash('sha256',$client),'created_at'=>now(),'updated_at'=>now()]);
        $controller=app(App\Http\Controllers\Api\V1\StorePushController::class);
        $request=static fn($event,$device)=>Illuminate\Http\Request::create('/','POST',['notification_id'=>$id,'event'=>$event,'client_id'=>$device]);
        for($i=0;$i<25;$i++) {
            $result=$controller->event($request('opened',$client),$stores[0])->getData(true);
            verify_push($result[$i===0?'recorded':'deduplicated']===true,'Central atomic deduplication');
        }
        foreach([[$stores[1],$client],[$stores[0],'qa-unrelated-client']] as [$store,$device]) {
            try {$controller->event($request('opened',$device),$store);throw new RuntimeException('Wrong tenant/recipient accepted');}
            catch(Symfony\Component\HttpKernel\Exception\HttpException $error){verify_push($error->getStatusCode()===404,'Isolation returns 404');}
        }
        try {$controller->event($request('converted',$client),$stores[0]);throw new RuntimeException('Unverified purchase accepted');}
        catch(Illuminate\Validation\ValidationException $error){}
        $report=app(App\Services\ConnectedPushAnalytics::class)->forStore($stores[0]);
        $rows=array_values(array_filter($report['campaigns'],fn($row)=>$row['id']===$id));
        verify_push(count($rows)===1&&$rows[0]['targeted']===1&&$rows[0]['received']===1&&$rows[0]['opened']===1,'Central aggregates');
        verify_push($report['conversion_supported']===false,'Unsupported conversion clearly identified');
        $other=app(App\Services\ConnectedPushAnalytics::class)->forStore($stores[1]);
        verify_push(!in_array($id,array_column($other['campaigns'],'id'),true),'Other store report cannot see campaign');
    } finally {$db::rollBack();}
    verify_push(!$db::table('store_push_campaigns')->where('id',$id)->exists(),'Central fixture rolled back');
    echo "Central MySQL checks passed: 25 duplicate receipts, tenant/recipient isolation, rejection of fake purchases, aggregates and rollback.\n";
} else {throw new InvalidArgumentException('Use wordpress or central and an application root.');}
$GLOBALS['push_live_contract_stage']='complete';
