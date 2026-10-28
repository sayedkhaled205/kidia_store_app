<?php
// Uses production vendor libraries but never boots the app or touches its database.
require ($argv[1] ?? '/home/woomobile/woomobile-api/vendor/autoload.php');
require __DIR__.'/backend/BuilderStoreRequest.php';

use App\Services\BuilderStoreRequest;
use GuzzleHttp\Psr7\Request;
use GuzzleHttp\Psr7\Response as PsrResponse;
use GuzzleHttp\TransferStats;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;

$container = new Illuminate\Container\Container;
Illuminate\Support\Facades\Facade::setFacadeApplication($container);
$container->instance('log', new Psr\Log\NullLogger);
$checks = 0;
function check(bool $ok, string $name): void {
    global $checks;
    if (!$ok) throw new RuntimeException('FAIL: '.$name);
    $checks++;
}
function failure(array $options, int $errno, array $stats): never {
    $options['on_stats'](new TransferStats(new Request('POST', 'https://store.invalid/save'), null, 0.01, $errno, $stats));
    throw new ConnectionException('Simulated transport error');
}
$zero = array_fill_keys(['request_size','size_upload','http_code','redirect_count','pretransfer_time','starttransfer_time'], 0);
$transport = new BuilderStoreRequest;
foreach ([6,7,28] as $errno) {
    $calls = [];
    $response = $transport->send(function ($options) use (&$calls, $errno, $zero) {
        $calls[] = $options;
        if (count($calls) === 1) failure($options, $errno, $zero);
        return new Response(new PsrResponse(200));
    }, 20);
    check(count($calls) === 2 && $response->status() === 200, 'one recovery before delivery '.$errno);
    check(!isset($calls[0]['force_ip_resolve']) && $calls[1]['force_ip_resolve'] === 'v4', 'normal first route, IPv4 recovery');
    check($calls[1]['timeout'] < $calls[0]['timeout'] && $calls[1]['connect_timeout'] <= 8, 'shared deadline');
    check(!isset($calls[1]['verify']) && !isset($calls[1]['allow_redirects']), 'transport never weakens TLS or redirects');
}
foreach (array_keys($zero) as $key) {
    $missing = $zero; unset($missing[$key]);
    check(!BuilderStoreRequest::notDelivered(28, $missing), 'missing '.$key.' is uncertain');
    $sent = $zero; $sent[$key] = 1;
    $calls = 0;
    try {
        $transport->send(function ($options) use (&$calls, $sent) { $calls++; failure($options, 28, $sent); }, 20);
        throw new RuntimeException('Expected uncertain write failure');
    } catch (ConnectionException) { check($calls === 1, 'no replay after '.$key); }
}
foreach ([35,60,55,56,0] as $errno) check(!BuilderStoreRequest::notDelivered($errno, $zero), 'no recovery for non-connect error '.$errno);
check(!BuilderStoreRequest::notDelivered(28, null), 'no stats means no recovery');
$calls = 0;
try {
    $transport->send(function ($options) use (&$calls, $zero) { $calls++; failure($options, 7, $zero); }, 20);
} catch (ConnectionException) { check($calls === 2, 'never a third attempt'); }
$calls = 0;
$response = $transport->send(function ($options) use (&$calls) { $calls++; return new Response(new PsrResponse(502)); }, 20);
check($calls === 1 && $response->status() === 502, 'HTTP 502 is never replayed');
$calls = 0;
try {
    $transport->send(function ($options) use (&$calls) { $calls++; throw new ConnectionException('No cURL statistics'); }, 20);
} catch (ConnectionException) { check($calls === 1, 'unknown transport cannot replay'); }

// Exercise real cURL statistics through Laravel's actual HTTP client.
$listener = stream_socket_server('tcp://127.0.0.1:0', $errorNumber, $errorText);
if (!$listener) throw new RuntimeException('Cannot create local fixture');
$address = stream_socket_get_name($listener, false);
fclose($listener); // Closed local port: no HTTP request can be delivered.
$calls = 0;
$factory = new Illuminate\Http\Client\Factory;
try {
    $transport->send(function ($options) use (&$calls, $factory, $address) {
        $calls++;
        return $factory->withOptions($options)->post('http://'.$address.'/fixture', ['test'=>true]);
    }, 2);
} catch (ConnectionException) { check($calls === 2, 'real cURL connect refusal recovered once'); }

if (function_exists('pcntl_fork')) {
    $listener = stream_socket_server('tcp://127.0.0.1:0', $errorNumber, $errorText);
    $address = stream_socket_get_name($listener, false);
    $pid = pcntl_fork();
    if ($pid === 0) {
        $client = stream_socket_accept($listener, 3);
        if (!$client) exit(2);
        fread($client, 8192); // HTTP has arrived, but the response is deliberately lost.
        usleep(500000);
        fclose($client); fclose($listener); exit(0);
    }
    fclose($listener);
    $calls = 0;
    try {
        $transport->send(function ($options) use (&$calls, $factory, $address) {
            $calls++;
            return $factory->withOptions($options)->post('http://'.$address.'/fixture', ['test'=>true]);
        }, 0.2);
    } catch (ConnectionException) { check($calls === 1, 'real cURL response timeout never repeats delivered POST'); }
    pcntl_waitpid($pid, $childStatus);
    check(pcntl_wexitstatus($childStatus) === 0, 'fixture received actual request');
}
echo json_encode(['ok'=>true,'checks'=>$checks,'database_used'=>false]).PHP_EOL;
