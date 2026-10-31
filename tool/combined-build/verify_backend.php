<?php
// Uses real current store/configuration, but fakes Codemagic and writes no database rows.
chdir('/home/woomobile/woomobile-api'); require 'vendor/autoload.php';
$app=require 'bootstrap/app.php'; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$stage=storage_path('app/private/combined-build-20261031');
foreach (glob($stage.'/backend/app/Services/*.php') as $file) require $file;
use App\Services\{NativeSigningRegistry,AndroidReleaseSigningIdentity,ConnectedStorePush,CodemagicClient,NativeBuildReadiness,BuildProgressPresenter};
use Illuminate\Support\Facades\{Http,Storage};
$count=0;
function check($condition,$message) { global $count; if (!$condition) throw new RuntimeException('FAIL: '.$message); $count++; }
$store=App\Models\Store::where('public_id','6990b322-e396-46bb-a188-a1e472b6bf64')->firstOrFail();
$row=json_decode(file_get_contents($stage.'/registration.json'),true,32,JSON_THROW_ON_ERROR);
$configKey='native_signing.stores.'.$store->public_id;
config([$configKey=>$row]);
$registry=app(NativeSigningRegistry::class); $push=app(ConnectedStorePush::class); $project=$push->project($store);
check($registry->dualReleaseIdentity($store,$project)!==null,'managed combined identity ready');
check(!$registry->pushReady($store,$project),'APNs not falsely enabled');
$ready=app(NativeBuildReadiness::class)->forStore($store);
check($ready['available_platforms']===['android','ios'] && $ready['android_release_ready'],'button offers both');
check($ready['ios_push_ready']===false,'separate iOS push status');
foreach ([['owner_id'=>99999],['site_host'=>'another.invalid'],['expires_at'=>'2020-01-01'],['verified_at'=>'2099-01-01'],
    ['bundle_id'=>'app.foreign.store'],['firebase_project_id'=>'foreign-project'],['android_package_name'=>'app.other.store'],
    ['android_certificate_sha256'=>str_repeat('a',64)],['android_release_verified'=>false],['android_expires_at'=>'2020-01-01'],
    ['workflow_id'=>'foreign-workflow'],['signing_provider'=>'unrecognized'],['android_signing_provider'=>'secret_group']] as $change) {
    config([$configKey=>array_replace($row,$change)]);
    check($registry->dualReleaseIdentity($store,$project)===null,'reject '.implode(',',array_keys($change)));
}
config([$configKey=>$row]);
check($registry->dualReleaseIdentity($store,$project,'app.other.package')===null,'reject requested foreign package');
$foreign=clone $store; $foreign->user_id=99999;
check($registry->identity($foreign)===null,'owner isolation');
$foreign=clone $store; $foreign->public_id='00000000-0000-0000-0000-000000000001';
config(['native_signing.stores.'.$foreign->public_id=>$row]);
check($registry->identity($foreign)===null,'managed workflow cannot be assigned to another store');
$variables=app(AndroidReleaseSigningIdentity::class)->variables($store,$row);
check(!isset($variables['MOBISHOP_QA_KEYSTORE']) && strlen($variables['CM_KEYSTORE_PASSWORD'])>=32,'release credentials only');
$previous=App\Models\ApkBuild::whereHas('activation.license',fn($q)=>$q->where('store_id',$store->id))->latest('requested_at')->firstOrFail();
$snapshot=json_decode(Storage::disk('local')->get($previous->settings_archive_path),true,512,JSON_THROW_ON_ERROR);
$snapshot['build_targets']=['android','ios'];
$testPath='combined-build-test/'.Illuminate\Support\Str::uuid().'.json';
Storage::disk('local')->put($testPath,json_encode($snapshot,JSON_THROW_ON_ERROR));
try {
    $build=clone $previous; $build->settings_archive_path=$testPath; $build->version_code=max(302,1+(int)$previous->version_code);
    $build->metadata=['build_targets'=>['android','ios']];
    $calls=[];
    Http::fake(function($request) use (&$calls) {
        if (!str_starts_with($request->url(),'https://api.codemagic.io/')) throw new RuntimeException('Unexpected outbound request in test.');
        $calls[]=$request->data(); return Http::response(['buildId'=>'test-dispatch-only'],200);
    });
    check(app(CodemagicClient::class)->start($build)==='test-dispatch-only','dispatch accepted');
    check(count($calls)===1,'exactly one combined provider build');
    $payload=$calls[0]; $env=$payload['environment']['variables'];
    check($payload['workflowId']==='kidia-managed-dual-release','managed workflow selected');
    check(!isset($payload['environment']['groups']),'no unrelated secret groups');
    check($env['ANDROID_APPLICATION_ID']===$row['android_package_name'] && $env['IOS_BUNDLE_ID']===$row['bundle_id'],'both existing identities preserved');
    check($env['MOBISHOP_ANDROID_BUILD_MODE']==='release' && $env['MOBISHOP_REQUIRE_RELEASE_SIGNING']==='true','release mode enforced');
    check(isset($env['CM_KEYSTORE']) && !isset($env['MOBISHOP_QA_KEYSTORE']),'correct signing credentials dispatched');
    check($env['APP_DESIGN_BUNDLE']===$snapshot['build']['dartDefines']['APP_DESIGN_BUNDLE'],'saved design preserved');
    check((int)$env['BUILD_VERSION_CODE']>=302,'new version above existing Apple build');
    $view=BuildProgressPresenter::present($build);
    check($view['platforms']===['android','ios'] && str_contains($view['output_label'],'IPA'),'correct progress outputs');
} finally { Storage::disk('local')->delete($testPath); }
echo json_encode(['passed'=>$count,'codemagic_requests_sent'=>0,'database_rows_written'=>0,'platforms'=>$ready['available_platforms'],'ios_push_ready'=>$ready['ios_push_ready']],JSON_PRETTY_PRINT).PHP_EOL;
