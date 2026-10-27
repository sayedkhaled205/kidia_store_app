<?php
/** FlyCart channel eligibility. FlyCart continues to own all discount arithmetic. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Discount_Channel {
    public const KEY = 'mobishop_channel';
    private static bool $embedded_checkout = false;

    public static function register(): void {
        add_filter( 'advanced_woo_discount_rules_has_rule_conditions', static fn( $has, $rule ) => $has || ! self::allowed( $rule ), 100, 2 );
        add_filter( 'advanced_woo_discount_rules_is_conditions_passed', static fn( $passed, $object, $rule ) => $passed && self::allowed( $rule ), 100, 3 );
        add_filter( 'advanced_woo_discount_rules_filter_passed', static fn( $passed, $rule ) => $passed && self::allowed( $rule ), 100, 2 );
        add_filter( 'advanced_woo_discount_rules_do_process_discounts_of_each_rule', static fn( $passed, $cart, $rule ) => $passed && self::allowed( $rule ), 100, 3 );
        add_filter( 'advanced_woo_discount_rules_is_rule_passed_for_exclusive_rule', static fn( $passed, $product, $rule ) => $passed && self::allowed( $rule ), 100, 3 );
        // The original FlyCart editor does not render our additional field. Its
        // normal save must retain the channel chosen in the central builder.
        add_filter( 'advanced_woo_discount_rules_before_save_rule_column', array( __CLASS__, 'preserve_channel' ), 100, 2 );
    }

    /** Called only after checkout88 validates its scoped ticket/cookie and path. */
    public static function verified_embedded_checkout(): void { self::$embedded_checkout = true; }

    public static function api_route( string $uri, string $rest_route = '' ): bool {
        $path = (string) parse_url( $uri, PHP_URL_PATH );
        return $rest_route !== ''
            ? (bool) preg_match( '~^/(?:wc/store/v[0-9]+|mobishop/v1)(?:/|$)~D', $rest_route )
            : (bool) preg_match( '~/wp-json/(?:wc/store/v[0-9]+|mobishop/v1)(?:/|$)~D', $path );
    }

    public static function current(): string {
        if ( self::$embedded_checkout ) return 'mobile';
        $route = isset( $_GET['rest_route'] ) && is_string( $_GET['rest_route'] ) ? $_GET['rest_route'] : '';
        if ( ! self::api_route( (string) ( $_SERVER['REQUEST_URI'] ?? '' ), $route ) ) return 'website';
        // This identifies the API sales channel, not device attestation or an
        // authorization credential. Website query flags/cookies never set it.
        if ( ( $_SERVER['HTTP_X_MOBISHOP_CHANNEL'] ?? '' ) === 'mobile' ) return 'mobile';
        // Existing signed-in app releases predate the explicit cart header.
        $token = $_SERVER['HTTP_X_MOBISHOP_SESSION'] ?? '';
        if ( is_string( $token ) && $token !== '' && class_exists( 'MobiShop_Customer_Auth_Endpoint' ) ) {
            $request = new WP_REST_Request();
            $request->set_header( 'X-MobiShop-Session', $token );
            $context = ( new MobiShop_Customer_Auth_Endpoint() )->session_context_from_request( $request );
            if ( ! is_wp_error( $context ) ) return 'mobile';
        }
        return 'website';
    }

    public static function scope( $rule ): string {
        if ( is_object( $rule ) && isset( $rule->rule ) ) $rule = $rule->rule;
        $extra = is_object( $rule ) ? ( $rule->additional ?? '' ) : ( $rule['additional'] ?? '' );
        $extra = is_string( $extra ) ? json_decode( $extra, true ) : (array) $extra;
        $channel = $extra[ self::KEY ] ?? 'all';
        return in_array( $channel, array( 'all', 'website', 'mobile' ), true ) ? $channel : 'all';
    }

    public static function allowed( $rule ): bool {
        $scope = self::scope( $rule );
        return $scope === 'all' || $scope === self::current();
    }

    public static function preserve_channel( array $columns, $id ): array {
        if ( (int) $id <= 0 ) return $columns;
        global $wpdb;
        $old = $wpdb->get_row( $wpdb->prepare( "SELECT additional FROM {$wpdb->prefix}wdr_rules WHERE id=%d", $id ), ARRAY_A );
        if ( ! is_array( $old ) ) return $columns;
        $extra = json_decode( (string) ( $columns['additional'] ?? '[]' ), true );
        if ( ! is_array( $extra ) ) $extra = array();
        $extra[ self::KEY ] = self::scope( $old );
        $columns['additional'] = wp_json_encode( $extra );
        return $columns;
    }
}
