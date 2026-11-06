<?php
declare(strict_types=1);
namespace App\Models {
    final class Store {
        public function __construct(public string $public_id = 'merchant-a', public string $connection_status = 'connected', public string $platform = 'woocommerce') {}
    }
}
namespace Google\Auth\Credentials {
    final class ServiceAccountCredentials {
        public function __construct(public array $scopes, public string $path) { $GLOBALS['scopes'] = $scopes; }
        public function fetchAuthToken(): array { $GLOBALS['token_fetches'] = ($GLOBALS['token_fetches'] ?? 0) + 1; return ['access_token' => 'synthetic-token']; }
    }
}
namespace Illuminate\Support\Facades {
    final class Http {
        public static array $queue = [], $calls = [];
        public static function withToken(string $token): Request { return new Request($token); }
    }
    final class Request {
        private array $options = [];
        public function __construct(private string $token) {}
        public function acceptJson(): self { return $this; }
        public function asJson(): self { return $this; }
        public function timeout(int $seconds): self { return $this; }
        public function withOptions(array $options): self { $this->options = $options; return $this; }
        public function post(string $url, array $body): Response {
            Http::$calls[] = ['url' => $url, 'body' => $body, 'options' => $this->options];
            $next = array_shift(Http::$queue);
            if ($next instanceof \Throwable) throw $next;
            if (!is_array($next)) throw new \RuntimeException('Synthetic missing response');
            return new Response($next[0], $next[1]);
        }
    }
    final class Response {
        public function __construct(private int $code, private string $raw) {}
        public function status(): int { return $this->code; }
        public function body(): string { return $this->raw; }
    }
}
namespace {
    require __DIR__.'/../../backend/app/Services/FirebaseIdentityErasureException.php';
    require __DIR__.'/../../backend/app/Services/FirebaseIdentityErasure.php';
    require __DIR__.'/../../backend/app/Services/StoreCustomerIdentity.php';
    use App\Models\Store;
    use App\Services\StoreCustomerIdentity;
    use Illuminate\Support\Facades\Http;
    function config(string $key, mixed $default = null): mixed { return $GLOBALS['config'][$key] ?? $default; }
    function resetFixture(): StoreCustomerIdentity {
        $GLOBALS['config'] = ['customer_identity.enabled' => true, 'customer_identity.auth_projects' => ['merchant-a' => 'synthetic-auth-project'], 'services.firebase_provisioner.credentials' => __FILE__];
        Http::$calls = []; Http::$queue = []; $GLOBALS['token_fetches'] = 0;
        return new StoreCustomerIdentity();
    }
    $checks = 0;
    function check(bool $value, string $name): void { global $checks; if (!$value) throw new \RuntimeException('FAIL: '.$name); $checks++; echo 'PASS: '.$name.PHP_EOL; }
    function rejected(callable $operation): bool { try { $operation(); } catch (\RuntimeException) { return true; } return false; }
}
