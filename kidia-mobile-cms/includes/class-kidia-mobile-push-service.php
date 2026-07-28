<?php
/**
 * Managed Push device registry, delivery and analytics.
 *
 * Every application receives an isolated Firebase project during the WooMobile
 * build. Provider credentials stay on the platform and never enter WordPress.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Push_Service {

	private const LEGACY_SETTINGS_OPTION = 'kidia_mobile_push_provider_settings';
	private const DEVICES_OPTION  = 'kidia_mobile_push_devices_v1';
	private const METRICS_OPTION  = 'kidia_mobile_push_metrics_v1';
	private const AUTOMATION_LOG  = 'kidia_mobile_push_automation_log_v1';

	public function register(): void {
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
		add_action( 'admin_init', array( $this, 'delete_legacy_credentials' ) );
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

	/** @return array<string,mixed> Public settings embedded in every exported application. */
	public static function client_configuration(): array {
		$status = self::connection_status();
		return array(
			'enabled'              => ! empty( $status['license_active'] ),
			'mode'                 => 'managed',
			'applicationReference' => self::application_reference(),
			'provisionOnBuild'     => true,
			'serverConnected'      => ! empty( $status['license_active'] ),
			'clientReady'          => ! empty( $status['license_active'] ),
			'requiresNativeSetup'  => false,
			'configUrl'            => rest_url( 'woo-mobile/v1/push/config' ),
			'registrationUrl'      => rest_url( 'woo-mobile/v1/push/devices' ),
			'eventsUrl'            => rest_url( 'woo-mobile/v1/push/events' ),
			'openActionContract'   => 'destination + destination_id + action_url',
		);
	}

	/** @return array{connected:bool,license_active:bool,mode:string,label:string,reason:string,devices:int} */
	public static function connection_status(): array {
		$license_active = class_exists( 'Kidia_Mobile_License_Manager' )
			&& ( new Kidia_Mobile_License_Manager() )->is_active();
		$build_state = class_exists( 'Kidia_Mobile_App_Exporter' )
			? Kidia_Mobile_App_Exporter::state()
			: array();
		$connected = $license_active && 'ready' === (string) ( $build_state['status'] ?? 'idle' );
		return array(
			'connected'      => $connected,
			'license_active' => $license_active,
			'mode'           => 'managed',
			'label'          => $connected
				? __( 'Push ready', 'kidia-mobile-cms' )
				: ( $license_active ? __( 'Build app to activate', 'kidia-mobile-cms' ) : __( 'License required', 'kidia-mobile-cms' ) ),
			'reason'         => $connected
				? __( 'WooMobile manages this application connection automatically.', 'kidia-mobile-cms' )
				: ( $license_active
					? __( 'Your private Push connection is created automatically with the first application build.', 'kidia-mobile-cms' )
					: __( 'Activate the WooMobile license, then build the application to enable Push.', 'kidia-mobile-cms' ) ),
			'devices'        => count( self::devices() ),
		);
	}

	/** Removes credentials saved by plugin versions that exposed provider setup. */
	public function delete_legacy_credentials(): void {
		if ( false !== get_option( self::LEGACY_SETTINGS_OPTION, false ) ) {
			delete_option( self::LEGACY_SETTINGS_OPTION );
		}
	}

	public function register_routes(): void {
		register_rest_route(
			'woo-mobile/v1',
			'/push/config',
			array(
				'methods'             => WP_REST_Server::READABLE,
				'callback'            => array( $this, 'public_configuration' ),
				'permission_callback' => '__return_true',
			)
		);
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

	public function public_configuration(): WP_REST_Response {
		return rest_ensure_response( self::client_configuration() );
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

	/** @return array<string,mixed> */
	public static function dispatch( array $payload ): array {
		$status = self::connection_status();
		$payload['sent_at'] = time();
		if ( ! $status['connected'] ) {
			$payload['status'] = empty( $status['license_active'] ) ? 'license_required' : 'build_required';
			$payload['delivery'] = array( 'mode' => 'managed', 'sent' => 0, 'failed' => 0, 'errors' => array( (string) $status['reason'] ) );
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
		if ( empty( $devices ) ) {
			$payload['status'] = 'no_devices';
			$payload['delivery'] = array( 'mode' => 'managed', 'sent' => 0, 'failed' => 0, 'errors' => array() );
			return $payload;
		}
		$result = self::dispatch_managed( $payload, $devices );
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

	/** @return array<string,mixed> */
	private static function dispatch_managed( array $payload, array $devices ): array {
		$targets = array_map(
			static function ( array $device ): array {
				return array(
					'token'    => (string) ( $device['token'] ?? '' ),
					'platform' => (string) ( $device['platform'] ?? 'android' ),
					'locale'   => (string) ( $device['locale'] ?? '' ),
				);
			},
			array_slice( $devices, 0, 500 )
		);
		$request = array(
			'applicationReference' => self::application_reference(),
			'siteUrl'              => home_url( '/' ),
			'notification'         => array(
				'id'          => (string) ( $payload['id'] ?? wp_generate_uuid4() ),
				'title'       => (string) ( $payload['title'] ?? '' ),
				'message'     => (string) ( $payload['message'] ?? '' ),
				'imageUrl'    => (string) ( $payload['image_url'] ?? '' ),
				'priority'    => (string) ( $payload['priority'] ?? 'normal' ),
				'sound'       => ! empty( $payload['sound'] ),
				'badge'       => absint( $payload['badge'] ?? 0 ),
				'expiryHours' => max( 1, min( 168, absint( $payload['expiry_hours'] ?? 24 ) ) ),
				'data'        => self::action_data( $payload ),
			),
			'targets'              => $targets,
		);
		$response = ( new Kidia_Mobile_License_Manager() )->push_service_request( 'notifications', 'POST', $request );
		if ( is_wp_error( $response ) ) {
			return array(
				'mode'   => 'managed',
				'sent'   => 0,
				'failed' => count( $targets ),
				'errors' => array( $response->get_error_message() ),
			);
		}

		$raw = isset( $response['delivery'] ) && is_array( $response['delivery'] )
			? $response['delivery']
			: ( isset( $response['data']['delivery'] ) && is_array( $response['data']['delivery'] )
				? $response['data']['delivery']
				: ( isset( $response['data'] ) && is_array( $response['data'] ) ? $response['data'] : $response ) );
		$accepted = ! empty( $raw['accepted'] );
		$sent     = isset( $raw['sent'] ) ? absint( $raw['sent'] ) : ( $accepted ? count( $targets ) : 0 );
		$failed   = isset( $raw['failed'] ) ? absint( $raw['failed'] ) : max( 0, count( $targets ) - $sent );
		$errors   = isset( $raw['errors'] ) && is_array( $raw['errors'] )
			? array_slice( array_map( 'sanitize_text_field', $raw['errors'] ), 0, 5 )
			: array();
		return array(
			'mode'      => 'managed',
			'requestId' => sanitize_text_field( (string) ( $raw['requestId'] ?? $raw['request_id'] ?? '' ) ),
			'sent'      => min( count( $targets ), $sent ),
			'failed'    => min( count( $targets ), $failed ),
			'errors'    => $errors,
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

	private static function application_reference(): string {
		return 'app_' . substr( hash( 'sha256', strtolower( untrailingslashit( home_url( '/' ) ) ) ), 0, 32 );
	}
}
