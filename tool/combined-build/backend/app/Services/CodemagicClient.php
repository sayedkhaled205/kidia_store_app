<?php

namespace App\Services;

use App\Models\ApkBuild;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

class CodemagicClient
{
    public function start(ApkBuild $build): string
    {
        $token = (string) config("codemagic.api_token");
        $appId = (string) config("codemagic.app_id");
        $workflowId = (string) config("codemagic.workflow_id");
        $branch = (string) config("codemagic.branch");
        $snapshot = [];
        $dualBuild = false;
        // WordPress plugin requests use their own source branch. Central builder
        // requests retain the configured shared runtime branch.
        if ($build->settings_archive_path) {
            $snapshot = json_decode(
                Storage::disk("local")->get($build->settings_archive_path),
                true,
                512,
                JSON_THROW_ON_ERROR,
            );
            if (($snapshot["builder_project"] ?? null) === "wordpress-plugin" || (($snapshot["builder_project"] ?? null) === "central-builder" && !empty($snapshot["native_design_revision"]))) {
                $branch = (string) config("codemagic.wordpress_branch", "main");
                // Publish the accepted Native runtime to the explicit staging
                // build only. Other existing plugin source branches stay intact.
                if (strtolower((string) parse_url($build->store_url, PHP_URL_HOST)) === "staging.kidiastore.com") {
                    $branch = (string) config("codemagic.native_runtime_branch", "codex/unified-mobile-build");
                }
                $targets = $snapshot["build_targets"] ?? [];
                sort($targets);
                $dualBuild = $targets === ["android", "ios"];
                if ($dualBuild) {
                    $firebase = app(StoreNotifications::class)->forActivation($build->activation) ?? $build->activation->firebaseProject;
                    $signing = app(NativeSigningRegistry::class)->dualReleaseIdentity(
                        $build->activation->license->store, $firebase, $build->package_name
                    );
                    if ($signing === null) {
                        throw new RuntimeException("Verified Android release signing and Apple signing are required for this store's combined build.");
                    }
                    $workflowId = $signing['workflow_id'];
                    $branch = (string) config("codemagic.native_runtime_branch", "codex/unified-mobile-build");
                }
            }
        }

        if (($snapshot["builder_project"] ?? null) === "central-builder"
            && isset($snapshot["native_design_revision"])) {
            $branch = (string) config("codemagic.native_runtime_branch", "codex/unified-mobile-build");
        }

        if ($token === "" || $appId === "" || $workflowId === "" || $branch === "") {
            throw new RuntimeException(
                "Codemagic API token, app ID, workflow ID, or branch is not configured.",
            );
        }

        $apiUrl = rtrim((string) config("codemagic.api_url"), "/");
        $buildsUrl = str_ends_with($apiUrl, "/builds")
            ? $apiUrl
            : $apiUrl."/builds";

        // Keep the request limited to fields supported by Codemagic's Builds
        // API. Build machine selection belongs in codemagic.yaml; sending the
        // old top-level instanceType field can cause the API to reject the
        // whole request before a build is created.
        $payload = [
                "appId" => $appId,
                "workflowId" => $workflowId,
                "branch" => $branch,
                "labels" => ["customer-build", "request-".$build->getKey()],
                "environment" => [
                    "variables" => array_filter([
                        ...NativeBuildRouting::environment($build, $snapshot),
                        "STORE_NAME" => $build->app_name,
                        "IOS_BUNDLE_ID" => $dualBuild ? $signing['bundle_id'] : null,
                        "APPLE_TEAM_ID" => $dualBuild ? $signing['team_id'] : null,
                        "IOS_SIGNING_PROFILE_UUID" => $dualBuild ? $signing['profile_uuid'] : null,
                        "IOS_SIGNING_CERTIFICATE_SHA256" => $dualBuild ? $signing['certificate_sha256'] : null,
                        "MOBISHOP_ANDROID_BUILD_MODE" => $dualBuild ? 'release' : 'qa',
                        "MOBISHOP_REQUIRE_RELEASE_SIGNING" => $dualBuild ? 'true' : null,
                        "ANDROID_SIGNING_CERTIFICATE_SHA256" => $dualBuild ? $signing['android_certificate_sha256'] : null,
                    "APP_ICON_URL" => (string) ($snapshot["app_icon_url"] ?? ""),
                        "BUILD_VERSION_NAME" => (string) $build->version_name,
                        "BUILD_VERSION_CODE" => (string) $build->version_code,
                        "STORE_LOCALE" => $build->store_locale ?: "en",
                        ...$this->nativeIdentityVariables($snapshot),
                        "ANDROID_APPLICATION_ID" => $build->package_name,
                    "PUSH_CONFIG_URL" => $build->push_config_url,
                        "MOBISHOP_REQUEST_ID" => $build->getKey(),
                        "MOBISHOP_CALLBACK_URL" => url("/v1/codemagic/callback"),
                        "MOBISHOP_CALLBACK_TOKEN" => (string) config("codemagic.callback_token"),
                    ], static fn ($value): bool => $value !== null && $value !== ""),
                ],
            ];

        if (!$dualBuild) $payload['environment']['variables'] = array_merge($payload['environment']['variables'], app(AndroidQaSigningIdentity::class)->variables((string) $build->package_name));

        if ($dualBuild && ($signing['android_signing_provider'] ?? '') === 'server') {
            $payload['environment']['variables'] = array_merge($payload['environment']['variables'],
                app(AndroidReleaseSigningIdentity::class)->variables($build->activation->license->store, $signing));
        }
        if ($dualBuild && ($signing['signing_provider'] ?? 'secret_group') === 'secret_group') {
            $payload['environment']['groups'] = [$signing['signing_group']];
        }

        try {
            $response = Http::acceptJson()
                ->asJson()
                ->withHeaders(["x-auth-token" => $token])
                ->timeout(30)
                ->post($buildsUrl, $payload);
        } catch (Throwable $exception) {
            throw new RuntimeException(
                "Could not connect to Codemagic: ".$exception->getMessage(),
                0,
                $exception,
            );
        }

        if ($response->failed()) {
            throw new RuntimeException(
                "Codemagic rejected the build request (HTTP ".$response->status().")"
                .$this->errorDetails($response),
            );
        }

        $buildId = $response->json("buildId");
        if (!is_string($buildId) || $buildId === "") {
            throw new RuntimeException("Codemagic did not return a build ID.");
        }

        return $buildId;
    }

