<?php
defined('ABSPATH') || exit;

/** The caller owns the durable merchant deletion receipt and global identity lock. */
final class MobiShop_Customer_Identity_Erasure_Stage {
    /** Snapshot before accepting deletion; never reconstruct ownership from email or phone. */
    public static function prepare(int $id): array {
        $capability = MobiShop_Customer_Identity_Client::capabilities();
        if (($capability['available'] ?? false) !== true) throw new RuntimeException('Identity erasure unavailable.');
        $entries = [];
        foreach (MobiShop_Customer_Identity_Links::inventory($id) as $link) {
            if (($capability['project_id'] ?? '') !== $link['project']) throw new RuntimeException('Identity project unverified.');
            if (MobiShop_Customer_Identity_Links::shared($id, $link)) {
                // Preserve a provider identity that still authenticates another customer.
                $entries[] = $link + ['action' => 'retain_shared'];
                continue;
            }
            $snapshot = MobiShop_Customer_Identity_Client::lookup($link['project'], $link['uid']);
            $entries[] = $link + ['action' => $snapshot['status'] === 'absent' ? 'absent' : 'erase',
                'created_at' => $snapshot['created_at'] ?? null,
                'apple_revoked' => $link['provider'] !== 'apple'];
        }
        return ['version' => 1, 'user_id' => $id, 'entries' => $entries, 'cursor' => 0];
    }

    /** One bounded provider step. Persist returned state before advancing the merchant worker. */
    public static function advance(int $id, array $state): array {
        if (($state['version'] ?? null) !== 1 || ($state['user_id'] ?? null) !== $id
            || !is_array($state['entries'] ?? null)
            || ($state['entries'] !== [] && array_keys($state['entries']) !== range(0, count($state['entries']) - 1))
            || !is_int($state['cursor'] ?? null) || $state['cursor'] < 0 || $state['cursor'] > count($state['entries'])) {
            throw new RuntimeException('Invalid identity deletion state.');
        }
        if ($state['cursor'] === count($state['entries'])) return $state;
        $entry = $state['entries'][$state['cursor']];
        if (!is_array($entry) || !in_array($entry['action'] ?? '', ['retain_shared', 'absent', 'erase'], true)
            || !is_string($entry['project'] ?? null) || !is_string($entry['uid'] ?? null)
            || !in_array($entry['provider'] ?? '', ['phone', 'apple'], true)) {
            throw new RuntimeException('Invalid identity deletion entry.');
        }
        if ($entry['action'] !== 'retain_shared' && $entry['provider'] === 'apple'
            && ($entry['apple_revoked'] ?? false) !== true) {
                throw new RuntimeException('Apple revocation is not confirmed.');
        }
        if ($entry['action'] === 'erase') {
            if (MobiShop_Customer_Identity_Links::shared($id, $entry)) {
                $state['entries'][$state['cursor']]['action'] = 'retain_shared';
            } else {
                if (!is_string($entry['created_at'] ?? null)) throw new RuntimeException('Identity generation unavailable.');
                $result = MobiShop_Customer_Identity_Client::erase($entry['project'], $entry['uid'], $entry['created_at']);
                if ($result !== ['status' => 'absent']) throw new RuntimeException('Identity erasure unconfirmed.');
                $state['entries'][$state['cursor']]['action'] = 'absent';
            }
        }
        $state['cursor']++;
        return $state;
    }
}
