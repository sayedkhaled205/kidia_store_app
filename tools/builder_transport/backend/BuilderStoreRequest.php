<?php
namespace App\Services;

use GuzzleHttp\TransferStats;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Log;

/** Recover a failed connection only when cURL proves no HTTP request was sent. */
final class BuilderStoreRequest
{
    public function send(callable $send, float $budget): Response
    {
        $deadline = hrtime(true) / 1e9 + $budget;
        for ($attempt = 0; $attempt < 2; $attempt++) {
            $stats = null;
            $errno = null;
            $remaining = $deadline - hrtime(true) / 1e9;
            if ($remaining <= 0) throw new ConnectionException('Store connection deadline exceeded.');
            $options = [
                'timeout' => $remaining,
                'connect_timeout' => min(8.0, $remaining),
                'on_stats' => static function (TransferStats $transfer) use (&$stats, &$errno): void {
                    $stats = $transfer->getHandlerStats();
                    $errno = $transfer->getHandlerErrorData();
                },
            ];
            // Keep the normal dual-stack attempt. Only recovery avoids a failed IPv6 route.
            if ($attempt === 1) $options['force_ip_resolve'] = 'v4';
            try {
                return $send($options);
            } catch (ConnectionException $error) {
                if ($attempt !== 0 || !self::notDelivered($errno, $stats)
                    || $deadline - hrtime(true) / 1e9 < 0.1) throw $error;
                // No URL, headers, credentials, form state or exception message in logs.
                Log::notice('builder_store_connection_retry_before_delivery', ['curl_errno' => $errno]);
            }
        }
        throw new \LogicException('Unreachable transport state.');
    }

    public static function notDelivered(mixed $errno, ?array $stats): bool
    {
        if (!in_array($errno, [6, 7, 28], true) || $stats === null) return false;
        // Missing measurements are uncertainty, never evidence that retry is safe.
        foreach (['request_size', 'size_upload', 'http_code', 'redirect_count',
            'pretransfer_time', 'starttransfer_time'] as $key) {
            if (!array_key_exists($key, $stats) || !is_numeric($stats[$key])
                || (float) $stats[$key] !== 0.0) return false;
        }
        return true;
    }
}