    public function status(string $buildId): array
    {
        $token = (string) config("codemagic.api_token");
        if ($token === "") {
            throw new RuntimeException("Codemagic API token is not configured.");
        }

        $url = rtrim((string) config("codemagic.status_api_url"), "/")
            ."/".rawurlencode($buildId);

        try {
            $response = Http::acceptJson()
                ->withHeaders(["x-auth-token" => $token])
                ->timeout(30)
                ->retry(2, 500, null, false)
                ->get($url);
        } catch (Throwable $exception) {
            throw new RuntimeException(
                "Could not read Codemagic build status: ".$exception->getMessage(),
                0,
                $exception,
            );
        }

        if ($response->failed()) {
            throw new RuntimeException(
                "Codemagic status request failed (HTTP ".$response->status().")"
                .$this->errorDetails($response),
            );
        }

        $data = $response->json("data");
        $payload = is_array($data) ? $data : $response->json();
        if (!is_array($payload)) {
            throw new RuntimeException(
                "Codemagic status response did not contain valid JSON.",
            );
        }

        return $payload;
    }

    public function cancel(string $buildId): void
    {
        $token = (string) config("codemagic.api_token");
        if ($token === "") {
            throw new RuntimeException("Codemagic API token is not configured.");
        }

        $apiUrl = rtrim((string) config("codemagic.api_url"), "/");
        $buildsUrl = str_ends_with($apiUrl, "/builds")
            ? $apiUrl
            : $apiUrl."/builds";
        $url = $buildsUrl."/".rawurlencode($buildId)."/cancel";

        try {
            $response = Http::acceptJson()
                ->withHeaders(["x-auth-token" => $token])
                ->timeout(30)
                ->retry(2, 500, null, false)
                ->post($url);
        } catch (Throwable $exception) {
            throw new RuntimeException(
                "Could not cancel the Codemagic build: ".$exception->getMessage(),
                0,
                $exception,
            );
        }

        if ($response->failed() && $response->status() !== 208) {
            throw new RuntimeException(
                "Codemagic cancel request failed (HTTP ".$response->status().")"
                .$this->errorDetails($response),
            );
        }
    }

