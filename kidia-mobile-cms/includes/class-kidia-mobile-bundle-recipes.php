<?php
/**
 * Universal bundle recipes shared by AI Studio, Home Builder and the app.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Bundle_Recipes {

	private const OPTION = 'kidia_mobile_bundle_recipes_v1';

	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
		add_action( 'admin_post_kidia_mobile_save_bundle_recipe', array( $this, 'save_recipe' ) );
		add_filter( 'woocommerce_coupon_is_valid', array( $this, 'validate_bundle_coupon' ), 25, 2 );
	}

	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/bundles',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_bundles' ),
				'permission_callback' => '__return_true',
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/bundles/(?P<id>[A-Za-z0-9_-]+)',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'get_bundle' ),
				'permission_callback' => '__return_true',
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/bundles/(?P<id>[A-Za-z0-9_-]+)/claim',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'claim_bundle' ),
				'permission_callback' => '__return_true',
			)
		);
	}

	public function get_bundles( WP_REST_Request $request ): WP_REST_Response {
		$channel = sanitize_key( (string) $request->get_param( 'channel' ) );
		$channel = in_array( $channel, array( 'website', 'mobile' ), true ) ? $channel : 'mobile';
		$rows = array_values(
			array_filter(
				self::all(),
				static fn( $recipe ) => 'published' === ( $recipe['status'] ?? 'draft' )
					&& in_array( (string) ( $recipe['channel'] ?? 'all' ), array( 'all', $channel ), true )
					&& self::is_active( $recipe )
			)
		);
		return rest_ensure_response( array( 'version' => 1, 'channel' => $channel, 'bundles' => $rows ) );
	}

	public function get_bundle( WP_REST_Request $request ) {
		$id = sanitize_key( (string) $request->get_param( 'id' ) );
		$rows = self::all();
		$recipe = is_array( $rows[ $id ] ?? null ) ? $rows[ $id ] : null;
		$channel = sanitize_key( (string) $request->get_param( 'channel' ) );
		$channel = in_array( $channel, array( 'website', 'mobile' ), true ) ? $channel : 'mobile';
		if (
			! is_array( $recipe )
			|| 'published' !== ( $recipe['status'] ?? 'draft' )
			|| ! self::is_active( $recipe )
			|| ! in_array( (string) ( $recipe['channel'] ?? 'all' ), array( 'all', $channel ), true )
		) {
			return new WP_Error( 'kidia_bundle_not_found', __( 'Bundle not found.', 'kidia-mobile-cms' ), array( 'status' => 404 ) );
		}
		return rest_ensure_response( $recipe );
	}

	public function claim_bundle( WP_REST_Request $request ) {
		$id = sanitize_key( (string) $request->get_param( 'id' ) );
		$rows = self::all();
		$recipe = is_array( $rows[ $id ] ?? null ) ? $rows[ $id ] : null;
		if ( ! is_array( $recipe ) || 'published' !== ( $recipe['status'] ?? 'draft' ) || ! self::is_active( $recipe ) ) {
			return new WP_Error( 'kidia_bundle_unavailable', __( 'Bundle is not currently available.', 'kidia-mobile-cms' ), array( 'status' => 404 ) );
		}
		$channel = sanitize_key( (string) $request->get_param( 'channel' ) );
		$channel = in_array( $channel, array( 'website', 'mobile' ), true ) ? $channel : 'mobile';
		if ( ! in_array( (string) ( $recipe['channel'] ?? 'all' ), array( 'all', $channel ), true ) ) {
			return new WP_Error( 'kidia_bundle_channel', __( 'Bundle is not available on this sales channel.', 'kidia-mobile-cms' ), array( 'status' => 403 ) );
		}
		$coupon_code = $this->ensure_bundle_coupon( $recipe );
		if ( is_wp_error( $coupon_code ) ) {
			return $coupon_code;
		}
		return rest_ensure_response(
			array(
				'bundle_id'   => $id,
				'coupon_code' => $coupon_code,
				'channel'     => $channel,
				'expires_at'  => (string) ( $recipe['ends_at'] ?? '' ),
			)
		);
	}

	public function save_recipe(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to manage bundles.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_save_bundle_recipe', 'kidia_mobile_bundle_nonce' );
		$raw = isset( $_POST['bundle'] ) && is_array( $_POST['bundle'] ) ? wp_unslash( $_POST['bundle'] ) : array();
		$recipe = self::sanitize( $raw );
		$rows = self::all();
		$rows[ $recipe['id'] ] = $recipe;
		update_option( self::OPTION, $rows, false );
		if ( ! empty( $raw['create_product'] ) && in_array( $recipe['type'], array( 'fixed', 'multipack' ), true ) ) {
			$rows[ $recipe['id'] ]['product_id'] = $this->create_or_update_bundle_product( $recipe );
			update_option( self::OPTION, $rows, false );
		}
		wp_safe_redirect(
			add_query_arg(
				array(
					'page'         => 'kidia-mobile-ai-insights',
					'bundle_saved' => '1',
					'bundle_id'    => $recipe['id'],
				),
				admin_url( 'admin.php' )
			)
		);
		exit;
	}

	/** @return array<string,array<string,mixed>> */
	public static function all(): array {
		$rows = get_option( self::OPTION, array() );
		return is_array( $rows ) ? $rows : array();
	}

	/** Stores one already sanitized recipe and returns its id. */
	public static function store( array $raw ): string {
		$recipe = self::sanitize( $raw );
		$rows = self::all();
		$rows[ $recipe['id'] ] = $recipe;
		update_option( self::OPTION, $rows, false );
		return (string) $recipe['id'];
	}

	/** Updates a reviewed bundle lifecycle without rebuilding its recipe. */
	public static function set_status( string $id, string $status ): bool {
		$id     = sanitize_key( $id );
		$status = 'published' === sanitize_key( $status ) ? 'published' : 'draft';
		$rows   = self::all();
		if ( '' === $id || ! is_array( $rows[ $id ] ?? null ) ) {
			return false;
		}
		$rows[ $id ]['status']     = $status;
		$rows[ $id ]['updated_at'] = time();
		update_option( self::OPTION, $rows, false );
		return true;
	}

	/** @return array<string,mixed> */
	public static function sanitize( array $raw ): array {
		$types = array(
			'fixed', 'multipack', 'mix_match', 'build_box', 'buy_x_get_y', 'bogo',
			'frequently_bought', 'complete_look', 'composite', 'quantity',
			'category', 'gift', 'chained', 'addons', 'mystery', 'subscription', 'ai',
		);
		$pricing = array( 'fixed', 'percentage', 'fixed_discount', 'cheapest_free', 'tiered', 'none' );
		$type = sanitize_key( (string) ( $raw['type'] ?? 'fixed' ) );
		$type = in_array( $type, $types, true ) ? $type : 'fixed';
		$product_ids = array_values( array_unique( array_filter( array_map( 'absint', preg_split( '/[\s,]+/', (string) ( $raw['product_ids'] ?? '' ) ) ) ) ) );
		$category_ids = array_values( array_unique( array_filter( array_map( 'absint', preg_split( '/[\s,]+/', (string) ( $raw['category_ids'] ?? '' ) ) ) ) ) );
		$id = sanitize_key( (string) ( $raw['id'] ?? '' ) );
		if ( '' === $id ) {
			$id = 'bundle_' . strtolower( wp_generate_password( 10, false, false ) );
		}
		$channel = sanitize_key( (string) ( $raw['channel'] ?? 'all' ) );
		$channel = in_array( $channel, array( 'all', 'website', 'mobile' ), true ) ? $channel : 'all';
		$price_mode = sanitize_key( (string) ( $raw['pricing'] ?? 'percentage' ) );
		$price_mode = in_array( $price_mode, $pricing, true ) ? $price_mode : 'percentage';
		$discount = max( 0, (float) ( $raw['discount_value'] ?? 0 ) );
		if ( 'percentage' === $price_mode ) {
			$discount = min( 100, $discount );
		}
		return array(
			'id'              => $id,
			'product_id'      => absint( $raw['product_id'] ?? 0 ),
			'coupon_id'       => absint( $raw['coupon_id'] ?? 0 ),
			'name'            => sanitize_text_field( (string) ( $raw['name'] ?? __( 'New bundle', 'kidia-mobile-cms' ) ) ),
			'description'     => sanitize_textarea_field( (string) ( $raw['description'] ?? '' ) ),
			'type'            => $type,
			'channel'         => $channel,
			'status'          => 'published' === sanitize_key( (string) ( $raw['status'] ?? 'draft' ) ) ? 'published' : 'draft',
			'product_ids'     => $product_ids,
			'category_ids'    => $category_ids,
			'groups'          => self::sanitize_groups( $raw['groups'] ?? array() ),
			'minimum_items'   => max( 1, absint( $raw['minimum_items'] ?? 2 ) ),
			'maximum_items'   => max( 1, absint( $raw['maximum_items'] ?? 2 ) ),
			'allow_variants'  => ! empty( $raw['allow_variants'] ),
			'allow_repeats'   => ! empty( $raw['allow_repeats'] ),
			'pricing'         => $price_mode,
			'discount_value'  => $discount,
			'minimum_spend'   => max( 0, (float) ( $raw['minimum_spend'] ?? 0 ) ),
			'coupon_stacking' => ! empty( $raw['coupon_stacking'] ),
			'stock_policy'    => in_array( sanitize_key( (string) ( $raw['stock_policy'] ?? 'all_components' ) ), array( 'all_components', 'allow_backorder', 'hide_unavailable' ), true )
				? sanitize_key( (string) $raw['stock_policy'] )
				: 'all_components',
			'starts_at'       => sanitize_text_field( (string) ( $raw['starts_at'] ?? '' ) ),
			'ends_at'         => sanitize_text_field( (string) ( $raw['ends_at'] ?? '' ) ),
			'customer_limit'  => max( 0, absint( $raw['customer_limit'] ?? 0 ) ),
			'cta_label'       => sanitize_text_field( (string) ( $raw['cta_label'] ?? __( 'Customize bundle', 'kidia-mobile-cms' ) ) ),
			'image_url'       => esc_url_raw( (string) ( $raw['image_url'] ?? '' ) ),
			'ai_source'       => in_array( sanitize_key( (string) ( $raw['ai_source'] ?? 'manual' ) ), array( 'manual', 'co_purchase', 'complementary', 'behavior', 'inventory' ), true )
				? sanitize_key( (string) $raw['ai_source'] )
				: 'manual',
			'created_at'      => absint( $raw['created_at'] ?? time() ),
			'updated_at'      => time(),
		);
	}

	private static function sanitize_groups( $groups ): array {
		if ( ! is_array( $groups ) ) {
			return array();
		}
		$clean = array();
		foreach ( array_slice( $groups, 0, 12 ) as $group ) {
			if ( ! is_array( $group ) ) {
				continue;
			}
			$clean[] = array(
				'label'        => sanitize_text_field( (string) ( $group['label'] ?? '' ) ),
				'product_ids'  => array_values( array_filter( array_map( 'absint', preg_split( '/[\s,]+/', (string) ( $group['product_ids'] ?? '' ) ) ) ) ),
				'category_ids' => array_values( array_filter( array_map( 'absint', preg_split( '/[\s,]+/', (string) ( $group['category_ids'] ?? '' ) ) ) ) ),
				'minimum'      => max( 0, absint( $group['minimum'] ?? 1 ) ),
				'maximum'      => max( 1, absint( $group['maximum'] ?? 1 ) ),
				'required'     => ! empty( $group['required'] ),
			);
		}
		return $clean;
	}

	private static function is_active( array $recipe ): bool {
		$now = time();
		$start = ! empty( $recipe['starts_at'] ) ? strtotime( (string) $recipe['starts_at'] ) : false;
		$end = ! empty( $recipe['ends_at'] ) ? strtotime( (string) $recipe['ends_at'] ) : false;
		return ( ! $start || $start <= $now ) && ( ! $end || $end >= $now );
	}

	public function validate_bundle_coupon( bool $valid, WC_Coupon $coupon ): bool {
		if ( ! $valid ) {
			return false;
		}
		$recipe_id = sanitize_key( (string) get_post_meta( $coupon->get_id(), '_kidia_bundle_recipe_id', true ) );
		if ( '' === $recipe_id ) {
			return true;
		}
		$recipes = self::all();
		$recipe = is_array( $recipes[ $recipe_id ] ?? null ) ? $recipes[ $recipe_id ] : null;
		if ( ! is_array( $recipe ) || 'published' !== ( $recipe['status'] ?? 'draft' ) || ! self::is_active( $recipe ) ) {
			return false;
		}
		$cart = function_exists( 'WC' ) && WC()->cart ? WC()->cart->get_cart() : array();
		$allowed_products = array_map( 'absint', (array) ( $recipe['product_ids'] ?? array() ) );
		$allowed_categories = array_map( 'absint', (array) ( $recipe['category_ids'] ?? array() ) );
		$eligible = 0;
		foreach ( $cart as $line ) {
			$product_id = absint( $line['product_id'] ?? 0 );
			$is_allowed = empty( $allowed_products ) && empty( $allowed_categories );
			if ( in_array( $product_id, $allowed_products, true ) ) {
				$is_allowed = true;
			}
			if ( ! $is_allowed && ! empty( $allowed_categories ) ) {
				$product_categories = wp_get_post_terms( $product_id, 'product_cat', array( 'fields' => 'ids' ) );
				$is_allowed = ! is_wp_error( $product_categories ) && (bool) array_intersect( $allowed_categories, array_map( 'absint', $product_categories ) );
			}
			if ( $is_allowed ) {
				$eligible += max( 1, absint( $line['quantity'] ?? 1 ) );
			}
		}
		$minimum = max( 1, absint( $recipe['minimum_items'] ?? 1 ) );
		$maximum = max( $minimum, absint( $recipe['maximum_items'] ?? $minimum ) );
		return $eligible >= $minimum && $eligible <= $maximum;
	}

	private function ensure_bundle_coupon( array $recipe ) {
		if ( ! class_exists( 'WC_Coupon' ) ) {
			return new WP_Error( 'kidia_bundle_coupon_unavailable', __( 'WooCommerce coupons are unavailable.', 'kidia-mobile-cms' ), array( 'status' => 503 ) );
		}
		if ( 'none' === ( $recipe['pricing'] ?? 'none' ) || (float) ( $recipe['discount_value'] ?? 0 ) <= 0 ) {
			return '';
		}
		$existing_id = absint( $recipe['coupon_id'] ?? 0 );
		$coupon = $existing_id ? new WC_Coupon( $existing_id ) : new WC_Coupon();
		$code = 'KIDIA-BUNDLE-' . strtoupper( substr( hash( 'sha256', (string) $recipe['id'] ), 0, 10 ) );
		$coupon->set_code( $code );
		$coupon->set_description( sprintf( __( 'Bundle recipe: %s', 'kidia-mobile-cms' ), (string) $recipe['name'] ) );
		$coupon->set_discount_type( 'percentage' === ( $recipe['pricing'] ?? '' ) ? 'percent' : 'fixed_cart' );
		$coupon->set_amount( max( 0, (float) ( $recipe['discount_value'] ?? 0 ) ) );
		$coupon->set_individual_use( ! empty( $recipe['coupon_stacking'] ) ? false : true );
		$coupon->set_product_ids( array_map( 'absint', (array) ( $recipe['product_ids'] ?? array() ) ) );
		$coupon->set_product_categories( array_map( 'absint', (array) ( $recipe['category_ids'] ?? array() ) ) );
		$coupon->set_usage_limit_per_user( max( 0, absint( $recipe['customer_limit'] ?? 0 ) ) );
		if ( ! empty( $recipe['ends_at'] ) ) {
			$coupon->set_date_expires( strtotime( (string) $recipe['ends_at'] ) );
		}
		$coupon_id = $coupon->save();
		if ( $coupon_id <= 0 ) {
			return new WP_Error( 'kidia_bundle_coupon_failed', __( 'Bundle discount could not be created.', 'kidia-mobile-cms' ), array( 'status' => 500 ) );
		}
		update_post_meta( $coupon_id, '_kidia_bundle_recipe_id', (string) $recipe['id'] );
		if ( class_exists( 'Kidia_Mobile_Coupon_Channel' ) ) {
			Kidia_Mobile_Coupon_Channel::set( $coupon_id, (string) ( $recipe['channel'] ?? 'all' ) );
		}
		$recipes = self::all();
		if ( is_array( $recipes[ $recipe['id'] ] ?? null ) ) {
			$recipes[ $recipe['id'] ]['coupon_id'] = $coupon_id;
			update_option( self::OPTION, $recipes, false );
		}
		return $code;
	}

	private function create_or_update_bundle_product( array $recipe ): int {
		if ( ! class_exists( 'WC_Product_Simple' ) ) {
			return 0;
		}
		$product_id = absint( $recipe['product_id'] ?? 0 );
		$product = $product_id ? wc_get_product( $product_id ) : new WC_Product_Simple();
		if ( ! $product instanceof WC_Product ) {
			$product = new WC_Product_Simple();
		}
		$product->set_name( (string) $recipe['name'] );
		$product->set_description( (string) $recipe['description'] );
		$product->set_status( 'published' === $recipe['status'] ? 'publish' : 'draft' );
		$product->set_catalog_visibility( 'visible' );
		if ( 'fixed' === $recipe['pricing'] && (float) $recipe['discount_value'] > 0 ) {
			$product->set_regular_price( (string) $recipe['discount_value'] );
			$product->set_price( (string) $recipe['discount_value'] );
		}
		$id = $product->save();
		if ( $id > 0 ) {
			update_post_meta( $id, '_kidia_bundle_recipe_id', $recipe['id'] );
		}
		return $id;
	}
}
