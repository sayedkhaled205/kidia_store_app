<?php
/**
 * Abandoned-cart recovery coupons, push delivery and revenue attribution.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Recovery_Campaigns {

	private const DB_VERSION = '1';
	private const DB_OPTION  = 'mobishop_recovery_db_version';

	public function register(): void {
		add_action( 'init', array( $this, 'maybe_install' ), 4 );
		add_action( 'admin_post_mobishop_create_recovery_campaign', array( $this, 'create_campaign' ) );
		add_action( 'mobishop_dispatch_recovery_push', array( $this, 'dispatch_scheduled' ), 10, 2 );
		add_action( 'woocommerce_payment_complete', array( $this, 'attribute_order' ) );
		add_action( 'woocommerce_order_status_processing', array( $this, 'attribute_order' ) );
		add_action( 'woocommerce_order_status_completed', array( $this, 'attribute_order' ) );
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
	}

	public function maybe_install(): void {
		if ( self::DB_VERSION === (string) get_option( self::DB_OPTION, '' ) ) {
			return;
		}
		global $wpdb;
		require_once ABSPATH . 'wp-admin/includes/upgrade.php';
		$table   = self::table();
		$charset = $wpdb->get_charset_collate();
		dbDelta(
			"CREATE TABLE {$table} (
				id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
				group_id varchar(36) NOT NULL,
				tracking_token varchar(36) NOT NULL,
				cart_id bigint(20) unsigned NOT NULL,
				cart_key varchar(64) NOT NULL,
				source varchar(12) NOT NULL,
				user_id bigint(20) unsigned NOT NULL DEFAULT 0,
				customer_email varchar(191) NOT NULL DEFAULT '',
				coupon_id bigint(20) unsigned NOT NULL DEFAULT 0,
				coupon_code varchar(100) NOT NULL DEFAULT '',
				discount_type varchar(20) NOT NULL,
				discount_value decimal(20,6) NOT NULL DEFAULT 0,
				status varchar(20) NOT NULL DEFAULT 'created',
				created_at datetime NOT NULL,
				scheduled_at datetime NULL,
				sent_at datetime NULL,
				opened_at datetime NULL,
				converted_at datetime NULL,
				order_id bigint(20) unsigned NOT NULL DEFAULT 0,
				order_total decimal(20,6) NOT NULL DEFAULT 0,
				discount_total decimal(20,6) NOT NULL DEFAULT 0,
				PRIMARY KEY  (id),
				UNIQUE KEY tracking_token (tracking_token),
				KEY group_id (group_id),
				KEY coupon_code (coupon_code),
				KEY cart_id (cart_id),
				KEY status_created (status, created_at)
			) {$charset};"
		);
		update_option( self::DB_OPTION, self::DB_VERSION, false );
	}

	public function register_routes(): void {
		register_rest_route(
			'mobishop/v1',
			'/recovery/open/(?P<token>[A-Za-z0-9-]{36})',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'record_open' ),
				'permission_callback' => '__return_true',
			)
		);
	}

	public function record_open( WP_REST_Request $request ) {
		$token = sanitize_text_field( (string) $request->get_param( 'token' ) );
		if ( ! preg_match( '/^[a-f0-9-]{36}$/i', $token ) ) {
			return new WP_Error( 'mobishop_recovery_token_invalid', __( 'Invalid recovery tracking token.', 'mobishop' ), array( 'status' => 400 ) );
		}
		global $wpdb;
		$updated = $wpdb->query(
			$wpdb->prepare(
				'UPDATE %i SET opened_at=COALESCE(opened_at,%s), status=IF(status=\'converted\',status,\'opened\') WHERE tracking_token=%s',
				self::table(),
				current_time( 'mysql', true ),
				$token
			)
		);
		return rest_ensure_response( array( 'recorded' => (bool) $updated ) );
	}

	/** Creates one customer-restricted coupon and delivery record per selected cart. */
	public function create_campaign(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to create recovery campaigns.', 'mobishop' ) );
		}
		check_admin_referer( 'mobishop_create_recovery_campaign', 'mobishop_recovery_nonce' );
		$ids = array_values( array_filter( array_map( 'absint', (array) ( $_POST['cart_ids'] ?? array() ) ) ) );
		if ( empty( $ids ) || ! class_exists( 'WC_Coupon' ) ) {
			$this->redirect( 'missing' );
		}

		$carts       = MobiShop_Analytics::carts_by_ids( $ids );
		$type        = sanitize_key( wp_unslash( $_POST['recovery_discount_type'] ?? 'percent' ) );
		$type        = in_array( $type, array( 'percent', 'fixed_cart' ), true ) ? $type : 'percent';
		$value       = max( 0, (float) ( $_POST['recovery_discount_value'] ?? 0 ) );
		$value       = 'percent' === $type ? min( 100, $value ) : $value;
		if ( $value <= 0 ) {
			$this->redirect( 'missing' );
		}
		$hours       = max( 1, min( 720, absint( $_POST['recovery_expiry_hours'] ?? 48 ) ) );
		$minimum     = max( 0, (float) ( $_POST['recovery_minimum_spend'] ?? 0 ) );
		$restrict    = ! empty( $_POST['recovery_restrict_products'] );
		$delivery    = sanitize_key( wp_unslash( $_POST['recovery_delivery'] ?? 'now' ) );
		$scheduled   = null;
		if ( 'scheduled' === $delivery ) {
			$raw = sanitize_text_field( wp_unslash( $_POST['recovery_schedule_at'] ?? '' ) );
			$scheduled = $raw ? strtotime( $raw . ' ' . wp_timezone_string() ) : false;
			if ( ! $scheduled || $scheduled <= time() ) {
				$this->redirect( 'schedule' );
			}
		}
		$title    = sanitize_text_field( wp_unslash( $_POST['recovery_title'] ?? __( 'Your cart is waiting', 'mobishop' ) ) );
		$message  = sanitize_textarea_field( wp_unslash( $_POST['recovery_message'] ?? __( 'Complete your order before your personal offer expires.', 'mobishop' ) ) );
		$default_url = function_exists( 'wc_get_cart_url' ) ? wc_get_cart_url() : home_url( '/' );
		$base_url    = esc_url_raw( wp_unslash( $_POST['recovery_action_url'] ?? $default_url ) );
		$action_style = sanitize_key( wp_unslash( $_POST['recovery_action_style'] ?? 'link' ) );
		$action_style = in_array( $action_style, array( 'link', 'button' ), true ) ? $action_style : 'link';
		$cta_label = 'button' === $action_style
			? mb_substr( sanitize_text_field( wp_unslash( $_POST['recovery_cta_label'] ?? __( 'Complete purchase', 'mobishop' ) ) ), 0, 30 )
			: '';
		$group_id = wp_generate_uuid4();
		$created  = 0;

		foreach ( $carts as $cart ) {
			$email = sanitize_email( (string) $cart['customer_email'] );
			if ( '' === $email ) {
				continue;
			}
			$code = 'MOBISHOP-' . absint( $cart['id'] ) . '-' . strtoupper( wp_generate_password( 6, false, false ) );
			$coupon = new WC_Coupon();
			$coupon->set_code( $code );
			$coupon->set_discount_type( $type );
			$coupon->set_amount( $value );
			$coupon->set_individual_use( true );
			$coupon->set_usage_limit( 1 );
			$coupon->set_usage_limit_per_user( 1 );
			$coupon->set_email_restrictions( array( $email ) );
			$coupon->set_minimum_amount( $minimum );
			$coupon->set_date_expires( time() + $hours * HOUR_IN_SECONDS );
			/* translators: Placeholder values are supplied at runtime. */
			$coupon->set_description( sprintf( __( 'MobiShop abandoned-cart recovery for cart #%d', 'mobishop' ), absint( $cart['id'] ) ) );
			if ( $restrict ) {
				$product_ids = array_values( array_filter( array_map( static fn( $item ) => absint( $item['product_id'] ?? 0 ), (array) $cart['items'] ) ) );
				$coupon->set_product_ids( $product_ids );
			}
			$coupon_id = $coupon->save();
			if ( $coupon_id <= 0 ) {
				continue;
			}
			if ( class_exists( 'MobiShop_Coupon_Channel' ) ) {
				MobiShop_Coupon_Channel::set(
					$coupon_id,
					'mobile' === sanitize_key( (string) $cart['source'] ) ? 'mobile' : 'website'
				);
			}

			$token = wp_generate_uuid4();
			$row = array(
				'group_id'        => $group_id,
				'tracking_token'  => $token,
				'cart_id'         => absint( $cart['id'] ),
				'cart_key'        => sanitize_text_field( (string) $cart['cart_key'] ),
				'source'          => sanitize_key( (string) $cart['source'] ),
				'user_id'         => absint( $cart['user_id'] ),
				'customer_email'  => $email,
				'coupon_id'       => $coupon_id,
				'coupon_code'     => $code,
				'discount_type'   => $type,
				'discount_value'  => $value,
				'status'          => $scheduled ? 'scheduled' : 'created',
				'created_at'      => current_time( 'mysql', true ),
				'scheduled_at'    => $scheduled ? gmdate( 'Y-m-d H:i:s', $scheduled ) : null,
			);
			global $wpdb;
			$wpdb->insert( self::table(), $row );
			$campaign_id = absint( $wpdb->insert_id );
			$payload = array(
				'id'               => wp_generate_uuid4(),
				'type'             => 'abandoned_cart',
				'title'            => mb_substr( $title, 0, 100 ),
				'message'          => mb_substr( str_replace( '{coupon}', $code, $message ), 0, 500 ),
				'coupon'           => $code,
				'audience'         => 'customer',
				'target_user_id'   => absint( $cart['user_id'] ),
				'target_email'     => $email,
				'action_url'       => add_query_arg( array( 'coupon' => $code, 'mobishop_recovery' => $token ), $base_url ),
				'action_style'     => $action_style,
				'cta_label'        => $cta_label,
				'tracking_url'     => rest_url( 'mobishop/v1/recovery/open/' . $token ),
				'recovery_token'   => $token,
				'recovery_cart_id' => absint( $cart['id'] ),
				'created_at'       => time(),
			);
			if ( $scheduled ) {
				wp_schedule_single_event( $scheduled, 'mobishop_dispatch_recovery_push', array( $campaign_id, $payload ) );
			} else {
				$this->dispatch( $campaign_id, $payload );
			}
			++$created;
		}

		$this->redirect( $created > 0 ? 'created' : 'no_email', $created );
	}

	public function dispatch_scheduled( int $campaign_id, array $payload ): void {
		$this->dispatch( $campaign_id, $payload );
	}

	private function dispatch( int $campaign_id, array $payload ): void {
		$payload = class_exists( 'MobiShop_Push_Service' )
			? MobiShop_Push_Service::dispatch( $payload )
			: array_merge( $payload, array( 'sent_at' => time(), 'status' => 'provider_required' ) );
		$campaign_status = 'sent' === (string) ( $payload['status'] ?? '' ) ? 'sent' : (string) ( $payload['status'] ?? 'provider_required' );
		global $wpdb;
		$wpdb->update(
			self::table(),
			array( 'status' => $campaign_status, 'sent_at' => current_time( 'mysql', true ) ),
			array( 'id' => $campaign_id ),
			array( '%s', '%s' ),
			array( '%d' )
		);
		$history = get_option( 'mobishop_push_history', array() );
		$history = is_array( $history ) ? $history : array();
		array_unshift( $history, $payload );
		update_option( 'mobishop_push_history', array_slice( $history, 0, 100 ), false );
	}

	/** Attributes a paid order only when the personal campaign coupon matches its owner. */
	public function attribute_order( $order_or_id ): void {
		$order = $order_or_id instanceof WC_Order ? $order_or_id : ( function_exists( 'wc_get_order' ) ? wc_get_order( absint( $order_or_id ) ) : null );
		if ( ! $order instanceof WC_Order ) {
			return;
		}
		$codes = array_map( 'strtolower', $order->get_coupon_codes() );
		if ( empty( $codes ) ) {
			return;
		}
		global $wpdb;
		$placeholders = implode( ',', array_fill( 0, count( $codes ), '%s' ) );
		$rows = $wpdb->get_results(
			$wpdb->prepare(
				"SELECT * FROM %i WHERE LOWER(coupon_code) IN ({$placeholders})",
				array_merge( array( self::table() ), $codes )
			),
			ARRAY_A
		);
		foreach ( $rows as $row ) {
			$email_matches = strtolower( (string) $row['customer_email'] ) === strtolower( (string) $order->get_billing_email() );
			$user_matches  = absint( $row['user_id'] ) > 0 && absint( $row['user_id'] ) === absint( $order->get_customer_id() );
			if ( ! $email_matches && ! $user_matches ) {
				continue;
			}
			$wpdb->update(
				self::table(),
				array(
					'status'         => 'converted',
					'converted_at'   => current_time( 'mysql', true ),
					'order_id'       => $order->get_id(),
					'order_total'    => (float) $order->get_total(),
					'discount_total' => (float) $order->get_discount_total(),
				),
				array( 'id' => absint( $row['id'] ) ),
				array( '%s', '%s', '%d', '%f', '%f' ),
				array( '%d' )
			);
			$order->update_meta_data( '_mobishop_recovery_campaign_id', absint( $row['id'] ) );
			$order->save();
		}
	}

	/** @return array<string,float|int> */
	public static function stats(): array {
		global $wpdb;
		$row = $wpdb->get_row(
			$wpdb->prepare(
				'SELECT COUNT(*) total, SUM(sent_at IS NOT NULL) sent, SUM(opened_at IS NOT NULL) opened,
				SUM(converted_at IS NOT NULL) converted, COALESCE(SUM(order_total),0) revenue,
				COALESCE(SUM(discount_total),0) discount,
				COALESCE(AVG(CASE WHEN converted_at IS NOT NULL AND sent_at IS NOT NULL
					THEN TIMESTAMPDIFF(SECOND,sent_at,converted_at) END),0) time_to_convert
				FROM %i',
				self::table()
			),
			ARRAY_A
		);
		return array(
			'total'     => absint( $row['total'] ?? 0 ),
			'sent'      => absint( $row['sent'] ?? 0 ),
			'opened'    => absint( $row['opened'] ?? 0 ),
			'converted' => absint( $row['converted'] ?? 0 ),
			'revenue'   => (float) ( $row['revenue'] ?? 0 ),
			'discount'  => (float) ( $row['discount'] ?? 0 ),
			'time_to_convert' => absint( $row['time_to_convert'] ?? 0 ),
		);
	}

	/** @return list<array<string,mixed>> */
	public static function recent( int $limit = 50 ): array {
		global $wpdb;
		return $wpdb->get_results(
			$wpdb->prepare( 'SELECT * FROM %i ORDER BY id DESC LIMIT %d', self::table(), max( 1, min( 100, $limit ) ) ),
			ARRAY_A
		);
	}

	private function redirect( string $result, int $created = 0 ): void {
		wp_safe_redirect(
			add_query_arg(
				array(
					'page'            => 'mobishop-store-data',
					'store_tab'       => 'abandoned-carts',
					'recovery_result' => $result,
					'recovery_count'  => $created,
				),
				admin_url( 'admin.php' )
			)
		);
		exit;
	}

	private static function table(): string {
		global $wpdb;
		return $wpdb->prefix . 'mobishop_recovery_campaigns';
	}
}
