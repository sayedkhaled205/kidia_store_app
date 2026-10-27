<?php
/** Private, store-owned merchant controls; never accepts arbitrary FlyCart JSON. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Discount_Rules_Admin {
    public static function authorized(): bool {
        return current_user_can( 'manage_options' ) && current_user_can( 'manage_woocommerce' );
    }

    public static function register(): void {
        add_action( 'rest_api_init', static function (): void {
            register_rest_route( 'mobishop/v1', '/central/discount-rules', array(
                'methods' => array( 'GET', 'POST' ),
                'permission_callback' => array( __CLASS__, 'authorized' ),
                'callback' => array( __CLASS__, 'handle' ),
            ) );
        } );
    }

    public static function revision( array $row ): string {
        // Purchases updating usage counters do not overwrite merchant settings.
        unset( $row['used_limits'] );
        ksort( $row );
        return hash( 'sha256', wp_json_encode( $row ) );
    }

    public static function handle( WP_REST_Request $request ) {
        if ( ! self::authorized() ) return new WP_Error( 'forbidden', 'Merchant access required.', array( 'status' => 403 ) );
        if ( ! class_exists( '\Wdr\App\Helpers\Rule' ) ) return new WP_Error( 'discount_unavailable', 'Activate Discount Rules on the connected store first.', array( 'status' => 409 ) );
        try {
            if ( $request->get_method() === 'GET' ) {
                if ( $request->get_param( 'operation' ) !== 'targets' ) throw new InvalidArgumentException( 'Choose a valid action.' );
                $result = array( 'ok' => true, 'items' => self::targets( (string) $request->get_param( 'kind' ), (string) $request->get_param( 'search' ) ) );
            } else {
                $body = $request->get_json_params();
                if ( ! is_array( $body ) ) throw new InvalidArgumentException( 'A valid offer is required.' );
                $result = self::mutate( $body );
            }
            $response = new WP_REST_Response( $result );
            $response->header( 'Cache-Control', 'no-store, private' );
            return $response;
        } catch ( InvalidArgumentException $error ) {
            return new WP_Error( 'invalid_discount', $error->getMessage(), array( 'status' => 422 ) );
        } catch ( DomainException $error ) {
            return new WP_Error( 'discount_conflict', $error->getMessage(), array( 'status' => 409 ) );
        } catch ( Throwable $error ) {
            return new WP_Error( 'discount_save_unconfirmed', 'Saving could not be confirmed. Retry the same request before creating another offer.', array( 'status' => 503 ) );
        }
    }

    public static function targets( string $kind, string $search ): array {
        if ( strlen( $search ) > 200 || ! in_array( $kind, array( 'products', 'categories' ), true ) ) throw new InvalidArgumentException( 'Invalid product search.' );
        $items = array();
        if ( $kind === 'categories' ) {
            $terms = get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false, 'search' => sanitize_text_field( $search ), 'number' => 30 ) );
            if ( is_wp_error( $terms ) ) throw new RuntimeException( 'Category lookup failed.' );
            foreach ( $terms as $term ) $items[] = array( 'id' => (int) $term->term_id, 'label' => $term->name );
        } else {
            $query = new WP_Query( array( 'post_type' => array( 'product', 'product_variation' ), 'post_status' => 'publish', 's' => sanitize_text_field( $search ), 'posts_per_page' => 30, 'no_found_rows' => true ) );
            foreach ( $query->posts as $post ) {
                $product = wc_get_product( $post->ID );
                if ( $product ) $items[] = array( 'id' => (int) $post->ID, 'label' => wp_strip_all_tags( $product->get_formatted_name() ) );
            }
        }
        return $items;
    }

    private static function ids( $value, string $kind, bool $gift = false ): array {
        if ( ! is_array( $value ) || ! $value || count( $value ) > 100 ) throw new InvalidArgumentException( 'Choose between 1 and 100 products or categories.' );
        $ids = array();
        foreach ( $value as $id ) {
            if ( ! is_int( $id ) || $id <= 0 ) throw new InvalidArgumentException( 'Choose a valid product or category.' );
            if ( $kind === 'categories' ) {
                if ( ! term_exists( $id, 'product_cat' ) ) throw new InvalidArgumentException( 'A selected category no longer exists.' );
            } else {
                $product = wc_get_product( $id );
                if ( ! $product || $product->get_status() !== 'publish' ) throw new InvalidArgumentException( 'A selected product is unavailable.' );
                if ( $gift && ! $product->is_type( array( 'simple', 'variation' ) ) ) throw new InvalidArgumentException( 'For a gift, choose a simple product or a specific variation.' );
            }
            $ids[] = $id;
        }
        return array_values( array_unique( $ids ) );
    }

    private static function number( $value, bool $integer = false ): float {
        if ( ! is_scalar( $value ) || is_bool( $value ) || ! preg_match( $integer ? '/^[1-9][0-9]{0,5}$/D' : '/^(?:0|[1-9][0-9]{0,8})(?:\.[0-9]{1,6})?$/D', (string) $value ) || (float) $value <= 0 ) throw new InvalidArgumentException( 'Enter a positive amount or quantity.' );
        return (float) $value;
    }

    private static function date( $value ): string {
        if ( $value === '' || $value === null ) return '';
        if ( ! is_string( $value ) ) throw new InvalidArgumentException( 'Choose a valid date.' );
        $date = DateTimeImmutable::createFromFormat( '!Y-m-d H:i', $value, wp_timezone() );
        if ( ! $date || $date->format( 'Y-m-d H:i' ) !== $value ) throw new InvalidArgumentException( 'Choose a valid date.' );
        return $value;
    }

    /** Builds the same input structure as the supported FlyCart editor. */
    public static function creation( array $input ): array {
        $types = array( 'simple' => 'wdr_simple_discount', 'cart' => 'wdr_cart_discount', 'bulk' => 'wdr_bulk_discount', 'set' => 'wdr_set_discount', 'bxgx' => 'wdr_buy_x_get_x_discount', 'bxgy' => 'wdr_buy_x_get_y_discount', 'shipping' => 'wdr_free_shipping' );
        $type = $input['type'] ?? '';
        if ( ! is_string( $type ) || ! isset( $types[ $type ] ) ) throw new InvalidArgumentException( 'Choose a supported discount type.' );
        if ( in_array( $type, array( 'set', 'bxgx', 'bxgy', 'shipping' ), true ) && ! class_exists( '\WDRPro\App\Rules\BOGO' ) ) throw new InvalidArgumentException( 'This offer needs Discount Rules Pro on the store.' );
        $target = $input['target'] ?? '';
        if ( ! in_array( $target, array( 'all', 'products', 'categories' ), true ) ) throw new InvalidArgumentException( 'Choose the products for this offer.' );
        if ( $type === 'shipping' && $target !== 'all' ) throw new InvalidArgumentException( 'Free shipping applies to the whole cart. Use the website editor for additional cart conditions.' );
        $ids = $target === 'all' ? array() : self::ids( $input['ids'] ?? array(), $target );
        $from = self::date( $input['date_from'] ?? '' );
        $to = self::date( $input['date_to'] ?? '' );
        if ( $from && $to && $to < $from ) throw new InvalidArgumentException( 'The end date must follow the start date.' );
        $post = array( 'title' => $input['title'], 'enabled' => $input['enabled'] ? '1' : '0', 'exclusive' => '0', 'usage_limits' => '0', 'discount_type' => $types[ $type ], 'date_from' => $from, 'date_to' => $to, 'conditions' => array(), 'additional' => array( MobiShop_Discount_Channel::KEY => $input['channel'] ) );
        $post['filters'] = $target === 'all' ? array() : array( '1' => array( 'type' => $target === 'categories' ? 'product_category' : 'products', 'method' => 'in_list', 'value' => $ids ) );
        if ( in_array( $type, array( 'simple', 'cart', 'bulk', 'set' ), true ) ) {
            $kind = $type === 'set' ? 'fixed_set_price' : ( $input['discount_kind'] ?? '' );
            if ( $type !== 'set' && ! in_array( $kind, array( 'percentage', 'flat' ), true ) ) throw new InvalidArgumentException( 'Choose percentage or a fixed discount.' );
            $value = self::number( $input['value'] ?? '' );
            if ( $kind === 'percentage' && $value > 100 ) throw new InvalidArgumentException( 'Percentage must not exceed 100.' );
            if ( $type === 'cart' && $kind === 'flat' ) $kind = 'flat_in_subtotal';
            $amount = array( 'type' => $kind, 'value' => (string) $value );
            if ( $type === 'simple' ) $post['product_adjustments'] = $amount + array( 'apply_as_cart_rule' => '0' );
            if ( $type === 'cart' ) $post['cart_adjustments'] = $amount + array( 'label' => $input['title'] );
            if ( $type === 'bulk' || $type === 'set' ) {
                $qty = (string) self::number( $input['min_qty'] ?? '', true );
                $post[ $type . '_adjustments' ] = array( 'operator' => 'product', 'apply_as_cart_rule' => '0', 'ranges' => array( '1' => $amount + array( 'from' => $qty, 'to' => '', 'recursive' => '1', 'label' => '' ) ) );
            }
        }
        if ( $type === 'bxgx' || $type === 'bxgy' ) {
            $buy = (string) self::number( $input['min_qty'] ?? '', true );
            $free = (string) self::number( $input['free_qty'] ?? '', true );
            $range = array( 'from' => $buy, 'to' => '', 'free_qty' => $free, 'free_type' => 'free_product', 'free_value' => '0', 'recursive' => '1' );
            $adjustments = array();
            if ( $type === 'bxgy' ) {
                $range['products'] = self::ids( $input['gift_ids'] ?? array(), 'products', true );
                $adjustments = array( 'type' => 'bxgy_product', 'mode' => 'auto_add', 'operator' => 'product_cumulative' );
            }
            $adjustments['ranges'] = array( '1' => $range );
            $post[ $type === 'bxgx' ? 'buyx_getx_adjustments' : 'buyx_gety_adjustments' ] = $adjustments;
        }
        $validation = \Wdr\App\Helpers\Validation::validateRules( $post );
        if ( $validation !== true ) throw new InvalidArgumentException( 'Check the offer amount, quantities and dates.' );
        return $post;
    }

    /** Atomic optimistic updates + idempotent creation/clone retries. */
    public static function mutate( array $input ): array {
        if ( ! self::authorized() ) throw new DomainException( 'Merchant access required.' );
        $allowed = array( 'operation', 'request_id', 'id', 'revision', 'title', 'channel', 'enabled', 'type', 'target', 'ids', 'discount_kind', 'value', 'min_qty', 'free_qty', 'gift_ids', 'date_from', 'date_to' );
        if ( array_diff( array_keys( $input ), $allowed ) ) throw new InvalidArgumentException( 'Unsupported offer fields.' );
        $operation = $input['operation'] ?? '';
        if ( ! in_array( $operation, array( 'create', 'update', 'clone' ), true ) || ! is_bool( $input['enabled'] ?? null ) || ! in_array( $input['channel'] ?? '', array( 'all', 'website', 'mobile' ), true ) ) throw new InvalidArgumentException( 'Choose an offer status and sales channel.' );
        $key = $input['request_id'] ?? '';
        if ( ! is_string( $key ) || ! preg_match( '/^[a-f0-9-]{36}$/Di', $key ) ) throw new InvalidArgumentException( 'Reload the offer editor and retry.' );
        if ( $operation !== 'update' ) {
            if ( ! is_string( $input['title'] ?? null ) || trim( $input['title'] ) === '' || mb_strlen( $input['title'] ) > 200 ) throw new InvalidArgumentException( 'Enter an offer name of up to 200 characters.' );
            $input['title'] = sanitize_text_field( $input['title'] );
            if ( trim( $input['title'] ) === '' ) throw new InvalidArgumentException( 'Enter an offer name.' );
        }
        if ( $operation !== 'create' && ( ! is_int( $input['id'] ?? null ) || $input['id'] <= 0 || ! is_string( $input['revision'] ?? null ) || ! preg_match( '/^[a-f0-9]{64}$/D', $input['revision'] ) ) ) throw new InvalidArgumentException( 'Reload this offer before saving.' );
        $post = $operation === 'create' ? self::creation( $input ) : null;
        global $wpdb;
        $table = $wpdb->prefix . 'wdr_rules';
        $option = 'mobishop_discount_request_' . hash( 'sha256', $key );
        $hash = hash( 'sha256', wp_json_encode( $input ) );
        if ( $wpdb->query( 'START TRANSACTION' ) === false ) throw new RuntimeException( 'Transaction unavailable.' );
        try {
            // Unique option_name serializes concurrent retries. No frontend data.
            $claimed = $wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$wpdb->options} (option_name,option_value,autoload) VALUES (%s,%s,'off')", $option, wp_json_encode( array( 'hash' => $hash ) ) ) );
            if ( $claimed === false ) throw new RuntimeException( 'Request claim failed.' );
            if ( $claimed === 0 ) {
                $saved = json_decode( (string) $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name=%s FOR UPDATE", $option ) ), true );
                if ( ! is_array( $saved ) || ! hash_equals( $saved['hash'] ?? '', $hash ) || ! isset( $saved['result'] ) ) throw new DomainException( 'This request changed. Reload the offer before saving.' );
                if ( $wpdb->query( 'COMMIT' ) === false ) throw new RuntimeException( 'Commit failed.' );
                return $saved['result'];
            }
            if ( $operation === 'create' ) {
                $id = ( new \Wdr\App\Helpers\Rule() )->save( $post );
                if ( ! is_numeric( $id ) || (int) $id <= 0 || $wpdb->last_error ) throw new RuntimeException( 'Create failed.' );
                $id = (int) $id;
            } else {
                $old = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM {$table} WHERE id=%d AND deleted=0 FOR UPDATE", $input['id'] ), ARRAY_A );
                if ( ! $old || ! hash_equals( self::revision( $old ), $input['revision'] ) ) throw new DomainException( 'This offer changed elsewhere. Refresh the list and reopen it.' );
                $metadata = $old['additional'] ?? '';
                $extra = trim( $metadata ) === '' ? array() : json_decode( $metadata, true );
                if ( ! is_array( $extra ) ) throw new DomainException( 'This offer needs repair in the website rule editor first.' );
                $extra[ MobiShop_Discount_Channel::KEY ] = $input['channel'];
                $changes = array( 'enabled' => $input['enabled'] ? 1 : 0, 'additional' => wp_json_encode( $extra ), 'modified_by' => get_current_user_id(), 'modified_on' => current_time( 'mysql' ) );
                if ( $operation === 'update' ) {
                    $id = $input['id'];
                    if ( $wpdb->update( $table, $changes, array( 'id' => $id ) ) === false ) throw new RuntimeException( 'Update failed.' );
                } else {
                    // Copy every existing condition/adjustment without reconstructing it.
                    unset( $old['id'] );
                    $row = array_merge( $old, $changes, array( 'title' => $input['title'], 'used_limits' => 0, 'created_by' => get_current_user_id(), 'created_on' => current_time( 'mysql' ) ) );
                    $row['priority'] = 1 + (int) $wpdb->get_var( "SELECT MAX(priority) FROM {$table}" );
                    if ( $wpdb->insert( $table, $row ) !== 1 ) throw new RuntimeException( 'Clone failed.' );
                    $id = (int) $wpdb->insert_id;
                }
            }
            $row = $wpdb->get_row( $wpdb->prepare( "SELECT * FROM {$table} WHERE id=%d", $id ), ARRAY_A );
            if ( ! $row || (int) $row['enabled'] !== (int) $input['enabled'] || MobiShop_Discount_Channel::scope( $row ) !== $input['channel'] ) throw new RuntimeException( 'Save verification failed.' );
            $result = array( 'ok' => true, 'id' => $id, 'revision' => self::revision( $row ), 'channel' => $input['channel'], 'enabled' => $input['enabled'] );
            if ( $wpdb->update( $wpdb->options, array( 'option_value' => wp_json_encode( array( 'hash' => $hash, 'result' => $result ) ) ), array( 'option_name' => $option ) ) === false ) throw new RuntimeException( 'Request record failed.' );
            if ( $wpdb->query( 'COMMIT' ) === false ) throw new RuntimeException( 'Commit failed.' );
            wp_cache_delete( $option, 'options' );
            // Invalidate FlyCart's own on-sale index after state/channel changes.
            if ( class_exists( '\Wdr\App\Controllers\OnSaleShortCode' ) ) \Wdr\App\Controllers\OnSaleShortCode::updateOnsaleRebuildPageStatus( $id );
            return $result;
        } catch ( Throwable $error ) {
            $wpdb->query( 'ROLLBACK' );
            wp_cache_delete( $option, 'options' );
            throw $error;
        }
    }
}
MobiShop_Discount_Rules_Admin::register();
