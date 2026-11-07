<?php
/** Authenticated self-deletion. Orders required for fulfilment/accounting remain. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Customer_Account_Deletion {
	private const INTENT = 'mobishop_deletion_intent_v1_';
	private const PREFIX = 'mobishop_account_deletion_v1_';
	private const HOOK = 'mobishop_delete_customer_batch';
	private const LIMIT = 50;
	private const RECEIPT_PREFIX = 'mobishop_deletion_receipt_v1_';
	private const RECEIPT_CURSOR = 'mobishop_deletion_receipt_cursor_v1';
	private const RECEIPT_TTL = 2592000;
	private const RECEIPT_CLEANUP = 'mobishop_cleanup_deletion_receipts';
	private const MAX_STEPS = 10;
	private const STEP_BUDGET = 2;
	private MobiShop_Customer_Auth_Endpoint $auth;

	public function __construct() { $this->auth = new MobiShop_Customer_Auth_Endpoint(); }
	public function register(): void {
		add_filter( 'cron_schedules', static function ( array $schedules ): array {
			$schedules['mobishop_deletion_minute'] = array( 'interval' => 60, 'display' => 'MobiShop account deletion' );
			return $schedules;
		} );
		add_action( 'rest_api_init', array( $this, 'register_routes' ) );
		add_action( self::HOOK, array( self::class, 'run_worker' ) );
		add_action( self::RECEIPT_CLEANUP, array( self::class, 'cleanup_receipts' ) );
		if ( ! wp_next_scheduled( self::RECEIPT_CLEANUP, array() ) ) wp_schedule_event( time() + 60, 'mobishop_deletion_minute', self::RECEIPT_CLEANUP, array() );
		add_filter( 'wp_authenticate_user', array( self::class, 'deny_pending_login' ), 99 );
		add_filter( 'determine_current_user', array( self::class, 'deny_pending_cookie' ), 99 );
	}
	public function register_routes(): void {
		foreach ( array( 'prepare' => 'prepare_deletion', 'apple-proof' => 'approve_apple', 'finalize' => 'finalize_deletion' ) as $path => $method ) register_rest_route( 'mobishop/v1', '/customer/account/deletion/' . $path, array( 'methods' => 'POST', 'callback' => array( $this, $method ), 'permission_callback' => array( $this->auth, 'authenticate_route' ) ) );
		register_rest_route( 'mobishop/v1', '/customer/account/deletion', array(
			array( 'methods' => 'GET', 'callback' => array( $this, 'availability' ), 'permission_callback' => array( $this->auth, 'authenticate_route' ) ),
			array( 'methods' => 'POST', 'callback' => array( $this, 'request_deletion' ), 'permission_callback' => array( $this->auth, 'authenticate_route' ) ),
		) );
		register_rest_route( 'mobishop/v1', '/customer/account/deletion/status', array(
			array( 'methods' => 'POST', 'callback' => array( $this, 'deletion_status' ), 'permission_callback' => '__return_true' ),
		) );
	}
	public function deletion_status( WP_REST_Request $request ) {
		if ( ! is_ssl() ) return self::error( 'https', 400 );
		$body = $request->get_json_params();
		$receipt = is_array( $body ) ? ( $body['receipt'] ?? '' ) : '';
		if ( ! self::valid_receipt( $receipt ) ) return self::response( array( 'status' => 'unknown' ) );
		try {
			$hash = self::receipt_hash( $receipt );
			$record = self::receipt_record( $hash );
			$intent = self::intent( $hash );
			$status = $intent && self::retain_intent( $intent ) ? 'prepared' : 'unknown';
			if ( $record ) {
				$job = self::job( (int) $record['userId'] );
				if ( $job && ( $job['receiptHash'] ?? '' ) === $hash && (int) $job['phase'] >= 0 ) $status = 'pending';
				else {
					// Completion is saved before job removal; do not use a stale prepared receipt.
					$record = self::receipt_record( $hash );
					if ( $record && 'completed' === $record['status'] && $record['expires'] > time() ) $status = 'completed';
				}
			}
			return self::response( array( 'status' => $status ) );
		} catch ( Throwable $error ) { return self::error( 'status_unavailable', 503 ); }
	}
	public function availability( WP_REST_Request $request ) {
		$auth = $this->auth->authenticate_route( $request );
		if ( is_wp_error( $auth ) ) return $auth;
		$user = get_user_by( 'id', $this->auth->customer_id_from_request( $request ) );
		return self::response( array( 'available' => self::enabled() && ! is_multisite() && $user instanceof WP_User && self::ordinary_customer( $user ) ) );
	}
	/** Keep rollout closed until external identity erasure and completion receipts are integrated. */
	private static function enabled(): bool {
		return defined( 'MOBISHOP_ACCOUNT_DELETION_ENABLED' ) && true === MOBISHOP_ACCOUNT_DELETION_ENABLED
			&& ( ( class_exists( 'MobiShop_Customer_Identity_Erasure_Stage' ) && class_exists( 'MobiShop_Customer_Identity_Guard' ) ) || ( defined( 'MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY' ) && MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY === true ) );
	}
	public function request_deletion( WP_REST_Request $request ) {
		if ( ! self::enabled() || is_multisite() ) return self::error( 'unavailable', 409 );
		if ( ! is_ssl() ) return self::error( 'https', 400 );
		$body = $request->get_json_params();
		if ( ! is_array( $body ) || 'delete-my-account' !== ( $body['confirmation'] ?? '' ) ) return self::error( 'confirmation', 400 );
		$receipt = $body['receipt'] ?? '';
		if ( ! self::valid_receipt( $receipt ) ) return self::error( 'receipt', 400 );
		$hash = self::receipt_hash( $receipt );
		// No caller-supplied user ID, email or WordPress admin cookie is a target.
		$prepared = 0;
		try {
			$result = $this->auth->begin_self_deletion( $request, 600, static function ( int $id ) use ( &$prepared, $hash, $request, $body ): bool {
				$user = get_user_by( 'id', $id );
				if ( ! $user instanceof WP_User || ! self::ordinary_customer( $user ) ) return false;
				return self::guarded( $id, $hash, static function () use ( $id, &$prepared, $hash, $request, $body ): bool {
				// Fail before revocation: the customer must retain access to resolve
				// an in-flight checkout, including when its ledger cannot be read.
				if ( self::has_pending_payment( $id ) ) return false;
				// Never reset an accepted job or overwrite another account's capability.
				if ( self::job( $id ) ) return false;
				$intent = self::intent( $hash );
				$legacy = defined( 'MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY' ) && MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY === true;
				if ( ! $intent && ! $legacy ) return false;
				if ( $intent ) {
					if ( $intent['userId'] !== $id || ! hash_equals( $intent['binding'], self::binding( $request ) ) || $intent['expires'] < time() ) return false;
					if ( ! ( class_exists( 'MobiShop_Customer_Identity_Erasure_Stage' ) && class_exists( 'MobiShop_Customer_Identity_Guard' ) ) || MobiShop_Customer_Identity_Links::inventory( $id ) !== $intent['inventory'] ) return false;
					if ( $intent['appleRequired'] ) {
						if ( ! $intent['appleApproved'] || ( $body['apple_revoked'] ?? null ) !== true ) return false;
						foreach ( $intent['inventory'] as $link ) if ( $link['provider'] === 'apple' && MobiShop_Customer_Identity_Links::shared( $id, $link ) !== false ) return false;
						foreach ( $intent['identityStage']['entries'] as &$entry ) {
							if ( $entry['provider'] !== 'apple' || $entry['action'] === 'retain_shared' ) continue;
							if ( MobiShop_Customer_Identity_Client::lookup( $entry['project'], $entry['uid'] ) !== array( 'status' => 'absent' ) ) return false;
							$entry['apple_revoked'] = true;
						}
						unset( $entry );
					}
				}
				$record = array( 'userId' => $id, 'status' => 'prepared', 'expires' => time() + self::RECEIPT_TTL );
				if ( ! add_option( self::RECEIPT_PREFIX . $hash, $record, '', false ) ) return false;
				$prepared = $id;
				if ( self::receipt_record( $hash ) !== $record ) throw new RuntimeException( 'Receipt persistence unavailable' );
				self::save( array( 'userId' => $id, 'phase' => -1, 'cursor' => time(), 'receiptHash' => $hash ) + ( $intent ? array( 'identityStage' => $intent['identityStage'], 'identityLinks' => $intent['inventory'] ) : array() ) );
				return self::schedule( $id );
				} );
			} );
			if ( is_wp_error( $result ) ) {
				self::cancel_prepared( $prepared, $hash );
				return $result;
			}
			// Only a VERIFIED session revocation opens the worker's ready barrier.
			$accepted = self::job( $prepared );
			$accepted['phase'] = 0; $accepted['cursor'] = 0;
			self::save( $accepted );
			if ( isset( $accepted['identityLinks'] ) ) MobiShop_Customer_Identity_Guard::accept( $prepared, $hash, $accepted['identityLinks'] );
			$intent = self::intent( $hash );
			if ( $intent ) self::remove_intent( $hash, $intent );
			if ( class_exists( 'WP_Session_Tokens' ) ) WP_Session_Tokens::get_instance( $prepared )->destroy_all();
			// Start only after the response is flushed; the durable cron retry remains authoritative.
			if ( function_exists( 'fastcgi_finish_request' ) ) add_action( 'shutdown', static function () use ( $prepared ): void {
				if ( fastcgi_finish_request() ) self::run_worker( $prepared );
			}, PHP_INT_MAX );
			return self::response( array( 'status' => 'pending', 'user_id' => $prepared ), 202 );
		} catch ( Throwable $error ) {
			self::cancel_prepared( $prepared, $hash );
			return self::error( 'unavailable', 503 );
		}
	}
	/** Caller holds the merchant session lock first; capture under owner then sorted UID locks. */
	private static function guarded( int $id, string $hash, callable $action ) {
		if ( ! class_exists( 'MobiShop_Customer_Identity_Guard' ) ) {
			if ( defined( 'MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY' ) && MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY === true ) return $action();
			throw new RuntimeException( 'Identity guard unavailable' );
		}
		return MobiShop_Customer_Identity_Guard::with_owner( $id, static function () use ( $id, $hash, $action ) {
			$row = self::intent( $hash );
			$current = MobiShop_Customer_Identity_Links::inventory( $id );
			return MobiShop_Customer_Identity_Guard::with_links( array_merge( $current, $row['inventory'] ?? array() ), $action );
		} );
	}
	private static function process_guarded( array &$job ): bool {
		if ( ! isset( $job['identityLinks'] ) ) return self::process( $job ); // Legacy fixtures only; process denies production legacy jobs.
		return MobiShop_Customer_Identity_Guard::with_owner( $job['userId'], static function () use ( &$job ): bool {
			return MobiShop_Customer_Identity_Guard::with_links( $job['identityLinks'], static function () use ( &$job ): bool {
				MobiShop_Customer_Identity_Guard::accept( $job['userId'], $job['receiptHash'], $job['identityLinks'] );
				return self::process( $job );
			} );
		} );
	}
	private static function binding( WP_REST_Request $request ): string {
		$token = trim( (string) $request->get_header( 'x-mobishop-session' ) );
		if ( $token === '' && preg_match( '/^Bearer\s+(.+)$/i', trim( (string) $request->get_header( 'authorization' ) ), $matches ) ) $token = trim( $matches[1] );
		if ( $token === '' ) throw new RuntimeException( 'Missing session binding' );
		return hash_hmac( 'sha256', home_url( '/' ) . '|' . $token, wp_salt( 'auth' ) );
	}
	/** A finalized request may crash before removing its original approved intent. */
	private static function remove_completed_intent( array $job ): void {
		if ( ! isset( $job['identityLinks'] ) ) return;
		$hash = $job['receiptHash'];
		$record = self::intent( $hash );
		if ( $record === null ) return;
		if ( $record['userId'] !== $job['userId'] || $record['inventory'] !== $job['identityLinks'] ) throw new RuntimeException( 'Completed intent owner changed' );
		self::remove_intent( $hash, $record );
		if ( self::raw_option( self::INTENT . $hash ) !== null ) throw new RuntimeException( 'Completed intent cleanup unconfirmed' );
	}
	private static function remove_intent( string $hash, array $record ): void {
		global $wpdb;
		$key = self::INTENT . $hash;
		$removed = $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name = %s AND BINARY option_value = BINARY %s", $key, maybe_serialize( $record ) ) );
		self::clear_option_cache( $key );
		if ( false === $removed ) throw new RuntimeException( 'Intent cleanup unavailable' );
	}
	private static function retain_intent( array $row ): bool {
		// Approval grants a device SDK capability; wall-clock expiry cannot revoke it.
		// Keep its reconciliation snapshot until durable acceptance or explicit reconciliation.
		return $row['appleApproved'] || $row['expires'] >= time();
	}
	private static function intent( string $hash ): ?array {
		$raw = self::raw_option( self::INTENT . $hash );
		if ( $raw === null ) return null;
		$row = maybe_unserialize( $raw );
		if ( ! is_array( $row ) || ! isset( $row['userId'], $row['binding'], $row['expires'], $row['identityStage'], $row['appleRequired'], $row['appleApproved'] ) ) throw new RuntimeException( 'Invalid deletion intent' );
		if ( ! is_string( $row['intentId'] ?? null ) || ! preg_match( '/^[a-f0-9]{64}$/D', $row['intentId'] ) || ! is_int( $row['userId'] ) || $row['userId'] < 1 || ! is_string( $row['binding'] ) || ! preg_match( '/^[a-f0-9]{64}$/D', $row['binding'] )
			|| ! is_int( $row['expires'] ) || ! is_array( $row['identityStage'] ) || ! is_array( $row['inventory'] ?? null ) || ! is_bool( $row['appleRequired'] ) || ! is_bool( $row['appleApproved'] ) ) throw new RuntimeException( 'Invalid deletion intent values' );
		$apple = false;
		foreach ( ( $row['identityStage']['entries'] ?? array() ) as $link ) if ( ( $link['provider'] ?? '' ) === 'apple' && ( $link['action'] ?? '' ) !== 'retain_shared' ) $apple = true;
		if ( $row['appleApproved'] && ( ! is_int( $row['approvedAt'] ?? null ) || $row['approvedAt'] <= 0 || $row['approvedAt'] > time() ) ) throw new RuntimeException( 'Invalid approved recovery window' );
		if ( $apple !== $row['appleRequired'] ) throw new RuntimeException( 'Invalid Apple intent flag' );
		return $row;
	}
	private function intent_operation( WP_REST_Request $request, callable $action ) {
		if ( ! self::enabled() || is_multisite() || ! class_exists( 'MobiShop_Customer_Identity_Erasure_Stage' ) ) return self::error( 'unavailable', 409 );
		$body = $request->get_json_params();
		if ( ! is_array( $body ) || ! self::valid_receipt( $body['receipt'] ?? '' ) ) return self::error( 'receipt', 400 );
		try {
			$hash = self::receipt_hash( $body['receipt'] );
			$response = null;
			$result = $this->auth->begin_self_deletion( $request, 600, static function ( int $id ) use ( $request, $body, $hash, $action, &$response ): bool {
				$user = get_user_by( 'id', $id );
				if ( ! $user instanceof WP_User || ! self::ordinary_customer( $user ) ) return false;
				if ( self::has_pending_payment( $id ) || self::job( $id ) ) return false;
				$response = self::guarded( $id, $hash, static fn() => $action( $id, $hash, self::binding( $request ), $body ) );
				return $response instanceof WP_REST_Response;
			}, false );
			return is_wp_error( $result ) ? $result : $response;
		} catch ( Throwable $error ) { return self::error( 'intent_unavailable', 503 ); }
	}
	public function prepare_deletion( WP_REST_Request $request ) {
		return $this->intent_operation( $request, static function ( int $id, string $hash, string $binding ): WP_REST_Response {
			$row = self::intent( $hash );
			if ( $row === null ) {
				if ( self::receipt_record( $hash ) ) throw new RuntimeException( 'Receipt already used' );
				$inventory = MobiShop_Customer_Identity_Links::inventory( $id );
				$stage = MobiShop_Customer_Identity_Erasure_Stage::prepare( $id );
				if ( ! is_array( $stage ) ) throw new RuntimeException( 'Invalid identity snapshot' );
				$apple = false;
				foreach ( $stage['entries'] as $link ) if ( $link['provider'] === 'apple' && $link['action'] !== 'retain_shared' ) $apple = true;
				$row = array( 'intentId' => bin2hex( random_bytes( 32 ) ), 'userId' => $id, 'binding' => $binding, 'expires' => time() + 600, 'identityStage' => $stage, 'inventory' => $inventory, 'appleRequired' => $apple, 'appleApproved' => false );
				$inserted = false;
				try {
					MobiShop_Customer_Identity_Guard::reserve( $id, $hash, $inventory, $row['expires'] );
					$inserted = add_option( self::INTENT . $hash, $row, '', false );
					if ( ! $inserted || self::intent( $hash ) !== $row ) throw new RuntimeException( 'Intent save unavailable' );
				} catch ( Throwable $error ) {
					// A stored intent may need reconciliation; never free an uncertain durable claim.
					if ( ! $inserted ) MobiShop_Customer_Identity_Guard::release( $id, $hash, $inventory );
					throw $error;
				}
			}
			if ( $row['userId'] !== $id ) throw new RuntimeException( 'Intent owner changed' );
			if ( ! hash_equals( $row['binding'], $binding ) || $row['expires'] < time() ) {
				// begin_self_deletion already verified this owner's fresh merchant session.
				// Preserve approved evidence after SDK deletion: a replacement Firebase proof may be impossible.
				if ( $row['appleApproved'] && ( MobiShop_Customer_Identity_Links::inventory( $id ) !== $row['inventory'] ) ) throw new RuntimeException( 'Approved recovery unavailable' );
				$next = $row;
				if ( ! $row['appleApproved'] ) {
					$next['inventory'] = MobiShop_Customer_Identity_Links::inventory( $id );
					$next['identityStage'] = MobiShop_Customer_Identity_Erasure_Stage::prepare( $id );
					$next['appleRequired'] = false;
					foreach ( $next['identityStage']['entries'] as $link ) if ( $link['provider'] === 'apple' && $link['action'] !== 'retain_shared' ) $next['appleRequired'] = true;
				}
				$next['binding'] = $binding;
				$next['expires'] = time() + 600;
				if ( ! self::cas( self::INTENT . $hash, maybe_serialize( $row ), maybe_serialize( $next ) ) ) throw new RuntimeException( 'Intent changed during recovery' );
				$row = $next;
			}
			// Repair a cleanup crash after prepared reservations were released but before intent removal.
			if ( ! $row['appleApproved'] ) MobiShop_Customer_Identity_Guard::reserve( $id, $hash, $row['inventory'], $row['expires'] );
			return self::response( array( 'status' => 'prepared', 'intent_id' => $row['intentId'], 'user_id' => $id, 'apple_revocation_required' => $row['appleRequired'] ) );
		} );
	}
	public function approve_apple( WP_REST_Request $request ) {
		return $this->intent_operation( $request, static function ( int $id, string $hash, string $binding ) use ( $request ): WP_REST_Response {
			$row = self::intent( $hash );
			if ( ! $row || $row['userId'] !== $id || ! hash_equals( $row['binding'], $binding ) || $row['expires'] < time() || ! $row['appleRequired'] || $request->get_param( 'platform' ) !== 'ios' ) throw new RuntimeException( 'Invalid Apple intent' );
			if ( MobiShop_Customer_Identity_Links::inventory( $id ) !== $row['inventory'] ) throw new RuntimeException( 'Identity snapshot changed' );
			$auth = new MobiShop_Native_Customer_Auth_Endpoint( static fn() => null, static fn( $user ) => $user instanceof WP_User && self::ordinary_customer( $user ) );
			if ( $auth->validate_deletion_apple_proof( $request, $id ) !== true ) throw new RuntimeException( 'Invalid Apple proof' );
			$next = $row; $next['appleApproved'] = true;
			if ( ! $row['appleApproved'] ) $next['approvedAt'] = time();
			if ( $next !== $row && ! self::cas( self::INTENT . $hash, maybe_serialize( $row ), maybe_serialize( $next ) ) ) throw new RuntimeException( 'Intent changed' );
			MobiShop_Customer_Identity_Guard::approve( $id, $hash, $row['inventory'] );
			return self::response( array( 'approved' => true ) );
		} );
	}
	public function finalize_deletion( WP_REST_Request $request ) {
		return $this->request_deletion( $request );
	}
	private static function response( array $data, int $status = 200 ): WP_REST_Response {
		$response = new WP_REST_Response( $data, $status );
		$response->header( 'Cache-Control', 'no-store, private, max-age=0' );
		return $response;
	}
	private static function error( string $code, int $status ): WP_Error {
		return new WP_Error( 'mobishop_account_deletion_' . $code, __( 'The account deletion request could not be completed. Please try again.', 'mobi2app-connector' ), array( 'status' => $status ) );
	}
	public static function deny_pending_login( $user ) {
		return $user instanceof WP_User && self::is_pending( $user->ID ) ? self::error( 'pending', 403 ) : $user;
	}
	public static function deny_pending_cookie( $id ) {
		return $id && self::is_pending( (int) $id ) ? 0 : $id;
	}
	public static function is_pending( int $id ): bool {
		try { return null !== self::job( $id ); }
		catch ( Throwable $error ) { return true; } // Database failure is never authorization.
	}
	private static function job( int $id ): ?array {
		$raw = self::raw_option( self::PREFIX . $id );
		if ( null === $raw ) return null;
		$job = maybe_unserialize( $raw );
		if ( ! is_array( $job ) || (int) ( $job['userId'] ?? 0 ) !== $id || ! isset( $job['phase'], $job['cursor'] ) ) throw new RuntimeException( 'Invalid deletion job' );
		return $job;
	}
	private static function raw_option( string $key ): ?string {
		global $wpdb;
		$wpdb->last_error = '';
		$raw = $wpdb->get_var( $wpdb->prepare( "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s LIMIT 1", $key ) );
		if ( $wpdb->last_error ) throw new RuntimeException( 'Option read unavailable' );
		return null === $raw ? null : (string) $raw;
	}
	private static function save( array $job ): void {
		$key = self::PREFIX . (int) $job['userId'];
		$raw = self::raw_option( $key );
		if ( null === $raw ) {
			if ( ! add_option( $key, $job, '', false ) ) throw new RuntimeException( 'Job insert unavailable' );
		} elseif ( ! self::cas( $key, $raw, maybe_serialize( $job ) ) ) {
			throw new RuntimeException( 'Job changed concurrently' );
		}
		if ( self::job( (int) $job['userId'] ) !== $job ) throw new RuntimeException( 'Job verification unavailable' );
	}
	private static function cancel_prepared( int $id, string $hash ): void {
		if ( $id < 1 ) return;
		try {
			$job = self::job( $id );
			if ( $job && -1 === (int) $job['phase'] && ( $job['receiptHash'] ?? '' ) === $hash ) self::remove_job( $job );
			if ( ! self::job( $id ) ) {
				$record = self::receipt_record( $hash );
				if ( $record && (int) $record['userId'] === $id && 'prepared' === $record['status'] ) self::remove_receipt( $hash, $record );
			}
		} catch ( Throwable $error ) { /* The prepared job expires without deleting customer data. */ }
	}
	private static function remove_job( array $job ): void {
		global $wpdb;
		$key = self::PREFIX . (int) $job['userId'];
		$deleted = $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name = %s AND BINARY option_value = BINARY %s", $key, maybe_serialize( $job ) ) );
		self::clear_option_cache( $key );
		if ( false === $deleted ) throw new RuntimeException( 'Job deletion unavailable' );
		if ( 1 === $deleted ) wp_clear_scheduled_hook( self::HOOK, array( (int) $job['userId'] ) );
	}
	private static function clear_option_cache( string $key ): void {
		wp_cache_delete( $key, 'options' );
		wp_cache_delete( 'alloptions', 'options' );
		wp_cache_delete( 'notoptions', 'options' );
	}

	private static function valid_receipt( $value ): bool {
		return is_string( $value ) && (bool) preg_match( '/^[a-f0-9]{64}$/', $value );
	}
	private static function receipt_hash( string $receipt ): string {
		global $wpdb;
		return hash_hmac( 'sha256', home_url( '/' ) . '|' . $wpdb->options . '|' . $receipt, wp_salt( 'auth' ) );
	}
	private static function receipt_record( string $hash ): ?array {
		$raw = self::raw_option( self::RECEIPT_PREFIX . $hash );
		if ( null === $raw ) return null;
		$value = maybe_unserialize( $raw );
		if ( ! is_array( $value ) || ! isset( $value['userId'], $value['status'], $value['expires'] ) || (int) $value['userId'] < 1 || ! in_array( $value['status'], array( 'prepared', 'completed' ), true ) ) throw new RuntimeException( 'Invalid receipt' );
		return $value;
	}
	private static function remove_receipt( string $hash, array $record ): void {
		global $wpdb;
		$key = self::RECEIPT_PREFIX . $hash;
		$removed = $wpdb->query( $wpdb->prepare( "DELETE FROM {$wpdb->options} WHERE option_name = %s AND BINARY option_value = BINARY %s", $key, maybe_serialize( $record ) ) );
		self::clear_option_cache( $key );
		if ( false === $removed ) throw new RuntimeException( 'Receipt cleanup unavailable' );
	}
	/** Keyset pagination prevents the first live receipts from starving older results. */
	public static function cleanup_receipts(): void {
		self::cleanup_intents();
		global $wpdb;
		try {
			$cursor = self::raw_option( self::RECEIPT_CURSOR ) ?? '';
			$wpdb->last_error = '';
			$rows = $wpdb->get_results( $wpdb->prepare( "SELECT option_name, option_value FROM {$wpdb->options} WHERE option_name LIKE %s AND option_name > %s ORDER BY option_name ASC LIMIT 20", $wpdb->esc_like( self::RECEIPT_PREFIX ) . '%', $cursor ), ARRAY_A );
			if ( ! is_array( $rows ) || $wpdb->last_error ) return;
			foreach ( $rows as $row ) {
				$hash = substr( $row['option_name'], strlen( self::RECEIPT_PREFIX ) );
				$record = self::receipt_record( $hash );
				if ( ! $record || $record['expires'] > time() ) continue;
				$job = self::job( (int) $record['userId'] );
				if ( $job && ( $job['receiptHash'] ?? '' ) === $hash ) continue;
				self::remove_receipt( $hash, $record );
			}
			$next = count( $rows ) < 20 ? '' : end( $rows )['option_name'];
			$old = self::raw_option( self::RECEIPT_CURSOR );
			if ( null === $old ) add_option( self::RECEIPT_CURSOR, $next, '', false );
			else self::cas( self::RECEIPT_CURSOR, $old, $next );
		} catch ( Throwable $error ) { /* Next scheduled batch retries safely. */ }
	}

	private static function cleanup_intents(): void {
		global $wpdb;
		try {
			$cursor = self::raw_option( 'mobishop_deletion_intent_cursor_v1' ) ?? '';
			$wpdb->last_error = '';
			$rows = $wpdb->get_results( $wpdb->prepare( "SELECT option_name, option_value FROM {$wpdb->options} WHERE option_name LIKE %s AND option_name > %s ORDER BY option_name ASC LIMIT 20", $wpdb->esc_like( self::INTENT ) . '%', $cursor ), ARRAY_A );
			if ( ! is_array( $rows ) || $wpdb->last_error ) return;
			foreach ( $rows as $row ) {
				$hash = substr( $row['option_name'], strlen( self::INTENT ) );
				$record = self::intent( $hash );
				if ( ! $record || self::retain_intent( $record ) ) continue;
				$job = self::job( (int) $record['userId'] );
				if ( $job && ( $job['receiptHash'] ?? '' ) === $hash ) continue;
				self::guarded( (int) $record['userId'], $hash, static function () use ( $hash ): void {
					$fresh = self::intent( $hash );
					if ( ! $fresh || self::retain_intent( $fresh ) ) return;
					$job = self::job( $fresh['userId'] );
					if ( $job && ( $job['receiptHash'] ?? '' ) === $hash ) return;
					MobiShop_Customer_Identity_Guard::release( $fresh['userId'], $hash, $fresh['inventory'] );
					self::remove_intent( $hash, $fresh );
				} );
			}
			$next = count( $rows ) < 20 ? '' : end( $rows )['option_name'];
			$old = self::raw_option( 'mobishop_deletion_intent_cursor_v1' );
			if ( null === $old ) add_option( 'mobishop_deletion_intent_cursor_v1', $next, '', false );
			else self::cas( 'mobishop_deletion_intent_cursor_v1', $old, $next );
		} catch ( Throwable $error ) { /* Next scheduled batch retries safely. */ }
	}

	private static function cas( string $key, string $old, string $new ): bool {
		if ( $old === $new ) return self::raw_option( $key ) === $old;
		global $wpdb;
		$changed = $wpdb->query( $wpdb->prepare( "UPDATE {$wpdb->options} SET option_value = %s WHERE option_name = %s AND BINARY option_value = BINARY %s", $new, $key, $old ) );
		self::clear_option_cache( $key );
		return 1 === $changed;
	}
	/** Shared by the three connector option writers and their eraser. */
	public static function mutate_option( string $key, callable $mutate ): array {
		if ( ! in_array( $key, array( 'mobishop_push_devices_v1', 'mobishop_push_history', 'mobishop_push_automation_log_v1' ), true ) ) throw new InvalidArgumentException( 'Unsupported customer option' );
		global $wpdb;
		$lock = 'mobishop_data_' . md5( $wpdb->options . '|' . $key );
		if ( '1' !== (string) $wpdb->get_var( $wpdb->prepare( 'SELECT GET_LOCK(%s, 3)', $lock ) ) ) throw new RuntimeException( 'Customer option busy' );
		try {
			$raw = self::raw_option( $key );
			$rows = null === $raw ? array() : maybe_unserialize( $raw );
			if ( ! is_array( $rows ) ) throw new RuntimeException( 'Invalid customer option' );
			$next = $mutate( $rows );
			if ( ! is_array( $next ) ) throw new RuntimeException( 'Invalid customer option mutation' );
			if ( null === $raw ) {
				if ( ! add_option( $key, $next, '', false ) ) throw new RuntimeException( 'Customer option insert failed' );
			} elseif ( ! self::cas( $key, $raw, maybe_serialize( $next ) ) ) throw new RuntimeException( 'Customer option write failed' );
			return $next;
		} finally { $wpdb->query( $wpdb->prepare( 'SELECT RELEASE_LOCK(%s)', $lock ) ); }
	}
	/** Check inside the option lock, even if a request authenticated earlier. */
	public static function can_retain_user( int $id ): bool {
		if ( $id <= 0 ) return true; // Anonymous installation, not a claimed account.
		if ( self::is_pending( $id ) ) return false;
		global $wpdb;
		$wpdb->last_error = '';
		$exists = $wpdb->get_var( $wpdb->prepare( "SELECT ID FROM {$wpdb->users} WHERE ID = %d", $id ) );
		return ! $wpdb->last_error && (int) $exists === $id;
	}
	/** A confirmed future watchdog is persisted BEFORE any destructive batch. */
	private static function schedule( int $id ): bool {
		$args = array( $id );
		$next = wp_next_scheduled( self::HOOK, $args );
		if ( $next && $next > time() ) return true;
		// WP reschedules a recurring event BEFORE invoking its callback. A failed
		// job read or crashed PHP process therefore cannot consume the last retry.
		$result = wp_schedule_event( time() + 60, 'mobishop_deletion_minute', self::HOOK, $args, true );
		return ! is_wp_error( $result ) && true === $result;
	}
	public static function run_worker( int $id ): void {
		// Closing rollout also pauses accepted jobs without discarding their retry.
		if ( $id < 1 || ! self::enabled() || is_multisite() ) return;
		global $wpdb;
		$lock = 'mobishop_del_' . md5( $wpdb->options . '|' . $id );
		if ( '1' !== (string) $wpdb->get_var( $wpdb->prepare( 'SELECT GET_LOCK(%s, 0)', $lock ) ) ) return;
		try {
			$job = self::job( $id );
			if ( ! $job ) { wp_clear_scheduled_hook( self::HOOK, array( $id ) ); return; }
			if ( -1 === (int) $job['phase'] && time() - (int) $job['cursor'] > 900 ) {
				self::cancel_prepared( $id, $job['receiptHash'] ?? '' ); // Interrupted request never became accepted.
				return;
			}
			if ( ! self::schedule( $id ) || -1 === (int) $job['phase'] ) return;
			$started = microtime( true );
			for ( $step = 0; $step < self::MAX_STEPS; $step++ ) {
				$user = get_user_by( 'id', $id );
				if ( $user && ! self::ordinary_customer( $user ) ) return;
				if ( self::has_pending_payment( $id ) ) return;
				$finished = ! $user && isset( $job['identityLinks'] ) ? self::receipt_record( $job['receiptHash'] ) : null;
				if ( $finished && $finished['status'] === 'completed' && (int) $finished['userId'] === $id ) {
					// Recover a crash after completion/release; never replay provider erasure.
					self::remove_completed_intent( $job );
					MobiShop_Customer_Identity_Guard::release( $id, $job['receiptHash'], $job['identityLinks'], true );
					self::remove_job( $job );
					return;
				}
				$phase_before = (int) $job['phase'];
				if ( self::process_guarded( $job ) ) {
					$hash = $job['receiptHash'] ?? '';
					if ( $hash !== '' ) {
						$record = self::receipt_record( $hash );
						if ( ! $record || (int) $record['userId'] !== $id ) throw new RuntimeException( 'Deletion receipt changed' );
						$completed = array( 'userId' => $id, 'status' => 'completed', 'expires' => time() + self::RECEIPT_TTL );
						if ( ! self::cas( self::RECEIPT_PREFIX . $hash, maybe_serialize( $record ), maybe_serialize( $completed ) ) ) throw new RuntimeException( 'Completion receipt unavailable' );
					}
					self::remove_completed_intent( $job );
					if ( isset( $job['identityLinks'] ) ) MobiShop_Customer_Identity_Guard::release( $id, $hash, $job['identityLinks'], true );
					self::remove_job( $job );
					return;
				}
				self::save( $job );
				// An unchanged phase means a row/provider batch limit was hit; retry on the next callback.
				if ( (int) $job['phase'] === $phase_before ) return;
				if ( microtime( true ) - $started >= self::STEP_BUDGET ) return;
			}
		} catch ( Throwable $error ) {
			// The pre-scheduled retry handles transient failures and process crashes.
			// Never log customer records, tokens, SQL values or provider exceptions.
		} finally {
			$wpdb->query( $wpdb->prepare( 'SELECT RELEASE_LOCK(%s)', $lock ) );
		}
	}
	private static function ordinary_customer( WP_User $user ): bool {
		// A customer-only shopping alias must never imply erasure of its privileged canonical owner.
		if ( ! class_exists( 'MobiShop_Storefront_Admin' ) || MobiShop_Storefront_Admin::data_owner_id( $user->ID ) !== $user->ID ) return false;
		$roles = (array) $user->roles;
		$caps = (array) $user->allcaps;
		return ! array_intersect( array( 'administrator', 'shop_manager' ), $roles ) &&
			! array_intersect_key( array_filter( $caps ), array_flip( array( 'manage_options', 'edit_users', 'manage_woocommerce' ) ) ) &&
			(bool) array_intersect( array( 'customer', 'subscriber' ), $roles );
	}
	private static function table_exists( string $table ): bool {
		global $wpdb;
		$wpdb->last_error = '';
		$found = $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) );
		if ( $wpdb->last_error ) throw new RuntimeException( 'Table lookup unavailable' );
		return $table === $found;
	}
	private static function has_pending_payment( int $id ): bool {
		global $wpdb;
		$table = $wpdb->prefix . 'mobishop_native_checkout50_buyers';
		if ( ! self::table_exists( $table ) ) return false;
		if ( ! defined( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY' ) ) return true;
		$buyer = hash_hmac( 'sha256', 'mobishop-native-checkout50|buyer|' . $id, MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY );
		$wpdb->last_error = '';
		$active = $wpdb->get_var( $wpdb->prepare( "SELECT active_attempt FROM {$table} WHERE buyer_scope = %s", $buyer ) );
		if ( $wpdb->last_error ) throw new RuntimeException( 'Payment lookup unavailable' );
		return ! empty( $active );
	}
	/** Each run mutates at most 50 owned rows; no lookup by editable email. */
	private static function process( array &$job ): bool {
		global $wpdb;
		$id = (int) $job['userId'];
		$phase = (int) $job['phase'];
		if ( isset( $job['identityStage'] ) ) {
			if ( ! class_exists( 'MobiShop_Customer_Identity_Erasure_Stage' ) ) throw new RuntimeException( 'Identity erasure unavailable' );
			$job['identityStage'] = MobiShop_Customer_Identity_Erasure_Stage::advance( $id, $job['identityStage'] );
			// Persist each bounded provider step before merchant data erasure begins.
			self::save( $job );
			if ( $job['identityStage']['cursor'] !== count( $job['identityStage']['entries'] ) ) return false;
		} elseif ( ! ( defined( 'MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY' ) && MOBISHOP_ACCOUNT_DELETION_LEGACY_TEST_ONLY === true ) ) throw new RuntimeException( 'Missing identity erasure stage' );
		if ( 0 === $phase ) {
			if ( ! function_exists( 'wc_get_orders' ) ) throw new RuntimeException( 'WooCommerce unavailable' );
			$orders = wc_get_orders( array( 'customer_id' => $id, 'limit' => self::LIMIT, 'orderby' => 'ID', 'order' => 'ASC', 'return' => 'objects' ) );
			if ( ! is_array( $orders ) ) throw new RuntimeException( 'Order lookup unavailable' );
			foreach ( $orders as $order ) {
				if ( (int) $order->get_customer_id() !== $id ) throw new RuntimeException( 'Order owner changed' );
				$order->set_customer_id( 0 );
				foreach ( array( '_mobishop_push_campaign', '_mobishop_push_client_hash', '_mobishop_recovery_campaign_id' ) as $key ) $order->delete_meta_data( $key );
				if ( ! $order->save() ) throw new RuntimeException( 'Order save unavailable' );
			}
			if ( count( $orders ) ) return false;
		} elseif ( $phase >= 1 && $phase <= 3 ) {
			$table = $wpdb->prefix . array( 1 => 'mobishop_events', 2 => 'mobishop_carts', 3 => 'mobishop_push_orders_v2' )[ $phase ];
			if ( self::table_exists( $table ) ) {
				$where = 3 === $phase ? $wpdb->prepare( 'buyer_hash = %s', hash( 'sha256', 'user:' . $id ) ) : $wpdb->prepare( 'user_id = %d', $id );
				$count = $wpdb->query( "DELETE FROM {$table} WHERE {$where} LIMIT 50" );
				if ( false === $count ) throw new RuntimeException( 'Owned records unavailable' );
				if ( $count ) return false;
			}
		} elseif ( 4 === $phase ) {
			if ( ! self::recovery_batch( $id ) ) return false;
		} elseif ( 5 === $phase ) {
			if ( ! self::filter_option( 'mobishop_push_devices_v1', static fn( $key, $row ) => is_array( $row ) && (int) ( $row['user_id'] ?? 0 ) === $id ) ) return false;
		} elseif ( 6 === $phase ) {
			if ( ! self::filter_option( 'mobishop_push_history', static fn( $key, $row ) => is_array( $row ) && (int) ( $row['target_user_id'] ?? 0 ) === $id, true ) ) return false;
		} elseif ( 7 === $phase ) {
			if ( ! self::filter_option( 'mobishop_push_automation_log_v1', static fn( $key, $row ) => str_ends_with( (string) $key, ':user:' . $id ) ) ) return false;
		} elseif ( 8 === $phase ) {
			if ( ! self::cancel_events( 'mobishop_dispatch_automation_push', static fn( $args ) => is_array( $args[0] ?? null ) && (int) ( $args[0]['target_user_id'] ?? 0 ) === $id ) ) return false;
		} elseif ( 9 === $phase ) {
			// wp_delete_user does not erase comments or product reviews. Ownership
			// is the authenticated user ID, never a matching editable email.
			$wpdb->last_error = '';
			$comments = get_comments( array( 'user_id' => $id, 'number' => self::LIMIT, 'status' => 'all', 'type' => 'all', 'orderby' => 'comment_ID', 'order' => 'ASC' ) );
			if ( ! is_array( $comments ) || $wpdb->last_error ) throw new RuntimeException( 'Comment lookup unavailable' );
			foreach ( $comments as $comment ) {
				if ( (int) $comment->user_id !== $id || ! wp_delete_comment( (int) $comment->comment_ID, true ) || get_comment( (int) $comment->comment_ID ) ) throw new RuntimeException( 'Comment deletion unavailable' );
			}
			if ( count( $comments ) ) return false;
			if ( get_user_by( 'id', $id ) ) {
				if ( ! function_exists( 'wp_delete_user' ) ) require_once ABSPATH . 'wp-admin/includes/user.php';
				if ( ! wp_delete_user( $id, 0 ) || get_user_by( 'id', $id ) ) throw new RuntimeException( 'User deletion unavailable' );
			}
			return true;
		} else throw new RuntimeException( 'Unknown deletion phase' );
		$job['phase']++;
		return false;
	}
	private static function recovery_batch( int $id ): bool {
		global $wpdb;
		$table = $wpdb->prefix . 'mobishop_recovery_campaigns';
		if ( ! self::table_exists( $table ) ) return true;
		$wpdb->last_error = '';
		$rows = $wpdb->get_results( $wpdb->prepare( "SELECT id, coupon_id FROM {$table} WHERE user_id = %d LIMIT 50", $id ), ARRAY_A );
		if ( ! is_array( $rows ) || $wpdb->last_error ) throw new RuntimeException( 'Campaign read unavailable' );
		foreach ( $rows as $row ) {
			$campaign = (int) $row['id'];
			$coupon = (int) $row['coupon_id'];
			if ( $coupon && get_post( $coupon ) ) {
				if ( 'shop_coupon' !== get_post( $coupon )->post_type || ! wp_delete_post( $coupon, true ) || get_post( $coupon ) ) throw new RuntimeException( 'Coupon deletion unavailable' );
			}
			if ( ! self::cancel_events( 'mobishop_dispatch_recovery_push', static fn( $args ) => (int) ( $args[0] ?? 0 ) === $campaign ) ) return false;
			if ( false === $wpdb->delete( $table, array( 'id' => $campaign, 'user_id' => $id ), array( '%d', '%d' ) ) ) throw new RuntimeException( 'Campaign deletion unavailable' );
		}
		return empty( $rows );
	}
	private static function filter_option( string $key, callable $remove, bool $reindex = false ): bool {
		$removed = 0;
		self::mutate_option( $key, static function ( array $rows ) use ( $remove, $reindex, &$removed ): array {
			foreach ( $rows as $index => $row ) {
				if ( $removed < self::LIMIT && $remove( $index, $row ) ) { unset( $rows[ $index ] ); $removed++; }
			}
			return $reindex ? array_values( $rows ) : $rows;
		} );
		return 0 === $removed;
	}
	private static function cancel_events( string $hook, callable $matches ): bool {
		$removed = 0;
		foreach ( (array) _get_cron_array() as $time => $hooks ) {
			foreach ( (array) ( $hooks[ $hook ] ?? array() ) as $event ) {
				$args = (array) ( $event['args'] ?? array() );
				if ( ! $matches( $args ) ) continue;
				$result = wp_unschedule_event( $time, $hook, $args, true );
				if ( is_wp_error( $result ) || ! $result ) throw new RuntimeException( 'Scheduled cleanup unavailable' );
				if ( ++$removed >= self::LIMIT ) return false;
			}
		}
		// Yield after any removal so the following batch never runs in the same callback.
		return 0 === $removed;
	}
}
