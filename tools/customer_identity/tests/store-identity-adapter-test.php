<?php
declare(strict_types=1);
require __DIR__.'/support/identity-fixture.php';
use App\Models\Store;
use Illuminate\Support\Facades\Http;
    $store = new Store();
    $service = resetFixture();
    $GLOBALS['config']['customer_identity.enabled'] = false;
    check($service->capabilities($store) === ['available' => false], 'Disabled deployment stays closed');
    check(rejected(fn() => $service->lookup($store, 'synthetic-auth-project', 'uid')), 'Disabled lookup rejected');
    check(Http::$calls === [], 'Disabled deployment makes no provider request');
    $service = resetFixture();
    foreach ([new Store('merchant-b'), new Store('merchant-a', 'disconnected'), new Store('merchant-a', 'connected', 'shopify')] as $foreign) {
        check($service->capabilities($foreign) === ['available' => false], 'Unbound/disconnected/foreign platform closed');
    }
    check(Http::$calls === [], 'Foreign stores cannot reach credentials/provider');
    check(rejected(fn() => $service->lookup($store, 'foreign-project', 'uid')), 'Caller project cannot override server binding');
    check(Http::$calls === [], 'Project substitution makes no provider request');
    $service = resetFixture();
    Http::$queue = [[200, '{"permissions":["firebaseauth.users.get"]}']];
    check($service->capabilities($store)['available'] === false, 'Lookup permission alone does not enable erasure');
    Http::$queue = [[200, '{"permissions":["firebaseauth.users.get","firebaseauth.users.delete"]}']];
    check($service->capabilities($store)['available'] === true, 'Both required permissions confirmed');
    check($GLOBALS['token_fetches'] === 2, 'Reused worker adapter refreshes token per operation');
    check(str_contains(Http::$calls[0]['url'], '/projects/synthetic-auth-project:testIamPermissions'), 'Permission probe uses fixed Auth project');
    check($GLOBALS['scopes'] === ['https://www.googleapis.com/auth/cloud-platform'], 'Existing short-lived credential scope');
    check(Http::$calls[0]['options'] === ['allow_redirects' => false], 'Credential-bearing requests cannot follow redirects');
    $service = resetFixture();
    Http::$queue = [[200, '{"users":[{"localId":"uid","createdAt":"12345"}]}'], [200, '{}'], [200, '{}']];
    check($service->erase($store, 'synthetic-auth-project', 'uid', '12345') === ['status' => 'absent'], 'Erasure requires final absence confirmation');
    check(array_column(Http::$calls, 'url') === [
        'https://identitytoolkit.googleapis.com/v1/projects/synthetic-auth-project/accounts:lookup',
        'https://identitytoolkit.googleapis.com/v1/projects/synthetic-auth-project/accounts:delete',
        'https://identitytoolkit.googleapis.com/v1/projects/synthetic-auth-project/accounts:lookup',
    ], 'All identity calls stay in bound Auth project');
    foreach (['not JSON', '[]', '', str_repeat('x', 262145)] as $malformed) {
        $service = resetFixture(); Http::$queue = [[200, $malformed]];
        check(rejected(fn() => $service->lookup($store, 'synthetic-auth-project', 'uid')), 'Malformed provider body cannot prove absence');
    }
    $service = resetFixture(); Http::$queue = [new \RuntimeException('synthetic-secret-provider-error')];
    try { $service->lookup($store, 'synthetic-auth-project', 'uid'); check(false, 'Provider transport must fail'); }
    catch (\RuntimeException $error) { check(!str_contains($error->getMessage(), 'synthetic-secret') && $error->getPrevious() === null, 'Private provider error stays sanitized'); }
    $service = resetFixture(); $GLOBALS['config']['services.firebase_provisioner.credentials'] = '/synthetic/nonexistent';
    check($service->capabilities($store) === ['available' => false], 'Missing credentials stay closed');
    check(Http::$calls === [], 'Missing credentials do not send unauthenticated requests');
    $service = resetFixture();
    $GLOBALS['config']['customer_identity.auth_projects']['merchant-b'] = 'synthetic-auth-project';
    check($service->capabilities($store) === ['available' => false], 'Shared Auth project cannot enable erasure');
    check(rejected(fn() => $service->erase($store, 'synthetic-auth-project', 'uid', '12345')), 'Shared Auth project erasure denied');
    check(Http::$calls === [], 'Duplicate project binding never reaches provider');
    echo $checks.' adapter checks passed.'.PHP_EOL;