    /** @return array{url:string,expires_at:string|null} */
    public function publicArtifactUrl(string $secureUrl, int $expiresAt): array
    {
        $token = (string) config("codemagic.api_token");
        if ($token === "") {
            throw new RuntimeException(
                "Codemagic API token is not configured.",
            );
        }

        $parts = parse_url($secureUrl);
        $path = is_array($parts)
            ? "/".ltrim((string) ($parts["path"] ?? ""), "/")
            : "";
        if (
            !is_array($parts)
            || strtolower((string) ($parts["scheme"] ?? "")) !== "https"
            || strtolower((string) ($parts["host"] ?? "")) !== "api.codemagic.io"
            || !str_starts_with($path, "/artifacts/")
        ) {
            throw new RuntimeException("Codemagic returned an invalid artifact URL.");
        }

        // Codemagic's build-status response currently exposes a fresh
        // short_lived_download_url. It is already a public signed URL and must
        // be returned directly; appending /public-url to it produces a 404.
        // The forced status sync before each download refreshes this value.
        if (str_starts_with(substr($path, strlen("/artifacts/")), ".")) {
            return [
                "url" => $secureUrl,
                "expires_at" => date(DATE_ATOM, $expiresAt),
            ];
        }

        $url = rtrim($secureUrl, "/")."/public-url";

        try {
            $response = Http::acceptJson()
                ->asJson()
                ->withHeaders(["x-auth-token" => $token])
                ->timeout(30)
                ->retry(2, 500, null, false)
                ->post($url, ["expiresAt" => $expiresAt]);
        } catch (Throwable $exception) {
            throw new RuntimeException(
                "Could not create the Codemagic download link: ".$exception->getMessage(),
                0,
                $exception,
            );
        }

        if ($response->failed()) {
            throw new RuntimeException(
                "Codemagic download-link request failed (HTTP ".$response->status().")"
                .$this->errorDetails($response),
            );
        }

        $publicUrl = $response->json("url");
        if (!is_string($publicUrl)
            || filter_var($publicUrl, FILTER_VALIDATE_URL) === false
            || strtolower((string) parse_url($publicUrl, PHP_URL_SCHEME)) !== "https") {
            throw new RuntimeException(
                "Codemagic did not return a valid public download URL.",
            );
        }

        return [
            "url" => $publicUrl,
            "expires_at" => is_string($response->json("expiresAt"))
                ? $response->json("expiresAt")
                : null,
        ];
    }

    private function errorDetails(Response $response): string
    {
        $details = $response->json("message")
            ?? $response->json("error.message")
            ?? $response->json("error")
            ?? $response->json("detail")
            ?? $response->json("details")
            ?? trim($response->body());

        if (is_array($details)) {
            $details = json_encode(
                $details,
                JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE,
            );
        }

        if (!is_string($details) || trim($details) === "") {
            return "";
        }

        return ": ".mb_substr(strip_tags(trim($details)), 0, 1000);
    }
    private function nativeIdentityVariables(array $snapshot): array {
        $build = is_array($snapshot['build'] ?? null) ? $snapshot['build'] : [];
        $defines = is_array($build['dartDefines'] ?? null) ? $build['dartDefines'] : [];
        $application = is_array($snapshot['application'] ?? null) ? $snapshot['application'] : [];
        $result = [];
        $fields = ['STORE_DIRECTION' => 'direction', 'STORE_FONT_FAMILY' => 'fontFamily', 'STORE_PRIMARY_COLOR' => 'primaryColor', 'STORE_SECONDARY_COLOR' => 'secondaryColor', 'APP_ICON_SHAPE' => 'appIconShape'];
        foreach ($fields as $key => $field) {
            $value = $defines[$key] ?? $application[$field] ?? null;
            if (!is_string($value)) continue;
            $valid = match ($key) {
                'APP_ICON_SHAPE' => in_array($value, ['rounded_square', 'circle', 'square'], true),
                'STORE_DIRECTION' => in_array($value, ['rtl', 'ltr'], true),
                'STORE_FONT_FAMILY' => in_array($value, ['system', 'poppins', 'roboto', 'noto_sans_arabic', 'serif', 'monospace'], true),
                default => (bool) preg_match('/^#[a-fA-F0-9]{6}$/D', $value),
            };
            if ($valid) $result[$key] = $value;
        }
        return $result;
    }

}
