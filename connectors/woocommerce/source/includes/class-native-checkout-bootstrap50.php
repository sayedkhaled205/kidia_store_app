<?php
/**
 * Normal Native checkout wiring; disabled unless server configuration opts in.
 *
 * wp-config.php must load the existing immutable installation key before
 * plugins load. This bootstrap never finds, generates, copies, or rotates keys
 * and never installs the ledger. Safety50 verifies its existing fingerprint.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Native_Checkout_Bootstrap50 {
	private static bool $started = false;
	private static bool $failed = false;
	private static ?MobiShop_Native_Checkout_Safety50 $instance = null;

	public static function boot(): void {
		if ( ! defined( 'MOBISHOP_NATIVE_CHECKOUT50_ENABLED' ) || true !== MOBISHOP_NATIVE_CHECKOUT50_ENABLED || self::$started ) {
			return;
		}
		self::$started = true;
		// A failed opt-in must not quietly reach unguarded core checkout.
		add_filter( 'rest_pre_dispatch', array( self::class, 'fail_closed' ), 1000, 3 );
		add_action( 'rest_api_init', array( self::class, 'register_unavailable_routes' ), 20 );
		try {
			if ( did_action( 'rest_api_init' ) ) {
				throw new RuntimeException( 'Native checkout bootstrap was called too late.' );
			}
			require_once MOBISHOP_PATH . 'api/class-native-checkout-safety50.php';
			self::$instance = new MobiShop_Native_Checkout_Safety50();
			self::$instance->register();
			// Retain Safety50's hooks, wrapping only metadata registration so a
			// broken Woo integration cannot make normal WordPress requests fatal.
			remove_action( 'woocommerce_blocks_loaded', array( self::$instance, 'register_extension' ) );
			if ( ! did_action( 'woocommerce_blocks_loaded' ) ) {
				add_action( 'woocommerce_blocks_loaded', array( self::class, 'register_extension' ) );
			}
			// Retry metadata before Woo constructs REST endpoint schemas, not
			// from a later verifier or from the checkout callback itself.
			add_action( 'rest_api_init', array( self::class, 'register_extension' ), -100 );
		} catch ( Throwable $error ) {
			self::unavailable();
		}
	}

	/** The verifier must inspect this object, not create/register a fresh guard. */
	public static function instance(): ?MobiShop_Native_Checkout_Safety50 {
		return self::$instance;
	}

	public static function register_extension(): void {
		if ( self::$failed || null === self::$instance ) {
			return;
		}
		try {
			self::$instance->register_extension();
		} catch ( Throwable $error ) {
			self::unavailable();
		}
	}

	private static function unavailable(): void {
		self::$failed = true;
		error_log( 'MobiShop Native checkout50 bootstrap unavailable; details redacted.' );
	}

	public static function fail_closed( $result, $server, WP_REST_Request $request ) {
		unset( $server );
		$extensions = $request->get_param( 'extensions' );
		if ( self::$failed && '/wc/store/v1/checkout' === $request->get_route() && 'POST' === $request->get_method() && is_array( $extensions ) && array_key_exists( 'mobishop_native_checkout50', $extensions ) ) {
			return self::unavailable_response();
		}
		return $result;
	}

	/** Only startup failure needs these routes; healthy routes belong to Safety50. */
	public static function register_unavailable_routes(): void {
		if ( ! self::$failed ) {
			return;
		}
		register_rest_route( 'mobishop/v1', '/native-checkout-capabilities', array(
			'methods' => 'GET', 'permission_callback' => '__return_true',
			'callback' => static fn() => self::response( array( 'protocol' => 50, 'enforced' => false, 'checkout_route' => '/wc/store/v1/checkout', 'recovery_route' => '/mobishop/v1/customer/checkout-attempts/{key}', 'guest_checkout' => false, 'automatic_replay' => false, 'qa_isolation' => false ) ),
		), true );
		register_rest_route( 'mobishop/v1', '/customer/checkout-attempts/(?P<key>[A-Za-z0-9._:-]{1,128})', array(
			'methods' => 'GET',
			'permission_callback' => static fn() => new WP_Error( 'mobishop_native_checkout50_unavailable', 'Checkout safety is unavailable.', array( 'status' => 503 ) ),
			'callback' => static fn() => self::unavailable_response(),
		), true );
	}

	private static function unavailable_response(): WP_REST_Response {
		return self::response( array( 'protocol' => 50, 'code' => 'mobishop_native_checkout50_unavailable', 'message' => 'Checkout safety is unavailable. Recover the existing attempt before retrying.', 'data' => array( 'status' => 503, 'automatic_replay' => false ) ), 503 );
	}

	private static function response( array $data, int $status = 200 ): WP_REST_Response {
		$response = new WP_REST_Response( $data, $status );
		$response->header( 'Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0' );
		$response->header( 'Pragma', 'no-cache' );
		return $response;
	}
}
