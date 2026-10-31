<?php

namespace App\Http\Controllers\Portal;

use App\Http\Controllers\Controller;
use App\Models\ApkBuild;
use App\Models\BuildIntent;
use App\Models\Store;
use App\Services\CodemagicBuildSynchronizer;
use App\Services\PortalNativeBuilds;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/** Customer-facing flow: server-owned identity, existing entitlement checks. */
final class PortalQuickBuildController extends Controller
{
    public function start(Request $request, Store $store): JsonResponse
    {
        abort_unless((string) $store->user_id === (string) $request->user()->id, 404);
        $store->load('licenses');
        if (!$store->hasBuildEntitlement()) {
            return response()->json(['ok'=>false,'message'=>'فعّل اشتراك بناء التطبيق أولًا.',
                'billing_url'=>route('portal.billing',['store'=>$store->public_id])],403);
        }
        try {
            app(\App\Services\StoreOnboarding::class)->request($store);
            $setup=app(\App\Services\NativeBuildReadiness::class)->forStore($store);
            if (!$setup['ready']) return response()->json(['ok'=>!$setup['blocked'],
                'preparing'=>!$setup['blocked'],'setup'=>$setup,'message'=>$setup['message']],$setup['blocked']?409:202);
            // Serialize automatic version allocation, including simultaneous tabs.
            return DB::transaction(function () use ($request, $store): JsonResponse {
                $store = Store::query()->whereKey($store->getKey())->lockForUpdate()->firstOrFail();
                $native = app(PortalNativeBuilds::class);
                $intent = BuildIntent::query()->create(['id'=>(string) Str::uuid(),
                    'user_id'=>$request->user()->id,'store_id'=>$store->id,'status'=>'ready',
                    'metadata'=>['requested_from'=>'one_click_builder']]);
                $previous = $this->latest($store);
                $options = $native->defaults($store,$intent);
                $options['package_name'] = $options['package_name'] ?: 'app.woomobile.store.s'.str_replace('-','',$store->public_id);
                $options['version_name'] = $options['version_name'] ?: '1.0.0';
                $registration = app(\App\Services\NativeSigningRegistry::class)->identity($store);
                $lastCode = max((int) ApkBuild::query()->whereHas('activation.license', fn($q)=>$q->where('store_id',$store->id))->max('version_code'),
                    (int) ($options['version_code'] ?? 0), (int) ($registration['minimum_build_number'] ?? 1) - 1);
                if ($lastCode >= 2100000000) throw new RuntimeException('وصل رقم إصدار التطبيق للحد الأقصى. تواصل مع الدعم.');
                $options['version_code'] = max(1, $lastCode + 1);
                $project=app(\App\Services\ConnectedStorePush::class)->project($store);
                $options['platform'] = app(\App\Services\NativeSigningRegistry::class)->dualReleaseIdentity($store,$project,$options['package_name']) !== null ? 'both' : 'android';
                $result = $native->create($store,$intent,$options);
                $data = $result->getData(true);
                if ($result->getStatusCode() >= 400 || ($data['ok']??false)!==true) {
                    // Roll back the intent and propagate a useful error after rollback.
                    throw new RuntimeException($data['error']['message']??'تعذّر بدء البناء. حاول مرة أخرى.');
                }
                $intent->forceFill(['status'=>'resumed','resumed_at'=>now(),'apk_build_id'=>$data['build']['id']])->save();
                return response()->json(['ok'=>true,'reused'=>$data['reused']??false,
                    'status_url'=>route('portal.quick-build.status',['store'=>$store->public_id])]);
            });
        } catch (\Illuminate\Http\Client\ConnectionException | \Illuminate\Http\Client\RequestException $exception) {
            return response()->json(['ok'=>false,'message'=>'The store connection is temporarily unavailable. Please try again shortly.'],422);
        } catch (RuntimeException $exception) {
            return response()->json(['ok'=>false,'message'=>$exception->getMessage()],422);
        }
    }

    public function status(Request $request, Store $store): JsonResponse
    {
        abort_unless((string) $store->user_id === (string) $request->user()->id,404);
        $build=$this->latest($store);
        $setup=app(\App\Services\NativeBuildReadiness::class)->forStore($store);
        if (!$build) return response()->json(['ok'=>true,'build'=>null,'setup'=>$setup])->header('Cache-Control','no-store');
        $build=app(CodemagicBuildSynchronizer::class)->sync($build);
        $status=$build->status->value;
        return response()->json(['ok'=>true,'setup'=>$setup,'build'=>['id'=>$build->id,'status'=>$status,'cancel_url'=>route('portal.builds.cancel',$build),
            ...\App\Services\BuildProgressPresenter::present($build),'version'=>$build->version_name,'error'=>in_array($status,['failed','cancelled'],true)?$build->error_message:null,
            'download_url'=>$status==='completed' && !empty($build->artifact_urls['bundle'])
                ?route('portal.builds.download',$build):null]])->header('Cache-Control','no-store');
    }

    private function latest(Store $store): ?ApkBuild
    {
        return ApkBuild::query()->whereHas('activation.license',fn($q)=>$q->where('store_id',$store->id))
            ->latest('requested_at')->first();
    }
}
