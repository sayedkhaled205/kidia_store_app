<?php

namespace App\Services;

use App\Enums\ApkBuildStatus;
use App\Http\Requests\CreateApkBuildRequest;
use App\Jobs\BuildApk;
use App\Models\ApkBuild;
use App\Models\LicenseActivation;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/** One protected creation path for the license API and authenticated Store portal. */
final class ApkBuildRequestService
{
    public function __construct(private readonly CodemagicBuildSynchronizer $codemagic) {}

    public function create(LicenseActivation $activation, array $input, \Closure $present): JsonResponse
    {
        if (!$activation->isActive()) {
            return response()->json(["ok" => false, "error" => ["code" => "license_activation_inactive", "message" => "The store license activation is not active."]], 403);
        }

        if (
            !in_array(
                "apk_builds",
                $activation->license->plan->entitlements(),
                true,
            )
        ) {
            return response()->json(
                [
                    "ok" => false,
                    "error" => [
                        "code" => "plan_upgrade_required",
                        "message" =>
                            "APK builds are not included in this license plan.",
                    ],
                ],
                403,
            );
        }

        try {
            $input["settings_snapshot"] = NativeBuildRouting::bindSnapshot($activation, $input["settings_snapshot"], $input["store_url"]);
        } catch (RuntimeException $exception) {
            return response()->json(["ok" => false, "error" => ["code" => "invalid_native_build_config", "message" => $exception->getMessage()]], 422);
        }
        $targets = $input["settings_snapshot"]["build_targets"] ?? [];
        sort($targets);
        if (($input["platform"] ?? "android") === "both" || $targets !== []) {
            if (($input["platform"] ?? null) !== "both" || ($input["artifact"] ?? null) !== "zip"
                || $targets !== ["android", "ios"]
                || !in_array($input["settings_snapshot"]["builder_project"] ?? null, ["wordpress-plugin", "central-builder"], true)
                || (($input["settings_snapshot"]["builder_project"] ?? null) === "central-builder" && empty($input["settings_snapshot"]["native_design_revision"]))) {
                return response()->json(["ok" => false, "error" => ["code" => "invalid_build_targets", "message" => "A combined build requires both Android and iOS targets."]], 422);
            }
        }
        $requestedHost = strtolower((string) parse_url($input["store_url"], PHP_URL_HOST));
        $activationHost = strtolower($activation->site_host);
        if (preg_replace('/^www\./', '', $requestedHost) !== preg_replace('/^www\./', '', $activationHost)) {
            return response()->json([
                "ok" => false,
                "error" => [
                    "code" => "store_url_mismatch",
                    "message" => "The build store URL must match the activated site.",
                ],
            ], 422);
        }

        // A merchant may cancel a build directly in Codemagic while the local
        // record still says "building". Refresh that record before applying
        // the single-flight guard, otherwise a new click would reuse the old,
        // cancelled build and immediately report it as failed/cancelled.
        $possiblyActiveBuild = $activation->builds()
            ->whereIn("status", self::activeStatuses())
            ->latest("requested_at")
            ->first();
        if ($possiblyActiveBuild !== null && $possiblyActiveBuild->codemagic_build_id !== null) {
            $this->codemagic->sync($possiblyActiveBuild, true);
        }

        [$build, $reused] = DB::transaction(function () use ($activation, $input): array {
            // Serialize build creation per activation. This database lock is the
            // authoritative guard against double-clicks, refreshes and requests
            // coming from another browser at the same time.
            $lockedActivation = LicenseActivation::query()
                ->whereKey($activation->getKey())
                ->lockForUpdate()
                ->firstOrFail();
            $activeBuild = $lockedActivation->builds()
				->whereIn("status", self::activeStatuses())
                ->latest("requested_at")
                ->first();

            if ($activeBuild !== null) {
                $activeTargets = $activeBuild->metadata['build_targets'] ?? ['android'];
                $requestedTargets = $input['metadata']['build_targets'] ?? ['android'];
                sort($activeTargets); sort($requestedTargets);
                if ($activeTargets !== $requestedTargets) throw new RuntimeException('A build for different platforms is already running. Wait for it to finish or cancel it before building both platforms.');
                return [$activeBuild, true];
            }

            $snapshot = NativeBuildRouting::bindSnapshot($lockedActivation, $input["settings_snapshot"], $input["store_url"]);
            if (($snapshot["builder_project"] ?? null) === "central-builder") {
                // A Builder save may land during the provider refresh. All
                // identity/pages must belong to this FINAL locked revision.
                $design = json_decode(base64_decode($snapshot["build"]["dartDefines"]["APP_DESIGN_BUNDLE"], true), true, 64, JSON_THROW_ON_ERROR);
                $input["app_name"] = $design["identity"]["app_name"];
                $input["store_locale"] = $design["identity"]["language"];
                $snapshot["pages"] = $design["pages"];
                $input["settings_snapshot"] = $snapshot;
                $form = new CreateApkBuildRequest();
                $input = Validator::make($input, $form->rules(), $form->messages())->validate();
            }
            if (($input['platform'] ?? '') === 'both') {
                $store = $lockedActivation->license->store;
                $registration = app(NativeSigningRegistry::class)->identity($store);
                $minimum = max((int) ($registration['minimum_build_number'] ?? 1),
                    1 + (int) ApkBuild::query()->whereHas('activation.license', fn($q)=>$q->where('store_id',$store->id))->max('version_code'));
                if ((int) $input['version_code'] < $minimum) throw new RuntimeException('Use a new build number (at least '.$minimum.') for both platforms.');
            }
            $buildId = (string) Str::uuid();
            $snapshotPath = "build-inputs/{$lockedActivation->getKey()}/{$buildId}.json";
            Storage::disk("local")->put(
                $snapshotPath,
                json_encode(
                    $snapshot,
                    JSON_UNESCAPED_SLASHES |
                        JSON_UNESCAPED_UNICODE |
                        JSON_THROW_ON_ERROR,
                ),
            );

            return [
                $lockedActivation->builds()->create([
                    "id" => $buildId,
                    "status" => ApkBuildStatus::Queued,
                    "version_name" => $input["version_name"],
                    "version_code" => $input["version_code"],
                    "app_name" => $input["app_name"],
                    "package_name" => $input["package_name"],
                    "store_url" => rtrim($input["store_url"], "/"),
                    "store_locale" => $input["store_locale"] ?? "en",
                    "push_config_url" => $input["push_config_url"] ?? null,
                    "settings_archive_path" => $snapshotPath,
                    "requested_at" => now(),
                    "metadata" => $input["metadata"] ?? null,
                ]),
                false,
            ];
        }, 3);

        if ($reused) {
            return response()->json(
                [
                    "ok" => true,
                    "reused" => true,
                    "message" => "A build is already in progress for this site.",
                    "build" => $present($this->codemagic->sync($build)),
                ],
                202,
            );
        }

        try {
            // Starting the remote build must not depend on a long-running queue
            // worker. The Codemagic request is short; Codemagic performs the
            // actual build asynchronously and reports progress via callbacks.
            BuildApk::dispatchSync($build->getKey());
            $build->refresh();
        } catch (Throwable $exception) {
            $build->refresh();

            return response()->json(
                [
                    "ok" => false,
                    "error" => [
                        "code" => $build->error_code ?? "codemagic_dispatch_failed",
                        "message" => $build->error_message
                            ?? "The build could not be sent to Codemagic.",
                    ],
                    "build" => $present($build),
                ],
                502,
            );
        }

        return response()->json(
            [
                "ok" => true,
                "reused" => false,
                "build" => $present($build),
            ],
            202,
        );
    }

    /** @return list<string> */
    private static function activeStatuses(): array
    {
        return [
            ApkBuildStatus::Queued->value,
            ApkBuildStatus::Preparing->value,
            ApkBuildStatus::Building->value,
            ApkBuildStatus::Signing->value,
        ];
    }

}
