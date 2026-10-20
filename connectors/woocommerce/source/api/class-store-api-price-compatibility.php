<?php
/** Keep Store API price query values textual after third-party query parsing. */
defined( 'ABSPATH' ) || exit;
final class MobiShop_Store_Api_Price_Compatibility {
    public static function register(): void {
        add_filter( 'rest_pre_dispatch', array( self::class, 'normalize_price_query' ), 20, 3 );
    }

    public static function normalize_price_query( $result, $server, $request ) {
        if ( null !== $result || 'GET' !== $request->get_method()
            || ! preg_match( '#^/wc/store/v[0-9]+/products(?:/collection-data)?/?$#', $request->get_route() ) ) {
            return $result;
        }
        // Some storefront filters convert $_GET prices to floats before REST
        // dispatch. WooCommerce requires strings representing minor units.
        // Restore only that representation; WooCommerce still validates the value.
        $query = $request->get_query_params();
        foreach ( array( 'min_price', 'max_price' ) as $key ) {
            $value = $query[ $key ] ?? null;
            if ( is_int( $value ) || ( is_float( $value ) && is_finite( $value ) ) ) {
                $request->set_param( $key, (string) $value );
            }
        }
        return $result;
    }
}
MobiShop_Store_Api_Price_Compatibility::register();
