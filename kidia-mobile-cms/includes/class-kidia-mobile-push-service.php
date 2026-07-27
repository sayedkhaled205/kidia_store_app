<?php
/**
 * Push provider, device registry and delivery analytics.
 *
 * Supports Firebase Cloud Messaging HTTP v1, OneSignal and a signed webhook.
 * Credentials remain inside WordPress and are never exposed by the REST API.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Push_Service {

	private const SETTINGS_OPTION = 'kidia_mobile_push_provider_settings';
	private const DEVICES_OPTION  = 'kidia_mobile_push_devices_v1';
	private const METRICS_OPTION  = 'kidia_mobile_push_metrics_v1';
	private const AUTOMATION_LOG  = 'kidia_mobile_push_automation_log_v1';

	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
		add_action( 'admin_post_kidia_mobile_save_push_provider', array( $this, 'save_provider' ) );
		add_action( 'kidia_mobile_trigger_push_automation', array( $this, 'trigger_automation' ), 10, 2 );
		add_action( 'kidia_mobile_dispatch_automation_push', array( $this, 'dispatch_automation' ), 10, 2 );
		add_action( 'kidia_mobile_scan_push_automations', array( $this, 'scan_automations' ) );
		add_action( 'user_register', array( $this, 'trigger_welcome' ) );
		add_action( 'transition_post_status', array( $this, 'trigger_new_product' ), 10, 3 );
		add_action( 'woocommerce_product_set_stock_status', array( $this, 'trigger_restock' ), 10, 3 );
		add_action( 'woocommerce_order_status_processing', array( $this, 'suppress_after_purchase' ) );
		add_action( 'woocommerce_order_status_completed', array( $this, 'suppress_after_purchase' ) );
		if ( ! wp_next_scheduled( 'kidia_mobile_scan_push_automations' ) ) {
			wp_schedule_event( time() + 5 * MINUTE_IN_SECONDS, 'hourly', 'kidia_mobile_scan_push_automations' );
		}
	}

	/** @return array<string,mixed> */
	public static function settings(): array {
		$defaults = array(
			'provider'           => 'none',
			'onesignal_app_id'   => '',
			'onesignal_api_key'  => '',
			'fcm_project_id'     => '',
			'fcm_client_email'   => '',
			'fcm_private_key'    => '',
			'webhook_url'        => '',
			'webhook_secret'     => '',
		);
		$saved = get_option( self::SETTINGS_OPTION, array() );
		return array_merge( $defaults, is_array( $saved ) ? $saved : array() );
	}

	/** @return array{connected:bool,provider:string,label:string,reason:string,devices:int} */
	public static function connection_status(): array {
		$settings = self::settings();
		$provider = sanitize_key( (string) $settings['provider'] );
		$connected = false;
		if ( 'onesignal' === $provider ) {
			$connected = '' !== trim( (string) $settings['onesignal_app_id'] )
				&& '' !== trim( (string) $settings['onesignal_api_key'] );
		} elseif ( 'fcm' === $provider ) {
			$connected = '' !== trim( (string) $settings['fcm_project_id'] )
				&& is_email( (string) $settings['fcm_client_email'] )
				&& str_contains( (string) $settings['fcm_private_key'], 'BEGIN PRIVATE KEY' );
		} elseif ( 'webhook' === $provider ) {
			$connected = (bool) wp_http_validate_url( (string) $settings['webhook_url'] );
		}
		$labels = array(
			'none'      => __( 'Not configured', 'kidia-mobile-cms' ),
			'fcm'       => __( 'Firebase Cloud Messaging', 'kidia-mobile-cms' ),
			'onesignal' => __( 'OneSignal', 'kidia-mobile-cms' ),
			'webhook'   => __( 'Signed webhook', 'kidia-mobile-cms' ),
		);
		return array(
			'connected' => $connected,
			'provider'  => $provider,
			'label'     => $labels[ $provider ] ?? $labels['none'],
			'reason'    => $connected
				? __( 'Provider credentials are configured. Send a test notification before publishing automations.', 'kidia-mobile-cms' )
				: __( 'Choose a provider and save valid credentials. Messages remain drafts until delivery is connected.', 'kidia-mobile-cms' ),
			'devices'   => count( self::devices() ),
		);
	}

	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/push/devices',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'register_device' ),
				'permission_callback' => '__return_true',
			)
		);
		register_rest_route(
			'woo-mobile/v1',
			'/push/events',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( $this, 'record_event' ),
				'permission_callback' => '__return_true',
			)
		);
	}

	public function register_device( WP_REST_Request $request ) {
		$token = trim( sanitize_text_field( (string) $request->get_param( 'token' ) ) );
		if ( strlen( $token ) < 16 || strlen( $token ) > 4096 ) {
			return new WP_Error( 'kidia_push_token_invalid', __( 'A valid device token is required.', 'kidia-mobile-cms' ), array( 'status' => 400 ) );
		}
		$platform = sanitize_key( (string) $request->get_param( 'platform' ) );
		$platform = in_array( $platform, array( 'android', 'ios', 'web' ), true ) ? $platform : 'android';
		$devices = self::devices();
		$key = hash( 'sha256', $token );
		$devices[ $key ] = array(
			'token'       => $token,
			'platform'    => $platform,
			'user_id'     => get_current_user_id(),
			'client_id'   => sanitize_text_field( (string) $request->get_param( 'client_id' ) ),
			'locale'      => sanitize_key( (string) $request->get_param( 'locale' ) ),
			'enabled'     => true,
			'test'        => rest_sanitize_boolean( $request->get_param( 'test' ) ),
			'updated_at'  => time(),
		);
		update_option( self::DEVICES_OPTION, array_slice( $devices, -5000, null, true ), false );
		update_option( 'kidia_mobile_push_registered_devices', count( $devices ), false );
		return rest_ensure_response( array( 'registered' => true, 'device_id' => $key ) );
	}

	public function record_event( WP_REST_Request $request ) {
		$notification_id = sanitize_text_field( (string) $request->get_param( 'notification_id' ) );
		$event = sanitize_key( (string) $request->get_param( 'event' ) );
		if ( '' === $notification_id || ! in_array( $event, array( 'delivered', 'opened', 'converted' ), true ) ) {
			return new WP_Error( 'kidia_push_event_invalid', __( 'A valid notification event is required.', 'kidia-mobile-cms' ), array( 'status' => 400 ) );
		}
		$metrics = get_option( self::METRICS_OPTION, array() );
		$metrics = is_array( $metrics ) ? $metrics : array();
		$row = is_array( $metrics[ $notification_id ] ?? null ) ? $metrics[ $notification_id ] : array();
		$row[ $event ] = absint( $row[ $event ] ?? 0 ) + 1;
		$row['updated_at'] = time();
		$metrics[ $notification_id ] = $row;
		update_option( self::METRICS_OPTION, array_slice( $metrics, -1000, null, true ), false );
		return rest_ensure_response( array( 'recorded' => true ) );
	}

	public function save_provider(): void {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'You do not have permission to configure push delivery.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_save_push_provider', 'kidia_mobile_push_provider_nonce' );
		$raw = isset( $_POST['push_provider'] ) && is_array( $_POST['push_provider'] )
			? wp_unslash( $_POST['push_provider'] )
			: array();
		$provider = sanitize_key( (string) ( $raw['provider'] ?? 'none' ) );
		$provider = in_array( $provider, array( 'none', 'fcm', 'onesignal', 'webhook' ), true ) ? $provider : 'none';
		$current = self::settings();
		$clean = array(
			'provider'          => $provider,
			'onesignal_app_id'  => sanitize_text_field( (string) ( $raw['onesignal_app_id'] ?? '' ) ),
			'onesignal_api_key' => $this->secret_or_existing( $raw['onesignal_api_key'] ?? '', $current['onesignal_api_key'] ),
			'fcm_project_id'    => sanitize_key( (string) ( $raw['fcm_project_id'] ?? '' ) ),
			'fcm_client_email'  => sanitize_email( (string) ( $raw['fcm_client_email'] ?? '' ) ),
			'fcm_private_key'   => $this->secret_or_existing( $raw['fcm_private_key'] ?? '', $current['fcm_private_key'] ),
			'webhook_url'       => esc_url_raw( (string) ( $raw['webhook_url'] ?? '' ) ),
			'webhook_secret'    => $this->secret_or_existing( $raw['webhook_secret'] ?? '', $current['webhook_secret'] ),
		);
		update_option( self::SETTINGS_OPTION, $clean, false );
		wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-push-notifications', 'provider_saved' => '1' ), admin_url( 'admin.php' ) ) );
		exit;
	}

	/** @return array<string,mixed> */
	public static function dispatch( array $payload ): array {
		$status = self::connection_status();
		$payload['sent_at'] = time();
		if ( ! $status['connected'] ) {
			$payload['status'] = 'provider_required';
			$payload['delivery'] = array( 'provider' => $status['provider'], 'sent' => 0, 'failed' => 0 );
			return $payload;
		}
		$devices = array_values( array_filter( self::devices(), static fn( $device ) => ! empty( $device['enabled'] ) ) );
		$target_user_id = absint( $payload['target_user_id'] ?? 0 );
		$target_client_id = sanitize_text_field( (string) ( $payload['target_client_id'] ?? '' ) );
		if ( $target_user_id > 0 ) {
			$devices = array_values( array_filter( $devices, static fn( $device ) => $target_user_id === absint( $device['user_id'] ?? 0 ) ) );
		} elseif ( '' !== $target_client_id ) {
			$devices = array_values( array_filter( $devices, static fn( $device ) => $target_client_id === (string) ( $device['client_id'] ?? '' ) ) );
		}
		if ( 'test' === (string) ( $payload['audience'] ?? '' ) ) {
			$devices = array_values( array_filter( $devices, static fn( $device ) => ! empty( $device['test'] ) ) );
		}
		if ( empty( $devices ) && 'webhook' !== $status['provider'] ) {
			$payload['status'] = 'no_devices';
			$payload['delivery'] = array( 'provider' => $status['provider'], 'sent' => 0, 'failed' => 0 );
			return $payload;
		}
		$result = array( 'sent' => 0, 'failed' => 0, 'provider' => $status['provider'], 'errors' => array() );
		if ( 'onesignal' === $status['provider'] ) {
			$result = self::dispatch_onesignal( $payload, $devices );
		} elseif ( 'fcm' === $status['provider'] ) {
			$result = self::dispatch_fcm( $payload, $devices );
		} elseif ( 'webhook' === $status['provider'] ) {
			$result = self::dispatch_webhook( $payload );
		}
		$payload['delivery'] = $result;
		$payload['status'] = $result['sent'] > 0 ? 'sent' : 'failed';
		$metrics = get_option( self::METRICS_OPTION, array() );
		$metrics = is_array( $metrics ) ? $metrics : array();
		$metrics[ (string) ( $payload['id'] ?? wp_generate_uuid4() ) ] = array(
			'sent'       => absint( $result['sent'] ),
			'delivered'  => 0,
			'opened'     => 0,
			'converted'  => 0,
			'updated_at' => time(),
		);
		update_option( self::METRICS_OPTION, array_slice( $metrics, -1000, null, true ), false );
		return $payload;
	}

	/**
	 * Schedules a reviewed automation for a concrete store event.
	 *
	 * App and store integrations can emit:
	 * do_action( 'kidia_mobile_trigger_push_automation', $trigger, $context ).
	 *
	 * @param array<string,mixed> $context Target user/client and destination context.
	 */
	public function trigger_automation( string $trigger, array $context = array() ): void {
		$trigger = sanitize_key( $trigger );
		$automations = get_option( 'kidia_mobile_push_automations', array() );
		$payload = is_array( $automations ) && is_array( $automations[ $trigger ] ?? null )
			? $automations[ $trigger ]
			: null;
		if ( ! is_array( $payload ) || empty( $payload['automation']['enabled'] ) ) {
			return;
		}
		$target_key = absint( $context['target_user_id'] ?? 0 ) > 0
			? 'user:' . absint( $context['target_user_id'] )
			: 'client:' . sanitize_key( (string) ( $context['target_client_id'] ?? 'anonymous' ) );
		$log = get_option( self::AUTOMATION_LOG, array() );
		$log = is_array( $log ) ? $log : array();
		$log_key = $trigger . ':' . $target_key;
		$entry = is_array( $log[ $log_key ] ?? null ) ? $log[ $log_key ] : array( 'count' => 0, 'last' => 0 );
		$cooldown = max( 1, absint( $payload['automation']['cooldown_hours'] ?? 24 ) ) * HOUR_IN_SECONDS;
		$max_sends = max( 1, absint( $payload['automation']['max_sends'] ?? 3 ) );
		if ( absint( $entry['count'] ?? 0 ) >= $max_sends || time() - absint( $entry['last'] ?? 0 ) < $cooldown ) {
			return;
		}
		$delay = min( 43200, absint( $payload['automation']['delay_minutes'] ?? 30 ) ) * MINUTE_IN_SECONDS;
		$when = $this->next_allowed_time( time() + $delay, (array) $payload['automation'] );
		$payload = array_merge( $payload, array_intersect_key( $context, array_flip( array( 'target_user_id', 'target_client_id', 'destination_id', 'action_url', 'coupon' ) ) ) );
		$payload['id'] = wp_generate_uuid4();
		$payload['automation_triggered_at'] = time();
		$payload['status'] = 'automation_scheduled';
		wp_schedule_single_event( $when, 'kidia_mobile_dispatch_automation_push', array( $payload, $log_key ) );
		$entry['count'] = absint( $entry['count'] ?? 0 ) + 1;
		$entry['last'] = time();
		$log[ $log_key ] = $entry;
		update_option( self::AUTOMATION_LOG, array_slice( $log, -5000, null, true ), false );
	}

	/** @param array<string,mixed> $payload */
	public function dispatch_automation( array $payload, string $log_key = '' ): void {
		unset( $log_key );
		$user_id = absint( $payload['target_user_id'] ?? 0 );
		if ( $user_id > 0 && ! empty( $payload['automation']['stop_on_purchase'] ) ) {
			$last_purchase = absint( get_user_meta( $user_id, '_kidia_mobile_last_purchase_at', true ) );
			if ( $last_purchase >= absint( $payload['automation_triggered_at'] ?? 0 ) ) {
				return;
			}
		}
		$payload = self::dispatch( $payload );
		$history = get_option( 'kidia_mobile_push_history', array() );
		$history = is_array( $history ) ? $history : array();
		array_unshift( $history, $payload );
		update_option( 'kidia_mobile_push_history', array_slice( $history, 0, 100 ), false );
	}

	public function trigger_welcome( int $user_id ): void {
		$this->trigger_automation( 'welcome', array( 'target_user_id' => $user_id ) );
	}

	/** Finds newly abandoned carts and feeds them into the guarded automation. */
	public function scan_automations(): void {
		$automations = get_option( 'kidia_mobile_push_automations', array() );
		if ( ! is_array( $automations ) || empty( $automations['abandoned_cart']['automation']['enabled'] ) ) {
			return;
		}
		$carts = Kidia_Mobile_Analytics::abandoned_carts(
			time() - 30 * DAY_IN_SECONDS,
			time(),
			'all',
			250
		);
		foreach ( $carts as $cart ) {
			$user_id = absint( $cart['user_id'] ?? 0 );
			$client_id = sanitize_text_field( (string) ( $cart['client_id'] ?? '' ) );
			if ( $user_id <= 0 && '' === $client_id ) {
				continue;
			}
			$this->trigger_automation(
				'abandoned_cart',
				array(
					'target_user_id'   => $user_id,
					'target_client_id' => $client_id,
					'destination_id'   => absint( $cart['id'] ?? 0 ),
					'action_url'       => function_exists( 'wc_get_cart_url' ) ? wc_get_cart_url() : home_url( '/' ),
				)
			);
		}
	}

	public function trigger_new_product( string $new_status, string $old_status, WP_Post $post ): void {
		if ( 'product' === $post->post_type && 'publish' === $new_status && 'publish' !== $old_status ) {
			$this->trigger_automation( 'new_product', array( 'destination_id' => $post->ID ) );
		}
	}

	public function trigger_restock( int $product_id, string $stock_status, $product = null ): void {
		unset( $product );
		if ( 'instock' === $stock_status ) {
			$this->trigger_automation( 'restock', array( 'destination_id' => $product_id ) );
		}
	}

	public function suppress_after_purchase( int $order_id ): void {
		$order = function_exists( 'wc_get_order' ) ? wc_get_order( $order_id ) : null;
		if ( $order instanceof WC_Order && $order->get_user_id() > 0 ) {
			update_user_meta( $order->get_user_id(), '_kidia_mobile_last_purchase_at', time() );
		}
	}

	/** @param array<string,mixed> $automation */
	private function next_allowed_time( int $timestamp, array $automation ): int {
		$from = preg_match( '/^\d{2}:\d{2}$/', (string) ( $automation['allowed_from'] ?? '' ) ) ? (string) $automation['allowed_from'] : '00:00';
		$to = preg_match( '/^\d{2}:\d{2}$/', (string) ( $automation['allowed_to'] ?? '' ) ) ? (string) $automation['allowed_to'] : '23:59';
		$current = wp_date( 'H:i', $timestamp );
		if ( $current < $from ) {
			return (int) strtotime( wp_date( 'Y-m-d', $timestamp ) . ' ' . $from . ' ' . wp_timezone_string() );
		}
		if ( $current > $to ) {
			return (int) strtotime( '+1 day ' . $from, $timestamp );
		}
		return $timestamp;
	}

	/** @return array<string,mixed> */
	public static function aggregate_metrics(): array {
		$metrics = get_option( self::METRICS_OPTION, array() );
		$totals = array( 'sent' => 0, 'delivered' => 0, 'opened' => 0, 'converted' => 0 );
		foreach ( is_array( $metrics ) ? $metrics : array() as $row ) {
			foreach ( array_keys( $totals ) as $key ) {
				$totals[ $key ] += absint( $row[ $key ] ?? 0 );
			}
		}
		return $totals;
	}

	/** @return array<string,array<string,mixed>> */
	private static function devices(): array {
		$devices = get_option( self::DEVICES_OPTION, array() );
		return is_array( $devices ) ? $devices : array();
	}

	private function secret_or_existing( $submitted, $existing ): string {
		$value = trim( (string) $submitted );
		return '' === $value ? (string) $existing : $value;
	}

	/** @return array<string,mixed> */
	private static function dispatch_onesignal( array $payload, array $devices ): array {
		$settings = self::settings();
		$body = array(
			'app_id'             => $settings['onesignal_app_id'],
			'include_player_ids' => array_values( array_map( static fn( $device ) => (string) $device['token'], $devices ) ),
			'headings'           => array( 'en' => (string) $payload['title'] ),
			'contents'           => array( 'en' => (string) $payload['message'] ),
			'data'               => self::action_data( $payload ),
		);
		$response = wp_remote_post(
			'https://api.onesignal.com/notifications',
			array(
				'timeout' => 20,
				'headers' => array( 'Authorization' => 'Key ' . $settings['onesignal_api_key'], 'Content-Type' => 'application/json' ),
				'body'    => wp_json_encode( $body ),
			)
		);
		$ok = ! is_wp_error( $response ) && wp_remote_retrieve_response_code( $response ) >= 200 && wp_remote_retrieve_response_code( $response ) < 300;
		return array(
			'provider' => 'onesignal',
			'sent'     => $ok ? count( $devices ) : 0,
			'failed'   => $ok ? 0 : count( $devices ),
			'errors'   => $ok ? array() : array( is_wp_error( $response ) ? $response->get_error_message() : wp_remote_retrieve_body( $response ) ),
		);
	}

	/** @return array<string,mixed> */
	private static function dispatch_fcm( array $payload, array $devices ): array {
		$settings = self::settings();
		$token = self::fcm_access_token( $settings );
		if ( is_wp_error( $token ) ) {
			return array( 'provider' => 'fcm', 'sent' => 0, 'failed' => count( $devices ), 'errors' => array( $token->get_error_message() ) );
		}
		$sent = 0;
		$errors = array();
		foreach ( array_slice( $devices, 0, 500 ) as $device ) {
			$body = array(
				'message' => array(
					'token'        => (string) $device['token'],
					'notification' => array( 'title' => (string) $payload['title'], 'body' => (string) $payload['message'] ),
					'data'         => array_map( 'strval', self::action_data( $payload ) ),
					'android'      => array( 'priority' => 'high' === ( $payload['priority'] ?? 'normal' ) ? 'HIGH' : 'NORMAL' ),
				),
			);
			$response = wp_remote_post(
				'https://fcm.googleapis.com/v1/projects/' . rawurlencode( (string) $settings['fcm_project_id'] ) . '/messages:send',
				array(
					'timeout' => 15,
					'headers' => array( 'Authorization' => 'Bearer ' . $token, 'Content-Type' => 'application/json' ),
					'body'    => wp_json_encode( $body ),
				)
			);
			$ok = ! is_wp_error( $response ) && 200 === wp_remote_retrieve_response_code( $response );
			if ( $ok ) {
				++$sent;
			} elseif ( count( $errors ) < 5 ) {
				$errors[] = is_wp_error( $response ) ? $response->get_error_message() : wp_remote_retrieve_body( $response );
			}
		}
		return array( 'provider' => 'fcm', 'sent' => $sent, 'failed' => count( $devices ) - $sent, 'errors' => $errors );
	}

	private static function fcm_access_token( array $settings ) {
		$cached = get_transient( 'kidia_mobile_fcm_access_token' );
		if ( is_string( $cached ) && '' !== $cached ) {
			return $cached;
		}
		$now = time();
		$header = self::base64url( wp_json_encode( array( 'alg' => 'RS256', 'typ' => 'JWT' ) ) );
		$claims = self::base64url(
			wp_json_encode(
				array(
					'iss'   => $settings['fcm_client_email'],
					'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
					'aud'   => 'https://oauth2.googleapis.com/token',
					'iat'   => $now,
					'exp'   => $now + 3600,
				)
			)
		);
		$unsigned = $header . '.' . $claims;
		$signature = '';
		if ( ! function_exists( 'openssl_sign' ) || ! openssl_sign( $unsigned, $signature, (string) $settings['fcm_private_key'], OPENSSL_ALGO_SHA256 ) ) {
			return new WP_Error( 'kidia_fcm_key_invalid', __( 'Firebase private key could not sign the access request.', 'kidia-mobile-cms' ) );
		}
		$response = wp_remote_post(
			'https://oauth2.googleapis.com/token',
			array(
				'timeout' => 20,
				'body'    => array(
					'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
					'assertion'  => $unsigned . '.' . self::base64url( $signature ),
				),
			)
		);
		if ( is_wp_error( $response ) || 200 !== wp_remote_retrieve_response_code( $response ) ) {
			return new WP_Error( 'kidia_fcm_auth_failed', __( 'Firebase authentication failed. Check the service-account fields.', 'kidia-mobile-cms' ) );
		}
		$data = json_decode( wp_remote_retrieve_body( $response ), true );
		$token = sanitize_text_field( (string) ( $data['access_token'] ?? '' ) );
		if ( '' === $token ) {
			return new WP_Error( 'kidia_fcm_token_missing', __( 'Firebase did not return an access token.', 'kidia-mobile-cms' ) );
		}
		set_transient( 'kidia_mobile_fcm_access_token', $token, max( 60, absint( $data['expires_in'] ?? 3600 ) - 120 ) );
		return $token;
	}

	/** @return array<string,mixed> */
	private static function dispatch_webhook( array $payload ): array {
		$settings = self::settings();
		$body = wp_json_encode( array( 'event' => 'kidia.push.send', 'payload' => $payload ) );
		$response = wp_remote_post(
			(string) $settings['webhook_url'],
			array(
				'timeout' => 20,
				'headers' => array(
					'Content-Type'      => 'application/json',
					'X-Kidia-Signature' => hash_hmac( 'sha256', (string) $body, (string) $settings['webhook_secret'] ),
				),
				'body' => $body,
			)
		);
		$ok = ! is_wp_error( $response ) && wp_remote_retrieve_response_code( $response ) >= 200 && wp_remote_retrieve_response_code( $response ) < 300;
		return array(
			'provider' => 'webhook',
			'sent'     => $ok ? 1 : 0,
			'failed'   => $ok ? 0 : 1,
			'errors'   => $ok ? array() : array( is_wp_error( $response ) ? $response->get_error_message() : wp_remote_retrieve_body( $response ) ),
		);
	}

	/** @return array<string,string|int> */
	private static function action_data( array $payload ): array {
		return array(
			'notification_id' => (string) ( $payload['id'] ?? '' ),
			'destination'     => (string) ( $payload['destination'] ?? 'home' ),
			'destination_id'  => (string) ( $payload['destination_id'] ?? '' ),
			'action_url'      => (string) ( $payload['action_url'] ?? '' ),
			'coupon'          => (string) ( $payload['coupon'] ?? '' ),
			'cta_label'       => (string) ( $payload['cta_label'] ?? '' ),
		);
	}

	private static function base64url( string $value ): string {
		return rtrim( strtr( base64_encode( $value ), '+/', '-_' ), '=' );
	}
}
