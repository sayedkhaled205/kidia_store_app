<?php
declare(strict_types=1);
namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Services\{FirebaseIdentityErasureException, StoreCustomerIdentity};
use Illuminate\Http\Request;

final class StoreCustomerIdentityController extends Controller
{
    public function __construct(private readonly StoreCustomerIdentity $identities) {}

    public function capabilities(Request $request)
    {
        $store = $this->store($request);
        return $store === null ? $this->result(['ok' => false], 401)
            : $this->result(['ok' => true] + $this->identities->capabilities($store));
    }

    public function lookup(Request $request) { return $this->perform($request, false); }
    public function erase(Request $request) { return $this->perform($request, true); }

    private function perform(Request $request, bool $erase)
    {
        $store = $this->store($request);
        if ($store === null) return $this->result(['ok' => false], 401);
        $body = $request->json()->all();
        $keys = $erase ? ['project_id', 'uid', 'created_at'] : ['project_id', 'uid'];
        if (!is_array($body) || array_diff(array_keys($body), $keys)
            || array_diff($keys, array_keys($body))) return $this->result(['ok' => false], 400);
        foreach ($keys as $key) {
            if (!is_string($body[$key])) return $this->result(['ok' => false], 400);
        }
        try {
            if ($erase) {
                $data = $this->identities->erase($store, $body['project_id'], $body['uid'], $body['created_at']);
            } else {
                $snapshot = $this->identities->lookup($store, $body['project_id'], $body['uid']);
                $data = $snapshot === null ? ['status' => 'absent']
                    : ['status' => 'present', 'created_at' => $snapshot['created_at']];
            }
            return $this->result(['ok' => true] + $data);
        } catch (FirebaseIdentityErasureException $error) {
            $status = match ($error->getCode()) {
                FirebaseIdentityErasureException::INVALID_PROJECT,
                FirebaseIdentityErasureException::INVALID_UID,
                FirebaseIdentityErasureException::INVALID_CREATED_AT => 400,
                FirebaseIdentityErasureException::FOREIGN_IDENTITY,
                FirebaseIdentityErasureException::IDENTITY_CHANGED => 409,
                default => 503,
            };
            return $this->result(['ok' => false, 'code' => 'identity_operation_unconfirmed'], $status);
        } catch (\Throwable) {
            return $this->result(['ok' => false, 'code' => 'identity_operation_unavailable'], 503);
        }
    }

    private function store(Request $request): ?Store
    {
        $store = $request->attributes->get('notificationStore');
        $route = $request->route('store');
        $publicId = $route instanceof Store ? $route->public_id : $route;
        return $store instanceof Store && is_string($publicId)
            && hash_equals($store->public_id, $publicId) ? $store : null;
    }

    private function result(array $data, int $status = 200)
    {
        return response()->json($data, $status, ['Cache-Control' => 'no-store, private, max-age=0']);
    }
}
