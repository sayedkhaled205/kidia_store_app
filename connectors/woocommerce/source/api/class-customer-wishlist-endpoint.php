<?php
/** Account-scoped wishlist with atomic device-independent deltas. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Customer_Wishlist_Endpoint {
	private const META = '_mobishop_wishlist_product_ids';
	private int $customer_id = 0;
	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}
	public function register_routes(): void {
		register_rest_route( 'mobishop/v1', '/customer/wishlist', array(
			array( 'methods' => 'GET', 'callback' => array( $this, 'read' ), 'permission_callback' => array( $this, 'authenticate' ) ),
			array( 'methods' => 'POST', 'callback' => array( $this, 'mutate' ), 'permission_callback' => array( $this, 'authenticate' ) ),
		) );
	}
	public function authenticate( WP_REST_Request $request ) {
		$auth = new MobiShop_Customer_Auth_Endpoint();
		$this->customer_id = $auth->customer_id_from_request( $request );
		return $this->customer_id > 0 ? true : new WP_Error( 'mobishop_auth_unauthorized', 'Sign in to view your wishlist.', array( 'status' => 401 ) );
	}
	private function ids( $raw ): array {
		return is_array( $raw ) ? array_values( array_unique( array_filter( array_map( 'absint', $raw ) ) ) ) : array();
	}
	private function response( array $ids ): WP_REST_Response {
		$response = new WP_REST_Response( array( 'product_ids' => $ids ) );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		return $response;
	}
	public function read() {
		if ( $this->customer_id <= 0 ) return new WP_Error( 'mobishop_auth_unauthorized', 'Sign in to view your wishlist.', array( 'status' => 401 ) );
		return $this->response( $this->ids( get_user_meta( $this->customer_id, self::META, true ) ) );
	}
	public function mutate( WP_REST_Request $request ) {
		if ( $this->customer_id <= 0 ) return new WP_Error( 'mobishop_auth_unauthorized', 'Sign in to update your wishlist.', array( 'status' => 401 ) );
		$body = $request->get_json_params();
		foreach ( array( 'add', 'remove' ) as $field ) {
			$values = is_array( $body ) ? ( $body[ $field ] ?? array() ) : null;
			if ( ! is_array( $values ) || count( $values ) > 1000 || array_filter( $values, static fn( $id ) => ! is_int( $id ) || $id <= 0 ) ) {
				return new WP_Error( 'mobishop_wishlist_invalid', 'Invalid wishlist changes.', array( 'status' => 400 ) );
			}
		}
		global $wpdb;
		$user_id = $this->customer_id;
		$lock = 'mobishop_wishlist_' . get_current_blog_id() . '_' . $user_id;
		if ( '1' !== (string) $wpdb->get_var( $wpdb->prepare( 'SELECT GET_LOCK(%s, %d)', $lock, 3 ) ) ) {
			return new WP_Error( 'mobishop_wishlist_busy', 'Please retry saving your wishlist.', array( 'status' => 503 ) );
		}
		try {
			wp_cache_delete( $user_id, 'user_meta' );
			$current = $this->ids( get_user_meta( $user_id, self::META, true ) );
			$next = array_values( array_diff( $this->ids( array_merge( $body['add'] ?? array(), $current ) ), $body['remove'] ?? array() ) );
			if ( count( $next ) > 5000 ) return new WP_Error( 'mobishop_wishlist_limit', 'Wishlist limit reached.', array( 'status' => 400 ) );
			if ( $next !== $current && ! update_user_meta( $user_id, self::META, $next ) ) {
				return new WP_Error( 'mobishop_wishlist_failed', 'Wishlist could not be saved.', array( 'status' => 500 ) );
			}
			return $this->response( $next );
		} finally {
			$wpdb->query( $wpdb->prepare( 'SELECT RELEASE_LOCK(%s)', $lock ) );
		}
	}
}
