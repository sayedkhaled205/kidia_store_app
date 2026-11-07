<?php
/** Verified identity inventory only. Callers must serialize identity writes and deletion separately. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Customer_Identity_Links {
    private const PHONE = '_mobishop_phone_firebase_identity_';

    private static function text( $value ): bool {
        return is_string( $value ) && $value !== '' && strlen( $value ) <= 128
            && preg_match( '//u', $value ) === 1 && preg_match( '/\p{C}/u', $value ) === 0;
    }

    private static function project( $value ): bool {
        return is_string( $value ) && preg_match( '/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/D', $value ) === 1;
    }

    private static function phone_key( string $project, string $uid ): string {
        return self::PHONE . hash( 'sha256', $project . '|' . $uid );
    }

    /** @throws RuntimeException A partial or malformed recorded identity must block deletion. */
    public static function inventory( int $id ): array {
        if ( $id <= 0 ) throw new RuntimeException( 'Invalid identity owner.' );
        $meta = get_user_meta( $id );
        if ( ! is_array( $meta ) ) throw new RuntimeException( 'Identity inventory unavailable.' );
        $out = array();
        foreach ( $meta as $key => $values ) {
            if ( ! str_starts_with( (string) $key, self::PHONE ) ) continue;
            if ( ! is_array( $values ) || ! $values ) throw new RuntimeException( 'Invalid phone identity.' );
            foreach ( $values as $raw ) {
                $value = maybe_unserialize( $raw );
                if ( ! is_array( $value ) || count( $value ) !== 2 || ! self::project( $value['project'] ?? null )
                    || ! self::text( $value['uid'] ?? null ) || $key !== self::phone_key( $value['project'], $value['uid'] ) ) {
                    throw new RuntimeException( 'Invalid phone identity.' );
                }
                $out[ $value['project'] . '|' . $value['uid'] ] = array( 'project' => $value['project'], 'uid' => $value['uid'], 'provider' => 'phone', 'key' => $key );
            }
        }
        $apple = array( '_mobishop_firebase_project', '_mobishop_firebase_uid', '_mobishop_apple_subject' );
        if ( array_intersect( $apple, array_keys( $meta ) ) ) {
            $values = array();
            foreach ( $apple as $key ) {
                if ( ! isset( $meta[$key] ) || ! is_array( $meta[$key] ) || count( $meta[$key] ) !== 1 ) throw new RuntimeException( 'Incomplete Apple identity.' );
                $values[] = maybe_unserialize( $meta[$key][0] );
            }
            if ( ! self::project( $values[0] ) || ! self::text( $values[1] ) || ! self::text( $values[2] ) ) throw new RuntimeException( 'Invalid Apple identity.' );
            $out[ $values[0] . '|' . $values[1] ] = array( 'project' => $values[0], 'uid' => $values[1], 'provider' => 'apple', 'key' => '_mobishop_apple_identity' );
        }
        return array_values( $out );
    }

    /** Any other owner, including privileged or pending accounts, prevents provider deletion. */
    public static function shared( int $id, array $link ): bool {
        global $wpdb;
        if ( $id <= 0 || ! self::project( $link['project'] ?? null ) || ! self::text( $link['uid'] ?? null )
            || ! in_array( $link['provider'] ?? null, array( 'phone', 'apple' ), true ) ) return true;
        $project = $link['project']; $uid = $link['uid'];
        // Scan both representations regardless of this owner's provider. No role/status filter or LIMIT.
        try {
        $sql = $wpdb->prepare(
            "SELECT DISTINCT p.user_id FROM {$wpdb->usermeta} p WHERE p.user_id <> %d AND ((BINARY p.meta_key = BINARY %s) OR (BINARY p.meta_key = BINARY %s AND BINARY p.meta_value = BINARY %s AND EXISTS (SELECT 1 FROM {$wpdb->usermeta} u WHERE u.user_id = p.user_id AND BINARY u.meta_key = BINARY %s AND BINARY u.meta_value = BINARY %s)))",
            $id, self::phone_key( $project, $uid ),
            '_mobishop_firebase_project', maybe_serialize( $project ), '_mobishop_firebase_uid', maybe_serialize( $uid )
        );
        if ( ! is_string( $sql ) || $sql === '' ) return true;
        $rows = $wpdb->get_col( $sql );
        return $wpdb->last_error !== '' || ! is_array( $rows ) || count( $rows ) > 0;
        } catch ( Throwable $error ) { return true; }
    }
}