<?php
namespace App\Services;

use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class LiveAppUiControls
{
    public static function schema(): array
    {
        return json_decode(file_get_contents(__DIR__.'/live-ui-controls-v1.json'), true, 32, JSON_THROW_ON_ERROR);
    }
    public static function normalize(array $values): array
    {
        $schema = self::schema(); $result = [];
        foreach ($values as $key => $value) {
            $rule = $schema[$key] ?? null;
            // Laravel converts empty form strings to null before validation.
            if ($rule && $rule['type'] === 'text' && $value === null) $value = '';
            $valid = $rule && match ($rule['type']) {
                'number' => (is_int($value) || is_float($value)) && is_finite((float)$value) && $value >= $rule['min'] && $value <= $rule['max'],
                'boolean' => is_bool($value),
                'color' => is_string($value) && preg_match('/^#[a-fA-F0-9]{6}$/D', $value),
                'text' => is_string($value) && mb_strlen($value) <= $rule['max_length'] && !preg_match('/[\x00-\x1f\x7f<>]/u', $value),
                default => false,
            };
            if (!$valid) throw ValidationException::withMessages(['controls.'.$key => 'Invalid appearance setting.']);
            $clean = is_string($value) ? trim($value) : $value;
            if ($clean !== '' && isset($rule['format'])) {
                $valid = match ($rule['format']) {
                    'phone' => preg_match('/^\+?[0-9][0-9 ()-]{5,30}[0-9]$/D', $clean)
                        && preg_match('/^[0-9]{7,15}$/D', preg_replace('/[^0-9]/', '', $clean)),
                    'email' => preg_match('~^[^\s@<>:/\\\\?#]+@[^\s@<>:/\\\\?#]+\.[^\s@<>:/\\\\?#]+$~D', $clean),
                    default => false,
                };
                if (!$valid) throw ValidationException::withMessages(['controls.'.$key => 'Invalid public contact.']);
            }
            if ($rule['type'] === 'color') $clean = strtoupper($clean);
            // Defaults are implicit, keeping older stored designs byte-identical.
            if ($clean != $rule['default']) $result[$key] = $clean;
        }
        ksort($result);
        return $result;
    }
    public static function values(Store $store): array
    {
        return self::normalize(data_get($store->settings, 'builder.ui_controls_v1', []));
    }
    public static function status(Store $store): array
    {
        $values = self::values($store);
        return ['schema' => self::schema(), 'values' => (object)$values,
            'controls_digest' => hash('sha256', json_encode($values, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES))];
    }
    public static function save(Store $store, int $actor, array $values, string $expected): array
    {
        $values = self::normalize($values);
        return DB::transaction(function () use ($store, $actor, $values, $expected): array {
            $locked = Store::whereKey($store->id)->lockForUpdate()->firstOrFail();
            abort_unless(User::find($actor)?->accessibleStores()->whereKey($locked->id)->exists(), 403);
            if (!hash_equals(self::status($locked)['controls_digest'], $expected)) abort(409, 'Appearance changed in another session.');
            $settings = $locked->settings;
            data_set($settings, 'builder.ui_controls_v1', $values);
            $locked->settings = $settings;
            // Appearance is part of the release digest; avoid changing unrelated
            // store metadata just because its draft presentation changed.
            $locked->timestamps = false;
            $locked->save();
            return self::status($locked);
        });
    }
}
