<?php
/** Merchant checkout in the app; card fields stay in the merchant/gateway document. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Embedded_Checkout88 {
    private const COOKIE = 'mobishop_checkout88';
    private const PREFIX = 'mobishop_checkout88_ticket_';
    private ?array $bootstrap = null;
    private ?array $scope = null;

    public function register(): void {
        add_action( 'rest_api_init', function () {
            register_rest_route( 'mobishop/v1', '/customer/checkout/session', array(
                'methods' => 'POST', 'callback' => array( $this, 'issue' ),
                'permission_callback' => array( new MobiShop_Customer_Auth_Endpoint(), 'authenticate_route' ),
            ) );
        } );
        add_filter( 'determine_current_user', array( $this, 'scoped_user' ), 40 );
        add_filter( 'user_has_cap', array( $this, 'customer_capabilities' ), 100, 4 );
        add_action( 'init', array( $this, 'restore_identity' ), -30 );
        add_action( 'init', array( $this, 'redeem' ), -20 );
        add_action( 'woocommerce_init', array( $this, 'restore_cart' ), 5 );
        add_action( 'template_redirect', array( $this, 'redirect' ), -100 );
        add_action( 'wp_head', array( $this, 'document_style' ), 99 );
        add_action( 'mobishop_checkout88_expire', static function ( $key ) {
            if ( is_string( $key ) && str_starts_with( $key, self::PREFIX ) ) delete_option( $key );
        } );
    }

    private function error( string $code, int $status = 409 ) {
        return new WP_Error( 'mobishop_checkout88_' . $code, 'The store checkout could not be opened safely. Return to your basket and retry.', array( 'status' => $status ) );
    }

    public static function valid_scope( array $scope, array $sessions, string $origin, int $now ): bool {
        if ( (int) ( $scope['user_id'] ?? 0 ) <= 0 || (int) ( $scope['expires'] ?? 0 ) <= $now ||
            ! hash_equals( $origin, (string) ( $scope['origin'] ?? '' ) ) ) return false;
        foreach ( $sessions as $session ) {
            if ( is_array( $session ) && (int) ( $session['expires'] ?? 0 ) > $now &&
                hash_equals( (string) ( $scope['session_hash'] ?? '' ), (string) ( $session['hash'] ?? '' ) ) &&
                preg_match( '/^[a-f0-9]{64}$/D', (string) ( $scope['session_hash'] ?? '' ) ) ) return true;
        }
        return false;
    }

    /** Never authenticate wp-admin, account/profile pages, REST, or arbitrary URLs. */
    public static function allowed_path( string $request_path, string $checkout_path, string $home_path, array $query ): bool {
        // WordPress permits localized checkout slugs. Decode exactly once,
        // then reject control characters and traversal (including double encoding).
        $request_path = rawurldecode( $request_path );
        $checkout_path = rawurldecode( $checkout_path );
        $home_path = rawurldecode( $home_path );
        if ( preg_match( '/[\\\\\x00-\x20\x7f]/', $request_path ) || str_contains( $request_path, '%' ) ||
            in_array( '..', explode( '/', $request_path ), true ) ) return false;
        $checkout = rtrim( $checkout_path, '/' );
        if ( $checkout === '' || $checkout === rtrim( $home_path, '/' ) ) return false;
        if ( $request_path === $checkout || str_starts_with( $request_path, $checkout . '/' ) ) return true;
        if ( rtrim( $request_path, '/' ) !== rtrim( $home_path, '/' ) ) return false;
        // WooCommerce and gateway callbacks still enforce their own nonces/signatures.
        return ( isset( $query['wc-ajax'] ) && is_string( $query['wc-ajax'] ) && preg_match( '/^[a-z0-9_\-]{1,100}$/D', $query['wc-ajax'] ) ) ||
            ( isset( $query['wc-api'] ) && is_string( $query['wc-api'] ) && preg_match( '/^[a-zA-Z0-9_\-]{1,100}$/D', $query['wc-api'] ) );
    }

    private function origin(): string { return untrailingslashit( home_url( '/' ) ); }
    private function active( array $scope ): bool {
        return wp_is_using_https() && self::valid_scope( $scope,
            (array) get_user_meta( (int) ( $scope['user_id'] ?? 0 ), '_mobishop_customer_sessions_v1', true ),
            $this->origin(), time() );
    }

    private function has_unresolved_checkout( int $customer ): bool {
        global $wpdb;
        if ( ! defined( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY' ) ) return true;
        $buyer = hash_hmac( 'sha256', 'mobishop-native-checkout50|buyer|' . $customer, MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY );
        $active = $wpdb->get_var( $wpdb->prepare( "SELECT active_attempt FROM {$wpdb->prefix}mobishop_native_checkout50_buyers WHERE buyer_scope=%s", $buyer ) );
        return ! empty( $active ) || ! empty( $wpdb->last_error );
    }

    /** Read authoritative Woo session contents, including extension cart-item metadata. */
    private function cart_data( string $key, int $customer ): ?array {
        global $wpdb;
        if ( ! preg_match( '/^(?:[1-9][0-9]{0,17}|t_[a-f0-9]{30}|(?:t_)?[a-f0-9]{32})$/D', $key ) ||
            ( ctype_digit( $key ) && $key !== (string) $customer ) ) return null;
        $row = $wpdb->get_row( $wpdb->prepare( "SELECT session_value, session_expiry FROM {$wpdb->prefix}woocommerce_sessions WHERE session_key=%s", $key ), ARRAY_A );
        if ( ! is_array( $row ) || (int) $row['session_expiry'] <= time() ) return null;
        $data = maybe_unserialize( $row['session_value'] );
        if ( ! is_array( $data ) ) return null;
        $owner = (array) maybe_unserialize( $data['customer'] ?? array() );
        if ( (int) ( $owner['id'] ?? 0 ) !== 0 && (int) $owner['id'] !== $customer ) return null;
        $cart = maybe_unserialize( $data['cart'] ?? array() );
        return is_array( $cart ) && count( $cart ) > 0 ? $data : null;
    }

    public function issue( WP_REST_Request $request ) {
        $context = ( new MobiShop_Customer_Auth_Endpoint() )->session_context_from_request( $request );
        if ( is_wp_error( $context ) ) return $context;
        $customer = (int) $context['user_id'];
        if ( $customer !== get_current_user_id() ) return $this->error( 'identity', 401 );
        $token = (string) $request->get_header( 'Cart-Token' );
        $class = '\Automattic\WooCommerce\StoreApi\Utilities\CartTokenUtils';
        if ( ! class_exists( $class ) || strlen( $token ) > 4096 || ! $class::validate_cart_token( $token ) ) return $this->error( 'cart', 403 );
        $payload = $class::get_cart_token_payload( $token );
        $key = (string) ( $payload['user_id'] ?? '' );
        if ( 'store-api' !== ( $payload['iss'] ?? '' ) || (int) ( $payload['exp'] ?? 0 ) <= time() || ! $this->cart_data( $key, $customer ) ) return $this->error( 'cart', 403 );
        // An uncertain Native dispatch must be recovered, never evaded by changing UI.
        if ( $this->has_unresolved_checkout( $customer ) ) return $this->error( 'recover_existing_order' );
        $checkout = wc_get_checkout_url();
        $home = wp_parse_url( home_url( '/' ) );
        $url = wp_parse_url( $checkout );
        if ( ( $url['scheme'] ?? '' ) !== 'https' || ( $url['host'] ?? '' ) !== ( $home['host'] ?? '' ) ||
            ( $url['port'] ?? 443 ) !== ( $home['port'] ?? 443 ) || isset( $url['query'] ) || isset( $url['user'] ) ) return $this->error( 'checkout_url', 503 );
        $ticket = bin2hex( random_bytes( 32 ) );
        $record = array_merge( $context, array( 'cart_key' => $key, 'origin' => $this->origin(),
            'checkout_url' => $checkout, 'checkout_path' => $url['path'], 'home_path' => $home['path'] ?? '/',
            'expires' => min( time() + 90, (int) $context['expires'] ) ) );
        $option = self::PREFIX . hash( 'sha256', $ticket );
        if ( ! add_option( $option, $record, '', false ) ) return $this->error( 'storage', 503 );
        wp_schedule_single_event( time() + 120, 'mobishop_checkout88_expire', array( $option ) );
        $response = new WP_REST_Response( array( 'protocol' => 88, 'url' => add_query_arg( 'mobishop-checkout88', '1', home_url( '/' ) ), 'checkout_url' => $checkout, 'ticket' => $ticket ), 200 );
        $response->header( 'Cache-Control', 'no-store, private' );
        $response->header( 'Referrer-Policy', 'no-referrer' );
        return $response;
    }

    public function scoped_user( $user ) {
        $raw = $_COOKIE[ self::COOKIE ] ?? '';
        if ( $raw === '' ) return $user;
        if ( ! is_string( $raw ) || ! preg_match( '/^[a-f0-9]{64}$/D', $raw ) ) return 0;
        $scope = get_transient( 'mobishop_checkout88_' . hash( 'sha256', $raw ) );
        if ( ! is_array( $scope ) || ! $this->active( $scope ) ) return 0;
        $path = wp_parse_url( (string) ( $_SERVER['REQUEST_URI'] ?? '' ), PHP_URL_PATH );
        if ( ! is_string( $path ) || ! self::allowed_path( $path, $scope['checkout_path'], $scope['home_path'], $_GET ) ) return 0;
        // This cookie cannot inherit an existing administrator's capabilities.
        $this->scope = $scope;
        return (int) $scope['user_id'];
    }

    public function restore_identity(): void {
        // Another extension may have resolved the user before our filter was
        // registered. Resolve the scoped cookie before Woo opens its session.
        if ( isset( $_COOKIE[ self::COOKIE ] ) ) wp_set_current_user( (int) $this->scoped_user( 0 ) );
    }

    public function customer_capabilities( array $caps, array $required, array $args, $user ): array {
        if ( null === $this->scope || (int) $user->ID !== (int) $this->scope['user_id'] ) return $caps;
        return array_intersect_key( $caps, array( 'read' => true ) );
    }

    public function redeem(): void {
        if ( ( $_GET['mobishop-checkout88'] ?? '' ) !== '1' ) return;
        nocache_headers();
        header( 'Referrer-Policy: no-referrer' );
        $ticket = $_POST['ticket'] ?? '';
        if ( ( $_SERVER['REQUEST_METHOD'] ?? '' ) !== 'POST' || ! is_string( $ticket ) || ! preg_match( '/^[a-f0-9]{64}$/D', $ticket ) ) $this->deny();
        $key = self::PREFIX . hash( 'sha256', $ticket );
        $record = get_option( $key );
        if ( ! is_array( $record ) || ! $this->active( $record ) || ! $this->cart_data( $record['cart_key'], (int) $record['user_id'] ) ) $this->deny();
        if ( $this->has_unresolved_checkout( (int) $record['user_id'] ) ) $this->deny();
        global $wpdb;
        // Atomic consume: two tabs cannot both redeem the same ticket.
        $deleted = $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name=%s AND option_value=%s", $key, maybe_serialize( $record ) ) );
        wp_cache_delete( $key, 'options' );
        if ( 1 !== $deleted ) $this->deny();
        $record['expires'] = time() + 1800;
        $cookie = bin2hex( random_bytes( 32 ) );
        set_transient( 'mobishop_checkout88_' . hash( 'sha256', $cookie ), $record, 1800 );
        setcookie( self::COOKIE, $cookie, array( 'expires' => $record['expires'], 'path' => $record['home_path'], 'secure' => true, 'httponly' => true, 'samesite' => 'Lax' ) );
        // Resolve only this request; never issue a general WordPress login cookie.
        $this->scope = $record;
        $this->bootstrap = $record;
        wp_set_current_user( (int) $record['user_id'] );
        // Avoid migrating/deleting a different previous WebView user's cart.
        unset( $_COOKIE[ apply_filters( 'woocommerce_cookie', 'wp_woocommerce_session_' . COOKIEHASH ) ] );
    }

    public function restore_cart(): void {
        if ( null === $this->bootstrap ) return;
        $data = $this->cart_data( $this->bootstrap['cart_key'], (int) $this->bootstrap['user_id'] );
        if ( null === $data || ! WC()->session ) $this->deny();
        // Extensions can initialize Woo before init. Rebind that handler after
        // the ticket has selected the customer and removed the old cookie.
        // Otherwise the copied basket is saved to a guest session and checkout
        // opens the customer's empty session on the following request.
        WC()->session->init_session_cookie();
        if ( (string) WC()->session->get_customer_id() !== (string) $this->bootstrap['user_id'] ) $this->deny();
        // Use Woo's session layer. No price, stock, field, gateway or order rules are replaced.
        foreach ( $data as $key => $value ) {
            if ( in_array( $key, array( 'customer', 'order_awaiting_payment', 'store_api_draft_order', 'previous_customer_id' ), true ) ) continue;
            WC()->session->set( $key, maybe_unserialize( $value ) );
        }
        WC()->session->set_customer_session_cookie( true );
        WC()->session->save_data();
    }

    public function redirect(): void {
        if ( null !== $this->bootstrap ) {
            wp_safe_redirect( $this->bootstrap['checkout_url'], 303 );
            exit;
        }
        if ( null !== $this->scope ) {
            nocache_headers();
            header( 'Referrer-Policy: no-referrer' );
        }
    }

    public function document_style(): void {
        if ( null === $this->scope || ! is_checkout() ) return;
        // Only surrounding site chrome is removed. Merchant checkout markup/JS stays intact.
        echo '<style id="mobishop-checkout88-chrome">.site-header,#masthead,header#header,.site-footer,#colophon,footer#footer,.woocommerce-breadcrumb{display:none!important}body{min-width:0!important}</style>';
    }

    private function deny(): void {
        wp_die( 'انتهت جلسة إتمام الطلب. ارجع للتطبيق وافتح السلة مرة أخرى.', 'Checkout unavailable', array( 'response' => 403 ) );
        exit;
    }
}
