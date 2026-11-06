<?php
declare(strict_types=1);

namespace App\Services;

use App\Models\Store;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Illuminate\Support\Facades\Http;

/** Server-only adapter. Its Store must come from the authenticated route middleware. */
final class StoreCustomerIdentity
{
    private ?string $accessToken = null;

    public function capabilities(Store $store): array
    {
        $this->accessToken = null;
        try {
            $project = $this->project($store);
            $response = $this->request(
                'https://cloudresourcemanager.googleapis.com/v1/projects/'.$project.':testIamPermissions',
                ['permissions' => ['firebaseauth.users.get', 'firebaseauth.users.delete']],
            );
            $permissions = $response['body']['permissions'] ?? [];
            $ready = $response['status'] === 200 && !array_key_exists('error', $response['body'])
                && is_array($permissions) && array_is_list($permissions)
                && in_array('firebaseauth.users.get', $permissions, true)
                && in_array('firebaseauth.users.delete', $permissions, true);
            return ['available' => $ready, 'project_id' => $project];
        } catch (\Throwable) {
            return ['available' => false];
        }
    }

    public function lookup(Store $store, string $project, string $uid): ?array
    {
        return $this->client($store, $project)->lookup($uid);
    }

    public function erase(Store $store, string $project, string $uid, string $createdAt): array
    {
        return $this->client($store, $project)->erase($uid, $createdAt);
    }

    private function client(Store $store, string $assertedProject): FirebaseIdentityErasure
    {
        // A reused queue-service instance must acquire a fresh token for each operation.
        $this->accessToken = null;
        $project = $this->project($store);
        if (!hash_equals($project, $assertedProject)) {
            throw new FirebaseIdentityErasureException(FirebaseIdentityErasureException::FOREIGN_IDENTITY);
        }
        return new FirebaseIdentityErasure($project, function (string $method, string $url, array $body): array {
            if ($method !== 'POST') throw new \RuntimeException('Unsupported identity request.');
            return $this->request($url, $body);
        });
    }

    private function project(Store $store): string
    {
        $projects = config('customer_identity.auth_projects', []);
        $project = is_array($projects) ? ($projects[$store->public_id] ?? null) : null;
        if (config('customer_identity.enabled', false) !== true
            || $store->connection_status !== 'connected' || $store->platform !== 'woocommerce'
            || !is_string($project) || preg_match('/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/D', $project) !== 1) {
            throw new \RuntimeException('Identity erasure is not configured for this store.');
        }
        return $project;
    }

    private function token(): string
    {
        if ($this->accessToken !== null) return $this->accessToken;
        try {
            $path = config('services.firebase_provisioner.credentials');
            if (!is_string($path) || !is_readable($path)) throw new \RuntimeException();
            $credentials = new ServiceAccountCredentials(
                ['https://www.googleapis.com/auth/cloud-platform'], $path,
            );
            $token = $credentials->fetchAuthToken()['access_token'] ?? null;
            if (!is_string($token) || $token === '') throw new \RuntimeException();
            return $this->accessToken = $token;
        } catch (\Throwable) {
            throw new \RuntimeException('Identity credentials are unavailable.');
        }
    }

    private function request(string $url, array $body): array
    {
        try {
            $response = Http::withToken($this->token())->acceptJson()->asJson()
                ->timeout(20)->withOptions(['allow_redirects' => false])->post($url, $body);
            $raw = $response->body();
            if (!is_string($raw) || strlen($raw) > 262144) throw new \RuntimeException();
            if (!is_object(json_decode($raw, false, 32, JSON_THROW_ON_ERROR))) throw new \RuntimeException();
            $json = json_decode($raw, true, 32, JSON_THROW_ON_ERROR);
            return ['status' => $response->status(), 'body' => $json];
        } catch (\Throwable) {
            // No response bodies, request payloads, tokens or exception causes leave this boundary.
            throw new \RuntimeException('Identity provider is unavailable.');
        }
    }
}
