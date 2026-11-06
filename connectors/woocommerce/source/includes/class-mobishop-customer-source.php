<?php
/** Display app registration and app sign-in independently from account identity. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Customer_Source {
    private static function label( string $text ): string {
        $arabic = array( 'Mobile app' => 'تطبيق الموبايل', 'App account' => 'حساب من التطبيق', 'App sign-in' => 'دخل من التطبيق', 'Mobile app customers' => 'عملاء التطبيق', 'All customer sources' => 'كل مصادر العملاء', 'Registered in app' => 'سجّل حسابه من التطبيق', 'Signed in through app' => 'سجّل الدخول من التطبيق', 'Filter' => 'تصفية', 'Contact phone' => 'رقم التواصل', 'Not verified by SMS' => 'لم يتم توثيقه بكود SMS' );
        $arabic['Has used the app'] = 'استخدم التطبيق';
        $arabic['All app users'] = 'كل مستخدمي التطبيق';
        if ( str_starts_with( determine_locale(), 'ar' ) ) return $arabic[$text] ?? $text;
        return match ( $text ) {
            'Mobile app' => __( 'Mobile app', 'mobi2app-connector' ),
            'App account' => __( 'App account', 'mobi2app-connector' ),
            'App sign-in' => __( 'App sign-in', 'mobi2app-connector' ),
            'Mobile app customers' => __( 'Mobile app customers', 'mobi2app-connector' ),
            'All customer sources' => __( 'All customer sources', 'mobi2app-connector' ),
            'Registered in app' => __( 'Registered in app', 'mobi2app-connector' ),
            'Signed in through app' => __( 'Signed in through app', 'mobi2app-connector' ),
            'Filter' => __( 'Filter', 'mobi2app-connector' ),
            'Contact phone' => __( 'Contact phone', 'mobi2app-connector' ),
            'Not verified by SMS' => __( 'Not verified by SMS', 'mobi2app-connector' ),
            'Has used the app' => __( 'Has used the app', 'mobi2app-connector' ),
            'All app users' => __( 'All app users', 'mobi2app-connector' ),
            default => $text,
        };
    }

    public static function register(): void {
        add_filter( 'manage_users_columns', array( self::class, 'columns' ) );
        add_filter( 'manage_users_custom_column', array( self::class, 'cell' ), 10, 3 );
        add_action( 'restrict_manage_users', array( self::class, 'filter_control' ) );
        add_action( 'pre_get_users', array( self::class, 'filter_query' ) );
        add_action( 'pre_user_query', array( self::class, 'filter_usage_sql' ) );
        add_action( 'show_user_profile', array( self::class, 'contact' ) );
        add_action( 'edit_user_profile', array( self::class, 'contact' ) );
        add_action( 'show_user_profile', array( self::class, 'profile_source' ) );
        add_action( 'edit_user_profile', array( self::class, 'profile_source' ) );
        if ( is_multisite() ) {
            add_action( 'added_user_meta', array( self::class, 'remember_site_activity' ), 10, 4 );
            add_action( 'updated_user_meta', array( self::class, 'remember_site_activity' ), 10, 4 );
        }
    }

    private static function source_key( string $key ): string {
        return is_multisite() ? '_mobishop_site_' . get_current_blog_id() . $key : $key;
    }

    /** WordPress shares user meta across a network. Attribute only an observed store event. */
    public static function remember_site_activity( $meta_id, $user_id, $key, $value ): void {
        if ( ! in_array( $key, array( '_mobishop_app_registered_at', '_mobishop_app_last_login_at', '_mobishop_customer' ), true ) ) return;
        if ( ! is_scalar( $value ) || ! $value || ( '_mobishop_customer' === $key && '1' !== (string) $value ) ) return;
        $scoped = self::source_key( $key );
        if ( '1' !== get_user_meta( $user_id, $scoped, true ) ) update_user_meta( $user_id, $scoped, '1' );
    }

    public static function columns( array $columns ): array {
        $columns['mobishop_app_customer'] = self::label( 'Mobile app' );
        return $columns;
    }

    public static function cell( string $value, string $column, int $id ): string {
        if ( $column !== 'mobishop_app_customer' ) return $value;
        if ( get_user_meta( $id, self::source_key( '_mobishop_app_registered_at' ), true ) ) {
            return self::badge( 'App account' );
        }
        if ( get_user_meta( $id, self::source_key( '_mobishop_app_last_login_at' ), true ) ) return self::badge( 'App sign-in' );
        // Historical app usage is not proof of where the account was registered.
        return '1' === (string) get_user_meta( $id, self::source_key( '_mobishop_customer' ), true ) || metadata_exists( 'user', $id, self::source_key( '_mobishop_customer_sessions_v1' ) )
            ? self::badge( 'Has used the app' ) : '—';
    }

    private static function badge( string $label ): string {
        return '<span class="mobishop-app-badge98"><span class="dashicons dashicons-smartphone" aria-hidden="true"></span> ' . esc_html( self::label( $label ) ) . '</span>';
    }

    public static function profile_source( $user ): void {
        if ( ! current_user_can( 'edit_user', $user->ID ) ) return;
        $badge = self::cell( '', 'mobishop_app_customer', (int) $user->ID );
        if ( '—' !== $badge ) echo '<h2>' . esc_html( self::label( 'Mobile app' ) ) . '</h2><p>' . wp_kses_post( $badge ) . '</p>';
    }

    private static function selected(): string {
        $value = isset( $_GET['mobishop_customer_channel'] ) && is_string( $_GET['mobishop_customer_channel'] ) ? sanitize_key( wp_unslash( $_GET['mobishop_customer_channel'] ) ) : '';
        return in_array( $value, array( 'mobile', 'registered', 'signed_in' ), true ) ? $value : '';
    }

    public static function filter_control( string $which = 'top' ): void {
        if ( $which !== 'top' ) return;
        $value = self::selected();
        echo '<label class="screen-reader-text" for="mobishop-channel-' . esc_attr( $which ) . '">' . esc_html( self::label( 'Mobile app customers' ) ) . '</label>';
        echo '<select name="mobishop_customer_channel" id="mobishop-channel-' . esc_attr( $which ) . '">';
        foreach ( array( '' => 'All customer sources', 'mobile' => 'All app users', 'registered' => 'Registered in app', 'signed_in' => 'Signed in through app' ) as $key => $label ) {
            echo '<option value="' . esc_attr( $key ) . '" ' . selected( $value, $key, false ) . '>' . esc_html( self::label( $label ) ) . '</option>';
        }
        echo '</select><button type="submit" class="button">' . esc_html( self::label( 'Filter' ) ) . '</button>';
    }

    public static function filter_query( $query ): void {
        if ( ! is_admin() || wp_doing_ajax() || ! current_user_can( 'list_users' ) || ( $GLOBALS['pagenow'] ?? '' ) !== 'users.php' ) return;
        $selected = self::selected();
        if ( $selected === '' ) return;
        if ( 'mobile' === $selected ) {
            // Multiple OR/EXISTS meta joins multiply rows on large member tables.
            // A correlated EXISTS keeps pagination/counts and existing filters intact.
            $query->set( 'mobishop_app_usage_filter', true );
            return;
        }
        $existing = $query->get( 'meta_query' );
        $clause = array( 'key' => self::source_key( $selected === 'registered' ? '_mobishop_app_registered_at' : '_mobishop_app_last_login_at' ), 'compare' => 'NOT IN', 'value' => array( '', '0' ) );
        $query->set( 'meta_query', $existing ? array( 'relation' => 'AND', $existing, $clause ) : array( $clause ) );
    }

    public static function filter_usage_sql( $query ): void {
        if ( ! $query->get( 'mobishop_app_usage_filter' ) ) return;
        global $wpdb;
        $query->query_where .= $wpdb->prepare(
            " AND EXISTS (SELECT 1 FROM {$wpdb->usermeta} AS mobishop_app_usage WHERE mobishop_app_usage.user_id = {$wpdb->users}.ID AND ((mobishop_app_usage.meta_key IN (%s, %s) AND mobishop_app_usage.meta_value NOT IN ('', '0')) OR mobishop_app_usage.meta_key = %s OR (mobishop_app_usage.meta_key = %s AND mobishop_app_usage.meta_value = %s)))",
            self::source_key( '_mobishop_app_registered_at' ), self::source_key( '_mobishop_app_last_login_at' ),
            self::source_key( '_mobishop_customer_sessions_v1' ), self::source_key( '_mobishop_customer' ), '1'
        );
    }

    public static function contact( $user ): void {
        if ( ! current_user_can( 'edit_user', $user->ID ) ) return;
        if ( get_user_meta( $user->ID, 'kidia_login_phone', true ) ) return;
        $phone = (string) get_user_meta( $user->ID, 'kidia_unverified_phone', true );
        if ( $phone === '' ) return;
        echo '<h2>' . esc_html( self::label( 'Contact phone' ) ) . '</h2><p><bdi>' . esc_html( $phone ) . '</bdi> — ' . esc_html( self::label( 'Not verified by SMS' ) ) . '</p>';
    }
}
