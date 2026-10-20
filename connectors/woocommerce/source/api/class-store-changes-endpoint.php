<?php
/** Cheap revision hints. Customer payloads always remain on their own API. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Store_Changes_Endpoint {

	private const PUBLIC_PREFIX = 'mobishop_live_revision_v1_';
	private const PRIVATE_PREFIX = '_mobishop_live_revision_v1_';
	private array $previous_order_customers = array();

	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
		foreach ( array( 'woocommerce_new_product', 'woocommerce_update_product', 'woocommerce_new_product_variation', 'woocommerce_update_product_variation' ) as $hook ) {
			add_action( $hook, array( $this, 'catalog_changed' ) );
		}
		foreach ( array( 'woocommerce_product_set_stock', 'woocommerce_variation_set_stock', 'woocommerce_product_set_stock_status', 'woocommerce_variation_set_stock_status' ) as $hook ) {
			add_action( $hook, array( $this, 'stock_changed' ) );
		}
		add_action( 'transition_post_status', array( $this, 'post_status_changed' ), 10, 3 );
		add_action( 'before_delete_post', array( $this, 'post_deleted' ), 10, 2 );
		foreach ( array( 'created_term', 'edited_term', 'delete_term' ) as $hook ) {
			add_action( $hook, array( $this, 'term_changed' ), 10, 3 );
		}
		add_action( 'profile_update', array( $this, 'profile_changed' ) );
		add_action( 'woocommerce_customer_object_updated_props', array( $this, 'customer_changed' ), 10, 2 );
		foreach ( array( 'added_user_meta', 'updated_user_meta', 'deleted_user_meta' ) as $hook ) {
			add_action( $hook, array( $this, 'customer_meta_changed' ), 10, 3 );
		}
		add_action( 'woocommerce_after_order_object_save', array( $this, 'order_changed' ) );
		add_action( 'woocommerce_before_order_object_save', array( $this, 'order_before_save' ), 10, 2 );
		add_action( 'woocommerce_after_order_refund_object_save', array( $this, 'order_changed' ) );
		add_action( 'woocommerce_before_order_refund_object_save', array( $this, 'order_before_save' ), 10, 2 );
		add_action( 'woocommerce_before_delete_order', array( $this, 'order_changed' ), 10, 2 );
		add_action( 'woocommerce_before_trash_order', array( $this, 'order_changed' ), 10, 2 );
	}

	public function register_routes(): void {
		register_rest_route( 'mobishop/v1', '/store-changes', array(
			'methods' => WP_REST_Server::READABLE,
			'callback' => array( $this, 'get_revisions' ),
			'permission_callback' => '__return_true',
		) );
	}

	public function get_revisions( WP_REST_Request $request ) {
		$origin = $this->store_origin();
		if ( ! is_ssl() || '' === $origin ) {
			return new WP_Error( 'mobishop_live_https_required', 'Live updates require HTTPS.', array( 'status' => 403 ) );
		}
		$data = array(
			'version' => 1,
			'type' => 'mobishop_store_revisions',
			'store_origin' => $origin,
			'revisions' => array(
				'catalog' => $this->revision( get_option( self::PUBLIC_PREFIX . 'catalog', '0' ) ),
				'stock' => $this->revision( get_option( self::PUBLIC_PREFIX . 'stock', '0' ) ),
			),
		);
		// Never silently downgrade a stale or forged customer session to guest.
		if ( '' !== trim( (string) $request->get_header( 'X-MobiShop-Session' ) ) ) {
			$auth = new MobiShop_Customer_Auth_Endpoint();
			if ( ! method_exists( $auth, 'session_context_from_request' ) ) {
				return new WP_Error( 'mobishop_live_auth_unavailable', 'Customer live updates are unavailable.', array( 'status' => 503 ) );
			}
			$context = $auth->session_context_from_request( $request );
			if ( is_wp_error( $context ) ) {
				return $context;
			}
			$customer_id = (int) ( $context['user_id'] ?? 0 );
			$scope = (string) ( $context['session_scope'] ?? '' );
			if ( $customer_id < 1 || ! preg_match( '/^mss1_[a-f0-9]{64}$/D', $scope ) ) {
				return new WP_Error( 'mobishop_live_invalid_scope', 'Customer live updates are unavailable.', array( 'status' => 503 ) );
			}
			$data['session_scope'] = $scope;
			foreach ( array( 'orders', 'profile' ) as $domain ) {
				$data['revisions'][ $domain ] = $this->revision( get_user_meta( $customer_id, self::PRIVATE_PREFIX . $domain, true ) );
			}
		}
		$response = new WP_REST_Response( $data, 200 );
		$response->header( 'Cache-Control', 'private, no-store, max-age=0' );
		$response->header( 'Vary', 'X-MobiShop-Session' );
		$response->header( 'X-Content-Type-Options', 'nosniff' );
		return $response;
	}

	public function catalog_changed(): void {
		$this->bump_public( 'catalog' );
	}

	public function stock_changed(): void {
		$this->bump_public( 'stock' );
	}

	public function post_status_changed( $new, $old, $post ): void {
		if ( $new !== $old && in_array( $post->post_type ?? '', array( 'product', 'product_variation' ), true ) ) {
			$this->catalog_changed();
			$this->stock_changed();
		}
	}

	public function post_deleted( $id, $post = null ): void {
		$post = $post ?: get_post( $id );
		if ( in_array( $post->post_type ?? '', array( 'product', 'product_variation' ), true ) ) {
			$this->catalog_changed();
			$this->stock_changed();
		} elseif ( in_array( $post->post_type ?? '', array( 'shop_order', 'shop_order_refund' ), true ) ) {
			$this->order_changed( $id );
		}
	}

	public function term_changed( $id, $tt_id, $taxonomy ): void {
		if ( in_array( $taxonomy, array( 'product_cat', 'product_tag', 'product_brand', 'product_visibility' ), true ) || 0 === strpos( (string) $taxonomy, 'pa_' ) ) {
			$this->catalog_changed();
		}
	}

	public function profile_changed( $customer_id ): void {
		$this->bump_private( (int) $customer_id, 'profile' );
	}

	public function customer_changed( $customer, $props = array() ): void {
		if ( is_object( $customer ) && is_callable( array( $customer, 'get_id' ) ) && ! empty( $props ) ) {
			$this->profile_changed( $customer->get_id() );
		}
	}

	public function customer_meta_changed( $meta_id, $customer_id, $key ): void {
		if ( in_array( $key, array( 'first_name', 'last_name', '_mobishop_account_phone' ), true ) || 0 === strpos( (string) $key, 'billing_' ) || 0 === strpos( (string) $key, 'shipping_' ) ) {
			$this->profile_changed( $customer_id );
		}
	}

	public function order_before_save( $order, $data_store = null ): void {
		unset( $data_store );
		if ( ! is_object( $order ) || ! is_callable( array( $order, 'get_id' ) ) || ! function_exists( 'wc_get_order' ) ) {
			return;
		}
		$id = (int) $order->get_id();
		if ( $id > 0 ) {
			// The separate persisted object still belongs to the previous customer.
			$stored = wc_get_order( $id );
			$this->previous_order_customers[ spl_object_id( $order ) ] = $this->order_customer_id( $stored );
		}
	}

	public function order_changed( $order, $supplied_order = null ): void {
		if ( is_object( $supplied_order ) && is_callable( array( $supplied_order, 'get_id' ) ) ) {
			$order = $supplied_order;
		}
		if ( ! is_object( $order ) && function_exists( 'wc_get_order' ) ) {
			$order = wc_get_order( $order );
		}
		if ( is_object( $order ) ) {
			$key = spl_object_id( $order );
			$old = (int) ( $this->previous_order_customers[ $key ] ?? 0 );
			unset( $this->previous_order_customers[ $key ] );
			$current = $this->order_customer_id( $order );
			$this->bump_private( $current, 'orders' );
			if ( $old !== $current ) {
				$this->bump_private( $old, 'orders' );
			}
		}
	}

	private function order_customer_id( $order ): int {
		if ( ! is_object( $order ) ) {
			return 0;
		}
		$id = is_callable( array( $order, 'get_customer_id' ) ) ? (int) $order->get_customer_id() : 0;
		// Refunds belong to the parent order rather than to customer ID zero.
		if ( 0 === $id && is_callable( array( $order, 'get_parent_id' ) ) && function_exists( 'wc_get_order' ) ) {
			$parent_id = (int) $order->get_parent_id();
			$parent = $parent_id > 0 ? wc_get_order( $parent_id ) : false;
			if ( is_object( $parent ) && is_callable( array( $parent, 'get_customer_id' ) ) ) {
				$id = (int) $parent->get_customer_id();
			}
		}
		return $id;
	}

	private function bump_public( string $domain ): void {
		// No queries over products/orders and no long-running PHP/poll workers.
		update_option( self::PUBLIC_PREFIX . $domain, wp_generate_uuid4(), false );
	}

	private function bump_private( int $customer_id, string $domain ): void {
		if ( $customer_id > 0 ) {
			update_user_meta( $customer_id, self::PRIVATE_PREFIX . $domain, wp_generate_uuid4() );
		}
	}

	private function revision( $value ): string {
		return is_string( $value ) && preg_match( '/^[a-zA-Z0-9_-]{1,128}$/D', $value ) ? $value : '0';
	}

	private function store_origin(): string {
		$parts = wp_parse_url( home_url( '/' ) );
		if ( ! is_array( $parts ) || 'https' !== ( $parts['scheme'] ?? '' ) || empty( $parts['host'] ) ) {
			return '';
		}
		$port = (int) ( $parts['port'] ?? 443 );
		return 'https://' . strtolower( $parts['host'] ) . ( 443 === $port ? '' : ':' . $port );
	}
}
