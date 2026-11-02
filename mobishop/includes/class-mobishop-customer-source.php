<?php
/** Display app registration and app sign-in independently from account identity. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Customer_Source {
    private static function label( string $text ): string {
        $arabic = array( 'Mobile app' => 'تطبيق الموبايل', 'App account' => 'حساب من التطبيق', 'App sign-in' => 'دخل من التطبيق', 'Mobile app customers' => 'عملاء التطبيق', 'All customer sources' => 'كل مصادر العملاء', 'Registered in app' => 'سجّل حسابه من التطبيق', 'Signed in through app' => 'سجّل الدخول من التطبيق', 'Filter' => 'تصفية', 'Contact phone' => 'رقم التواصل', 'Not verified by SMS' => 'لم يتم توثيقه بكود SMS' );
        return str_starts_with( determine_locale(), 'ar' ) ? ( $arabic[$text] ?? $text ) : __( $text, 'mobi2app-connector' );
    }

    public static function register(): void {
        add_filter( 'manage_users_columns', array( self::class, 'columns' ) );
        add_filter( 'manage_users_custom_column', array( self::class, 'cell' ), 10, 3 );
        add_action( 'restrict_manage_users', array( self::class, 'filter_control' ) );
        add_action( 'pre_get_users', array( self::class, 'filter_query' ) );
        add_action( 'show_user_profile', array( self::class, 'contact' ) );
        add_action( 'edit_user_profile', array( self::class, 'contact' ) );
    }

    public static function columns( array $columns ): array {
        $columns['mobishop_app_customer'] = self::label( 'Mobile app' );
        return $columns;
    }

    public static function cell( string $value, string $column, int $id ): string {
        if ( $column !== 'mobishop_app_customer' ) return $value;
        if ( get_user_meta( $id, '_mobishop_app_registered_at', true ) ) {
            return '<span class="dashicons dashicons-smartphone" aria-hidden="true"></span> ' . esc_html( self::label( 'App account' ) );
        }
        return get_user_meta( $id, '_mobishop_app_last_login_at', true )
            ? '<span class="dashicons dashicons-smartphone" aria-hidden="true"></span> ' . esc_html( self::label( 'App sign-in' ) ) : '—';
    }

    private static function selected(): string {
        $value = isset( $_GET['mobishop_customer_channel'] ) && is_string( $_GET['mobishop_customer_channel'] ) ? sanitize_key( wp_unslash( $_GET['mobishop_customer_channel'] ) ) : '';
        return in_array( $value, array( 'registered', 'signed_in' ), true ) ? $value : '';
    }

    public static function filter_control( string $which = 'top' ): void {
        if ( $which !== 'top' ) return;
        $value = self::selected();
        echo '<label class="screen-reader-text" for="mobishop-channel-' . esc_attr( $which ) . '">' . esc_html( self::label( 'Mobile app customers' ) ) . '</label>';
        echo '<select name="mobishop_customer_channel" id="mobishop-channel-' . esc_attr( $which ) . '">';
        foreach ( array( '' => 'All customer sources', 'registered' => 'Registered in app', 'signed_in' => 'Signed in through app' ) as $key => $label ) {
            echo '<option value="' . esc_attr( $key ) . '" ' . selected( $value, $key, false ) . '>' . esc_html( self::label( $label ) ) . '</option>';
        }
        echo '</select><button type="submit" class="button">' . esc_html( self::label( 'Filter' ) ) . '</button>';
    }

    public static function filter_query( $query ): void {
        if ( ! is_admin() || ! current_user_can( 'list_users' ) || ( $GLOBALS['pagenow'] ?? '' ) !== 'users.php' ) return;
        $selected = self::selected();
        if ( $selected === '' ) return;
        $existing = $query->get( 'meta_query' );
        $clause = array( 'key' => $selected === 'registered' ? '_mobishop_app_registered_at' : '_mobishop_app_last_login_at', 'compare' => 'EXISTS' );
        $query->set( 'meta_query', $existing ? array( 'relation' => 'AND', $existing, $clause ) : array( $clause ) );
    }

    public static function contact( $user ): void {
        if ( ! current_user_can( 'edit_user', $user->ID ) ) return;
        if ( get_user_meta( $user->ID, 'kidia_login_phone', true ) ) return;
        $phone = (string) get_user_meta( $user->ID, 'kidia_unverified_phone', true );
        if ( $phone === '' ) return;
        echo '<h2>' . esc_html( self::label( 'Contact phone' ) ) . '</h2><p><bdi>' . esc_html( $phone ) . '</bdi> — ' . esc_html( self::label( 'Not verified by SMS' ) ) . '</p>';
    }
}
