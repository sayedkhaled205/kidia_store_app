<?php
defined( 'ABSPATH' ) || exit;

/** Short DB locks serialize writes; durable reservations cover asynchronous SDK work. */
final class MobiShop_Customer_Identity_Guard {
    private const PREFIX = 'mobishop_identity_guard_v1_';
    private static $held = array();

    private static function link_key( array $link ): string {
        $project = $link['project'] ?? null; $uid = $link['uid'] ?? null;
        if ( ! is_string( $project ) || preg_match( '/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/D', $project ) !== 1
            || ! is_string( $uid ) || $uid === '' || strlen( $uid ) > 512 || preg_match( '//u', $uid ) !== 1
            || preg_match( '/\p{C}/u', $uid ) !== 0 || preg_match_all( '/./us', $uid ) > 128 ) throw new RuntimeException( 'Invalid identity guard key.' );
        return self::PREFIX . 'uid_' . hash( 'sha256', $project . '|' . $uid );
    }
    private static function owner_key( int $id ): string {
        if ( $id < 1 ) throw new RuntimeException( 'Invalid identity owner.' );
        return self::PREFIX . 'owner_' . $id;
    }
    private static function keys( array $links ): array {
        $keys = array(); foreach ( $links as $link ) $keys[] = self::link_key( $link );
        $keys = array_values( array_unique( $keys ) ); sort( $keys, SORT_STRING ); return $keys;
    }
    private static function locked( array $keys, callable $action ) {
        global $wpdb; $acquired = array();
        try {
            foreach ( $keys as $key ) {
                $name = 'mobishop_id_' . md5( $wpdb->options . '|' . $key );
                if ( ! isset( self::$held[$name] ) ) {
                    if ( '1' !== (string) $wpdb->get_var( $wpdb->prepare( 'SELECT GET_LOCK(%s, 3)', $name ) ) ) throw new RuntimeException( 'Identity busy.' );
                    self::$held[$name] = 0;
                }
                self::$held[$name]++; $acquired[] = $name;
            }
            return $action();
        } finally {
            foreach ( array_reverse( $acquired ) as $name ) if ( --self::$held[$name] === 0 ) {
                unset( self::$held[$name] ); $wpdb->query( $wpdb->prepare( 'SELECT RELEASE_LOCK(%s)', $name ) );
            }
        }
    }
    public static function with_owner( int $id, callable $action ) { return self::locked( array( self::owner_key( $id ) ), $action ); }
    public static function with_links( array $links, callable $action ) { return self::locked( self::keys( $links ), $action ); }
    private static function read( string $key ): ?array {
        global $wpdb; $wpdb->last_error = '';
        $raw = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s", $key ) );
        if ( $wpdb->last_error !== '' ) throw new RuntimeException( 'Identity reservation unavailable.' );
        if ( $raw === null ) return null;
        $row = maybe_unserialize( $raw );
        if ( ! is_array( $row ) || ! is_int( $row['owner'] ?? null ) || $row['owner'] < 1
            || ! is_string( $row['receipt'] ?? null ) || preg_match( '/^[a-f0-9]{64}$/D', $row['receipt'] ) !== 1
            || ! in_array( $row['state'] ?? null, array( 'prepared', 'approved', 'accepted' ), true )
            || ! is_int( $row['expires'] ?? null ) || ! is_array( $row['keys'] ?? null ) ) throw new RuntimeException( 'Invalid identity reservation.' );
        return $row;
    }
    private static function write( string $key, array $row, ?array $old ): void {
        global $wpdb;
        if ( $old === null ) { if ( ! add_option( $key, $row, '', false ) ) throw new RuntimeException( 'Identity reservation save failed.' ); }
        elseif ( $old !== $row ) {
            $count = $wpdb->query( $wpdb->prepare( "UPDATE {$wpdb->options} SET option_value = %s WHERE option_name = %s AND BINARY option_value = BINARY %s", maybe_serialize( $row ), $key, maybe_serialize( $old ) ) );
            if ( $count !== 1 ) throw new RuntimeException( 'Identity reservation changed.' );
        }
        wp_cache_delete( $key, 'options' );
        if ( self::read( $key ) !== $row ) throw new RuntimeException( 'Identity reservation readback failed.' );
    }
    private static function remove( string $key, array $row ): void {
        global $wpdb;
        if ( $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name = %s AND BINARY option_value = BINARY %s", $key, maybe_serialize( $row ) ) ) !== 1 ) throw new RuntimeException( 'Identity reservation removal failed.' );
        wp_cache_delete( $key, 'options' );
        if ( self::read( $key ) !== null ) throw new RuntimeException( 'Identity reservation removal unconfirmed.' );
    }
    private static function owns( array $row, int $id, string $receipt, array $keys ): bool {
        return $row['owner'] === $id && hash_equals( $row['receipt'], $receipt ) && $row['keys'] === $keys;
    }
    /** No timeout auto-release. Cleanup must explicitly release an unapproved intent. */
    public static function reserve( int $id, string $receipt, array $links, int $expires ): void {
        if ( preg_match( '/^[a-f0-9]{64}$/D', $receipt ) !== 1 || $expires <= 0 ) throw new RuntimeException( 'Invalid reservation receipt.' );
        self::with_owner( $id, static function () use ( $id, $receipt, $links, $expires ): void {
            self::with_links( $links, static function () use ( $id, $receipt, $links, $expires ): void {
                $keys = self::keys( $links ); $all = array_merge( array( self::owner_key( $id ) ), $keys ); $existing = array();
                foreach ( $all as $key ) {
                    $row = self::read( $key );
                    if ( $row !== null && ! self::owns( $row, $id, $receipt, $keys ) ) throw new RuntimeException( 'Identity already reserved.' );
                    $existing[$key] = $row;
                }
                $row = array( 'owner' => $id, 'receipt' => $receipt, 'keys' => $keys, 'state' => 'prepared', 'expires' => $expires );
                // Persist owner first. Partial/crashed preparation cannot grant SDK permission.
                foreach ( $all as $key ) {
                    if ( $existing[$key] !== null ) continue;
                    self::write( $key, $row, null );
                }
            } );
        } );
    }
    private static function transition( int $id, string $receipt, array $links, string $state ): void {
        self::with_owner( $id, static function () use ( $id, $receipt, $links, $state ): void {
            self::with_links( $links, static function () use ( $id, $receipt, $links, $state ): void {
                $keys = self::keys( $links ); $all = array_merge( $keys, array( self::owner_key( $id ) ) ); $rows = array();
                foreach ( $all as $key ) {
                    $row = self::read( $key );
                    if ( $row === null || ! self::owns( $row, $id, $receipt, $keys ) || ( $state === 'approved' && $row['state'] === 'accepted' ) ) throw new RuntimeException( 'Identity reservation mismatch.' );
                    $rows[$key] = $row;
                }
                // Owner committed last; retries can complete an interrupted transition.
                foreach ( $rows as $key => $old ) { $next = $old; $next['state'] = $state; self::write( $key, $next, $old ); }
            } );
        } );
    }
    public static function approve( int $id, string $receipt, array $links ): void { self::transition( $id, $receipt, $links, 'approved' ); }
    public static function accept( int $id, string $receipt, array $links ): void { self::transition( $id, $receipt, $links, 'accepted' ); }
    public static function release( int $id, string $receipt, array $links, bool $completed = false ): void {
        self::with_owner( $id, static function () use ( $id, $receipt, $links, $completed ): void {
            self::with_links( $links, static function () use ( $id, $receipt, $links, $completed ): void {
                $keys = self::keys( $links ); $all = array_merge( $keys, array( self::owner_key( $id ) ) ); $rows = array();
                foreach ( $all as $key ) {
                    $row = self::read( $key );
                    if ( $row === null ) continue; // Retry partial rollback/release.
                    if ( ! self::owns( $row, $id, $receipt, $keys ) ) {
                        // Completed cleanup may race a new owner after partial release; never remove their reservation.
                        if ( $completed ) continue;
                        throw new RuntimeException( 'Identity reservation cannot be released.' );
                    }
                    if ( ! $completed && $row['state'] !== 'prepared' ) throw new RuntimeException( 'Identity reservation cannot be released.' );
                    $rows[$key] = $row;
                }
                foreach ( $rows as $key => $row ) self::remove( $key, $row );
            } );
        } );
    }
    public static function writer( int $id, array $link, callable $action, ?callable $already_linked = null ) {
        return self::with_owner( $id, static function () use ( $id, $link, $action, $already_linked ) {
            return self::with_links( array( $link ), static function () use ( $id, $link, $action, $already_linked ) {
                $owner = self::read( self::owner_key( $id ) ); $identity = self::read( self::link_key( $link ) );
                // Existing verified login needs no identity mutation; keep fresh reauthentication possible.
                if ( $already_linked !== null && $already_linked() === true ) return true;
                if ( $owner !== null || $identity !== null ) throw new RuntimeException( 'Identity deletion reserved.' );
                return $action();
            } );
        } );
    }
    public static function new_identity( array $link, callable $action ) {
        return self::with_links( array( $link ), static function () use ( $link, $action ) {
            if ( self::read( self::link_key( $link ) ) !== null ) throw new RuntimeException( 'Identity deletion reserved.' );
            return $action();
        } );
    }
}
