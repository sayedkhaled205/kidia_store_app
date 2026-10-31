<?php
chdir('/home/woomobile/woomobile-api'); require 'vendor/autoload.php';
$app=require 'bootstrap/app.php'; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$store=App\Models\Store::where('public_id','6990b322-e396-46bb-a188-a1e472b6bf64')->firstOrFail();
$builds=App\Models\ApkBuild::whereHas('activation.license',fn($q)=>$q->where('store_id',$store->id))->latest('requested_at')->limit(3)->get();
foreach($builds as $build) echo json_encode(['id'=>$build->id,'remote'=>$build->codemagic_build_id,'status'=>$build->status->value,
 'version'=>$build->version_code,'targets'=>$build->metadata['build_targets']??null,'error'=>$build->error_message,'requested'=>$build->requested_at]).PHP_EOL;
echo json_encode(['setup'=>app(App\Services\NativeBuildReadiness::class)->forStore($store),'workflow'=>app(App\Services\NativeSigningRegistry::class)->identity($store)['workflow_id']??null]).PHP_EOL;
