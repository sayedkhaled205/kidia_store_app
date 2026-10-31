<?php
namespace App\Services;

use App\Models\Store;
use Illuminate\Support\Facades\Crypt;
use RuntimeException;

/** Reads an operator-provisioned upload key. Never generates or silently rotates a signer. */
final class AndroidReleaseSigningIdentity
{
    public function variables(Store $store, array $registration): array
    {
        $path = storage_path('app/private/android-release-signing/'.hash('sha256', $store->public_id).'.enc');
        if (!is_file($path)) throw new RuntimeException('The registered Android release key is unavailable.');
        try {
            $identity = json_decode(Crypt::decryptString(file_get_contents($path)), true, 32, JSON_THROW_ON_ERROR);
            if (($identity['store'] ?? '') !== $store->public_id
                || (string) ($identity['owner_id'] ?? '') !== (string) $store->user_id
                || ($identity['package'] ?? '') !== ($registration['android_package_name'] ?? '')
                || !is_string($identity['password'] ?? null) || strlen($identity['password']) < 32
                || !preg_match('/^[a-zA-Z0-9_-]+$/D', $identity['alias'] ?? '')) throw new RuntimeException();
            $bytes = base64_decode($identity['keystore'] ?? '', true);
            if (!$bytes || strlen($bytes) > 1048576 || !openssl_pkcs12_read($bytes, $parts, $identity['password'])) throw new RuntimeException();
            $cert = openssl_x509_parse($parts['cert']);
            if (!openssl_x509_check_private_key($parts['cert'], $parts['pkey'])
                || ($cert['validFrom_time_t'] ?? PHP_INT_MAX) > time()
                || ($cert['validTo_time_t'] ?? 0) <= time()
                || strcasecmp($cert['subject']['CN'] ?? '', 'Android Debug') === 0
                || !hash_equals(strtolower($registration['android_certificate_sha256'] ?? ''), openssl_x509_fingerprint($parts['cert'], 'sha256'))) throw new RuntimeException();
        } catch (\Throwable) {
            throw new RuntimeException('The Android release identity could not be verified. Its key has not been replaced.');
        }
        return ['CM_KEYSTORE' => $identity['keystore'], 'CM_KEYSTORE_PASSWORD' => $identity['password'],
            'CM_KEY_ALIAS' => $identity['alias'], 'CM_KEY_PASSWORD' => $identity['password']];
    }
}
