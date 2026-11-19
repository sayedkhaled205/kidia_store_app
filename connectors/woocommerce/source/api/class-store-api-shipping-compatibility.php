<?php
/** Keep an unresolved mobile shipping quote distinct from genuine free delivery. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Store_Api_Shipping_Compatibility {
    public static function register(): void {
        add_filter( 'rest_post_dispatch', array( self::class, 'cart_response' ), 60, 3 );
    }

    public static function cart_response( $response, $server, $request ) {
        if ( 'mobile' !== strtolower( (string) $request->get_header( 'X-MobiShop-Channel' ) )
            || ! preg_match( '#^/wc/store/v[0-9]+/cart(?:/[^/]+)?/?$#', $request->get_route() )
            || ! ( $response instanceof WP_REST_Response )
            || $response->get_status() < 200 || $response->get_status() >= 300 ) {
            return $response;
        }
        $original = $response->get_data();
        if ( ! is_array( $original ) && ! ( $original instanceof stdClass ) ) {
            return $response;
        }
        $data = (array) $original;
        $address = (array) ( $data['shipping_address'] ?? array() );
        if ( true !== ( $data['needs_shipping'] ?? null ) || true !== ( $data['has_calculated_shipping'] ?? null )
            || '' !== trim( (string) ( $address['country'] ?? '' ) ) ) {
            return $response;
        }
        // Woo can report calculated=true before any destination or rate exists.
        // Preserve a real quote (including zero), and no-rates errors for a known destination.
        $packages = (array) ( $data['shipping_rates'] ?? array() );
        $quoted = ! empty( $packages );
        foreach ( $packages as $package ) {
            $package = (array) $package;
            $selected = 0;
            foreach ( (array) ( $package['shipping_rates'] ?? array() ) as $rate ) {
                $rate = (array) $rate;
                if ( true === ( $rate['selected'] ?? null ) && '' !== trim( (string) ( $rate['rate_id'] ?? '' ) ) ) {
                    ++$selected;
                }
            }
            $quoted = $quoted && 1 === $selected;
        }
        if ( ! $quoted ) {
            $data['has_calculated_shipping'] = false;
            $response->set_data( is_object( $original ) ? (object) $data : $data );
        }
        return $response;
    }
}
MobiShop_Store_Api_Shipping_Compatibility::register();
