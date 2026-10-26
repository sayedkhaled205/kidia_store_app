<?php
namespace App\Services;

use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/** One immutable, public, validated layout per release. Never raw Store settings. */
final class LiveAppDesign
{
    public static function query(Store $store)
    {
        return DB::table('app_design_releases')->where('store_id', $store->id)->where('schema_version', 1);
    }
    public static function bundle(Store $store): string
    {
        if (!in_array($store->platform, ['woocommerce', 'shopify', 'odoo'], true) || $store->connection_status !== 'connected') {
            throw ValidationException::withMessages(['design' => 'Connect this store before publishing its design.']);
        }
        $screens = data_get($store->settings, 'builder.screens', []);
        try {
            $encoded = SavedBuilderNativeDesign::fromPersistedScreens(
                $store->platform, rtrim($store->site_url, '/'), $screens, $store->updated_at->format(DATE_ATOM));
            if (strlen($encoded) > 1400000) throw new \RuntimeException('Too large');
            $design = json_decode(base64_decode($encoded, true), true, 64, JSON_THROW_ON_ERROR);
            if (empty($design['home']['blocks'])) throw new \RuntimeException('Empty Home');
            $checkout = self::checkoutPresentation($screens);
            if ($checkout !== null) {
                $design['pages']['home']['settings']['checkout_presentation_v1'] = $checkout;
            }
            $controls = LiveAppUiControls::values($store);
            if ($controls) {
                $design['pages']['home']['settings']['ui_controls_v1'] = $controls;
            }
            if ($controls || $checkout !== null) {
                $encoded = base64_encode(json_encode($design, JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR));
                if (strlen($encoded) > 1400000) throw new \RuntimeException('Too large');
            }
            return $encoded;
        } catch (\Throwable $error) {
            throw ValidationException::withMessages(['design' => 'Save all app pages with a valid Home layout before publishing.']);
        }
    }

    /** Only appearance: never publish checkout fields, addresses or gateways. */
    public static function checkoutPresentation(array $screens): ?array
    {
        $result = null;
        foreach (($screens['checkout-builder']['entries'] ?? []) as $entry) {
            if (!is_array($entry) || ($entry[0] ?? null) !== 'checkout_design') continue;
            if ($result !== null || !in_array($entry[1] ?? null, ['classic', 'summary_first', 'compact'], true)) {
                throw new \RuntimeException('Invalid saved checkout presentation');
            }
            $result = ['design' => $entry[1]];
        }
        return $result;
    }
    public static function status(Store $store): array
    {
        $latest = self::query($store)->orderByDesc('id')->first();
        $ready = true; $digest = null;
        try { $digest = hash('sha256', self::bundle($store)); } catch (ValidationException) { $ready = false; }
        return ['revision' => $latest?->id ?? 0, 'published_at' => $latest?->created_at,
            'ready' => $ready, 'has_changes' => $ready && $digest !== $latest?->digest,
            'can_rollback' => $latest && self::query($store)->where('id', '<', $latest->id)->where('digest', '!=', $latest->digest)->exists(),
            'draft_digest' => $digest];
    }
    public static function publish(Store $store, int $actor, int $expected, ?string $expectedDigest, bool $rollback = false): array
    {
        return DB::transaction(function () use ($store, $actor, $expected, $expectedDigest, $rollback): array {
            $locked = Store::whereKey($store->id)->lockForUpdate()->firstOrFail();
            // Match the Builder's existing owner/verified-team scope, rechecked
            // inside the publication transaction to catch removed membership.
            abort_unless(User::find($actor)?->accessibleStores()->whereKey($locked->id)->exists(), 403);
            $latest = self::query($locked)->orderByDesc('id')->first();
            if ((int)($latest?->id ?? 0) !== $expected) abort(409, 'The published version changed. Refresh and review it.');
            if ($rollback) {
                $previous = $latest ? self::query($locked)->where('id', '<', $latest->id)->where('digest', '!=', $latest->digest)->orderByDesc('id')->first() : null;
                if (!$previous) abort(409, 'No previous design is available.');
                $bundle = $previous->bundle;
            } else {
                $bundle = self::bundle($locked);
                if (!is_string($expectedDigest) || !hash_equals(hash('sha256', $bundle), $expectedDigest)) abort(409, 'Saved changes changed. Refresh and review before publishing.');
            }
            $digest = hash('sha256', $bundle);
            if ($digest !== $latest?->digest) {
                DB::table('app_design_releases')->insert(['store_id' => $locked->id, 'schema_version' => 1,
                    'digest' => $digest, 'bundle' => $bundle, 'published_by' => $actor,
                    'action' => $rollback ? 'rollback' : 'publish', 'created_at' => now()]);
            }
            return self::status($locked);
        });
    }
    public static function envelope(object $release): array
    {
        return ['protocol' => 1, 'revision' => (int)$release->id, 'sha256' => $release->digest, 'bundle' => $release->bundle];
    }
}
