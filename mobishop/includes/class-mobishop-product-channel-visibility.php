<?php
/**
 * Per-channel WooCommerce product visibility.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Product_Channel_Visibility {

	public const MOBILE_META  = '_mobishop_hide_mobile';
	public const WEBSITE_META = '_mobishop_hide_website';

	/** Register channel-aware catalogue filters. */
	public function register(): void {
		add_filter( 'woocommerce_store_api_product_query', array( $this, 'filter_store_api_query' ), 20, 2 );
		add_filter( 'woocommerce_product_query_meta_query', array( $this, 'filter_website_product_query' ), 20, 2 );
		add_filter( 'woocommerce_product_is_visible', array( $this, 'filter_product_visibility' ), 20, 2 );
		add_filter( 'rest_request_before_callbacks', array( $this, 'guard_single_mobile_product' ), 20, 3 );
		add_action( 'template_redirect', array( $this, 'guard_hidden_website_product' ), 1 );
	}

	/**
	 * Exclude products hidden from the requesting Store API channel.
	 *
	 * @param array<string,mixed> $query_args Product query arguments.
	 * @param mixed               $request Store API request.
	 * @return array<string,mixed>
	 */
	public function filter_store_api_query( array $query_args, $request ): array {
		if ( ! $request instanceof WP_REST_Request ) {
			return $query_args;
		}

		$meta_key     = $this->is_mobile_request( $request ) ? self::MOBILE_META : self::WEBSITE_META;
		$meta_query   = isset( $query_args['meta_query'] ) && is_array( $query_args['meta_query'] )
			? $query_args['meta_query']
			: array();
		$meta_query[] = array(
			'relation' => 'OR',
			array(
				'key'     => $meta_key,
				'compare' => 'NOT EXISTS',
			),
			array(
				'key'     => $meta_key,
				'value'   => 'yes',
				'compare' => '!=',
			),
		);
		$query_args['meta_query'] = $meta_query;
		return $query_args;
	}

	/**
	 * Exclude website-hidden products from WooCommerce archives and search.
	 *
	 * @param array<mixed> $meta_query Existing product meta query.
	 * @param mixed        $query WooCommerce query.
	 * @return array<mixed>
	 */
	public function filter_website_product_query( array $meta_query, $query ): array {
		unset( $query );
		if ( ( is_admin() && ( ! wp_doing_ajax() || current_user_can( 'edit_products' ) ) ) || $this->is_mobile_request() || ( defined( 'REST_REQUEST' ) && REST_REQUEST ) ) {
			return $meta_query;
		}
		$meta_query[] = array(
			'relation' => 'OR',
			array(
				'key'     => self::WEBSITE_META,
				'compare' => 'NOT EXISTS',
			),
			array(
				'key'     => self::WEBSITE_META,
				'value'   => 'yes',
				'compare' => '!=',
			),
		);
		return $meta_query;
	}

	/** Hide products from the matching public sales channel. */
	public function filter_product_visibility( bool $visible, int $product_id ): bool {
		if ( ! $visible || $product_id <= 0 || ( is_admin() && ( ! wp_doing_ajax() || current_user_can( 'edit_products' ) ) ) ) {
			return $visible;
		}

		if ( $this->is_mobile_request() ) {
			return ! self::is_hidden( $product_id, 'mobile' );
		}
		if ( defined( 'REST_REQUEST' ) && REST_REQUEST ) {
			return $visible;
		}
		return ! self::is_hidden( $product_id, 'website' );
	}

	/**
	 * Return a 404 for a product hidden from the requesting Store API channel.
	 *
	 * @param mixed           $response Existing REST response.
	 * @param mixed           $handler Route handler.
	 * @param WP_REST_Request $request Request.
	 * @return mixed
	 */
	public function guard_single_mobile_product( $response, $handler, WP_REST_Request $request ) {
		unset( $handler );
		if ( null !== $response ) {
			return $response;
		}
		if ( ! preg_match( '#/wc/store/v\d+/products/(\d+)(?:/|$)#', $request->get_route(), $matches ) ) {
			return $response;
		}
		$channel = $this->is_mobile_request( $request ) ? 'mobile' : 'website';
		if ( ! self::is_hidden( absint( $matches[1] ), $channel ) ) {
			return $response;
		}
		return new WP_Error(
			'mobishop_product_hidden_for_channel',
			__( 'This product is not available in this sales channel.', 'mobishop' ),
			array( 'status' => 404 )
		);
	}

	/** Prevent direct website access to a product hidden from the website. */
	public function guard_hidden_website_product(): void {
		if ( is_admin() || $this->is_mobile_request() || ! function_exists( 'is_product' ) || ! is_product() ) {
			return;
		}
		$product_id = get_queried_object_id();
		if ( ! self::is_hidden( $product_id, 'website' ) ) {
			return;
		}

		global $wp_query;
		if ( $wp_query instanceof WP_Query ) {
			$wp_query->set_404();
		}
		status_header( 404 );
		nocache_headers();
		$template = get_404_template();
		if ( $template ) {
			include $template;
		}
		exit;
	}

	public static function is_hidden( int $product_id, string $channel ): bool {
		$meta_key = 'mobile' === $channel ? self::MOBILE_META : self::WEBSITE_META;
		return 'yes' === (string) get_post_meta( $product_id, $meta_key, true );
	}

	private function is_mobile_request( ?WP_REST_Request $request = null ): bool {
		$channel = $request instanceof WP_REST_Request
			? sanitize_key( (string) $request->get_header( 'X-MobiShop-Channel' ) )
			: sanitize_key( (string) ( $_SERVER['HTTP_X_MOBISHOP_CHANNEL'] ?? '' ) );
		return 'mobile' === $channel;
	}
}
