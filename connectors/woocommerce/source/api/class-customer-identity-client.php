<?php
defined('ABSPATH') || exit;

/** Server-to-server transport only; normal customer sessions never receive its bearer. */
final class MobiShop_Customer_Identity_Client {
    private const BASE = 'https://api.woomobile.app/v1/stores/';

    public static function capabilities(): array { return self::request('capabilities', 'GET'); }
    public static function lookup(string $project, string $uid): array {
        return self::request('lookup', 'POST', ['project_id' => $project, 'uid' => $uid]);
    }
    public static function erase(string $project, string $uid, string $created_at): array {
        return self::request('erase', 'POST', ['project_id' => $project, 'uid' => $uid, 'created_at' => $created_at]);
    }

    private static function request(string $operation, string $method, array $body = []): array {
        $connection = class_exists('MobiShop_Store_Notifications') ? MobiShop_Store_Notifications::connection() : [];
        if (!is_string($connection['store_id'] ?? null)
            || preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/D', $connection['store_id']) !== 1
            || !is_string($connection['token'] ?? null)
            || preg_match('/^[A-Za-z0-9]{80}$/D', $connection['token']) !== 1) {
            throw new RuntimeException('Identity service connection unavailable.');
        }
        $args = ['method' => $method, 'timeout' => 25, 'redirection' => 0, 'limit_response_size' => 8192,
            'headers' => ['Authorization' => 'Bearer '.$connection['token'], 'Accept' => 'application/json', 'Content-Type' => 'application/json']];
        if ($method === 'POST') $args['body'] = wp_json_encode($body);
        $response = wp_remote_request(self::BASE.$connection['store_id'].'/customer-identities/'.$operation, $args);
        if (is_wp_error($response) || wp_remote_retrieve_response_code($response) !== 200) {
            throw new RuntimeException('Identity operation unconfirmed.');
        }
        $raw = wp_remote_retrieve_body($response);
        if (!is_string($raw) || strlen($raw) > 8192) throw new RuntimeException('Identity response invalid.');
        $value = json_decode($raw, true, 16);
        if (!is_array($value) || ($value['ok'] ?? null) !== true) throw new RuntimeException('Identity response invalid.');
        if ($operation === 'capabilities') {
            if (!is_bool($value['available'] ?? null)
                || ($value['available'] && (!is_string($value['project_id'] ?? null)
                    || preg_match('/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/D', $value['project_id']) !== 1))) {
                throw new RuntimeException('Identity capability invalid.');
            }
            return ['available' => $value['available']] + (isset($value['project_id']) ? ['project_id' => $value['project_id']] : []);
        }
        if (($value['status'] ?? null) === 'absent') return ['status' => 'absent'];
        if ($operation === 'lookup' && ($value['status'] ?? null) === 'present'
            && is_string($value['created_at'] ?? null) && preg_match('/^[0-9]{1,20}$/D', $value['created_at']) === 1) {
            return ['status' => 'present', 'created_at' => $value['created_at']];
        }
        throw new RuntimeException('Identity absence unconfirmed.');
    }
}
