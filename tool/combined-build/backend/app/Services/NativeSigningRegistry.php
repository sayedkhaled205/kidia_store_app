<?php
namespace App\Services;

use App\Models\Store;
use Carbon\CarbonImmutable;

/** Operator-managed, verified identities. Customer design/settings cannot grant signing access. */
final class NativeSigningRegistry
{
    public function identity(Store $store): ?array
    {
        $row = config('native_signing.stores.'.$store->public_id);
        if (!is_array($row) || ($row['enabled'] ?? false) !== true
            || (string) ($row['owner_id'] ?? '') !== (string) $store->user_id
            || ($row['site_host'] ?? '') !== strtolower((string) parse_url($store->site_url, PHP_URL_HOST))) return null;
        $patterns = [
            'bundle_id' => '/^[A-Za-z0-9]+(?:\.[A-Za-z0-9-]+)+$/D',
            'team_id' => '/^[A-Z0-9]{10}$/D',
            'profile_uuid' => '/^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$/D',
            'certificate_sha256' => '/^[a-fA-F0-9]{64}$/D',
            'workflow_id' => '/^[A-Za-z0-9_-]{1,100}$/D',
        ];
        foreach ($patterns as $key => $pattern) {
            if (!is_string($row[$key] ?? null) || !preg_match($pattern, $row[$key])) return null;
        }
        if (($row['signing_provider'] ?? 'secret_group') === 'managed') {
            // Managed references belong to a dedicated, store-bound workflow.
            if ($row['workflow_id'] !== 'kidia-managed-dual-release'
                || $store->public_id !== '6990b322-e396-46bb-a188-a1e472b6bf64'
                || ($row['android_signing_provider'] ?? '') !== 'server') return null;
        } elseif (($row['signing_provider'] ?? 'secret_group') !== 'secret_group'
            || !preg_match('/^[A-Za-z0-9_-]{1,100}$/D', $row['signing_group'] ?? '')) return null;
        try {
            $verified = CarbonImmutable::parse($row['verified_at'] ?? '');
            $expires = CarbonImmutable::parse($row['expires_at'] ?? '');
            if (empty($row['verified_at']) || empty($row['expires_at']) || $verified->isFuture() || !$expires->isFuture()) return null;
        } catch (\Throwable) { return null; }
        return $row;
    }

    public function pushReady(Store $store, ?\App\Models\FirebaseProject $project): bool
    {
        $row = $this->identity($store);
        if (!$row || !$project || ($row['apns_verified'] ?? false) !== true
            || ($row['firebase_project_id'] ?? '') !== $project->google_project_id
            || $row['bundle_id'] !== $project->ios_bundle_id) return false;
        try {
            if (empty($row['apns_verified_at'])) return false;
            return !CarbonImmutable::parse($row['apns_verified_at'])->isFuture();
        } catch (\Throwable) { return false; }
    }

    /** Store-bound signing and SDK configuration; APNs delivery is checked separately. */
    public function dualReleaseIdentity(Store $store, ?\App\Models\FirebaseProject $project, ?string $packageName = null): ?array
    {
        if (!$project || $project->status !== 'ready') return null;
        $push = app(ConnectedStorePush::class);
        $currentProject = $push->project($store);
        if (!$currentProject || (string) $currentProject->getKey() !== (string) $project->getKey()
            || (string) $currentProject->license_activation_id !== (string) $project->license_activation_id) return null;
        $project = $currentProject;
        $activation = $project->activation;
        $license = $activation?->license;
        if ($store->connection_status !== 'connected' || !$activation || !$license || !$activation->isActive()
            || !in_array('apk_builds', $license->plan->entitlements(), true)
            || (string) $project->license_activation_id !== (string) $activation->getKey()
            || (string) $license->store_id !== (string) $store->getKey()
            || (string) $license->user_id !== (string) $store->user_id
            || strtolower((string) $activation->site_host) !== strtolower((string) parse_url($store->site_url, PHP_URL_HOST))) return null;
        $row = $this->identity($store);
        if (!$row || !in_array($row['workflow_id'] ?? '', ['mobishop-customer-dual-release', 'kidia-managed-dual-release'], true)
            || ($row['firebase_project_id'] ?? '') !== $project->google_project_id
            || $row['bundle_id'] !== $project->ios_bundle_id
            || ($row['android_release_verified'] ?? false) !== true
            || !is_string($row['android_package_name'] ?? null)
            || !preg_match('/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$/D', $row['android_package_name'])
            || $row['android_package_name'] !== $project->android_package
            || ($packageName !== null && $packageName !== $row['android_package_name'])
            || !is_string($row['android_certificate_sha256'] ?? null)
            || !preg_match('/^[a-fA-F0-9]{64}$/D', $row['android_certificate_sha256'])) return null;
        try {
            if (empty($row['android_verified_at']) || empty($row['android_expires_at'])) return null;
            $verified = CarbonImmutable::parse($row['android_verified_at']);
            $expires = CarbonImmutable::parse($row['android_expires_at']);
            if ($verified->isFuture() || !$expires->isFuture()) return null;
        } catch (\Throwable) { return null; }
        // Availability and dispatch require the same parsed, current SDK configuration.
        $ios = $push->config($store, 'ios')['firebaseOptions'];
        if (!$push->config($store, 'android')['clientReady'] || $ios === []
            || ($ios['iosBundleId'] ?? '') !== $row['bundle_id']
            || ($ios['projectId'] ?? '') !== $row['firebase_project_id']) return null;
        if (($row['android_signing_provider'] ?? '') === 'server') {
            try { app(AndroidReleaseSigningIdentity::class)->variables($store, $row); }
            catch (\Throwable) { return null; }
        }
        return $row;
    }
}
