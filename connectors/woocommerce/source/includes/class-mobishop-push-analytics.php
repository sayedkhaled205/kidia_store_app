<?php
/** Deduplicated delivery evidence and server-verified, seven-day click attribution. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Push_Analytics {

	const VERSION = '1';
	const OPTION = 'mobishop_push_analytics_schema';

	public static function register(): void {
		add_action( 'admin_init', array( self::class, 'install' ) );
		add_action( 'woocommerce_store_api_checkout_update_order_from_request', array( self::class, 'attribute_order' ), 30, 2 );
		add_action( 'woocommerce_store_api_checkout_order_processed', array( self::class, 'sync_order' ), 30 );
		add_action( 'woocommerce_order_status_changed', array( self::class, 'sync_order' ), 30 );
		add_action( 'woocommerce_order_refunded', array( self::class, 'sync_order' ), 30 );
		add_action( 'woocommerce_payment_complete', array( self::class, 'sync_order' ), 30 );
	}

	public static function table( string $kind ): string {
		global $wpdb;
		return $wpdb->prefix . 'mobishop_push_' . ( in_array( $kind, array( 'orders', 'campaigns' ), true ) ? $kind : 'events' ) . '_v2';
	}

	/** Called only from authenticated management/delivery, never a public event. */
	public static function install(): void {
		if ( self::VERSION === get_option( self::OPTION ) ) return;
		global $wpdb;
		require_once ABSPATH . 'wp-admin/includes/upgrade.php';
		$events = self::table( 'events' ); $orders = self::table( 'orders' ); $campaigns = self::table( 'campaigns' ); $charset = $wpdb->get_charset_collate();
		dbDelta( "CREATE TABLE {$campaigns} (
			id varchar(80) NOT NULL,
			title text NOT NULL,
			message text NOT NULL,
			status varchar(30) NOT NULL,
			audience varchar(30) NOT NULL,
			sent int unsigned NOT NULL DEFAULT 0,
			failed int unsigned NOT NULL DEFAULT 0,
			created_at bigint unsigned NOT NULL,
			PRIMARY KEY  (id),
			KEY created_at (created_at)
		) {$charset};" );
		dbDelta( "CREATE TABLE {$events} (
			id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
			campaign varchar(80) NOT NULL,
			event varchar(12) NOT NULL,
			client_hash char(64) NOT NULL,
			platform varchar(10) NOT NULL DEFAULT '',
			occurred_at datetime NOT NULL,
			PRIMARY KEY  (id),
			UNIQUE KEY event_once (campaign,event,client_hash),
			KEY last_click (client_hash,event,occurred_at),
			KEY campaign_time (campaign,occurred_at)
		) {$charset};" );
		dbDelta( "CREATE TABLE {$orders} (
			order_id bigint(20) unsigned NOT NULL,
			campaign varchar(80) NOT NULL,
			client_hash char(64) NOT NULL,
			buyer_hash char(64) NOT NULL,
			currency varchar(12) NOT NULL,
			amount decimal(20,6) NOT NULL DEFAULT 0,
			status varchar(30) NOT NULL,
			paid tinyint(1) NOT NULL DEFAULT 0,
			created_at datetime NOT NULL,
			updated_at datetime NOT NULL,
			PRIMARY KEY  (order_id),
			KEY campaign_time (campaign,created_at)
		) {$charset};" );
		if ( $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $events ) ) === $events
			&& $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $orders ) ) === $orders
			&& $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $campaigns ) ) === $campaigns ) {
			update_option( self::OPTION, self::VERSION, false );
			add_option( 'mobishop_push_analytics_started_at', time(), '', false );
		}
	}

	public static function identifier( $value ): string {
		return is_string( $value ) && preg_match( '/^[a-zA-Z0-9_-]{8,160}$/D', $value ) ? $value : '';
	}

	/** Persist audience evidence before contacting the provider, preventing receipt races. */
	public static function begin( array $payload, array $devices ): void {
		self::install();
		if ( self::VERSION !== get_option( self::OPTION ) ) return;
		$id = (string) ( $payload['id'] ?? '' );
		if ( '' === self::identifier( $id ) || strlen( $id ) > 80 ) return;
		global $wpdb; $table = self::table( 'events' ); $campaigns = self::table( 'campaigns' );
		$wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$campaigns} (id,title,message,status,created_at,audience) VALUES (%s,%s,%s,%s,%d,%s)",
			$id, (string) ( $payload['title'] ?? '' ), (string) ( $payload['message'] ?? '' ), 'sending', time(), (string) ( $payload['audience'] ?? 'all' ) ) );
		foreach ( array_chunk( $devices, 100 ) as $chunk ) {
			$values = array(); $params = array();
			foreach ( $chunk as $device ) {
				$client = self::identifier( $device['client_id'] ?? null );
				if ( '' === $client ) continue;
				$values[] = '(%s,%s,%s,%s,%s)';
				array_push( $params, $id, 'target', hash( 'sha256', $client ), substr( (string) ( $device['platform'] ?? '' ), 0, 10 ), gmdate( 'Y-m-d H:i:s' ) );
			}
			if ( $values ) $wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$table} (campaign,event,client_hash,platform,occurred_at) VALUES " . implode( ',', $values ), ...$params ) );
		}
	}

	public static function finish( array $payload ): void {
		global $wpdb;
		if ( self::VERSION !== get_option( self::OPTION ) ) return;
		$wpdb->update( self::table( 'campaigns' ), array( 'status' => (string) ( $payload['status'] ?? 'failed' ),
			'sent' => max( 0, (int) ( $payload['delivery']['sent'] ?? 0 ) ),
			'failed' => max( 0, (int) ( $payload['delivery']['failed'] ?? 0 ) ) ), array( 'id' => (string) ( $payload['id'] ?? '' ) ) );
	}

	public static function record( WP_REST_Request $request ) {
		$id = self::identifier( $request->get_param( 'notification_id' ) );
		$client = self::identifier( $request->get_param( 'client_id' ) );
		$event = $request->get_param( 'event' );
		if ( ! in_array( $event, array( 'delivered', 'opened' ), true ) || '' === $id || '' === $client || strlen( $id ) > 80 ) {
			return new WP_Error( 'invalid_push_event', 'A valid device receipt or open is required.', array( 'status' => 400 ) );
		}
		if ( self::VERSION !== get_option( self::OPTION ) ) return new WP_Error( 'push_metrics_unavailable', 'Analytics is not ready.', array( 'status' => 503 ) );
		global $wpdb; $table = self::table( 'events' ); $hash = hash( 'sha256', $client );
		// Only a device in this campaign's actual audience can report an event.
		$target = $wpdb->get_row( $wpdb->prepare( "SELECT platform FROM {$table} WHERE campaign=%s AND client_hash=%s AND event='target' LIMIT 1", $id, $hash ), ARRAY_A );
		if ( ! $target ) return new WP_Error( 'push_campaign_unavailable', 'Notification audience not found.', array( 'status' => 404 ) );
		$values = array( $id, $event, $hash, $target['platform'], gmdate( 'Y-m-d H:i:s' ) );
		$placeholders = '(%s,%s,%s,%s,%s)';
		if ( 'opened' === $event ) {
			$placeholders .= ',(%s,%s,%s,%s,%s)';
			array_push( $values, $id, 'delivered', $hash, $target['platform'], gmdate( 'Y-m-d H:i:s' ) );
		}
		$result = $wpdb->query( $wpdb->prepare( "INSERT IGNORE INTO {$table} (campaign,event,client_hash,platform,occurred_at) VALUES {$placeholders}", ...$values ) );
		if ( false === $result ) return new WP_Error( 'push_metrics_write_failed', 'Please retry later.', array( 'status' => 503 ) );
		return rest_ensure_response( array( 'recorded' => $result > 0, 'deduplicated' => 0 === $result ) );
	}

	/** This hook observes an already-authorized Store API checkout; it cannot create/pay orders. */
	public static function attribute_order( $order, $request ): void {
		try {
			if ( ! $order instanceof WC_Order || ! $request instanceof WP_REST_Request || self::VERSION !== get_option( self::OPTION ) ) return;
			if ( $order->get_meta( '_mobishop_push_campaign' ) ) return;
			$client = self::identifier( $request->get_header( 'X-MobiShop-Push-Client' ) );
			if ( '' === $client || 'mobile' !== $order->get_meta( '_mobishop_order_source' ) ) return;
			global $wpdb; $table = self::table( 'events' ); $hash = hash( 'sha256', $client );
			$campaign = $wpdb->get_var( $wpdb->prepare( "SELECT campaign FROM {$table} WHERE client_hash=%s AND event='opened' AND occurred_at >= %s AND occurred_at <= %s ORDER BY occurred_at DESC,id DESC LIMIT 1", $hash, gmdate( 'Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS ), gmdate( 'Y-m-d H:i:s' ) ) );
			if ( ! $campaign ) return;
			$order->update_meta_data( '_mobishop_push_campaign', $campaign );
			$order->update_meta_data( '_mobishop_push_client_hash', $hash );
		} catch ( Throwable $error ) { /* Analytics must never interrupt checkout. */ }
	}

	public static function sync_order( $order ): void {
		try {
			if ( ! $order instanceof WC_Order ) $order = wc_get_order( $order );
			if ( ! $order instanceof WC_Order || self::VERSION !== get_option( self::OPTION ) ) return;
			$id = (string) $order->get_meta( '_mobishop_push_campaign' );
			if ( '' === $id || ! $order->get_date_created() ) return;
			$client = (string) $order->get_meta( '_mobishop_push_client_hash' );
			$buyer = $order->get_customer_id() > 0 ? 'user:' . $order->get_customer_id() : 'device:' . $client;
			global $wpdb;
			$wpdb->replace( self::table( 'orders' ), array( 'order_id' => $order->get_id(), 'campaign' => $id,
				'client_hash' => $client, 'buyer_hash' => hash( 'sha256', $buyer ), 'currency' => $order->get_currency(),
				'amount' => max( 0, (float) $order->get_total() - (float) $order->get_total_refunded() ),
				'status' => $order->get_status(), 'paid' => $order->get_date_paid() ? 1 : 0,
				'created_at' => gmdate( 'Y-m-d H:i:s', $order->get_date_created()->getTimestamp() ), 'updated_at' => gmdate( 'Y-m-d H:i:s' ) ) );
		} catch ( Throwable $error ) { /* Optional reporting cannot change an order's outcome. */ }
	}

	/** Aggregate only; raw device/customer identifiers never leave this service. */
	public static function report(): array {
		self::install();
		if ( self::VERSION !== get_option( self::OPTION ) ) return array( 'status' => 'unavailable' );
		global $wpdb; $events = self::table( 'events' ); $orders = self::table( 'orders' );
		$campaigns = self::table( 'campaigns' );
		$records = $wpdb->get_results( "SELECT * FROM {$campaigns} ORDER BY created_at DESC,id DESC LIMIT 1001", ARRAY_A );
		if ( ! is_array( $records ) ) return array( 'status' => 'unavailable' );
		$meta = array( 'status' => 'ready', 'version' => 2, 'started_at' => (int) get_option( 'mobishop_push_analytics_started_at', 0 ),
			'conversion_supported' => true, 'attribution_days' => 7, 'receipt_coverage' => 'foreground_and_open', 'truncated' => count( $records ) > 1000 );
		$records = array_slice( $records, 0, 1000 );
		if ( ! $records ) return array_merge( $meta, array( 'campaigns' => array() ) );
		$rows = array_column( $records, null, 'id' );
		$campaign_scope = $wpdb->prepare( 'campaign IN ('.implode( ',', array_fill( 0, count( $rows ), '%s' ) ).')', ...array_keys( $rows ) );
		$counts = $wpdb->get_results( "SELECT campaign,event,platform,COUNT(*) AS total FROM {$events} WHERE {$campaign_scope} GROUP BY campaign,event,platform", ARRAY_A );
		if ( ! is_array( $counts ) ) return array( 'status' => 'unavailable' );
		foreach ( $rows as &$row ) { foreach ( array( 'sent', 'failed', 'created_at' ) as $key ) $row[ $key ] = (int) $row[ $key ]; $row['targeted'] = 0; $row['received'] = 0; $row['opened'] = 0; $row['orders'] = 0; $row['buyers'] = 0; $row['paid_orders'] = 0; $row['revenue'] = array(); $row['platforms'] = array(); } unset( $row );
		foreach ( (array) $counts as $count ) {
			$id = $count['campaign']; if ( ! isset( $rows[ $id ] ) ) continue;
			$key = array( 'target' => 'targeted', 'delivered' => 'received', 'opened' => 'opened' )[ $count['event'] ] ?? null;
			if ( null === $key ) continue;
			$rows[ $id ][ $key ] += (int) $count['total'];
			$rows[ $id ]['platforms'][ $count['platform'] ][ $key ] = (int) $count['total'];
		}
		$commerce = $wpdb->get_results( "SELECT campaign,currency,COUNT(*) AS orders,COUNT(DISTINCT buyer_hash) AS buyers,SUM(paid) AS paid_orders,SUM(amount) AS revenue FROM {$orders} WHERE {$campaign_scope} AND status IN ('processing','completed','on-hold') GROUP BY campaign,currency", ARRAY_A );
		if ( ! is_array( $commerce ) ) return array( 'status' => 'unavailable' );
		foreach ( (array) $commerce as $item ) {
			$id = $item['campaign']; if ( ! isset( $rows[ $id ] ) ) continue;
			foreach ( array( 'orders', 'paid_orders' ) as $key ) $rows[ $id ][ $key ] += (int) $item[ $key ];
			$rows[ $id ]['revenue'][ $item['currency'] ] = (string) $item['revenue'];
		}
		$buyers = $wpdb->get_results( "SELECT campaign,COUNT(DISTINCT buyer_hash) AS buyers FROM {$orders} WHERE {$campaign_scope} AND status IN ('processing','completed','on-hold') GROUP BY campaign", ARRAY_A );
		if ( ! is_array( $buyers ) ) return array( 'status' => 'unavailable' );
		foreach ( (array) $buyers as $item ) if ( isset( $rows[ $item['campaign'] ] ) ) $rows[ $item['campaign'] ]['buyers'] = (int) $item['buyers'];
		return array_merge( $meta, array( 'campaigns' => array_values( $rows ) ) );
	}
}
