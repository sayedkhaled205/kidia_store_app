<?php
/**
 * Mobile commerce analytics and abandoned-cart storage.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Analytics {

	private const DB_VERSION = '4';
	private const DB_OPTION  = 'kidia_mobile_analytics_db_version';
	private const MOBILE_META = '_kidia_mobile_customer';
	private const WEBSITE_META = '_kidia_website_customer';
	private const ORIGIN_META = '_kidia_customer_origin';
	private const WEBSITE_IMPORT_OPTION = 'kidia_mobile_website_cart_import_v3';
	private const WEBSITE_IMPORT_HOOK = 'kidia_mobile_import_website_cart_sessions';
	private const WEBSITE_IMPORT_LOCK = 'kidia_mobile_website_cart_import_lock_v3';
	private const WEBSITE_IMPORT_BATCH = 300;

	/** @var list<string> */
	private const EVENTS = array(
		'site_visit',
		'app_open',
		'app_resume',
		'registration_started',
		'sign_up',
		'login',
		'view_item',
		'view_category',
		'search',
		'add_to_cart',
		'remove_from_cart',
		'cart_updated',
		'begin_checkout',
		'purchase',
		'purchase_item',
	);

	public function register(): void {
		add_action( 'init', array( $this, 'maybe_install' ), 3 );
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
		add_action( 'wp_enqueue_scripts', array( $this, 'enqueue_website_tracker' ), 20 );
		add_action( 'user_register', array( $this, 'mark_website_registration' ) );
		add_action( 'wp_login', array( $this, 'mark_website_login' ), 10, 2 );
		add_action( 'wp', array( $this, 'capture_website_page_activity' ), 30 );
		add_action( 'woocommerce_register_form_start', array( $this, 'capture_website_registration_start' ) );
		add_action( 'register_form', array( $this, 'capture_website_registration_start' ) );
		add_action( 'woocommerce_cart_updated', array( $this, 'capture_website_cart' ) );
		add_action( 'woocommerce_add_to_cart', array( $this, 'capture_website_cart' ), 50 );
		add_action( 'woocommerce_cart_item_removed', array( $this, 'capture_website_cart' ), 50 );
		add_action( 'woocommerce_add_to_cart', array( $this, 'capture_website_add_to_cart' ), 20, 6 );
		add_action( 'woocommerce_cart_item_removed', array( $this, 'capture_website_remove_from_cart' ), 20, 2 );
		add_action( 'woocommerce_checkout_order_created', array( $this, 'capture_completed_order' ) );
		add_action( 'woocommerce_payment_complete', array( $this, 'capture_paid_order' ) );
		add_action( 'woocommerce_order_status_processing', array( $this, 'capture_paid_order' ) );
		add_action( 'woocommerce_order_status_completed', array( $this, 'capture_paid_order' ) );
		add_action( self::WEBSITE_IMPORT_HOOK, array( $this, 'run_website_session_import' ) );
		add_action( 'init', array( $this, 'ensure_website_session_import' ), 25 );
	}

	public function maybe_install(): void {
		if ( self::DB_VERSION === (string) get_option( self::DB_OPTION, '' ) ) {
			return;
		}

		global $wpdb;
		require_once ABSPATH . 'wp-admin/includes/upgrade.php';

		$charset = $wpdb->get_charset_collate();
		$events  = self::events_table();
		$carts   = self::carts_table();

		dbDelta(
			"CREATE TABLE {$events} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				event_id varchar(64) NULL DEFAULT NULL,
				client_id varchar(64) NOT NULL,
				session_id varchar(64) NOT NULL DEFAULT '',
				user_id bigint(20) unsigned NOT NULL DEFAULT 0,
				source varchar(12) NOT NULL DEFAULT 'mobile',
				event_name varchar(50) NOT NULL,
				object_id bigint(20) unsigned NOT NULL DEFAULT 0,
				event_label varchar(191) NOT NULL DEFAULT '',
				event_value decimal(20,6) NOT NULL DEFAULT 0,
				currency varchar(12) NOT NULL DEFAULT '',
				properties longtext NULL,
				occurred_at datetime NOT NULL,
				PRIMARY KEY  (id),
				UNIQUE KEY event_id (event_id),
				KEY event_time (event_name, occurred_at),
				KEY source_event_time (source, event_name, occurred_at),
				KEY client_time (client_id, occurred_at),
				KEY user_time (user_id, occurred_at),
				KEY object_event (object_id, event_name)
			) {$charset};"
		);

		dbDelta(
			"CREATE TABLE {$carts} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				cart_key varchar(64) NOT NULL,
				source varchar(12) NOT NULL,
				client_id varchar(64) NOT NULL DEFAULT '',
				session_id varchar(64) NOT NULL DEFAULT '',
				user_id bigint(20) unsigned NOT NULL DEFAULT 0,
				customer_name varchar(191) NOT NULL DEFAULT '',
				customer_email varchar(191) NOT NULL DEFAULT '',
				items longtext NULL,
				item_count int(10) unsigned NOT NULL DEFAULT 0,
				cart_total decimal(20,6) NOT NULL DEFAULT 0,
				currency varchar(12) NOT NULL DEFAULT '',
				status varchar(20) NOT NULL DEFAULT 'active',
				started_at datetime NOT NULL,
				last_activity_at datetime NOT NULL,
				converted_at datetime NULL,
				order_id bigint(20) unsigned NOT NULL DEFAULT 0,
				PRIMARY KEY  (id),
				UNIQUE KEY cart_key (cart_key),
				KEY status_activity (status, last_activity_at),
				KEY source_activity (source, last_activity_at),
				KEY user_activity (user_id, last_activity_at)
			) {$charset};"
		);

		update_option( self::DB_OPTION, self::DB_VERSION, false );
	}

	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/analytics/event',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'record_event' ),
				'permission_callback' => '__return_true',
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/analytics/cart',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'record_mobile_cart' ),
				'permission_callback' => '__return_true',
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/analytics/website-event',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'record_website_event_request' ),
				'permission_callback' => '__return_true',
			)
		);
	}

	/**
	 * Loads a cache-safe browser tracker. Server hooks alone cannot count visits
	 * served entirely by a page cache or CDN.
	 */
	public function enqueue_website_tracker(): void {
		if ( is_admin() || wp_doing_ajax() || wp_doing_cron() ) {
			return;
		}

		$context = array(
			'event'     => '',
			'objectId'  => 0,
			'label'     => '',
			'currency'  => function_exists( 'get_woocommerce_currency' ) ? get_woocommerce_currency() : '',
			'isCheckout' => function_exists( 'is_checkout' ) && is_checkout()
				&& ( ! function_exists( 'is_wc_endpoint_url' ) || ! is_wc_endpoint_url( 'order-received' ) ),
		);
		if ( function_exists( 'is_product' ) && is_product() ) {
			$product = function_exists( 'wc_get_product' ) ? wc_get_product( get_queried_object_id() ) : null;
			$context['event']    = 'view_item';
			$context['objectId'] = get_queried_object_id();
			$context['label']    = $product instanceof WC_Product ? $product->get_name() : '';
		} elseif ( function_exists( 'is_product_category' ) && is_product_category() ) {
			$category = get_queried_object();
			if ( $category instanceof WP_Term ) {
				$context['event']    = 'view_category';
				$context['objectId'] = $category->term_id;
				$context['label']    = $category->name;
			}
		} elseif ( is_search() ) {
			$context['event'] = 'search';
			$context['label'] = sanitize_text_field( get_search_query() );
		}

		wp_enqueue_script(
			'kidia-mobile-website-analytics',
			KIDIA_MOBILE_CMS_URL . 'public/assets/website-analytics.js',
			array(),
			KIDIA_MOBILE_CMS_VERSION,
			true
		);
		wp_add_inline_script(
			'kidia-mobile-website-analytics',
			'window.KidiaWebsiteAnalytics=' . wp_json_encode(
				array(
					'endpoint' => esc_url_raw( rest_url( 'woo-mobile/v1/analytics/website-event' ) ),
					'context'  => $context,
				)
			) . ';',
			'before'
		);
	}

	/** Receives cache-safe first-party website events from the browser. */
	public function record_website_event_request( WP_REST_Request $request ) {
		$this->maybe_install();
		$event = sanitize_key( (string) $request->get_param( 'event' ) );
		$allowed = array(
			'site_visit',
			'registration_started',
			'view_item',
			'view_category',
			'search',
			'add_to_cart',
			'remove_from_cart',
			'begin_checkout',
		);
		if ( ! in_array( $event, $allowed, true ) ) {
			return new WP_Error(
				'kidia_website_analytics_event_invalid',
				__( 'Unknown website analytics event.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}

		$client_id = $this->identifier( $request->get_param( 'client_id' ) );
		if ( '' === $client_id ) {
			return new WP_Error(
				'kidia_website_analytics_client_missing',
				__( 'A valid analytics client id is required.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}
		if ( ! $this->allow_request( 'web-' . $client_id, 240 ) || ! $this->allow_request( 'web-ip-' . $this->request_ip(), 900 ) ) {
			return new WP_Error(
				'kidia_website_analytics_rate_limited',
				__( 'Too many analytics events were received.', 'kidia-mobile-cms' ),
				array( 'status' => 429 )
			);
		}

		$object_id = absint( $request->get_param( 'object_id' ) );
		$label     = mb_substr( sanitize_text_field( (string) $request->get_param( 'label' ) ), 0, 191 );
		$value     = max( 0, (float) $request->get_param( 'value' ) );
		$properties = $request->get_param( 'properties' );
		$properties = is_array( $properties ) ? $this->sanitize_properties( $properties ) : array();
		$deduplicate_for = in_array( $event, array( 'site_visit', 'begin_checkout' ), true )
			? 30 * MINUTE_IN_SECONDS
			: ( in_array( $event, array( 'view_item', 'view_category', 'search' ), true )
				? 5 * MINUTE_IN_SECONDS
				: ( in_array( $event, array( 'add_to_cart', 'remove_from_cart' ), true ) ? 15 : 0 ) );

		$deduplication_key = '';
		if ( $deduplicate_for > 0 ) {
			$deduplication_key = $this->website_event_cache_key( $event, $client_id, $object_id, $label );
			if ( get_transient( $deduplication_key ) ) {
				return rest_ensure_response( array( 'recorded' => false, 'deduplicated' => true ) );
			}
		}

		$result = $this->insert_event(
			array(
				'event_id'    => $this->identifier( $request->get_param( 'event_id' ) ),
				'client_id'   => $client_id,
				'session_id'  => $this->identifier( $request->get_param( 'session_id' ) ),
				'user_id'     => get_current_user_id(),
				'source'      => 'website',
				'event_name'  => $event,
				'object_id'   => $object_id,
				'event_label' => $label,
				'event_value' => $value,
				'currency'    => strtoupper( sanitize_key( (string) $request->get_param( 'currency' ) ) ),
				'properties'  => $properties,
			)
		);

		if ( 'failed' === $result ) {
			return new WP_Error(
				'kidia_website_analytics_write_failed',
				__( 'The analytics event could not be stored.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}
		if ( 'inserted' === $result && '' !== $deduplication_key ) {
			set_transient( $deduplication_key, 1, $deduplicate_for );
		}

		return rest_ensure_response(
			array(
				'recorded'     => 'inserted' === $result,
				'deduplicated' => 'duplicate' === $result,
			)
		);
	}

	public function record_event( WP_REST_Request $request ) {
		$this->maybe_install();
		$event = sanitize_key( (string) $request->get_param( 'event' ) );
		if ( ! in_array( $event, self::EVENTS, true ) ) {
			return new WP_Error(
				'kidia_mobile_analytics_event_invalid',
				__( 'Unknown mobile analytics event.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}

		$client_id = $this->identifier( $request->get_param( 'client_id' ) );
		if ( '' === $client_id ) {
			return new WP_Error(
				'kidia_mobile_analytics_client_missing',
				__( 'A valid analytics client id is required.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}
		if ( ! $this->allow_request( $client_id ) || ! $this->allow_request( 'ip-' . $this->request_ip(), 600 ) ) {
			return new WP_Error(
				'kidia_mobile_analytics_rate_limited',
				__( 'Too many analytics events were received.', 'kidia-mobile-cms' ),
				array( 'status' => 429 )
			);
		}

		$user_id    = get_current_user_id();
		$object_id  = absint( $request->get_param( 'object_id' ) );
		$label      = sanitize_text_field( (string) $request->get_param( 'label' ) );
		$value      = max( 0, (float) $request->get_param( 'value' ) );
		$currency   = strtoupper( sanitize_key( (string) $request->get_param( 'currency' ) ) );
		$properties = $request->get_param( 'properties' );
		$properties = is_array( $properties ) ? $this->sanitize_properties( $properties ) : array();

		$result = $this->insert_event(
			array(
				'event_id'    => $this->identifier( $request->get_param( 'event_id' ) ),
				'client_id'   => $client_id,
				'session_id'  => $this->identifier( $request->get_param( 'session_id' ) ),
				'user_id'     => $user_id,
				'source'      => 'mobile',
				'event_name'  => $event,
				'object_id'   => $object_id,
				'event_label' => mb_substr( $label, 0, 191 ),
				'event_value' => $value,
				'currency'    => mb_substr( $currency, 0, 12 ),
				'properties'  => $properties,
			)
		);
		if ( 'failed' === $result ) {
			return new WP_Error(
				'kidia_mobile_analytics_write_failed',
				__( 'The analytics event could not be stored.', 'kidia-mobile-cms' ),
				array( 'status' => 500 )
			);
		}

		if ( $user_id > 0 ) {
			self::mark_mobile_customer( $user_id );
		}
		if ( 'purchase' === $event ) {
			$this->mark_mobile_cart_converted(
				$client_id,
				$this->identifier( $request->get_param( 'session_id' ) ),
				absint( $request->get_param( 'order_id' ) )
			);
		}

		return rest_ensure_response(
			array(
				'recorded'     => 'inserted' === $result,
				'deduplicated' => 'duplicate' === $result,
			)
		);
	}

	public function record_mobile_cart( WP_REST_Request $request ) {
		$this->maybe_install();
		$client_id = $this->identifier( $request->get_param( 'client_id' ) );
		if ( '' === $client_id ) {
			return new WP_Error(
				'kidia_mobile_cart_client_missing',
				__( 'A valid cart client id is required.', 'kidia-mobile-cms' ),
				array( 'status' => 400 )
			);
		}
		if ( ! $this->allow_request( 'cart-' . $client_id, 90 ) || ! $this->allow_request( 'cart-ip-' . $this->request_ip(), 300 ) ) {
			return new WP_Error(
				'kidia_mobile_cart_rate_limited',
				__( 'Too many cart updates were received.', 'kidia-mobile-cms' ),
				array( 'status' => 429 )
			);
		}

		$items = $this->normalize_mobile_items( $request->get_param( 'items' ) );
		$minor = max( 0, min( 6, absint( $request->get_param( 'currency_minor_unit' ) ) ) );
		$total = (float) $request->get_param( 'total_minor' ) / ( 10 ** $minor );
		$session_id = $this->identifier( $request->get_param( 'session_id' ) );
		$user = wp_get_current_user();
		$this->upsert_cart(
			array(
				'cart_key'       => hash( 'sha256', 'mobile|' . $client_id . '|' . $session_id ),
				'source'         => 'mobile',
				'client_id'      => $client_id,
				'session_id'     => $session_id,
				'user_id'        => get_current_user_id(),
				'customer_name'  => $user instanceof WP_User ? $user->display_name : '',
				'customer_email' => $user instanceof WP_User ? $user->user_email : '',
				'items'          => $items,
				'item_count'     => array_sum( array_column( $items, 'quantity' ) ),
				'cart_total'     => max( 0, $total ),
				'currency'       => strtoupper( sanitize_key( (string) $request->get_param( 'currency' ) ) ),
			)
		);

		if ( get_current_user_id() > 0 ) {
			self::mark_mobile_customer( get_current_user_id() );
		}
		return rest_ensure_response( array( 'recorded' => true ) );
	}

	/** Capture the website-side entry and intent events used by the channel filter. */
	public function capture_website_page_activity(): void {
		if ( is_admin() || wp_doing_ajax() || wp_doing_cron() || ( defined( 'REST_REQUEST' ) && REST_REQUEST ) ) {
			return;
		}

		$this->record_website_event( 'site_visit', 0, '', 0.0, array(), 30 * MINUTE_IN_SECONDS );
		if ( function_exists( 'is_product' ) && is_product() ) {
			$product_id = get_queried_object_id();
			$product    = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
			$this->record_website_event(
				'view_item',
				$product_id,
				$product instanceof WC_Product ? $product->get_name() : '',
				0.0,
				array(),
				5 * MINUTE_IN_SECONDS
			);
		} elseif ( function_exists( 'is_product_category' ) && is_product_category() ) {
			$category = get_queried_object();
			if ( $category instanceof WP_Term ) {
				$this->record_website_event( 'view_category', $category->term_id, $category->name, 0.0, array(), 10 * MINUTE_IN_SECONDS );
			}
		}

		if ( is_search() ) {
			$query = sanitize_text_field( get_search_query() );
			if ( '' !== $query ) {
				$this->record_website_event( 'search', 0, $query, 0.0, array(), 10 * MINUTE_IN_SECONDS );
			}
		}
		if ( function_exists( 'is_checkout' ) && is_checkout() && ( ! function_exists( 'is_wc_endpoint_url' ) || ! is_wc_endpoint_url( 'order-received' ) ) ) {
			$this->record_website_event( 'begin_checkout', 0, '', 0.0, array(), 30 * MINUTE_IN_SECONDS );
		}
	}

	public function capture_website_registration_start(): void {
		$this->record_website_event( 'registration_started', 0, '', 0.0, array(), 30 * MINUTE_IN_SECONDS );
	}

	/** Capture a website add-to-cart event without waiting for the next page load. */
	public function capture_website_add_to_cart( string $cart_item_key, int $product_id, int $quantity, int $variation_id, array $variation, array $cart_item_data ): void {
		unset( $cart_item_key, $variation_id, $variation, $cart_item_data );
		$product = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
		$this->record_website_event(
			'add_to_cart',
			$product_id,
			$product instanceof WC_Product ? $product->get_name() : '',
			0.0,
			array( 'quantity' => max( 1, $quantity ) ),
			15
		);
	}

	/** Capture removal intent before WooCommerce discards the removed line. */
	public function capture_website_remove_from_cart( string $cart_item_key, $cart ): void {
		$item = is_object( $cart ) && isset( $cart->removed_cart_contents[ $cart_item_key ] )
			? $cart->removed_cart_contents[ $cart_item_key ]
			: array();
		$product_id = absint( $item['product_id'] ?? 0 );
		$product    = $product_id > 0 && function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
		$this->record_website_event(
			'remove_from_cart',
			$product_id,
			$product instanceof WC_Product ? $product->get_name() : '',
			0.0,
			array( 'quantity' => max( 1, absint( $item['quantity'] ?? 1 ) ) ),
			15
		);
	}

	/** Record paid website orders once, including product-level purchase demand. */
	public function capture_paid_order( $order_or_id ): void {
		$order = $order_or_id instanceof WC_Order
			? $order_or_id
			: ( function_exists( 'wc_get_order' ) ? wc_get_order( absint( $order_or_id ) ) : null );
		if ( ! $order instanceof WC_Order || 'mobile' === $order->get_meta( '_kidia_order_source' ) ) {
			return;
		}
		if ( 'yes' === $order->get_meta( '_kidia_website_analytics_recorded' ) ) {
			return;
		}

		$this->record_website_event(
			'purchase',
			$order->get_id(),
			(string) $order->get_order_number(),
			(float) $order->get_total(),
			array( 'order_id' => $order->get_id() )
		);
		foreach ( $order->get_items() as $item ) {
			$this->record_website_event(
				'purchase_item',
				absint( $item->get_product_id() ),
				$item->get_name(),
				(float) $item->get_total(),
				array( 'quantity' => max( 1, absint( $item->get_quantity() ) ) )
			);
		}
		$order->update_meta_data( '_kidia_website_analytics_recorded', 'yes' );
		$order->save();
	}

	public function capture_website_cart(): void {
		if ( is_admin() && ! wp_doing_ajax() ) {
			return;
		}
		if ( ! function_exists( 'WC' ) || ! WC() || ! WC()->cart || ! WC()->session ) {
			return;
		}

		$session_id = sanitize_text_field( (string) WC()->session->get_customer_id() );
		if ( '' === $session_id ) {
			return;
		}
		$items = array();
		foreach ( WC()->cart->get_cart() as $cart_item ) {
			$product = $cart_item['data'] ?? null;
			$items[] = array(
				'product_id' => absint( $cart_item['product_id'] ?? 0 ),
				'name'       => is_object( $product ) && method_exists( $product, 'get_name' ) ? sanitize_text_field( $product->get_name() ) : '',
				'quantity'   => max( 1, absint( $cart_item['quantity'] ?? 1 ) ),
			);
		}

		$user = wp_get_current_user();
		$this->upsert_cart(
			array(
				'cart_key'       => hash( 'sha256', 'website|' . $session_id ),
				'source'         => 'website',
				'client_id'      => '',
				'session_id'     => $session_id,
				'user_id'        => get_current_user_id(),
				'customer_name'  => $user instanceof WP_User ? $user->display_name : '',
				'customer_email' => $user instanceof WP_User ? $user->user_email : '',
				'items'          => $items,
				'item_count'     => array_sum( array_column( $items, 'quantity' ) ),
				'cart_total'     => max( 0, (float) WC()->cart->get_total( 'edit' ) ),
				'currency'       => function_exists( 'get_woocommerce_currency' ) ? get_woocommerce_currency() : '',
			)
		);
		$this->record_website_event(
			'cart_updated',
			0,
			'',
			(float) WC()->cart->get_total( 'edit' ),
			array( 'item_count' => WC()->cart->get_cart_contents_count() ),
			MINUTE_IN_SECONDS
		);
		if ( get_current_user_id() > 0 ) {
			self::mark_website_customer( get_current_user_id() );
		}
	}

	public function capture_completed_order( $order ): void {
		if ( ! $order instanceof WC_Order ) {
			return;
		}
		$source  = 'mobile' === $order->get_meta( '_kidia_order_source' ) ? 'mobile' : 'website';
		$user_id = absint( $order->get_customer_id() );
		if ( $user_id > 0 ) {
			if ( 'mobile' === $source ) {
				self::mark_mobile_customer( $user_id );
			} else {
				self::mark_website_customer( $user_id );
			}
		}
		if ( 'website' === $source && function_exists( 'WC' ) && WC() && WC()->session ) {
			$session_id = sanitize_text_field( (string) WC()->session->get_customer_id() );
			if ( '' !== $session_id ) {
				$this->mark_cart_converted( hash( 'sha256', 'website|' . $session_id ), $order->get_id() );
			}
		}
	}

	public function mark_website_registration( int $user_id ): void {
		if ( '' === (string) get_user_meta( $user_id, self::ORIGIN_META, true ) ) {
			update_user_meta( $user_id, self::ORIGIN_META, 'website' );
		}
		self::mark_website_customer( $user_id );
		if ( ! is_admin() || wp_doing_ajax() ) {
			$this->record_website_event( 'sign_up', $user_id, '', 0.0, array( 'user_id' => $user_id ) );
		}
	}

	public function mark_website_login( string $user_login, WP_User $user ): void {
		unset( $user_login );
		self::mark_website_customer( $user->ID );
		$this->record_website_event( 'login', $user->ID, '', 0.0, array( 'user_id' => $user->ID ) );
	}

	public static function mark_mobile_registration( int $user_id ): void {
		update_user_meta( $user_id, self::ORIGIN_META, 'mobile' );
		update_user_meta( $user_id, self::MOBILE_META, '1' );
		delete_user_meta( $user_id, self::WEBSITE_META );
	}

	public static function mark_mobile_customer( int $user_id ): void {
		if ( $user_id > 0 ) {
			update_user_meta( $user_id, self::MOBILE_META, '1' );
		}
	}

	public static function mark_website_customer( int $user_id ): void {
		if ( $user_id > 0 ) {
			update_user_meta( $user_id, self::WEBSITE_META, '1' );
		}
	}

	/**
	 * @return array{website:bool,mobile:bool}
	 */
	public static function customer_sources( int $user_id ): array {
		$origin  = (string) get_user_meta( $user_id, self::ORIGIN_META, true );
		$mobile  = '1' === (string) get_user_meta( $user_id, self::MOBILE_META, true )
			|| metadata_exists( 'user', $user_id, '_kidia_mobile_customer_sessions_v1' );
		$website = 'mobile' !== $origin
			|| '1' === (string) get_user_meta( $user_id, self::WEBSITE_META, true );
		return array( 'website' => $website, 'mobile' => $mobile );
	}

	/**
	 * @return array<string,mixed>
	 */
	public static function empty_summary(): array {
		return array(
			'events'          => array_fill_keys( self::EVENTS, array( 'count' => 0, 'unique' => 0, 'value' => 0.0 ) ),
			'visitors'        => 0,
			'new_users'       => 0,
			'returning_users' => 0,
			'top_products'          => array(),
			'top_purchases'         => array(),
			'tracked_top_purchases' => array(),
			'top_categories'        => array(),
			'top_searches'          => array(),
			'activity_hours'        => array(),
			'funnel'                => self::empty_funnel_snapshot(),
			'coverage'              => self::empty_coverage_snapshot(),
			'commerce'              => self::empty_commerce_snapshot(),
		);
	}

	/**
	 * @return array<string,mixed>
	 */
	public static function summary( int $from, int $to, string $source = 'all', bool $fresh = false ): array {
		$source    = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		$cache_key = self::summary_cache_key( $from, $to, $source );
		if ( ! $fresh ) {
			$cached = get_transient( $cache_key );
			if ( is_array( $cached ) ) {
				return array_merge( self::empty_summary(), $cached );
			}
		}

		global $wpdb;
		$table = self::events_table();
		$start = gmdate( 'Y-m-d H:i:s', $from );
		$end   = gmdate( 'Y-m-d H:i:s', $to );
		$source_sql = 'all' === $source ? '' : ' AND source = %s';
		$event_args = array( $start, $end );
		if ( 'all' !== $source ) {
			$event_args[] = $source;
		}
		$rows  = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT event_name, COUNT(*) AS event_count, COUNT(DISTINCT client_id) AS unique_clients,
					SUM(event_value) AS event_value
				FROM {$table}
				WHERE occurred_at BETWEEN %s AND %s {$source_sql}
				GROUP BY event_name",
				...$event_args
			),
			ARRAY_A
		);
		$events = array_fill_keys( self::EVENTS, array( 'count' => 0, 'unique' => 0, 'value' => 0.0 ) );
		foreach ( $rows as $row ) {
			$name = (string) $row['event_name'];
			if ( isset( $events[ $name ] ) ) {
				$events[ $name ] = array(
					'count'  => absint( $row['event_count'] ),
					'unique' => absint( $row['unique_clients'] ),
					'value'  => (float) $row['event_value'],
				);
			}
		}

		$visitor_args = array( $start, $end );
		if ( 'all' !== $source ) {
			$visitor_args[] = $source;
		}
		$visitors = (int) $wpdb->get_var(
			$wpdb->prepare(
				"SELECT COUNT(DISTINCT client_id)
				FROM {$table}
				WHERE event_name IN ('app_open','site_visit')
				AND occurred_at BETWEEN %s AND %s {$source_sql}",
				...$visitor_args
			)
		);
		$new_args = array();
		if ( 'all' !== $source ) {
			$new_args[] = $source;
		}
		$new_args[] = $start;
		$new_args[] = $end;
		$new      = (int) $wpdb->get_var(
			$wpdb->prepare(
				"SELECT COUNT(*) FROM (
					SELECT client_id, MIN(occurred_at) AS first_seen
					FROM {$table}
					WHERE event_name IN ('app_open','site_visit') {$source_sql}
					GROUP BY client_id
					HAVING first_seen BETWEEN %s AND %s
				) AS first_visits",
				...$new_args
			)
		);

		/*
		 * Historical WooCommerce orders and live journey events are deliberately
		 * kept separate. Replacing tracked purchase events with order-history
		 * totals makes an impossible funnel (purchases without tracked carts).
		 */
		$commerce = self::commerce_snapshot( $from, $to, $source, $fresh );
		$tracked_top_purchases = self::top_objects( $from, $to, 'purchase_item', $source );
		$top_purchases         = $tracked_top_purchases;
		if ( ! empty( $commerce['products'] ) ) {
			$top_purchases = $commerce['products'];
		}
		$activity_hours = self::activity_hours( $from, $to, $source );
		if ( empty( $activity_hours ) && ! empty( $commerce['activity_hours'] ) ) {
			$activity_hours = $commerce['activity_hours'];
		}

		$summary = array(
			'events'                => $events,
			'visitors'              => $visitors,
			'new_users'             => min( $visitors, $new ),
			'returning_users'       => max( 0, $visitors - $new ),
			'top_products'          => self::top_objects( $from, $to, 'view_item', $source ),
			'top_purchases'         => $top_purchases,
			'tracked_top_purchases' => $tracked_top_purchases,
			'top_categories'        => self::top_objects( $from, $to, 'view_category', $source ),
			'top_searches'          => self::top_labels( $from, $to, 'search', $source ),
			'activity_hours'        => $activity_hours,
			'funnel'                => self::funnel_snapshot( $from, $to, $source ),
			'coverage'              => self::coverage_snapshot( $from, $to, $source, $commerce ),
			'commerce'              => $commerce,
		);
		if ( ! $fresh ) {
			set_transient( $cache_key, $summary, 10 * MINUTE_IN_SECONDS );
		}
		return $summary;
	}

	/**
	 * Builds a closed, client-level funnel. A shopper is counted at a stage only
	 * when the previous tracked stage happened first in the selected period.
	 * Historical orders are never injected into this live journey.
	 *
	 * @return array<string,mixed>
	 */
	private static function funnel_snapshot( int $from, int $to, string $source ): array {
		global $wpdb;
		$table      = self::events_table();
		$source_sql = 'all' === $source ? '' : ' AND source = %s';
		$args       = array( gmdate( 'Y-m-d H:i:s', $from ), gmdate( 'Y-m-d H:i:s', $to ) );
		if ( 'all' !== $source ) {
			$args[] = $source;
		}
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT client_id, event_name, MIN(occurred_at) AS first_at
				FROM {$table}
				WHERE client_id <> ''
					AND event_name IN ('site_visit','app_open','view_item','add_to_cart','begin_checkout','purchase')
					AND occurred_at BETWEEN %s AND %s {$source_sql}
				GROUP BY client_id, event_name
				ORDER BY client_id ASC, first_at ASC",
				...$args
			),
			ARRAY_A
		);
		$clients = array();
		foreach ( $rows as $row ) {
			$client_id = sanitize_text_field( (string) ( $row['client_id'] ?? '' ) );
			$event     = sanitize_key( (string) ( $row['event_name'] ?? '' ) );
			$timestamp = strtotime( (string) ( $row['first_at'] ?? '' ) . ' UTC' );
			if ( '' === $client_id || false === $timestamp ) {
				continue;
			}
			if ( in_array( $event, array( 'site_visit', 'app_open' ), true ) ) {
				$clients[ $client_id ]['visitor'] = isset( $clients[ $client_id ]['visitor'] )
					? min( $clients[ $client_id ]['visitor'], $timestamp )
					: $timestamp;
				continue;
			}
			$clients[ $client_id ][ $event ] = $timestamp;
		}

		$funnel = self::empty_funnel_snapshot();
		foreach ( $clients as $stages ) {
			$visitor = absint( $stages['visitor'] ?? 0 );
			if ( 0 === $visitor ) {
				continue;
			}
			++$funnel['visitors'];
			$view = absint( $stages['view_item'] ?? 0 );
			if ( 0 === $view || $view < $visitor ) {
				continue;
			}
			++$funnel['viewed_product'];
			$cart = absint( $stages['add_to_cart'] ?? 0 );
			if ( 0 === $cart || $cart < $view ) {
				continue;
			}
			++$funnel['added_to_cart'];
			$checkout = absint( $stages['begin_checkout'] ?? 0 );
			if ( 0 === $checkout || $checkout < $cart ) {
				continue;
			}
			++$funnel['started_checkout'];
			$purchase = absint( $stages['purchase'] ?? 0 );
			if ( 0 === $purchase || $purchase < $checkout ) {
				continue;
			}
			++$funnel['purchased'];
		}

		$raw_purchases = absint(
			$wpdb->get_var(
				$wpdb->prepare(
					"SELECT COUNT(DISTINCT client_id)
					FROM {$table}
					WHERE client_id <> '' AND event_name = 'purchase'
						AND occurred_at BETWEEN %s AND %s {$source_sql}",
					...$args
				)
			)
		);
		$funnel['unmatched_purchases'] = max( 0, $raw_purchases - $funnel['purchased'] );
		$funnel['is_reliable'] = $funnel['visitors'] >= 20
			&& 0 === $funnel['unmatched_purchases'];
		return $funnel;
	}

	/** @return array<string,int|bool> */
	private static function empty_funnel_snapshot(): array {
		return array(
			'visitors'            => 0,
			'viewed_product'      => 0,
			'added_to_cart'       => 0,
			'started_checkout'    => 0,
			'purchased'           => 0,
			'unmatched_purchases' => 0,
			'is_reliable'         => false,
		);
	}

	/**
	 * Explains how much of the selected period is backed by live tracking.
	 *
	 * @param array<string,mixed> $commerce Historical commerce snapshot.
	 * @return array<string,mixed>
	 */
	private static function coverage_snapshot( int $from, int $to, string $source, array $commerce ): array {
		global $wpdb;
		$table      = self::events_table();
		$source_sql = 'all' === $source ? '' : ' WHERE source = %s';
		$args       = 'all' === $source ? array() : array( $source );
		$first      = $wpdb->get_var(
			empty( $args )
				? "SELECT MIN(occurred_at) FROM {$table}"
				: $wpdb->prepare( "SELECT MIN(occurred_at) FROM {$table}{$source_sql}", ...$args )
		);
		$first_at = is_string( $first ) && '' !== $first ? strtotime( $first . ' UTC' ) : false;
		$requested_days = max( 1, (int) ceil( max( 1, $to - $from ) / DAY_IN_SECONDS ) );
		$tracked_from   = false === $first_at ? 0 : max( $from, $first_at );
		$tracked_days   = 0 === $tracked_from
			? 0
			: max( 1, (int) ceil( max( 1, $to - $tracked_from ) / DAY_IN_SECONDS ) );
		return array(
			'tracking_started_at' => false === $first_at ? 0 : $first_at,
			'requested_days'      => $requested_days,
			'tracked_days'        => min( $requested_days, $tracked_days ),
			'tracking_percent'    => min( 100, round( 100 * $tracked_days / $requested_days, 1 ) ),
			'historical_orders'   => absint( $commerce['orders'] ?? 0 ),
			'orders_truncated'    => ! empty( $commerce['truncated'] ),
		);
	}

	/** @return array<string,int|float|bool> */
	private static function empty_coverage_snapshot(): array {
		return array(
			'tracking_started_at' => 0,
			'requested_days'      => 0,
			'tracked_days'        => 0,
			'tracking_percent'    => 0.0,
			'historical_orders'   => 0,
			'orders_truncated'    => false,
		);
	}

	/**
	 * Reads orders from the active WooCommerce data store and verifies every
	 * returned order against the requested UTC range and channel.
	 *
	 * Some stores can return an empty result for a supported date range while
	 * their unfiltered order query still returns the real orders. In that case
	 * the fallback walks newest-first pages and applies the same range locally.
	 * This keeps Reports and Analytics compatible with both CPT and HPOS storage.
	 *
	 * @param string[] $statuses Optional WooCommerce order statuses.
	 * @return WC_Order[]
	 */
	public static function orders_in_period( int $from, int $to, string $source = 'all', array $statuses = array() ): array {
		if ( ! function_exists( 'wc_get_orders' ) || $to < $from ) {
			return array();
		}

		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		$args   = array(
			'limit'        => 250,
			'page'         => 1,
			'paginate'     => true,
			'type'         => 'shop_order',
			'date_created' => $from . '...' . $to,
			'orderby'      => 'date',
			'order'        => 'DESC',
			'return'       => 'objects',
		);
		if ( ! empty( $statuses ) ) {
			$args['status'] = array_values( array_filter( array_map( 'sanitize_key', $statuses ) ) );
		}

		$orders = self::collect_orders_in_period( $args, $from, $to, $source, false );
		if ( ! empty( $orders ) ) {
			return $orders;
		}

		unset( $args['date_created'] );
		$args['page'] = 1;
		return self::collect_orders_in_period( $args, $from, $to, $source, true );
	}

	/**
	 * @param array<string,mixed> $args WooCommerce order query arguments.
	 * @return WC_Order[]
	 */
	private static function collect_orders_in_period( array $args, int $from, int $to, string $source, bool $stop_at_older_order ): array {
		$orders        = array();
		$maximum_pages = 1;
		do {
			$result = wc_get_orders( $args );
			$batch  = is_object( $result ) && isset( $result->orders )
				? (array) $result->orders
				: ( is_array( $result ) ? $result : array() );
			if ( is_object( $result ) && isset( $result->max_num_pages ) ) {
				$maximum_pages = max( 1, absint( $result->max_num_pages ) );
			}

			$reached_older_order = false;
			foreach ( $batch as $order ) {
				if ( ! $order instanceof WC_Order ) {
					continue;
				}
				$created = $order->get_date_created();
				if ( ! $created ) {
					continue;
				}
				$created_at = $created->getTimestamp();
				if ( $created_at < $from ) {
					$reached_older_order = true;
					continue;
				}
				if ( $created_at > $to ) {
					continue;
				}
				$order_source = 'mobile' === (string) $order->get_meta( '_kidia_order_source' )
					? 'mobile'
					: 'website';
				if ( 'all' !== $source && $source !== $order_source ) {
					continue;
				}
				$orders[] = $order;
			}

			++$args['page'];
			if ( $stop_at_older_order && $reached_older_order ) {
				break;
			}
		} while ( ! empty( $batch ) && absint( $args['page'] ) <= $maximum_pages );

		return $orders;
	}

	/**
	 * Reads real historical WooCommerce orders so AI Studio has useful evidence
	 * immediately, including stores that installed tracking after years of sales.
	 *
	 * @return array<string,mixed>
	 */
	public static function commerce_snapshot( int $from, int $to, string $source = 'all', bool $fresh = false ): array {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		$cache_key = self::commerce_cache_key( $from, $to, $source );
		if ( ! $fresh ) {
			$cached = get_transient( $cache_key );
			if ( is_array( $cached ) ) {
				return array_merge( self::empty_commerce_snapshot(), $cached );
			}
		}
		if ( ! function_exists( 'wc_get_orders' ) ) {
			return self::empty_commerce_snapshot();
		}

		$snapshot             = self::empty_commerce_snapshot();
		$orders               = self::orders_in_period(
			$from,
			$to,
			$source,
			function_exists( 'wc_get_is_paid_statuses' ) ? wc_get_is_paid_statuses() : array( 'processing', 'completed' )
		);
		$total_available      = count( $orders );
		$customers            = array();
		$products             = array();
		$product_customers    = array();
		$product_availability = array();
		$pairs                = array();
		$hours                = array();
		foreach ( $orders as $order ) {
				if ( ! $order instanceof WC_Order ) {
					continue;
				}
				++$snapshot['orders'];
				$snapshot['revenue'] += max( 0, (float) $order->get_total() );
				$customer_key = $order->get_customer_id() > 0
					? 'user-' . $order->get_customer_id()
					: 'email-' . hash( 'sha256', strtolower( (string) $order->get_billing_email() ) );
				$customers[ $customer_key ] = true;
				$order_product_ids = array();
				foreach ( $order->get_items() as $item ) {
					$product_id = absint( $item->get_product_id() );
					$quantity   = max( 1, absint( $item->get_quantity() ) );
					if ( $product_id <= 0 ) {
						continue;
					}
					if ( ! array_key_exists( $product_id, $product_availability ) ) {
						$product = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
						$product_availability[ $product_id ] = $product instanceof WC_Product && $product->is_in_stock();
					}
					if ( ! $product_availability[ $product_id ] ) {
						continue;
					}
					$snapshot['units'] += $quantity;
					if ( ! isset( $products[ $product_id ] ) ) {
						$products[ $product_id ] = array(
							'object_id'      => $product_id,
							'event_label'    => sanitize_text_field( $item->get_name() ),
							'event_count'    => 0,
							'unique_clients' => 0,
							'order_count'    => 0,
							'revenue'        => 0.0,
						);
					}
					$products[ $product_id ]['event_count'] += $quantity;
					$products[ $product_id ]['order_count'] += 1;
					$products[ $product_id ]['revenue'] += max( 0, (float) $item->get_total() );
					$product_customers[ $product_id ][ $customer_key ] = true;
					$order_product_ids[] = $product_id;
				}
				$order_product_ids = array_values( array_unique( $order_product_ids ) );
				sort( $order_product_ids );
				for ( $left = 0; $left < count( $order_product_ids ); ++$left ) {
					for ( $right = $left + 1; $right < count( $order_product_ids ); ++$right ) {
						$key = $order_product_ids[ $left ] . ':' . $order_product_ids[ $right ];
						$pairs[ $key ] = ( $pairs[ $key ] ?? 0 ) + 1;
					}
				}
				$created = $order->get_date_created();
				if ( $created ) {
					$hour = absint( wp_date( 'G', $created->getTimestamp() ) );
					$hours[ $hour ] = ( $hours[ $hour ] ?? 0 ) + 1;
				}
		}

		$snapshot['customers'] = count( $customers );
		$snapshot['average_order_value'] = $snapshot['orders'] > 0
			? round( $snapshot['revenue'] / $snapshot['orders'], 2 )
			: 0.0;
		foreach ( $products as $product_id => &$product_row ) {
			$product_row['unique_clients'] = count( $product_customers[ $product_id ] ?? array() );
			$product_row['order_share'] = $snapshot['orders'] > 0
				? round( 100 * absint( $product_row['order_count'] ) / $snapshot['orders'], 1 )
				: 0.0;
			$product = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
			if ( $product instanceof WC_Product ) {
				$product_row['price'] = max( 0, (float) $product->get_price() );
				$product_row['regular_price'] = max( 0, (float) $product->get_regular_price() );
				$product_row['stock'] = $product->managing_stock()
					? max( 0, (int) $product->get_stock_quantity() )
					: null;
				$product_row['image_url'] = $product->get_image_id()
					? (string) wp_get_attachment_image_url( $product->get_image_id(), 'woocommerce_thumbnail' )
					: '';
			}
		}
		unset( $product_row );
		uasort(
			$products,
			static fn( $left, $right ) => $right['event_count'] <=> $left['event_count']
		);
		$snapshot['products']      = array_values( $products );
		$snapshot['product_sales'] = array();
		foreach ( $products as $product_id => $product_row ) {
			$snapshot['product_sales'][ absint( $product_id ) ] = absint( $product_row['event_count'] ?? 0 );
		}
		arsort( $pairs );
		foreach ( array_slice( $pairs, 0, 20, true ) as $key => $count ) {
			$ids = array_map( 'absint', explode( ':', (string) $key ) );
			$names = array_map(
				static function ( int $product_id ) use ( $products ): string {
					return sanitize_text_field( (string) ( $products[ $product_id ]['event_label'] ?? '#' . $product_id ) );
				},
				$ids
			);
			$snapshot['pairs'][] = array(
				'product_ids' => $ids,
				'names'       => $names,
				'count'       => absint( $count ),
			);
		}
		arsort( $hours );
		foreach ( array_slice( $hours, 0, 6, true ) as $hour => $count ) {
			$snapshot['activity_hours'][] = array( 'hour' => absint( $hour ), 'event_count' => absint( $count ) );
		}
		$snapshot['catalog_products'] = function_exists( 'wp_count_posts' )
			? absint( wp_count_posts( 'product' )->publish ?? 0 )
			: 0;
		$snapshot['catalog_in_stock'] = function_exists( 'wc_get_products' )
			? count( wc_get_products( array( 'status' => 'publish', 'stock_status' => 'instock', 'limit' => -1, 'return' => 'ids' ) ) )
			: 0;
		$snapshot['orders_scanned']   = $snapshot['orders'];
		$snapshot['orders_available'] = max( $total_available, $snapshot['orders'] );
		$snapshot['truncated']        = $snapshot['orders_available'] > $snapshot['orders_scanned'];
		if ( ! $fresh ) {
			set_transient( $cache_key, $snapshot, 10 * MINUTE_IN_SECONDS );
		}
		return $snapshot;
	}

	/** Returns whether a completed incremental snapshot exists for this selection. */
	public static function has_commerce_snapshot( int $from, int $to, string $source = 'all' ): bool {
		return is_array( get_transient( self::commerce_cache_key( $from, $to, $source ) ) );
	}

	/** Stores a complete incremental snapshot and invalidates its derived summary. */
	public static function store_commerce_snapshot( int $from, int $to, string $source, array $snapshot ): void {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		set_transient(
			self::commerce_cache_key( $from, $to, $source ),
			array_merge( self::empty_commerce_snapshot(), $snapshot ),
			6 * HOUR_IN_SECONDS
		);
		delete_transient( self::summary_cache_key( $from, $to, $source ) );
	}

	/** Stable cache key shared by the incremental job and readers. */
	public static function commerce_cache_key( int $from, int $to, string $source = 'all' ): string {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		return 'kidia_commerce_snapshot_v5_' . md5( $from . '|' . $to . '|' . $source );
	}

	private static function summary_cache_key( int $from, int $to, string $source = 'all' ): string {
		$source = in_array( $source, array( 'website', 'mobile' ), true ) ? $source : 'all';
		return 'kidia_analytics_summary_v3_' . md5( $from . '|' . $to . '|' . $source );
	}

	/** @return array<string,mixed> */
	public static function empty_commerce_snapshot(): array {
		return array(
			'orders'              => 0,
			'orders_scanned'      => 0,
			'revenue'             => 0.0,
			'units'               => 0,
			'customers'           => 0,
			'average_order_value' => 0.0,
			'catalog_products'    => 0,
			'catalog_in_stock'    => 0,
			'products'            => array(),
			'product_sales'       => array(),
			'catalog_rows'        => array(),
			'pairs'               => array(),
			'activity_hours'      => array(),
			'orders_available'    => 0,
			'truncated'           => false,
		);
	}

	/**
	 * @return list<array<string,mixed>>
	 */
	public static function abandoned_carts( int $from, int $to, string $source = 'all', int $limit = 100 ): array {
		self::sync_website_sessions();
		global $wpdb;
		$table     = self::carts_table();
		$threshold = gmdate( 'Y-m-d H:i:s', time() - 30 * MINUTE_IN_SECONDS );
		$where     = 'last_activity_at BETWEEN %s AND %s AND item_count > 0';
		$args      = array( gmdate( 'Y-m-d H:i:s', $from ), gmdate( 'Y-m-d H:i:s', $to ) );
		if ( in_array( $source, array( 'website', 'mobile' ), true ) ) {
			$where .= ' AND source = %s';
			$args[] = $source;
		}
		$where .= " AND (status IN ('abandoned','recovered','converted') OR (status = 'active' AND last_activity_at <= %s))";
		$args[] = $threshold;
		$args[] = max( 1, min( 250, $limit ) );
		$rows   = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT * FROM {$table} WHERE {$where}
				ORDER BY CASE WHEN status = 'active' THEN 0 ELSE 1 END, cart_total DESC, last_activity_at DESC
				LIMIT %d",
				...$args
			),
			ARRAY_A
		);
		foreach ( $rows as &$row ) {
			if ( 'active' === $row['status'] ) {
				$row['status'] = 'abandoned';
			}
			$row['items'] = json_decode( (string) $row['items'], true );
			$row['items'] = is_array( $row['items'] ) ? $row['items'] : array();
		}
		unset( $row );
		return $rows;
	}

	/**
	 * Returns complete filtered totals independently from the limited table page.
	 *
	 * @return array{carts:int,abandoned:int,recovered:int,potential_value:float}
	 */
	public static function abandoned_summary( int $from, int $to, string $source = 'all' ): array {
		global $wpdb;
		$table      = self::carts_table();
		$threshold  = gmdate( 'Y-m-d H:i:s', time() - 30 * MINUTE_IN_SECONDS );
		$where      = 'last_activity_at BETWEEN %s AND %s AND item_count > 0';
		$args       = array( gmdate( 'Y-m-d H:i:s', $from ), gmdate( 'Y-m-d H:i:s', $to ) );
		if ( in_array( $source, array( 'website', 'mobile' ), true ) ) {
			$where .= ' AND source = %s';
			$args[] = $source;
		}
		$where .= " AND (status IN ('abandoned','recovered','converted') OR (status = 'active' AND last_activity_at <= %s))";
		$args[] = $threshold;
		$row    = $wpdb->get_row(
			$wpdb->prepare(
				"SELECT
					COUNT(*) AS carts,
					SUM(CASE WHEN status = 'abandoned' OR (status = 'active' AND last_activity_at <= %s) THEN 1 ELSE 0 END) AS abandoned,
					SUM(CASE WHEN status IN ('recovered','converted') THEN 1 ELSE 0 END) AS recovered,
					SUM(CASE WHEN status = 'abandoned' OR (status = 'active' AND last_activity_at <= %s) THEN cart_total ELSE 0 END) AS potential_value
				FROM {$table}
				WHERE {$where}",
				$threshold,
				$threshold,
				...$args
			),
			ARRAY_A
		);
		return array(
			'carts'           => absint( $row['carts'] ?? 0 ),
			'abandoned'       => absint( $row['abandoned'] ?? 0 ),
			'recovered'       => absint( $row['recovered'] ?? 0 ),
			'potential_value' => max( 0, (float) ( $row['potential_value'] ?? 0 ) ),
		);
	}

	public static function abandoned_count(): int {
		global $wpdb;
		$table     = self::carts_table();
		$threshold = gmdate( 'Y-m-d H:i:s', time() - 30 * MINUTE_IN_SECONDS );
		return absint(
			$wpdb->get_var(
				$wpdb->prepare(
					"SELECT COUNT(*) FROM {$table}
					WHERE item_count > 0
					AND (status = 'abandoned' OR (status = 'active' AND last_activity_at <= %s))",
					$threshold
				)
			)
		);
	}

	/**
	 * Starts a one-time, cursor-based import of every retained WooCommerce cart
	 * session. The old implementation repeatedly read only the first 300 rows.
	 *
	 * @return array<string,int|string>
	 */
	public function ensure_website_session_import(): array {
		$state = self::website_session_import_status();
		if ( in_array( (string) ( $state['phase'] ?? '' ), array( 'running', 'complete' ), true ) ) {
			if ( 'running' === (string) $state['phase'] ) {
				self::schedule_website_session_import();
			}
			return $state;
		}

		global $wpdb;
		$sessions_table = $wpdb->prefix . 'woocommerce_sessions';
		$table_exists   = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $sessions_table ) );
		if ( $sessions_table !== $table_exists ) {
			$state = array(
				'phase'     => 'unavailable',
				'processed' => 0,
				'total'     => 0,
				'imported'  => 0,
				'cursor'    => 0,
			);
			update_option( self::WEBSITE_IMPORT_OPTION, $state, false );
			return $state;
		}

		$total        = absint(
			$wpdb->get_var(
				"SELECT COUNT(*) FROM {$sessions_table}"
			)
		);
		$state        = array(
			'phase'      => $total > 0 ? 'running' : 'complete',
			'processed'  => 0,
			'total'      => $total,
			'imported'   => 0,
			'cursor'     => 0,
			'started_at' => time(),
		);
		update_option( self::WEBSITE_IMPORT_OPTION, $state, false );
		if ( $total > 0 ) {
			self::schedule_website_session_import();
		}
		return $state;
	}

	/** Action Scheduler / WP-Cron callback for one historical-cart batch. */
	public function run_website_session_import(): void {
		self::process_website_session_import_batch( self::WEBSITE_IMPORT_BATCH );
	}

	/**
	 * Imports one real batch immediately and leaves the rest to the server queue.
	 * This keeps the Abandoned Carts page responsive on large stores.
	 */
	public static function sync_website_sessions( int $limit = self::WEBSITE_IMPORT_BATCH ): int {
		$service = new self();
		$state   = $service->ensure_website_session_import();
		if ( 'running' !== (string) ( $state['phase'] ?? '' ) ) {
			return 0;
		}
		return self::process_website_session_import_batch( max( 1, min( 1000, $limit ) ) );
	}

	/** @return array<string,int|string> */
	public static function website_session_import_status(): array {
		$state = get_option( self::WEBSITE_IMPORT_OPTION, array() );
		return is_array( $state )
			? array_merge(
				array(
					'phase'     => 'not_started',
					'processed' => 0,
					'total'     => 0,
					'imported'  => 0,
					'cursor'    => 0,
				),
				$state
			)
			: array( 'phase' => 'not_started', 'processed' => 0, 'total' => 0, 'imported' => 0, 'cursor' => 0 );
	}

	/** Processes the next ordered session-id range exactly once. */
	private static function process_website_session_import_batch( int $limit ): int {
		if ( get_transient( self::WEBSITE_IMPORT_LOCK ) ) {
			return 0;
		}
		set_transient( self::WEBSITE_IMPORT_LOCK, 1, 2 * MINUTE_IN_SECONDS );

		$state = self::website_session_import_status();
		if ( 'running' !== (string) ( $state['phase'] ?? '' ) ) {
			delete_transient( self::WEBSITE_IMPORT_LOCK );
			return 0;
		}

		global $wpdb;
		$sessions_table = $wpdb->prefix . 'woocommerce_sessions';
		$rows           = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT session_id, session_key, session_value, session_expiry
				FROM {$sessions_table}
				WHERE session_id > %d
				ORDER BY session_id ASC
				LIMIT %d",
				absint( $state['cursor'] ?? 0 ),
				$limit
			),
			ARRAY_A
		);
		$imported = 0;
		$cursor   = absint( $state['cursor'] ?? 0 );
		foreach ( $rows as $row ) {
			$cursor = max( $cursor, absint( $row['session_id'] ?? 0 ) );
			if ( self::import_website_session_row( $row ) ) {
				++$imported;
			}
		}

		$state['cursor']    = $cursor;
		$state['processed'] = min(
			absint( $state['total'] ?? 0 ),
			absint( $state['processed'] ?? 0 ) + count( $rows )
		);
		$state['imported']  = absint( $state['imported'] ?? 0 ) + $imported;
		if ( count( $rows ) < $limit ) {
			$state['phase']        = 'complete';
			$state['completed_at'] = time();
			$state['processed']    = max( absint( $state['processed'] ), absint( $state['total'] ) );
		}
		update_option( self::WEBSITE_IMPORT_OPTION, $state, false );
		delete_transient( self::WEBSITE_IMPORT_LOCK );
		if ( 'running' === (string) $state['phase'] ) {
			self::schedule_website_session_import( true );
		}
		return $imported;
	}

	/** Imports one serialized WooCommerce session when it still contains items. */
	private static function import_website_session_row( array $row ): bool {
		$session = maybe_unserialize( $row['session_value'] ?? '' );
		if ( ! is_array( $session ) ) {
			return false;
		}
		$cart = maybe_unserialize( $session['cart'] ?? array() );
		if ( ! is_array( $cart ) || empty( $cart ) ) {
			return false;
		}
		$customer = maybe_unserialize( $session['customer'] ?? array() );
		$customer = is_array( $customer ) ? $customer : array();
		$items    = array();
		$total    = 0.0;
		foreach ( $cart as $cart_item ) {
			if ( ! is_array( $cart_item ) ) {
				continue;
			}
			$product_id = absint( $cart_item['product_id'] ?? 0 );
			$quantity   = max( 1, absint( $cart_item['quantity'] ?? 1 ) );
			if ( $product_id <= 0 ) {
				continue;
			}
			$product = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
			$items[] = array(
				'product_id' => $product_id,
				'name'       => $product instanceof WC_Product ? $product->get_name() : '',
				'quantity'   => $quantity,
			);
			$total += max( 0, (float) ( $cart_item['line_total'] ?? 0 ) )
				+ max( 0, (float) ( $cart_item['line_tax'] ?? 0 ) );
		}
		if ( empty( $items ) ) {
			return false;
		}

		$session_key  = sanitize_text_field( (string) ( $row['session_key'] ?? '' ) );
		if ( '' === $session_key ) {
			return false;
		}
		$user_id      = ctype_digit( $session_key ) ? absint( $session_key ) : 0;
		$expiry       = absint( $row['session_expiry'] ?? 0 );
		$expiration   = max( HOUR_IN_SECONDS, absint( apply_filters( 'wc_session_expiration', 48 * HOUR_IN_SECONDS ) ) );
		$last_activity = $expiry > 0 ? max( 1, $expiry - $expiration ) : time();
		( new self() )->upsert_cart(
			array(
				'cart_key'         => hash( 'sha256', 'website|' . $session_key ),
				'source'           => 'website',
				'client_id'        => '',
				'session_id'       => $session_key,
				'user_id'          => $user_id,
				'customer_name'    => trim( sanitize_text_field( (string) ( $customer['first_name'] ?? '' ) ) . ' ' . sanitize_text_field( (string) ( $customer['last_name'] ?? '' ) ) ),
				'customer_email'   => sanitize_email( (string) ( $customer['email'] ?? '' ) ),
				'items'            => $items,
				'item_count'       => array_sum( array_column( $items, 'quantity' ) ),
				'cart_total'       => $total,
				'currency'         => function_exists( 'get_woocommerce_currency' ) ? get_woocommerce_currency() : '',
				'started_at'       => gmdate( 'Y-m-d H:i:s', $last_activity ),
				'last_activity_at' => gmdate( 'Y-m-d H:i:s', $last_activity ),
			)
		);
		return true;
	}

	/** Schedules the next import batch without requiring the admin page to stay open. */
	private static function schedule_website_session_import( bool $from_runner = false ): void {
		if ( ! $from_runner && function_exists( 'as_has_scheduled_action' ) && as_has_scheduled_action( self::WEBSITE_IMPORT_HOOK, array(), 'kidia-mobile-cms' ) ) {
			return;
		}
		if ( function_exists( 'as_enqueue_async_action' ) ) {
			as_enqueue_async_action( self::WEBSITE_IMPORT_HOOK, array(), 'kidia-mobile-cms', false );
			return;
		}
		if ( ! wp_next_scheduled( self::WEBSITE_IMPORT_HOOK ) ) {
			wp_schedule_single_event( time() + 1, self::WEBSITE_IMPORT_HOOK );
		}
	}

	/**
	 * Returns normalized carts for an explicitly selected admin recovery action.
	 *
	 * @param list<int> $ids Cart row ids.
	 * @return list<array<string,mixed>>
	 */
	public static function carts_by_ids( array $ids ): array {
		$ids = array_values( array_filter( array_map( 'absint', $ids ) ) );
		if ( empty( $ids ) ) {
			return array();
		}
		global $wpdb;
		$table        = self::carts_table();
		$placeholders = implode( ',', array_fill( 0, count( $ids ), '%d' ) );
		$rows         = $wpdb->get_results(
			$wpdb->prepare( "SELECT * FROM {$table} WHERE id IN ({$placeholders}) AND item_count > 0", ...$ids ),
			ARRAY_A
		);
		foreach ( $rows as &$row ) {
			$row['items'] = json_decode( (string) $row['items'], true );
			$row['items'] = is_array( $row['items'] ) ? $row['items'] : array();
		}
		unset( $row );
		return $rows;
	}

	/**
	 * @return list<array<string,mixed>>
	 */
	private static function top_objects( int $from, int $to, string $event, string $source ): array {
		global $wpdb;
		$table = self::events_table();
		$source_sql = 'all' === $source ? '' : ' AND source = %s';
		$args = array( $event, gmdate( 'Y-m-d H:i:s', $from ), gmdate( 'Y-m-d H:i:s', $to ) );
		if ( 'all' !== $source ) {
			$args[] = $source;
		}
		$rows  = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT object_id, MAX(event_label) AS event_label, COUNT(*) AS event_count,
					COUNT(DISTINCT client_id) AS unique_clients
				FROM {$table}
				WHERE event_name = %s AND object_id > 0 AND occurred_at BETWEEN %s AND %s {$source_sql}
				GROUP BY object_id
				ORDER BY event_count DESC
				LIMIT 50",
				...$args
			),
			ARRAY_A
		);
		$filtered = array();
		foreach ( $rows as &$row ) {
			if ( 'view_category' === $event && taxonomy_exists( 'product_cat' ) ) {
				$category = get_term( absint( $row['object_id'] ), 'product_cat' );
				if ( $category instanceof WP_Term ) {
					$row['event_label'] = $category->name;
				}
				$filtered[] = $row;
			} else {
				$product = function_exists( 'wc_get_product' ) ? wc_get_product( absint( $row['object_id'] ) ) : null;
				if ( $product instanceof WC_Product && $product->is_in_stock() ) {
					$row['event_label'] = $product->get_name();
					$filtered[] = $row;
				}
			}
			if ( count( $filtered ) >= 8 ) {
				break;
			}
		}
		unset( $row );
		return array_values( $filtered );
	}

	/**
	 * @return list<array<string,mixed>>
	 */
	private static function top_labels( int $from, int $to, string $event, string $source ): array {
		global $wpdb;
		$table = self::events_table();
		$source_sql = 'all' === $source ? '' : ' AND source = %s';
		$args = array( $event, gmdate( 'Y-m-d H:i:s', $from ), gmdate( 'Y-m-d H:i:s', $to ) );
		if ( 'all' !== $source ) {
			$args[] = $source;
		}
		return $wpdb->get_results(
			$wpdb->prepare(
				"SELECT event_label, COUNT(*) AS event_count, COUNT(DISTINCT client_id) AS unique_clients
				FROM {$table}
				WHERE event_name = %s AND event_label <> '' AND occurred_at BETWEEN %s AND %s {$source_sql}
				GROUP BY event_label
				ORDER BY event_count DESC
				LIMIT 8",
				...$args
			),
			ARRAY_A
		);
	}

	/**
	 * @return list<array{hour:int,event_count:int}>
	 */
	private static function activity_hours( int $from, int $to, string $source ): array {
		global $wpdb;
		$table = self::events_table();
		$source_sql = 'all' === $source ? '' : ' AND source = %s';
		$args = array( gmdate( 'Y-m-d H:i:s', $from ), gmdate( 'Y-m-d H:i:s', $to ) );
		if ( 'all' !== $source ) {
			$args[] = $source;
		}
		$rows  = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT HOUR(occurred_at) AS activity_hour, COUNT(*) AS event_count
				FROM {$table}
				WHERE occurred_at BETWEEN %s AND %s {$source_sql}
				GROUP BY activity_hour
				ORDER BY event_count DESC
				LIMIT 6",
				...$args
			),
			ARRAY_A
		);
		$offset = (int) round( wp_timezone()->getOffset( new DateTimeImmutable( 'now', new DateTimeZone( 'UTC' ) ) ) / HOUR_IN_SECONDS );
		return array_map(
			static fn( $row ) => array(
				'hour'        => ( absint( $row['activity_hour'] ) + $offset + 24 ) % 24,
				'event_count' => absint( $row['event_count'] ),
			),
			$rows
		);
	}

	/**
	 * Store a trusted server-side website event.
	 *
	 * @param array<string,mixed> $properties Event properties.
	 */
	private function record_website_event(
		string $event,
		int $object_id = 0,
		string $label = '',
		float $value = 0.0,
		array $properties = array(),
		int $deduplicate_for = 0
	): void {
		if ( ! in_array( $event, self::EVENTS, true ) ) {
			return;
		}
		$client_id = $this->website_client_id();
		if ( '' === $client_id ) {
			return;
		}
		$deduplication_key = '';
		if ( $deduplicate_for > 0 ) {
			$deduplication_key = $this->website_event_cache_key( $event, $client_id, $object_id, $label );
			if ( get_transient( $deduplication_key ) ) {
				return;
			}
		}

		$this->maybe_install();
		$session_id = '';
		if ( function_exists( 'WC' ) && WC() && WC()->session ) {
			$session_id = $this->identifier( (string) WC()->session->get_customer_id() );
		}
		$result = $this->insert_event(
			array(
				'client_id'   => $client_id,
				'session_id'  => $session_id,
				'user_id'     => get_current_user_id(),
				'source'      => 'website',
				'event_name'  => $event,
				'object_id'   => max( 0, $object_id ),
				'event_label' => mb_substr( sanitize_text_field( $label ), 0, 191 ),
				'event_value' => max( 0, $value ),
				'currency'    => function_exists( 'get_woocommerce_currency' ) ? mb_substr( get_woocommerce_currency(), 0, 12 ) : '',
				'properties'  => $this->sanitize_properties( $properties ),
			)
		);
		if ( 'inserted' === $result && '' !== $deduplication_key ) {
			set_transient( $deduplication_key, 1, $deduplicate_for );
		}
	}

	/**
	 * @param array<string,mixed> $event Event payload.
	 * @return string inserted, duplicate or failed.
	 */
	private function insert_event( array $event ): string {
		global $wpdb;
		$event_id = $this->identifier( $event['event_id'] ?? '' );
		if ( '' !== $event_id ) {
			$exists = $wpdb->get_var(
				$wpdb->prepare(
					'SELECT id FROM ' . self::events_table() . ' WHERE event_id = %s LIMIT 1',
					$event_id
				)
			);
			if ( null !== $exists ) {
				return 'duplicate';
			}
		}

		$inserted = $wpdb->insert(
			self::events_table(),
			array(
				'event_id'    => '' === $event_id ? null : $event_id,
				'client_id'   => $this->identifier( $event['client_id'] ?? '' ),
				'session_id'  => $this->identifier( $event['session_id'] ?? '' ),
				'user_id'     => absint( $event['user_id'] ?? 0 ),
				'source'      => in_array( $event['source'] ?? '', array( 'website', 'mobile' ), true ) ? $event['source'] : 'website',
				'event_name'  => sanitize_key( (string) ( $event['event_name'] ?? '' ) ),
				'object_id'   => absint( $event['object_id'] ?? 0 ),
				'event_label' => mb_substr( sanitize_text_field( (string) ( $event['event_label'] ?? '' ) ), 0, 191 ),
				'event_value' => max( 0, (float) ( $event['event_value'] ?? 0 ) ),
				'currency'    => mb_substr( strtoupper( sanitize_key( (string) ( $event['currency'] ?? '' ) ) ), 0, 12 ),
				'properties'  => wp_json_encode( $this->sanitize_properties( (array) ( $event['properties'] ?? array() ) ) ),
				'occurred_at' => current_time( 'mysql', true ),
			),
			array( '%s', '%s', '%s', '%d', '%s', '%s', '%d', '%s', '%f', '%s', '%s', '%s' )
		);
		if ( false !== $inserted ) {
			return 'inserted';
		}
		if ( '' !== $event_id ) {
			$exists = $wpdb->get_var(
				$wpdb->prepare(
					'SELECT id FROM ' . self::events_table() . ' WHERE event_id = %s LIMIT 1',
					$event_id
				)
			);
			if ( null !== $exists ) {
				return 'duplicate';
			}
		}
		return 'failed';
	}

	private function website_event_cache_key( string $event, string $client_id, int $object_id, string $label ): string {
		return 'kidia_web_event_' . substr( hash( 'sha256', $event . '|' . $client_id . '|' . $object_id . '|' . $label ), 0, 28 );
	}

	private function website_client_id(): string {
		static $client_id = '';
		if ( '' !== $client_id ) {
			return $client_id;
		}

		$client_id = $this->identifier( $_COOKIE['kidia_website_client'] ?? '' );
		if ( '' !== $client_id ) {
			return $client_id;
		}
		$client_id = 'web-' . wp_generate_uuid4();
		$_COOKIE['kidia_website_client'] = $client_id;
		if ( ! headers_sent() ) {
			setcookie(
				'kidia_website_client',
				$client_id,
				array(
					'expires'  => time() + YEAR_IN_SECONDS,
					'path'     => defined( 'COOKIEPATH' ) && COOKIEPATH ? COOKIEPATH : '/',
					'domain'   => defined( 'COOKIE_DOMAIN' ) ? COOKIE_DOMAIN : '',
					'secure'   => is_ssl(),
					'httponly' => false,
					'samesite' => 'Lax',
				)
			);
		}
		return $client_id;
	}

	/**
	 * @param array<string,mixed> $cart
	 */
	private function upsert_cart( array $cart ): void {
		$this->maybe_install();
		global $wpdb;
		$table = self::carts_table();
		$now   = current_time( 'mysql', true );
		$started_at = self::safe_mysql_time( $cart['started_at'] ?? '', $now );
		$last_activity_at = self::safe_mysql_time( $cart['last_activity_at'] ?? '', $now );
		$items = is_array( $cart['items'] ?? null ) ? $cart['items'] : array();
		$empty = empty( $items ) || empty( $cart['item_count'] );

		$sql = $wpdb->prepare(
			"INSERT INTO {$table}
				(cart_key, source, client_id, session_id, user_id, customer_name, customer_email, items, item_count, cart_total, currency, status, started_at, last_activity_at)
			VALUES (%s,%s,%s,%s,%d,%s,%s,%s,%d,%f,%s,%s,%s,%s)
			ON DUPLICATE KEY UPDATE
				source=VALUES(source), client_id=VALUES(client_id), session_id=VALUES(session_id),
				user_id=IF(VALUES(user_id)>0,VALUES(user_id),user_id),
				customer_name=IF(VALUES(customer_name)<>'',VALUES(customer_name),customer_name),
				customer_email=IF(VALUES(customer_email)<>'',VALUES(customer_email),customer_email),
				items=VALUES(items), item_count=VALUES(item_count), cart_total=VALUES(cart_total),
				currency=VALUES(currency),
				status=CASE
					WHEN status='converted' THEN status
					WHEN VALUES(status)='empty' THEN 'empty'
					WHEN status='active' AND last_activity_at <= DATE_SUB(VALUES(last_activity_at), INTERVAL 30 MINUTE) THEN 'recovered'
					WHEN status='recovered' THEN status
					ELSE VALUES(status)
				END,
				last_activity_at=GREATEST(last_activity_at,VALUES(last_activity_at))",
			(string) $cart['cart_key'],
			(string) $cart['source'],
			(string) $cart['client_id'],
			(string) $cart['session_id'],
			absint( $cart['user_id'] ),
			sanitize_text_field( (string) $cart['customer_name'] ),
			sanitize_email( (string) $cart['customer_email'] ),
			wp_json_encode( array_slice( $items, 0, 100 ) ),
			absint( $cart['item_count'] ),
			max( 0, (float) $cart['cart_total'] ),
			mb_substr( strtoupper( sanitize_key( (string) $cart['currency'] ) ), 0, 12 ),
			$empty ? 'empty' : 'active',
			$started_at,
			$last_activity_at
		);
		$wpdb->query( $sql );
	}

	private static function safe_mysql_time( $value, string $fallback ): string {
		$timestamp = is_numeric( $value ) ? absint( $value ) : strtotime( (string) $value . ' UTC' );
		return $timestamp ? gmdate( 'Y-m-d H:i:s', $timestamp ) : $fallback;
	}

	private function mark_mobile_cart_converted( string $client_id, string $session_id, int $order_id ): void {
		$this->mark_cart_converted( hash( 'sha256', 'mobile|' . $client_id . '|' . $session_id ), $order_id );
	}

	private function mark_cart_converted( string $cart_key, int $order_id ): void {
		global $wpdb;
		$wpdb->update(
			self::carts_table(),
			array(
				'status'       => 'converted',
				'converted_at' => current_time( 'mysql', true ),
				'order_id'     => $order_id,
			),
			array( 'cart_key' => $cart_key ),
			array( '%s', '%s', '%d' ),
			array( '%s' )
		);
	}

	/**
	 * @return list<array{product_id:int,name:string,quantity:int}>
	 */
	private function normalize_mobile_items( $raw ): array {
		if ( ! is_array( $raw ) ) {
			return array();
		}
		$items = array();
		foreach ( array_slice( $raw, 0, 100 ) as $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}
			$product_id = absint( $item['product_id'] ?? 0 );
			$quantity   = max( 1, absint( $item['quantity'] ?? 1 ) );
			if ( $product_id <= 0 ) {
				continue;
			}
			$product = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
			$name    = is_object( $product ) && method_exists( $product, 'get_name' )
				? $product->get_name()
				: sanitize_text_field( (string) ( $item['name'] ?? '' ) );
			$items[] = array( 'product_id' => $product_id, 'name' => $name, 'quantity' => $quantity );
		}
		return $items;
	}

	/**
	 * @param array<string,mixed> $properties
	 * @return array<string,string|int|float|bool>
	 */
	private function sanitize_properties( array $properties ): array {
		$clean = array();
		foreach ( array_slice( $properties, 0, 20, true ) as $key => $value ) {
			$key = sanitize_key( (string) $key );
			if ( '' === $key || is_array( $value ) || is_object( $value ) ) {
				continue;
			}
			$clean[ $key ] = is_string( $value ) ? mb_substr( sanitize_text_field( $value ), 0, 191 ) : $value;
		}
		return $clean;
	}

	private function identifier( $value ): string {
		$value = preg_replace( '/[^A-Za-z0-9._-]/', '', (string) $value );
		return strlen( $value ) >= 8 && strlen( $value ) <= 64 ? $value : '';
	}

	private function allow_request( string $key, int $limit = 240 ): bool {
		$transient = 'kidia_analytics_rate_' . substr( hash( 'sha256', $key ), 0, 24 );
		$count     = absint( get_transient( $transient ) );
		if ( $count >= $limit ) {
			return false;
		}
		set_transient( $transient, $count + 1, MINUTE_IN_SECONDS );
		return true;
	}

	private function request_ip(): string {
		$ip = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : 'unknown';
		return filter_var( $ip, FILTER_VALIDATE_IP ) ? $ip : 'unknown';
	}

	private static function events_table(): string {
		global $wpdb;
		return $wpdb->prefix . 'kidia_mobile_events';
	}

	private static function carts_table(): string {
		global $wpdb;
		return $wpdb->prefix . 'kidia_mobile_carts';
	}
}
