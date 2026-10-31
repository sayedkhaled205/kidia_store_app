<?php
namespace App\Services;
use App\Models\{Store,StoreSetup};

/** GET-safe readiness; only an explicit build POST queues missing preparation. */
final class NativeBuildReadiness
{
    public function forStore(Store $store): array
    {
        $setup=StoreSetup::where('store_id',$store->id)->first();
        $steps=$setup?->steps ?? [];
        $ready=$store->connection_status==='connected' && $store->hasBuildEntitlement()
            && $setup?->revision>=StoreOnboarding::REVISION;
        foreach (['design','commerce','license','checkout','notifications'] as $step) $ready=$ready && ($steps[$step]??'')==='ready';
        $ready=$ready && app(ConnectedStorePush::class)->config($store,'android')['clientReady'];
        $connected=$store->connection_status==='connected';
        $entitled=$store->hasBuildEntitlement();
        $iosConfigReady=(bool)$ready && app(ConnectedStorePush::class)->config($store,'ios')['firebaseOptions'] !== [];
        $iosReady=$iosConfigReady && app(NativeSigningRegistry::class)->dualReleaseIdentity(
            $store, app(ConnectedStorePush::class)->project($store)
        )!==null;
        $code=$setup?->error_code;
        $blocked=$store->connection_status!=='connected' || !$store->hasBuildEntitlement() || $setup?->status==='needs_attention';
        $message=match($code) {
            'connector_update_required'=>'Update the store connector to the latest version; preparation will continue automatically.',
            'connection_review_required'=>'Reconnect the store to restore the permissions required for its app.',
            'native_checkout_disabled'=>'App checkout is disabled by this store’s server configuration. Ask the store administrator to enable it.',
            'native_checkout_woocommerce_update_required'=>'Update WooCommerce to version 9.9 or later and PHP to version 8.1 or later; preparation will then continue automatically.',
            'native_checkout_installation_review_required'=>'The existing app checkout installation needs a server review. Previous orders have been preserved.',
            'ambiguous_activation'=>'This store has more than one active installation. Its connection needs review.',
            default=>$blocked?'The store connection or plan needs attention.':'Preparing your store connection automatically…',
        };
        return ['ready'=>(bool)$ready,'blocked'=>$blocked,'status'=>$setup?->status??'pending',
            'connected'=>$connected,'has_build_entitlement'=>$entitled,
            'steps'=>array_intersect_key($steps,array_flip(['design','commerce','license','checkout','notifications'])),
            'available_platforms'=>$ready?($iosReady?['android','ios']:['android']):[],
            'android_distribution'=>$iosReady?'release':'test','android_release_ready'=>$iosReady,
            'ios_status'=>$iosReady?'ready':($iosConfigReady?'release_signing_required':'apple_setup_required'),
            'ios_push_ready'=>app(ConnectedStorePush::class)->config($store,'ios')['clientReady'],
            'message'=>$ready?'Your store is ready to build.':$message,'retry_after'=>5];
    }
}
