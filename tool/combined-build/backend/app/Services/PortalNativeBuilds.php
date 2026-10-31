<?php

namespace App\Services;

use App\Http\Requests\CreateApkBuildRequest;
use App\Models\BuildIntent;
use App\Models\LicenseActivation;
use App\Models\Store;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;
use RuntimeException;

/** Authenticated Store adapter; it never impersonates the license API middleware. */
final class PortalNativeBuilds
{
    public function __construct(private readonly ApkBuildRequestService $buildRequests) {}

    public function prepare(Store $store): array
    {
        $activation = $this->activation($store);
        $notifications = app(StoreNotifications::class);
        $project = $notifications->project($store);
        $setup = \App\Models\StoreSetup::where('store_id', $store->id)->first();
        // Onboarding already confirms the connector. Reposting that connection
        // for every build made a healthy saved project depend on website latency.
        $prepared = $project && $project->status === 'ready'
            && (string) $project->license_activation_id === (string) $activation->id
            && $setup?->revision >= StoreOnboarding::REVISION
            && ($setup?->steps['notifications'] ?? '') === 'ready'
            && app(ConnectedStorePush::class)->config($store, 'android')['clientReady'];
        if (!$prepared) $notifications->prepare($store, $activation);
        $snapshot = NativeBuildRouting::bindSnapshot($activation, [
            "builder_project" => "central-builder",
            "schema_version" => SavedBuilderNativeDesign::REVISION,
        ], $store->site_url);
        $bundle = $snapshot["build"]["dartDefines"]["APP_DESIGN_BUNDLE"] ?? null;
        if (!is_string($bundle)) throw new RuntimeException("Save the app design in the Builder before requesting a Native build.");
        $design = json_decode(base64_decode($bundle, true), true, 64, JSON_THROW_ON_ERROR);
        $snapshot["pages"] = $design["pages"];
        return ["activation" => $activation, "snapshot" => $snapshot, "app_name" => $design["identity"]["app_name"],
            "store_locale" => $design["identity"]["language"]];
    }

    public function defaults(Store $store, BuildIntent $intent): array
    {
        $saved = is_array($intent->metadata) ? ($intent->metadata["native_build_options"] ?? []) : [];
        if (!is_array($saved)) $saved = [];
        $previous = $this->activation($store)->builds()->latest("requested_at")->first();
        $options = [];
        foreach (["package_name", "version_name", "version_code"] as $key) {
            $options[$key] = $saved[$key] ?? $previous?->{$key} ?? "";
        }
        $project=app(StoreNotifications::class)->project($store);
        if ($project && is_string($project->android_package)) $options['package_name']=$project->android_package;
        // Reuse the app identity already prepared for this store.
        $options["platform"] = $saved["platform"] ?? "android";
        return $options;
    }

    public function create(Store $store, BuildIntent $intent, array $submitted): JsonResponse
    {
        if ((string) $intent->store_id !== (string) $store->getKey()
            || (string) $intent->user_id !== (string) $store->user_id) {
            throw new RuntimeException("The build request does not belong to this store.");
        }
        $prepared = $this->prepare($store);
        $project=app(StoreNotifications::class)->project($store);
        if ($project && ($submitted['package_name']??'') !== $project->android_package) {
            throw new RuntimeException('Use this store’s prepared application ID so its notification connection remains valid.');
        }
        $dual = ($submitted['platform'] ?? 'android') === 'both';
        if ($dual && app(NativeSigningRegistry::class)->dualReleaseIdentity($store, $project, $submitted['package_name'] ?? null) === null) {
            throw new RuntimeException('Verified Android release signing and Apple signing are required for a combined build. An Android test build is available separately.');
        }
        if ($dual) $prepared['snapshot']['build_targets'] = ['android', 'ios'];
        $input = [
            "store_url" => $store->site_url,
            "app_name" => $prepared["app_name"],
            "package_name" => $submitted["package_name"] ?? null,
            "version_name" => $submitted["version_name"] ?? null,
            "version_code" => $submitted["version_code"] ?? null,
            "platform" => $submitted["platform"] ?? null,
            "artifact" => $dual ? "zip" : "apk",
            "settings_snapshot" => $prepared["snapshot"],
            "store_locale" => $prepared["store_locale"],
            "push_config_url" => $store->platform === 'woocommerce'
                ? rtrim($store->site_url,'/').'/wp-json/mobishop/v1/push/config'
                : url('/v1/stores/'.$store->public_id.'/push/config'),
            "metadata" => ["requested_from" => "customer_portal", "build_intent_id" => $intent->getKey(), "build_targets" => $dual ? ["android", "ios"] : ["android"]],
        ];
        $form = new CreateApkBuildRequest();
        $rules = $form->rules();
        $rules["platform"] = ["required", "in:android,both"];
        $input = Validator::make($input, $rules, $form->messages())->validate();
        $metadata = $intent->metadata ?? [];
        $metadata["native_build_options"] = array_intersect_key($input, array_flip(["package_name", "version_name", "version_code", "platform"]));
        $intent->forceFill(["metadata" => $metadata])->save();
        $result = $this->buildRequests->create($prepared["activation"], $input, static fn ($build): array => ["id" => $build->getKey()]);
        $data = $result->getData(true);
        if (is_string($data["build"]["id"] ?? null)) {
            // Link the server-owned result through the actual model field,
            // including a failed provider dispatch that still has a build row.
            $intent->forceFill(["apk_build_id" => $data["build"]["id"]])->save();
        }
        return $result;
    }

    private function activation(Store $store): LicenseActivation
    {
        if (!in_array($store->platform, ["woocommerce", "odoo", "shopify"], true)) {
            throw new RuntimeException("This store has no supported Native build platform.");
        }
        if ($store->connection_status !== "connected") {
            throw new RuntimeException("Connect or reconnect this store before requesting its Native build.");
        }
        $store->loadMissing("licenses.activations");
        $host = strtolower((string) parse_url($store->site_url, PHP_URL_HOST));
        $candidates = [];
        foreach ($store->licenses as $license) {
            if ((string) $license->store_id !== (string) $store->getKey()
                || (string) $license->user_id !== (string) $store->user_id || !$license->isUsable()
                || !in_array("apk_builds", $license->plan->entitlements(), true)) continue;
            foreach ($license->activations as $activation) {
                if ((string) $activation->license_id !== (string) $license->getKey() || !$activation->isActive()
                    || strtolower((string) $activation->site_host) !== $host) continue;
                $candidates[] = $activation;
            }
        }
        if ($candidates === []) {
            throw new RuntimeException("Activate an APK-build license for this registered store before starting its Native build.");
        }
        if (count($candidates) !== 1) {
            throw new RuntimeException("This store has multiple active build installations; review its linked license installations before building.");
        }
        return $candidates[0];
    }
}
