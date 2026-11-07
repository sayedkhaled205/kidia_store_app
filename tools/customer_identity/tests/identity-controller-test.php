<?php
declare(strict_types=1);
namespace App\Http\Controllers { abstract class Controller {} }
namespace Illuminate\Http {
    final class Bag {
        public function __construct(private mixed $data) {}
        public function get(string $key): mixed { return $this->data[$key] ?? null; }
        public function all(): mixed { return $this->data; }
    }
    final class Request {
        public Bag $attributes;
        public function __construct(private mixed $body = [], ?\App\Models\Store $store = null, private mixed $routeStore = 'merchant-a') {
            $this->attributes = new Bag(['notificationStore' => $store]);
        }
        public function route(string $key): mixed { return $this->routeStore; }
        public function json(): Bag { return new Bag($this->body); }
    }
}
namespace Illuminate\Support\Facades {
    final class Route {
        public static array $routes = [], $middleware = [];
        public static string $prefix = '';
        public static function prefix(string $value): Group { return new Group($value); }
        public static function get(string $path, array $action): void { self::record('GET', $path, $action); }
        public static function post(string $path, array $action): void { self::record('POST', $path, $action); }
        private static function record(string $method, string $path, array $action): void { self::$routes[] = ['method' => $method, 'path' => self::$prefix.$path, 'middleware' => self::$middleware, 'action' => $action]; }
    }
    final class Group {
        private array $middleware = [];
        public function __construct(private string $prefix) {}
        public function middleware(array $value): self { $this->middleware = $value; return $this; }
        public function group(callable $callback): void {
            Route::$prefix = $this->prefix; Route::$middleware = $this->middleware;
            try { $callback(); } finally { Route::$prefix = ''; Route::$middleware = []; }
        }
    }
}
namespace {
    require __DIR__.'/support/identity-fixture.php';
    require __DIR__.'/../backend/app/Http/Controllers/Api/V1/StoreCustomerIdentityController.php';
    use App\Models\Store;
    use App\Http\Controllers\Api\V1\StoreCustomerIdentityController;
    use Illuminate\Http\Request;
    use Illuminate\Support\Facades\{Http, Route};
    function response(): object { return new class {
        public function json(array $data, int $status, array $headers): array { return compact('data', 'status', 'headers'); }
    }; }
    $service = resetFixture(); $controller = new StoreCustomerIdentityController($service); $store = new Store();
    foreach (['capabilities', 'lookup', 'erase'] as $method) {
        check($controller->$method(new Request())['status'] === 401, 'Missing authenticated store cannot call '.$method);
        check($controller->$method(new Request([], $store, 'merchant-b'))['status'] === 401, 'Route/store mismatch cannot call '.$method);
    }
    check(Http::$calls === [], 'Unauthorized controller paths never contact provider');
    foreach ([[], ['project_id' => 'synthetic-auth-project'], ['project_id' => 'synthetic-auth-project', 'uid' => 'uid', 'tenantId' => 'foreign'], ['project_id' => [], 'uid' => 'uid']] as $body) {
        check($controller->lookup(new Request($body, $store))['status'] === 400, 'Malformed/unexpected fields rejected');
    }
    $body = ['project_id' => 'foreign-project', 'uid' => 'uid'];
    check($controller->lookup(new Request($body, $store))['status'] === 409, 'Caller cannot choose a foreign Auth project');
    check(Http::$calls === [], 'Malformed/project-substitution paths never contact provider');
    $body = ['project_id' => 'synthetic-auth-project', 'uid' => 'uid'];
    Http::$queue = [[200, '{"users":[{"localId":"uid","createdAt":"12345","email":"synthetic@example.invalid"}]}']];
    $result = $controller->lookup(new Request($body, $store));
    check($result['status'] === 200 && $result['data'] === ['ok' => true, 'status' => 'present', 'created_at' => '12345'], 'Lookup returns only minimal generation snapshot');
    check($result['headers']['Cache-Control'] === 'no-store, private, max-age=0', 'Identity responses cannot be cached publicly');
    $body['created_at'] = '12345';
    Http::$queue = [[200, '{"users":[{"localId":"uid","createdAt":"99999"}]}']];
    $count = count(Http::$calls); $result = $controller->erase(new Request($body, $store));
    check($result['status'] === 409 && count(Http::$calls) === $count + 1, 'Changed identity generation cannot dispatch deletion');
    Http::$queue = [[200, '{"users":[{"localId":"uid","createdAt":"12345"}]}'], [200, '{}'], [200, '{"unexpected":"pending"}']];
    $result = $controller->erase(new Request($body, $store));
    check($result['status'] === 503 && $result['data']['ok'] === false, 'Unrecognized final lookup cannot report completion');
    Http::$queue = [[200, '{}']];
    $result = $controller->erase(new Request($body, $store));
    check($result['data'] === ['ok' => true, 'status' => 'absent'], 'Already absent identity is confirmed without replay');
    require __DIR__.'/../backend/routes/customer-identity.php';
    check(count(Route::$routes) === 3, 'Only three narrowly scoped identity routes');
    foreach (Route::$routes as $route) {
        check($route['middleware'] === ['App\\Http\\Middleware\\AuthenticateStoreNotifications', 'throttle:30,1'], 'Every identity route authenticates store and limits rate');
        check(str_starts_with($route['path'], 'v1/stores/{store}/customer-identities/'), 'Every identity route is store scoped');
    }
    check(array_column(Route::$routes, 'method') === ['GET', 'POST', 'POST'], 'Mutation routes cannot be invoked with GET');
    echo $checks.' controller/route checks passed.'.PHP_EOL;
}
