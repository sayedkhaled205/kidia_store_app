<?php
namespace App\Services;

use App\Models\Store;
use Illuminate\Support\Facades\Http;

/** Woo uses its unchanged connector; foreign designs await Dashboard's durable commit. */
final class BuilderApplicationState
{
    public const SCREENS = ['home-builder','category-builder','catalog-builder','product-builder','size-chart-builder','wishlist-builder','account-builder','checkout-builder','splash','website-promotion','setup'];

    public function forStore(Store $store,string $screen,array $state,bool $validateOnly=false): array
    {
        $error = static fn(string $code): array => ['ok'=>false,'code'=>$code,'message'=>'Application settings could not be confirmed. Your builder draft has not been marked as applied.'];
        if (!in_array($screen,self::SCREENS,true)) return $error('unsupported_screen');
        if (in_array($store->platform, ['shopify', 'odoo'], true)) {
            $settings = is_array($store->settings ?? null) ? $store->settings : [];
            $screens = is_array($settings['builder']['screens'] ?? null) ? $settings['builder']['screens'] : [];
            return ForeignBuilderDesignSave::prepare((string) $store->platform, $screen, $state, $screens,
                (string) ($store->public_id ?? $store->id ?? ''), $validateOnly);
        }
        if ($store->platform !== 'woocommerce') return $error('unsupported_platform');
        $url=rtrim((string)$store->site_url,'/');
        if(parse_url($url,PHP_URL_SCHEME)!=='https' || trim((string)$store->wordpress_user)==='' || trim((string)$store->wordpress_application_password)==='') return $error('connection_required');
        if(!isset($state['entries']) || !is_array($state['entries']) || count($state['entries'])>10000) return $error('invalid_state');
        foreach($state['entries'] as $entry) {
            if(!is_array($entry) || array_keys($entry)!==[0,1] || !is_string($entry[0]) || !is_string($entry[1])) return $error('invalid_state');
        }
        try {
            $body=json_encode(['screen'=>$screen,'state'=>$state,'validate_only'=>$validateOnly],JSON_THROW_ON_ERROR);
            if(strlen($body)>2097152) return $error('state_too_large');
            // A response timeout can follow a committed write. The shared transport
            // reconnects only with affirmative proof that no HTTP request was sent.
            $response=app(BuilderStoreRequest::class)->send(
                fn(array $options)=>Http::withBasicAuth($store->wordpress_user,$store->wordpress_application_password)
                    ->acceptJson()->withOptions(array_merge($options,['allow_redirects'=>false]))
                    ->post($url.'/wp-json/mobishop/v1/builder/application-state',[
                        'screen'=>$screen,'state'=>$state,'validate_only'=>$validateOnly,
                    ]), 45);
            $data=$response->json();
            if(!$response->successful() || !is_array($data) || ($data['ok']??null)!==true || ($data['screen']??null)!==$screen) return $error('application_sync_failed');
            if($validateOnly && ($data['validated']??null)!==true)return $error('invalid_receipt');
            if($validateOnly && $screen!=='setup')return ['ok'=>true,'validated'=>true,'screen'=>$screen];
            if(!$validateOnly && (($data['applied']??null)!==true || !is_string($data['receipt']??null) || !preg_match('/^[a-f0-9]{64}$/D',$data['receipt']))) return $error('invalid_receipt');
            $canonical=$data['state']??null;
            if(!is_array($canonical)||array_keys($canonical)!==['entries']||!is_array($canonical['entries'])||count($canonical['entries'])>10000) return $error('invalid_receipt');
            foreach($canonical['entries'] as $entry) if(!is_array($entry)||array_keys($entry)!==[0,1]||!is_string($entry[0])||!is_string($entry[1])) return $error('invalid_receipt');
            if(strlen(json_encode($canonical,JSON_THROW_ON_ERROR))>2097152) return $error('invalid_receipt');
            if($validateOnly)return ['ok'=>true,'validated'=>true,'screen'=>$screen,'state'=>$canonical];
            return ['ok'=>true,'applied'=>true,'screen'=>$screen,'receipt'=>$data['receipt'],'state'=>$canonical];
        } catch(\Throwable $exception) {
            \Illuminate\Support\Facades\Log::warning('builder_application_save_unconfirmed', [
                'store_id'=>$store->getKey(), 'screen'=>$screen,
                'validation_only'=>$validateOnly, 'exception_type'=>get_class($exception),
            ]);
            return $error('application_sync_uncertain');
        }
    }
}
