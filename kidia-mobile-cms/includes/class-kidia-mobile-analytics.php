<?php
/**
 * Mobile commerce analytics and abandoned-cart storage.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Analytics {

	private const DB_VERSION = '1';
	private const DB_OPTION  = 'kidia_mobile_analytics_db_version';
	private const MOBILE_META = '_kidia_mobile_customer';
	private const WEBSITE_META = '_kidia_website_customer';
	private const ORIGIN_META = '_kidia_customer_origin';

	/** @var list<string> */
	private const EVENTS = array(
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
		add_action( 'user_register', array( $this, 'mark_website_registration' ) );
		add_action( 'wp_login', array( $this, 'mark_website_login' ), 10, 2 );
		add_action( 'woocommerce_cart_updated', array( $this, 'capture_website_cart' ) );
		add_action( 'woocommerce_add_to_cart', array( $this, 'capture_website_cart' ), 50 );
		add_action( 'woocommerce_cart_item_removed', array( $this, 'capture_website_cart' ), 50 );
		add_action( 'woocommerce_checkout_order_created', array( $this, 'capture_completed_order' ) );
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
				client_id varchar(64) NOT NULL,
				session_id varchar(64) NOT NULL DEFAULT '',
				user_id bigint(20) unsigned NOT NULL DEFAULT 0,
				event_name varchar(50) NOT NULL,
				object_id bigint(20) unsigned NOT NULL DEFAULT 0,
				event_label varchar(191) NOT NULL DEFAULT '',
				event_value decimal(20,6) NOT NULL DEFAULT 0,
				currency varchar(12) NOT NULL DEFAULT '',
				properties longtext NULL,
				occurred_at datetime NOT NULL,
				PRIMARY KEY  (id),
				KEY event_time (event_name, occurred_at),
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

		global $wpdb;
		$wpdb->insert(
			self::events_table(),
			array(
				'client_id'    => $client_id,
				'session_id'   => $this->identifier( $request->get_param( 'session_id' ) ),
				'user_id'      => $user_id,
				'event_name'   => $event,
				'object_id'    => $object_id,
				'event_label'  => mb_substr( $label, 0, 191 ),
				'event_value'  => $value,
				'currency'     => mb_substr( $currency, 0, 12 ),
				'properties'   => wp_json_encode( $properties ),
				'occurred_at'  => current_time( 'mysql', true ),
			),
			array( '%s', '%s', '%d', '%s', '%d', '%s', '%f', '%s', '%s', '%s' )
		);

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

		return rest_ensure_response( array( 'recorded' => true ) );
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
	}

	public function mark_website_login( string $user_login, WP_User $user ): void {
		unset( $user_login );
		self::mark_website_customer( $user->ID );
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
			'top_products'    => array(),
			'top_purchases'   => array(),
			'top_categories'  => array(),
			'top_searches'    => array(),
			'activity_hours'  => array(),
		);
	}

	/**
	 * @return array<string,mixed>
	 */
	public static function summary( int $from, int $to ): array {
		global $wpdb;
		$table = self::events_table();
		$start = gmdate( 'Y-m-d H:i:s', $from );
		$end   = gmdate( 'Y-m-d H:i:s', $to );
		$rows  = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT event_name, COUNT(*) AS event_count, COUNT(DISTINCT client_id) AS unique_clients,
					SUM(event_value) AS event_value
				FROM {$table}
				WHERE occurred_at BETWEEN %s AND %s
				GROUP BY event_name",
				$start,
				$end
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

		$visitors = (int) $events['app_open']['unique'];
		$new      = (int) $wpdb->get_var(
			$wpdb->prepare(
				"SELECT COUNT(*) FROM (
					SELECT client_id, MIN(occurred_at) AS first_seen
					FROM {$table}
					GROUP BY client_id
					HAVING first_seen BETWEEN %s AND %s
				) AS first_visits",
				$start,
				$end
			)
		);

		return array(
			'events'          => $events,
			'visitors'        => $visitors,
			'new_users'       => min( $visitors, $new ),
			'returning_users' => max( 0, $visitors - $new ),
			'top_products'    => self::top_objects( $from, $to, 'view_item' ),
			'top_purchases'   => self::top_objects( $from, $to, 'purchase_item' ),
			'top_categories'  => self::top_objects( $from, $to, 'view_category' ),
			'top_searches'    => self::top_labels( $from, $to, 'search' ),
			'activity_hours'  => self::activity_hours( $from, $to ),
		);
	}

	/**
	 * @return list<array<string,mixed>>
	 */
	public static function abandoned_carts( int $from, int $to, string $source = 'all', int $limit = 100 ): array {
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
	 * @return list<array<string,mixed>>
	 */
	private static function top_objects( int $from, int $to, string $event ): array {
		global $wpdb;
		$table = self::events_table();
		$rows  = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT object_id, MAX(event_label) AS event_label, COUNT(*) AS event_count,
					COUNT(DISTINCT client_id) AS unique_clients
				FROM {$table}
				WHERE event_name = %s AND object_id > 0 AND occurred_at BETWEEN %s AND %s
				GROUP BY object_id
				ORDER BY event_count DESC
				LIMIT 8",
				$event,
				gmdate( 'Y-m-d H:i:s', $from ),
				gmdate( 'Y-m-d H:i:s', $to )
			),
			ARRAY_A
		);
		foreach ( $rows as &$row ) {
			if ( 'view_category' === $event && taxonomy_exists( 'product_cat' ) ) {
				$category = get_term( absint( $row['object_id'] ), 'product_cat' );
				if ( $category instanceof WP_Term ) {
					$row['event_label'] = $category->name;
				}
			} else {
				$product = function_exists( 'wc_get_product' ) ? wc_get_product( absint( $row['object_id'] ) ) : null;
				if ( is_object( $product ) && method_exists( $product, 'get_name' ) ) {
					$row['event_label'] = $product->get_name();
				}
			}
		}
		unset( $row );
		return $rows;
	}

	/**
	 * @return list<array<string,mixed>>
	 */
	private static function top_labels( int $from, int $to, string $event ): array {
		global $wpdb;
		$table = self::events_table();
		return $wpdb->get_results(
			$wpdb->prepare(
				"SELECT event_label, COUNT(*) AS event_count, COUNT(DISTINCT client_id) AS unique_clients
				FROM {$table}
				WHERE event_name = %s AND event_label <> '' AND occurred_at BETWEEN %s AND %s
				GROUP BY event_label
				ORDER BY event_count DESC
				LIMIT 8",
				$event,
				gmdate( 'Y-m-d H:i:s', $from ),
				gmdate( 'Y-m-d H:i:s', $to )
			),
			ARRAY_A
		);
	}

	/**
	 * @return list<array{hour:int,event_count:int}>
	 */
	private static function activity_hours( int $from, int $to ): array {
		global $wpdb;
		$table = self::events_table();
		$rows  = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT HOUR(occurred_at) AS activity_hour, COUNT(*) AS event_count
				FROM {$table}
				WHERE occurred_at BETWEEN %s AND %s
				GROUP BY activity_hour
				ORDER BY event_count DESC
				LIMIT 6",
				gmdate( 'Y-m-d H:i:s', $from ),
				gmdate( 'Y-m-d H:i:s', $to )
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
	 * @param array<string,mixed> $cart
	 */
	private function upsert_cart( array $cart ): void {
		$this->maybe_install();
		global $wpdb;
		$table = self::carts_table();
		$now   = current_time( 'mysql', true );
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
				last_activity_at=VALUES(last_activity_at)",
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
			$now,
			$now
		);
		$wpdb->query( $sql );
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
