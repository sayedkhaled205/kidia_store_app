<?php
/**
 * Local stub contracts only: no WordPress/server/order/payment execution.
 * php mobishop/tests/native-checkout-safety50-contract-test.php
 * These tests do NOT certify installed SQL concurrency, gateways or Native.
 */
declare( strict_types=1 );

namespace Automattic\WooCommerce\StoreApi\Schemas\V1 {
	class CheckoutSchema { public const IDENTIFIER = 'checkout'; }
}
namespace Automattic\WooCommerce\StoreApi\Exceptions {
	class RouteException extends \RuntimeException {}
}
namespace Automattic\WooCommerce\StoreApi\Utilities {
	class CartTokenUtils {
		public static function validate_cart_token( string $token ): bool { return isset( $GLOBALS['tokens50'][ $token ] ); }
		public static function get_cart_token_payload( string $token ): array { return $GLOBALS['tokens50'][ $token ]; }
	}
	class OrderController {
		public function validate_order_before_payment( $order ): void {
			$this->perform_custom_order_validation( $order );
		}
		protected function perform_custom_order_validation( $order ): void {
			\do_action( 'woocommerce_checkout_validate_order_before_payment', $order, new \WP_Error() );
		}
	}
}
namespace {
	define( 'ABSPATH', __DIR__ );
	define( 'ARRAY_A', 'ARRAY_A' );
	define( 'WC_VERSION', '10.0.0' );
	if ( ! in_array( '--missing-installation-key', $argv ?? array(), true ) ) {
		define( 'MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY', str_repeat( 'f', 64 ) ); // Local fixture only.
	}

	class WP_Error {
		public function __construct( public string $code = '', public string $message = '', public array $data = array() ) {}
		public function get_error_codes(): array { return $this->code ? array( $this->code ) : array(); }
		public function get_error_data() { return $this->data; }
	}
	class WP_REST_Request {
		public ?WP_Error $validation = null;
		public bool $invalid_json = false;
		public function __construct( public array $body = array(), public array $headers = array(), public string $route = '/wc/store/v1/checkout', public string $method = 'POST' ) { $this->headers = array_change_key_case( $headers, CASE_LOWER ); }
		public function get_param( string $key ) { return $this->body[ $key ] ?? null; }
		public function get_header( string $key ): string { return (string) ( $this->headers[ strtolower( $key ) ] ?? '' ); }
		public function get_json_params() { return $this->invalid_json ? new WP_Error( 'rest_invalid_json', '', array( 'status' => 400 ) ) : $this->body; }
		public function has_valid_params() { return $this->validation ?: true; }
		public function get_route(): string { return $this->route; }
		public function get_method(): string { return $this->method; }
	}
	class WP_REST_Response {
		public array $headers = array();
		public function __construct( private $data, private int $status = 200 ) {}
		public function get_status(): int { return $this->status; }
		public function get_data() { return $this->data; }
		public function header( string $name, string $value ): void { $this->headers[ $name ] = $value; }
	}
	/** Models the verified WP 6.8 boundary; this is NOT installed WP execution. */
	class WP_REST_Server {
		public function dispatch( $request ) {
			$check_required = $request->has_valid_params();
			$error = is_wp_error( $check_required ) ? $check_required : null;
			return $this->respond_to_request( $request, $request->get_route(), $GLOBALS['handler50'], $error );
		}
		protected function respond_to_request( $request, $route, $handler, $response ) {
			$response = apply_filters( 'rest_request_before_callbacks', $response, $handler, $request );
			if ( ! is_wp_error( $response ) && ! empty( $handler['permission_callback'] ) ) {
				$permission = call_user_func( $handler['permission_callback'], $request );
				if ( is_wp_error( $permission ) ) { $response = $permission; }
			}
			if ( ! is_wp_error( $response ) ) {
				$dispatch_result = apply_filters( 'rest_dispatch_request', null, $request, $route, $handler );
				if ( null !== $dispatch_result ) { $response = $dispatch_result; }
				else { $response = call_user_func( $handler['callback'], $request ); }
			}
			$response = apply_filters( 'rest_request_after_callbacks', $response, $handler, $request );
			if ( is_wp_error( $response ) ) { $response = new WP_REST_Response( array( 'code' => $response->code, 'message' => $response->message, 'data' => $response->data ), (int) ( $response->data['status'] ?? 500 ) ); }
			return apply_filters( 'rest_post_dispatch', $response, $this, $request );
		}
	}
	class WC_Order {
		public array $meta = array();
		public string $status = 'checkout-draft';
		public string $via = 'store-api';
		public function __construct( public int $id = 0, public int $customer = 7, public $total = '0.00', public string $currency = 'EGP' ) {}
		public function get_id(): int { return $this->id; }
		public function get_customer_id(): int { return $this->customer; }
		public function get_type(): string { return 'shop_order'; }
		public function get_created_via(): string { return $this->via; }
		public function get_status(): string { return $this->status; }
		public function is_paid(): bool { return in_array($this->status,['processing','completed'],true); }
		public function needs_payment(): bool { return in_array($this->status,['pending','failed'],true); }
		public function get_total( string $context = 'view' ) { return $this->total; }
		public function get_currency(): string { return $this->currency; }
		public function get_meta( string $key, bool $single = true ) { return $this->meta[ $key ] ?? ''; }
		public function update_meta_data( string $key, $value ): void { $this->meta[ $key ] = $value; }
	}
	class MobiShop_Customer_Auth_Endpoint {
		public function session_context_from_request( WP_REST_Request $request ) {
			$token = $request->get_header( 'X-MobiShop-Session' );
			return isset( $GLOBALS['auth50'][ $token ] ) ? array( 'user_id' => $GLOBALS['auth50'][ $token ] ) : new WP_Error( 'expired', '', array( 'status' => 401 ) );
		}
	}
	function add_action( string $name, $callback, int $priority = 10, int $count = 1 ): void { $GLOBALS['hooks50'][ $name ][] = array( $callback, $priority ); }
	function add_filter( string $name, $callback, int $priority = 10, int $count = 1 ): void { add_action( $name, $callback, $priority, $count ); }
	function apply_filters( string $name, $value, ...$args ) { $rows = $GLOBALS['hooks50'][ $name ] ?? array(); usort( $rows, fn( $a, $b ) => $a[1] <=> $b[1] ); foreach ( $rows as $row ) { $value = ( $row[0] )( $value, ...$args ); } return $value; }
	function has_action( string $name, $callback ) { foreach ( $GLOBALS['hooks50'][ $name ] ?? array() as $row ) { if ( $row[0] === $callback ) { return $row[1]; } } return false; }
	function do_action( string $name, ...$args ): void { foreach ( $GLOBALS['hooks50'][ $name ] ?? array() as $row ) { ( $row[0] )( ...$args ); } }
	function did_action( string $name ): int { return 1; }
	function register_rest_route( string $namespace, string $route, array $args ): void { $GLOBALS['routes50'][ $namespace . $route ] = $args; }
	function woocommerce_store_api_register_endpoint_data( array $args ) { $GLOBALS['schema50'][] = $args; return $GLOBALS['registration50']; }
	function is_wp_error( $value ): bool { return $value instanceof WP_Error; }
	function rest_ensure_response( $value ) { return $value instanceof WP_REST_Response || $value instanceof WP_Error ? $value : new WP_REST_Response( $value ); }
	function get_current_user_id(): int { return $GLOBALS['user50']; }
	function wp_is_using_https(): bool { return $GLOBALS['https50']; }
	function home_url( string $path = '' ): string { return ( $GLOBALS['origin50'] ?? 'https://fixture.example.invalid' ) . $path; }
	function wp_salt( string $scheme = '' ): string { return ( $GLOBALS['salt50'] ?? 'LOCAL-TEST-ONLY-SALT-' ) . $scheme; }
	function wc_get_price_decimals(): int { return $GLOBALS['minor50']; }
	function WC(): object { return $GLOBALS['wc50']; }
	function wc_get_order( int $id ) { return isset( $GLOBALS['orders50'][ $id ] ) ? clone $GLOBALS['orders50'][ $id ] : false; }

	require rtrim(getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__).'/source', '/\\') . '/api/class-native-checkout-safety50.php';

	final class Memory_Store50 implements MobiShop_Native_Checkout_Store50 {
		public bool $available = true;
		public bool $association = true;
		public bool $guard = true;
		public bool $settlement = true;
		public bool $finish = true;
		public bool $pre_rejection = true;
		public bool $empty = false;
		public array $buyers = array();
		public array $attempts = array();
		public array $carts = array();
		public array $customers = array( '7' => 7, '9' => 9 );
		public function ready(): bool { return $this->available; }
		public function cart_customer( string $user ): ?int { return $this->customers[ $user ] ?? null; }
		public function cart_empty( string $user ): bool { return $this->empty; }
		public function claim( array $claim ): array {
			$buyer = $claim['buyer_scope']; $key = $claim['attempt_hash'];
			$row = $this->find( $buyer, $key );
			if ( $row ) { return array( 'result' => hash_equals( $row['payload_hash'], $claim['payload_hash'] ) ? 'existing' : 'conflict', 'attempt' => $row ); }
			if ( isset( $this->buyers[ $buyer ] ) ) { return array( 'result' => 'blocked' ); }
			foreach ( $this->attempts[ $buyer ] ?? array() as $open ) { if ( 'in_progress' === $open['state'] ) { return array( 'result' => 'blocked' ); } }
			if ( isset( $this->carts[ $claim['cart_scope'] ] ) && $this->carts[ $claim['cart_scope'] ] !== $buyer ) { return array( 'result' => 'cart_conflict' ); }
			$this->carts[ $claim['cart_scope'] ] = $buyer;
			$this->attempts[ $buyer ][ $key ] = $claim + array( 'order_id' => 0, 'state' => 'in_progress', 'guard_passed' => 0, 'dispatch_finished' => 0, 'payment_status' => '' );
			$this->buyers[ $buyer ] = $key;
			return array( 'result' => 'claimed' );
		}
		public function find( string $buyer, string $key ): ?array { return $this->attempts[ $buyer ][ $key ] ?? null; }
		public function reject_before_dispatch( array $claim ): array {
			if ( ! $this->pre_rejection ) { return array( 'result' => 'unavailable' ); }
			$buyer = $claim['buyer_scope']; $key = $claim['attempt_hash']; $row = $this->find( $buyer, $key );
			if ( $row ) { return array( 'result' => 'existing', 'attempt' => $row ); }
			if ( isset( $this->buyers[ $buyer ] ) ) { return array( 'result' => 'blocked' ); }
			foreach ( $this->attempts[ $buyer ] ?? array() as $open ) { if ( 'in_progress' === $open['state'] ) { return array( 'result' => 'blocked' ); } }
			$row = $claim + array( 'state' => 'rejected_before_dispatch', 'order_id' => 0, 'guard_passed' => 0, 'dispatch_finished' => 1, 'payment_status' => '' );
			$this->attempts[ $buyer ][ $key ] = $row;
			return array( 'result' => 'rejected', 'attempt' => $row );
		}
		public function associate( string $buyer, string $key, int $id ): bool { if ( ! $this->association || ! isset( $this->attempts[ $buyer ][ $key ] ) || ! in_array( $this->attempts[ $buyer ][ $key ]['order_id'], array( 0, $id ), true ) ) { return false; } $this->attempts[ $buyer ][ $key ]['order_id'] = $id; return true; }
		public function passed( string $buyer, string $key ): bool { if ( ! $this->guard ) { return false; } $this->attempts[ $buyer ][ $key ]['guard_passed'] = 1; return true; }
		public function finished( string $buyer, string $key ): bool { if ( ! $this->finish ) { return false; } $this->attempts[ $buyer ][ $key ]['dispatch_finished'] = 1; return true; }
		public function settle( string $buyer, string $key, string $state, string $payment ): bool { if ( !in_array($payment,['','success','unknown','pending'],true) || ($payment==='pending' && $state!=='order_created') || ! $this->settlement || ( $this->buyers[ $buyer ] ?? null ) !== $key || 1 !== $this->attempts[ $buyer ][ $key ]['dispatch_finished'] ) { return false; } $this->attempts[ $buyer ][ $key ]['state'] = $state; $this->attempts[ $buyer ][ $key ]['payment_status'] = $payment; unset( $this->buyers[ $buyer ] ); return true; }
		public function owns_cart( string $cart, string $buyer ): bool { return ( $this->carts[ $cart ] ?? null ) === $buyer; }
	}

	function fixture50(): array {
		$GLOBALS['hooks50'] = $GLOBALS['routes50'] = $GLOBALS['orders50'] = $GLOBALS['schema50'] = array();
		$GLOBALS['registration50'] = true; $GLOBALS['user50'] = 7; $GLOBALS['https50'] = true; $GLOBALS['minor50'] = 2;
		$GLOBALS['auth50'] = array( 'SESSION-A-DO-NOT-PERSIST' => 7, 'SESSION-B-DO-NOT-PERSIST' => 9 );
		$GLOBALS['tokens50'] = array( 'CART-A-DO-NOT-PERSIST' => array( 'user_id' => '7', 'iss' => 'store-api', 'exp' => time() + 600 ), 'CART-B-DO-NOT-PERSIST' => array( 'user_id' => '9', 'iss' => 'store-api', 'exp' => time() + 600 ) );
		$GLOBALS['cart_empty50'] = false;
		$GLOBALS['wc50'] = (object) array( 'session' => new class { public function get_customer_id(): string { return $GLOBALS['cart_user50'] ?? (string) $GLOBALS['user50']; } public function save_data(): void { $GLOBALS['store50']->empty = $GLOBALS['cart_empty50']; } }, 'customer' => new class { public function get_id(): int { return $GLOBALS['user50']; } }, 'cart' => new class { public function is_empty(): bool { return $GLOBALS['cart_empty50']; } public function get_cart(): array { return $GLOBALS['cart_empty50'] ? [] : ['fixture-line'=>['product_id'=>1,'variation_id'=>0,'variation'=>[],'quantity'=>1,'line_subtotal'=>'0','line_subtotal_tax'=>'0','line_total'=>'0','line_tax'=>'0']]; } public function empty_cart(): void { $GLOBALS['cart_empty50']=true; } } );
		$GLOBALS['cart_user50'] = '7'; $GLOBALS['core_calls50'] = $GLOBALS['stock50'] = $GLOBALS['payment50'] = 0;
		$store = new Memory_Store50(); $GLOBALS['store50'] = $store; $api = new MobiShop_Native_Checkout_Safety50( $store ); $api->register(); $api->register_routes();
		return array( $api, $store );
	}
	function request50( string $key = 'fixture-key-A', int $customer = 7, ?array $confirmed = null ): WP_REST_Request {
		return new WP_REST_Request( array( 'billing_address' => array( 'first_name' => 'PRIVATE-NAME-DO-NOT-PERSIST', 'email' => 'private@example.invalid' ), 'payment_method' => '', 'extensions' => array( MobiShop_Native_Checkout_Safety50::NAMESPACE => array( 'protocol' => 50, 'confirmed' => $confirmed ?? array( 'total_price' => '0', 'currency_code' => 'EGP', 'currency_minor_unit' => 2 ) ) ) ), array( 'X-MobiShop-Session' => 7 === $customer ? 'SESSION-A-DO-NOT-PERSIST' : 'SESSION-B-DO-NOT-PERSIST', 'Cart-Token' => 7 === $customer ? 'CART-A-DO-NOT-PERSIST' : 'CART-B-DO-NOT-PERSIST', 'Idempotency-Key' => $key ) );
	}
	function core50( MobiShop_Native_Checkout_Safety50 $api, ?WC_Order $order = null, string $mode = 'success' ): Closure {
		return function ( $request ) use ( $api, $order, $mode ) {
			++$GLOBALS['core_calls50'];
			if ( 'throw_before_order' === $mode ) { throw new RuntimeException( 'Private server failure not for response.' ); }
			if ( 'generic_400_before_order' === $mode ) { return new WP_REST_Response( array( 'private' => 'not persisted' ), 400 ); }
			$target = $order ?? new WC_Order( 0, $GLOBALS['user50'] );
			$api->before_save( $target ); $target->id = $target->id ?: 100 + $GLOBALS['core_calls50']; $GLOBALS['orders50'][ $target->id ] = clone $target; $api->after_save( $target );
			if ( 'revoked_before_guard' === $mode ) { unset( $GLOBALS['auth50']['SESSION-A-DO-NOT-PERSIST'] ); }
			if ( 'foreign_cart_before_guard' === $mode ) { $GLOBALS['cart_user50'] = '9'; }
			try { $api->validate_final( $target, new WP_Error() ); } catch ( \Automattic\WooCommerce\StoreApi\Exceptions\RouteException $error ) { return new WP_REST_Response( array( 'code' => 'core-wrapper-error' ), $error->getCode() ); }
			if ( 'throw_after_guard' === $mode ) { throw new RuntimeException( 'After guard unknown outcome.' ); }
			++$GLOBALS['stock50']; ++$GLOBALS['payment50'];
			$target->status = 'pending' === $mode ? 'pending' : 'completed'; $GLOBALS['orders50'][ $target->id ] = clone $target;
			if ( 'lost_response' === $mode ) { throw new RuntimeException( 'Connection lost after order completion.' ); }
			if ( 'generic_400_after_payment' === $mode ) { return new WP_REST_Response( array( 'code' => 'gateway-or-plugin-error' ), 400 ); }
			$GLOBALS['cart_empty50'] = true;
			return new WP_REST_Response( array( 'order_id' => $target->id, 'status' => $target->status, 'order_key' => 'NEVER-PERSIST-ORDER-KEY', 'payment_result' => array( 'payment_status' => 'pending' === $mode ? 'pending' : 'success', 'redirect_url' => 'https://fixture.example.invalid/order?key=NEVER-PERSIST' ) ), 200 );
		};
	}
	function dispatch50( MobiShop_Native_Checkout_Safety50 $api, WP_REST_Request $request, Closure $callback ) { return $api->dispatch( null, $request, $request->get_route(), array( 'callback' => $callback ) ); }
	function wp_dispatch50( WP_REST_Request $request, Closure $callback ) { $GLOBALS['handler50'] = array( 'callback' => $callback, 'permission_callback' => fn() => true ); return ( new WP_REST_Server() )->dispatch( $request ); }
	function recover50( MobiShop_Native_Checkout_Safety50 $api, string $key = 'fixture-key-A', int $customer = 7 ) { $request = request50( $key, $customer ); $request->body = array( 'key' => $key ); $request->route = '/mobishop/v1/customer/checkout-attempts/' . $key; $request->method = 'GET'; return $api->recover( $request ); }
	function check50( bool $value, string $message ): void { if ( ! $value ) { throw new RuntimeException( $message ); } }
	function status50( $response ): int { return $response instanceof WP_Error ? (int) ( $response->data['status'] ?? 500 ) : $response->get_status(); }
	function test50( string $name, Closure $test ): void { $test(); ++$GLOBALS['count50']; echo "PASS $name\n"; }
	$GLOBALS['count50'] = 0;
	if ( in_array( '--missing-installation-key', $argv ?? array(), true ) ) {
		[ $api ] = fixture50(); check50( false === $api->capabilities()['enforced'], 'Missing immutable installation key fails closed.' ); echo "PASS missing immutable installation key fails capability closed\n"; exit;
	}

	test50( 'capability requires actual schema registration and exact runtime guard', function () { [ $api, $store ] = fixture50(); check50( true === $api->capabilities()['enforced'], 'Ready fixture supported.' ); $store->available = false; check50( false === $api->capabilities()['enforced'], 'Missing tables unsupported.' ); [ $api ] = fixture50(); $GLOBALS['registration50'] = new WP_Error( 'registration_failed' ); $other = new MobiShop_Native_Checkout_Safety50( new Memory_Store50() ); $other->register(); check50( false === $other->capabilities()['enforced'], 'Failed actual schema registration unsupported.' ); } );
	test50( 'unregistered source does not declare capability or install tables', function () { fixture50(); $api = new MobiShop_Native_Checkout_Safety50( new Memory_Store50() ); check50( false === $api->capabilities()['enforced'], 'Not registered is false.' ); } );
	test50( 'schema explicitly registers namespace and required confirmed properties', function () { [ $api ] = fixture50(); $schema = $api->extension_schema(); check50( count( $schema['confirmed']['required'] ) === 3 && false === $schema['confirmed']['additionalProperties'], 'Exact schema.' ); check50( $GLOBALS['schema50'][0]['namespace'] === MobiShop_Native_Checkout_Safety50::NAMESPACE, 'Namespace registered.' ); check50( false === $api->capabilities()['qa_isolation'], 'No invented QA bypass.' ); } );
	test50( 'normal website and different routes are untouched', function () { [ $api ] = fixture50(); $request = request50(); unset( $request->body['extensions'] ); check50( null === dispatch50( $api, $request, core50( $api ) ), 'Website pass-through.' ); $request = request50(); $request->route = '/wc/store/v1/cart'; check50( null === dispatch50( $api, $request, core50( $api ) ), 'Cart endpoint untouched.' ); check50( 0 === $GLOBALS['core_calls50'], 'No direct core call.' ); } );
	test50( 'unknown registration blocks before any core call', function () { [ $api, $store ] = fixture50(); $store->available = false; check50( 503 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Unsupported rejected.' ); check50( 0 === $GLOBALS['core_calls50'], 'No core call.' ); } );
	test50( 'expired sessions and admin cookie conflicts cannot authorize checkout', function () { [ $api, $store ] = fixture50(); unset( $GLOBALS['auth50']['SESSION-A-DO-NOT-PERSIST'] ); check50( 401 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Expired denied.' ); check50( $api->authenticate( request50() ) instanceof WP_Error, 'Permission denies.' ); [ $api, $store ] = fixture50(); $GLOBALS['user50'] = 99; check50( 401 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Admin cookie cannot substitute buyer.' ); check50( ! $store->attempts, 'No claim.' ); } );
	test50( 'HTTPS required for explicit customer auth', function () { [ $api, $store ] = fixture50(); $GLOBALS['https50'] = false; check50( 401 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'HTTP denied.' ); check50( ! $store->attempts, 'No claim on HTTP.' ); } );
	test50( 'unsigned expired foreign-issuer and cross-buyer cart tokens denied', function () { foreach ( array( 'unsigned', 'expired', 'issuer', 'buyer' ) as $case ) { [ $api, $store ] = fixture50(); $request = request50(); if ( 'unsigned' === $case ) { unset( $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST'] ); } if ( 'expired' === $case ) { $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['exp'] = time() - 1; } if ( 'issuer' === $case ) { $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['iss'] = 'foreign'; } if ( 'buyer' === $case ) { $request->headers['cart-token'] = 'CART-B-DO-NOT-PERSIST'; } check50( 403 === status50( dispatch50( $api, $request, core50( $api ) ) ), $case . ' denied.' ); check50( 0 === $GLOBALS['core_calls50'], 'No cart/order mutation.' ); } } );
	test50( 'persisted guest session belonging to another buyer is denied', function () { [ $api, $store ] = fixture50(); $guest = 't_' . str_repeat( 'a', 32 ); $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['user_id'] = $guest; $store->customers[ $guest ] = 9; check50( 403 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Foreign stored customer rejected.' ); check50( ! $store->attempts, 'No claim.' ); } );
	test50( 'legitimate guest cart adoption binds permanently to first buyer', function () { [ $api, $store ] = fixture50(); $guest = 't_' . str_repeat( 'a', 32 ); $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['user_id'] = $guest; $GLOBALS['cart_user50'] = $guest; $store->customers[ $guest ] = 0; check50( 200 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Own guest cart adopted.' ); $GLOBALS['user50'] = 9; $GLOBALS['tokens50']['CART-B-DO-NOT-PERSIST']['user_id'] = $guest; check50( 409 === status50( dispatch50( $api, request50( 'fixture-key-B', 9 ), core50( $api ) ) ), 'Cannot adopt same guest cart as B.' ); check50( 1 === $GLOBALS['core_calls50'], 'No second core call.' ); } );
	test50( 'Woo 10.9.4 t_30 guest cart reaches guarded checkout without changing buyer scope', function () {
		$guest = 't_' . '0123456789abcdef0123456789abcd';
		foreach ( array( 0, 7 ) as $owner ) {
			[ $api, $store ] = fixture50(); $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['user_id'] = $guest; $GLOBALS['cart_user50'] = $guest; $store->customers[ $guest ] = $owner;
			check50( strlen( $guest ) === 32 && 200 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Current Woo guest format accepted only with persisted unowned/current buyer session.' );
			$recovered = recover50( $api ); check50( 200 === status50( $recovered ) && 'order_created' === $recovered->get_data()['state'] && false === $recovered->get_data()['checkout_locked'] && false === $recovered->get_data()['automatic_replay'], 'Exact buyer recovery remains unchanged.' );
			check50( true === $api->capabilities()['enforced'] && false === $api->capabilities()['qa_isolation'] && 1 === $GLOBALS['core_calls50'], 'Parser fix does not weaken capability or replay guards.' );
			$GLOBALS['user50'] = 9; $GLOBALS['tokens50']['CART-B-DO-NOT-PERSIST']['user_id'] = $guest;
			check50( 404 === status50( recover50( $api, 'fixture-key-A', 9 ) ), 'Guest ID never becomes another customer identity.' );
			check50( in_array( status50( dispatch50( $api, request50( 'different-buyer', 9 ), core50( $api ) ) ), array( 403, 409 ), true ) && 1 === $GLOBALS['core_calls50'], 'Foreign stored owner or permanent guest adoption prevents a second buyer callback.' );
		}
	} );
	test50( 'current Woo guest format still requires valid signed issuer expiry and persisted ownership', function () {
		foreach ( array( 'unsigned', 'issuer', 'expired', 'missing_session', 'foreign_owner' ) as $case ) {
			[ $api, $store ] = fixture50(); $guest = 't_' . str_repeat( 'a', 30 ); $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['user_id'] = $guest; $store->customers[ $guest ] = 0;
			if ( 'unsigned' === $case ) { unset( $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST'] ); }
			if ( 'issuer' === $case ) { $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['iss'] = 'foreign'; }
			if ( 'expired' === $case ) { $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['exp'] = time() - 1; }
			if ( 'missing_session' === $case ) { unset( $store->customers[ $guest ] ); }
			if ( 'foreign_owner' === $case ) { $store->customers[ $guest ] = 9; }
			check50( 403 === status50( dispatch50( $api, request50(), core50( $api ) ) ) && ! $store->attempts && ! $store->carts && 0 === $GLOBALS['core_calls50'], 'No adoption or order callback for ' . $case );
		}
	} );
	test50( 'guest parser accepts only exact current and previously supported formats', function () {
		foreach ( array( 't_' . str_repeat( 'a', 29 ), 't_' . str_repeat( 'a', 31 ), 't_' . str_repeat( 'a', 33 ), 't_' . str_repeat( 'a', 40 ), 't_' . str_repeat( 'A', 30 ), 't_' . str_repeat( 'g', 30 ), 't_' . str_repeat( 'a', 30 ) . "\n", str_repeat( 'a', 30 ), str_repeat( 'a', 40 ), 'dbb6b8c7-bac8-4d44-a2bc-0f86aa7f6370' ) as $guest ) {
			[ $api, $store ] = fixture50(); $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['user_id'] = $guest; $store->customers[ $guest ] = 0;
			check50( 403 === status50( dispatch50( $api, request50(), core50( $api ) ) ) && 0 === $GLOBALS['core_calls50'] && ! $store->attempts, 'Malformed ID or independent web UUID refused.' );
		}
		foreach ( array( str_repeat( 'a', 32 ), 't_' . str_repeat( 'a', 32 ), '7' ) as $guest ) {
			[ $api, $store ] = fixture50(); $GLOBALS['tokens50']['CART-A-DO-NOT-PERSIST']['user_id'] = $guest; $GLOBALS['cart_user50'] = $guest; $store->customers[ $guest ] = 7;
			check50( 200 === status50( dispatch50( $api, request50(), core50( $api ) ) ) && 1 === $GLOBALS['core_calls50'], 'Previous supported cart ID still checks actual stored current owner.' );
		}
	} );
	test50( 'confirmed contract rejects unsafe keys and tombstones malformed money before callback', function () { foreach ( array( array( 'total_price' => 0, 'currency_code' => 'EGP', 'currency_minor_unit' => 2 ), array( 'total_price' => '-1', 'currency_code' => 'EGP', 'currency_minor_unit' => 2 ), array( 'total_price' => '0', 'currency_code' => 'egp', 'currency_minor_unit' => 2 ), array( 'total_price' => '0', 'currency_code' => 'EGP', 'currency_minor_unit' => '2' ) ) as $value ) { [ $api, $store ] = fixture50(); $result = dispatch50( $api, request50( 'key', 7, $value ), core50( $api ) ); check50( 409 === status50( $result ) && false === $result->get_data()['checkout_dispatched'] && 'rejected_before_dispatch' === $result->get_data()['state'], 'Exact durable malformed rejection.' ); check50( 0 === $GLOBALS['core_calls50'] && ! $store->buyers && ! $store->carts, 'No callback, active claim or cart adoption.' ); } [ $api, $store ] = fixture50(); check50( 400 === status50( dispatch50( $api, request50( "key\nInjected" ), core50( $api ) ) ), 'Header newline denied without exact-key proof.' ); check50( ! $store->attempts && 0 === $GLOBALS['core_calls50'], 'No ambiguous-key ledger row.' ); } );
	test50( 'canonical body sorts object keys but does not persist PII or tokens', function () { [ $api, $store ] = fixture50(); $request = request50(); check50( 200 === status50( dispatch50( $api, $request, core50( $api ) ) ), 'First success.' ); $request->body = array_reverse( $request->body, true ); check50( 200 === status50( dispatch50( $api, $request, core50( $api ) ) ), 'Object order stable.' ); check50( 1 === $GLOBALS['core_calls50'], 'No replay.' ); $persisted = json_encode( array( $store->attempts, $store->buyers, $store->carts ) ); foreach ( array( 'SESSION-', 'CART-', 'PRIVATE-NAME', 'private@example.invalid', 'NEVER-PERSIST', 'redirect_url', 'billing_address' ) as $secret ) { check50( ! str_contains( $persisted, $secret ), 'No ' . $secret . ' persisted.' ); } } );
	test50( 'same key with changed body conflicts even after successful order', function () { [ $api ] = fixture50(); dispatch50( $api, request50(), core50( $api ) ); $request = request50(); $request->body['billing_address']['first_name'] = 'changed'; check50( 409 === status50( dispatch50( $api, $request, core50( $api ) ) ), 'Payload conflict.' ); check50( 1 === $GLOBALS['core_calls50'], 'No second execution.' ); } );
	test50( 'unresolved attempt blocks different keys and different carts for same buyer', function () { [ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, null, 'throw_before_order' ) ); $request = request50( 'new-key' ); $GLOBALS['tokens50']['NEW-CART'] = array( 'user_id' => 't_' . str_repeat( 'b', 32 ), 'iss' => 'store-api', 'exp' => time() + 600 ); $store->customers[ 't_' . str_repeat( 'b', 32 ) ] = 0; $request->headers['cart-token'] = 'NEW-CART'; check50( 409 === status50( dispatch50( $api, $request, core50( $api ) ) ), 'New key and cart blocked.' ); check50( 1 === $GLOBALS['core_calls50'], 'No duplicate core execution.' ); } );
	test50( 'same-key in-flight reentrant call cannot execute callback twice', function () { [ $api ] = fixture50(); $callback = function ( $request ) use ( $api ) { ++$GLOBALS['core_calls50']; check50( 503 === status50( dispatch50( $api, $request, core50( $api ) ) ), 'Nested request denied.' ); throw new RuntimeException( 'Original outcome unknown.' ); }; dispatch50( $api, request50(), $callback ); check50( 1 === $GLOBALS['core_calls50'], 'No double callback.' ); } );
	test50( 'new API instance retains unresolved block and no missing-order expiry', function () { [ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, null, 'throw_before_order' ) ); $restarted = new MobiShop_Native_Checkout_Safety50( $store ); $restarted->register(); check50( 202 === status50( recover50( $restarted ) ), 'Known claim with missing order remains unknown.' ); check50( 409 === status50( dispatch50( $restarted, request50( 'new-key' ), core50( $restarted ) ) ), 'Restart cannot bypass.' ); check50( 404 === status50( recover50( $restarted, 'absent-key' ) ), 'Missing claim unknown not safe retry.' ); check50( 1 === count( $store->attempts ), 'Unknown preserved.' ); } );
	test50( 'exact integer money handles large values and insignificant decimal zeros', function () { check50( '12345678901234567890123456789012' === MobiShop_Native_Checkout_Safety50::decimal_to_minor( '123456789012345678901234567890.1200', 2 ), 'No int/float overflow.' ); check50( '0' === MobiShop_Native_Checkout_Safety50::decimal_to_minor( '000.000', 2 ), 'Zero canonical.' ); check50( '2' === MobiShop_Native_Checkout_Safety50::decimal_to_minor( '2.000', 0 ), 'Zero-decimal currency.' ); foreach ( array( '1.001', '-1', '1e2', ' 1', '1,00', 1.0 ) as $bad ) { check50( null === MobiShop_Native_Checkout_Safety50::decimal_to_minor( $bad, 2 ), 'No rounded/coerced value.' ); } } );
	test50( 'raise decrease currency and precision mismatch stop before stock or payment', function () { foreach ( array( array( '100', '2.00', 'EGP', 2 ), array( '200', '1.00', 'EGP', 2 ), array( '100', '1.00', 'USD', 2 ), array( '100', '1.00', 'EGP', 3 ) ) as $case ) { [ $api, $store ] = fixture50(); $GLOBALS['minor50'] = $case[3]; $confirmed = array( 'total_price' => $case[0], 'currency_code' => 'EGP', 'currency_minor_unit' => 2 ); check50( 409 === status50( dispatch50( $api, request50( 'key', 7, $confirmed ), core50( $api, new WC_Order( 0, 7, $case[1], $case[2] ) ) ) ), 'Exact mismatch rejected.' ); check50( 0 === $GLOBALS['stock50'] && 0 === $GLOBALS['payment50'], 'No stock/payment.' ); check50( ! $store->buyers, 'Proven guard rejection resolved.' ); check50( 'rejected_before_payment' === recover50( $api, 'key' )->get_data()['state'], 'Old key stays rejected.' ); } } );
	test50( 'generic early or late 400 and 500 never clear unresolved claims', function () { foreach ( array( 'generic_400_before_order', 'generic_400_after_payment', 'throw_before_order', 'throw_after_guard' ) as $mode ) { [ $api, $store ] = fixture50(); check50( 503 === status50( dispatch50( $api, request50(), core50( $api, null, $mode ) ) ), 'Unknown response.' ); check50( count( $store->buyers ) === 1, 'Claim retained.' ); check50( 409 === status50( dispatch50( $api, request50( 'new-key' ), core50( $api ) ) ), 'New key blocked.' ); } } );
	test50( 'verified external gateway handoff creates unpaid receipt once', function () {
		[ $api, $store ] = fixture50();
		$callback=function($request) use($api) {
			$response=(core50($api,null,'pending'))($request);$data=$response->get_data();
			$data['payment_result']['payment_status']='success';
			return new WP_REST_Response($data,200);
		};
		$result=dispatch50($api,request50(),$callback);$data=$result->get_data();
		check50(200===status50($result) && $data['state']==='order_created' && $data['payment_status']==='pending' && $data['order']['status']==='pending','Proven handoff is an unpaid existing order.');
		check50($data['checkout_locked']===false && $data['automatic_replay']===false && !$store->buyers,'Only verified consumed cart releases buyer; no automatic replay.');
		check50(!isset($data['payment_result'],$data['order_key'],$data['redirect_url']),'No untrusted gateway continuation or secret in durable receipt.');
		$result=dispatch50($api,request50(),$callback);
		check50(200===status50($result) && $result->get_data()['payment_status']==='pending' && $GLOBALS['core_calls50']===1,'Repeated POST resolves existing attempt, never creates another order.');
		$result=recover50($api);
		check50(200===status50($result) && $result->get_data()['payment_status']==='pending' && $GLOBALS['core_calls50']===1,'Read recovery returns only persisted proven pending receipt.');
		foreach(['processing','completed','cancelled'] as $changed_status) {
			$GLOBALS['orders50'][$data['order']['id']]->status=$changed_status;
			$result=recover50($api);
			check50(200===status50($result) && $result->get_data()['payment_status']==='unknown' && $result->get_data()['order']['status']===$changed_status,'Changed order status cannot carry a stale pending payment assertion.');
			$buyer=array_key_first($store->attempts);$attempt=array_key_first($store->attempts[$buyer]);
			check50($store->attempts[$buyer][$attempt]['payment_status']==='pending' && $GLOBALS['core_calls50']===1,'Status refresh does not mutate receipt or redispatch checkout.');
		}
	});
	test50( 'pending handoff must preserve every durable ownership proof', function () {
		foreach(['guard_passed','dispatch_finished','customer_id','order_id','buyer_scope','attempt_hash','cart_scope','order_customer','order_attempt','order_buyer','cart_owner','core_status','cancelled','failed','refunded','draft'] as $fault) {
			[$api,$store]=fixture50();
			$callback=function($request)use($api,$store,$fault){
				$response=(core50($api,null,'pending'))($request);$data=$response->get_data();$data['payment_result']['payment_status']='success';
				$buyer=array_key_first($store->attempts);$attempt=array_key_first($store->attempts[$buyer]);
				if(in_array($fault,['guard_passed','customer_id','order_id'],true))$store->attempts[$buyer][$attempt][$fault]=0;
				if($fault==='dispatch_finished')$store->finish=false;
				if(in_array($fault,['buyer_scope','attempt_hash','cart_scope'],true))$store->attempts[$buyer][$attempt][$fault]=str_repeat('0',64);
				$order=$GLOBALS['orders50'][$data['order_id']];
				if($fault==='order_customer')$order->customer=99;
				if($fault==='order_attempt')$order->meta['_mobishop_native_attempt50']=str_repeat('0',64);
				if($fault==='order_buyer')$order->meta['_mobishop_native_buyer50']=str_repeat('0',64);
				if($fault==='cart_owner')$store->carts=[];
				if($fault==='core_status')$data['status']='completed';
				if(in_array($fault,['cancelled','failed','refunded','draft'],true))$order->status=$fault==='draft'?'checkout-draft':$fault;
				return new WP_REST_Response($data,200);
			};
			$result=dispatch50($api,request50(),$callback);
			check50(503===status50($result) && count($store->buyers)===1,'Unproven or changed pending handoff must retain lock: '.$fault);
		}
	});

	test50( 'draft and pending payment are not successful recovery', function () { foreach ( array( 'throw_after_guard', 'pending' ) as $mode ) { [ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, null, $mode ) ); $response = recover50( $api ); check50( 202 === status50( $response ), 'Still unresolved.' ); check50( 'order_created' !== $response->get_data()['state'], 'No invented receipt.' ); check50( count( $store->buyers ) === 1, 'Buyer remains locked.' ); } } );
	test50( 'lost response recovers exact owned order but needs persisted empty cart before unlock', function () { [ $api, $store ] = fixture50(); check50( 503 === status50( dispatch50( $api, request50(), core50( $api, null, 'lost_response' ) ) ), 'Original response unknown.' ); $response = recover50( $api ); check50( 200 === status50( $response ) && 'order_created' === $response->get_data()['state'], 'Actual order recovered.' ); check50( true === $response->get_data()['checkout_locked'] && count( $store->buyers ) === 1, 'Unconsumed cart cannot unlock.' ); $store->empty = true; $response = recover50( $api ); check50( false === $response->get_data()['checkout_locked'], 'Persisted empty cart unlocks finished callback.' ); check50( 'unknown' === $response->get_data()['payment_status'], 'No invented payment response.' ); check50( false === $response->get_data()['automatic_replay'], 'No automatic replay.' ); check50( 1 === $GLOBALS['core_calls50'], 'Still exactly one callback.' ); check50( ! $store->buyers, 'Safe recovery resolves buyer lock.' ); $payload = json_encode( $response->get_data() ); check50( ! str_contains( $payload, 'order_key' ) && ! str_contains( $payload, 'redirect_url' ) && ! str_contains( $payload, 'address' ), 'Minimal private result.' ); } );
	test50( 'cross-customer recovery never reveals or matches another buyer attempt', function () { [ $api ] = fixture50(); dispatch50( $api, request50(), core50( $api ) ); $GLOBALS['user50'] = 9; $response = recover50( $api, 'fixture-key-A', 9 ); check50( 404 === status50( $response ), 'Foreign attempt opaque.' ); check50( ! isset( $response->get_data()['order'] ), 'No foreign order.' ); } );
	test50( 'ownership changed order or missing persisted marker fail closed', function () { foreach ( array( 'customer', 'marker' ) as $case ) { [ $api ] = fixture50(); dispatch50( $api, request50(), core50( $api ) ); $id = array_key_first( $GLOBALS['orders50'] ); if ( 'customer' === $case ) { $GLOBALS['orders50'][ $id ]->customer = 9; } else { $GLOBALS['orders50'][ $id ]->meta = array(); } check50( 202 === status50( recover50( $api ) ), 'Fresh ownership/tag checked.' ); } } );
	test50( 'session revoked and final cart identity switched cannot proceed', function () { foreach ( array( 'revoked_before_guard', 'foreign_cart_before_guard' ) as $mode ) { [ $api, $store ] = fixture50(); check50( 503 === status50( dispatch50( $api, request50(), core50( $api, null, $mode ) ) ), 'Final ownership denied.' ); check50( 0 === $GLOBALS['payment50'], 'No payment.' ); check50( count( $store->buyers ) === 1, 'Unknown not erased.' ); } } );
	test50( 'association and persisted guard failures block payment and recovery', function () { foreach ( array( 'association', 'guard' ) as $fault ) { [ $api, $store ] = fixture50(); $store->$fault = false; check50( 503 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Guard persistence fails.' ); check50( 0 === $GLOBALS['payment50'], 'No payment before durable guard.' ); check50( 202 === status50( recover50( $api ) ), 'No success recovery.' ); } } );
	test50( 'settlement failure after order keeps uncertainty without leaking result credentials', function () { [ $api, $store ] = fixture50(); $store->settlement = false; check50( 503 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Unable to acknowledge outcome.' ); check50( count( $store->buyers ) === 1, 'Buyer locked.' ); check50( 503 === status50( recover50( $api ) ), 'Retry recovery remains uncertain.' ); } );
	test50( 'successful and rejected recovery and permission error are no-store', function () { [ $api ] = fixture50(); $result = dispatch50( $api, request50(), core50( $api ) ); check50( str_contains( $result->headers['Cache-Control'], 'no-store' ), 'Core success no-store.' ); check50( str_contains( recover50( $api )->headers['Cache-Control'], 'no-store' ), 'Recovery no-store.' ); $request = new WP_REST_Request( array(), array(), '/mobishop/v1/customer/checkout-attempts/key', 'GET' ); $response = $api->private_headers( new WP_REST_Response( array(), 401 ), null, $request ); check50( str_contains( $response->headers['Cache-Control'], 'no-store' ), 'Permission failure no-store.' ); } );
	test50( 'first draft marker does not rely on new-order action or throwing from save', function () { [ $api, $store ] = fixture50(); $order = new WC_Order( 0, 9 ); check50( 503 === status50( dispatch50( $api, request50(), core50( $api, $order ) ) ), 'Wrong first-draft customer denied at final hook.' ); check50( empty( $order->meta ), 'Never stamps foreign order.' ); check50( 0 === $GLOBALS['payment50'], 'No payment.' ); } );
	test50( 'explicit activation DDL has unique keys and fingerprint but no expiry or PII columns', function () { $db = (object) array( 'prefix' => 'fixture_' ); $storage = new MobiShop_Native_Checkout_Wpdb50( $db ); $sql = implode( "\n", $storage->installation_sql() ); check50( str_contains( $sql, 'PRIMARY KEY (buyer_scope, attempt_hash)' ) && str_contains( $sql, 'PRIMARY KEY (buyer_scope)' ) && str_contains( $sql, 'PRIMARY KEY (cart_scope)' ), 'Required unique constraints.' ); foreach ( array( 'email', 'address', 'session_token', 'cart_token', 'expires', 'redirect', 'order_key' ) as $private ) { check50( ! str_contains( $sql, $private ), 'No unsafe column ' . $private ); } check50( ! str_contains( $sql, MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY ), 'Setup SQL contains fingerprint, not secret.' ); check50( 4 === substr_count( $sql, 'ENGINE=InnoDB' ), 'Transactional tables.' ); } );
	test50( 'concurrent recovery cannot unlock while original callback is still running', function () { [ $first, $store ] = fixture50(); $second = new MobiShop_Native_Checkout_Safety50( $store ); $second->register(); $callback = function ( $request ) use ( $first, $second, $store ) { ++$GLOBALS['core_calls50']; $order = new WC_Order( 0, 7 ); $first->before_save( $order ); $order->id = 201; $GLOBALS['orders50'][201] = clone $order; $first->after_save( $order ); $first->validate_final( $order, new WP_Error() ); $order->status = 'completed'; $GLOBALS['orders50'][201] = clone $order; $store->empty = true; $recovery = recover50( $second ); check50( 200 === status50( $recovery ) && true === $recovery->get_data()['checkout_locked'], 'Even completed status + empty cart cannot release live callback.' ); check50( 409 === status50( dispatch50( $second, request50( 'second-key' ), core50( $second ) ) ), 'Different key cannot run.' ); check50( 1 === $GLOBALS['core_calls50'], 'One callback only.' ); $GLOBALS['cart_empty50'] = true; return new WP_REST_Response( array( 'order_id' => 201, 'payment_result' => array( 'payment_status' => 'success' ) ) ); }; check50( 200 === status50( dispatch50( $first, request50(), $callback ) ), 'Original can finish.' ); check50( ! $store->buyers, 'Unlock after original completion only.' ); } );
	test50( 'failed durable total-rejection settlement returns uncertainty not reconfirmation', function () { [ $api, $store ] = fixture50(); $store->settlement = false; check50( 503 === status50( dispatch50( $api, request50(), core50( $api, new WC_Order( 0, 7, '1.00' ) ) ) ), 'No definitive 409 when settlement failed.' ); check50( 0 === $GLOBALS['payment50'] && count( $store->buyers ) === 1, 'No payment; blocker retained.' ); check50( 409 === status50( dispatch50( $api, request50( 'other-key' ), core50( $api ) ) ), 'No reconfirmation bypass.' ); } );
	test50( 'auth-salt rotation and same-customer reauthentication preserve durable scope', function () { [ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, null, 'throw_before_order' ) ); $GLOBALS['salt50'] = 'ROTATED-AUTH-SALT-'; unset( $GLOBALS['auth50']['SESSION-A-DO-NOT-PERSIST'] ); $GLOBALS['auth50']['REAUTHENTICATED-SAME-BUYER'] = 7; $request = request50( 'different-key' ); $request->headers['x-mobishop-session'] = 'REAUTHENTICATED-SAME-BUYER'; check50( 409 === status50( dispatch50( $api, $request, core50( $api ) ) ), 'Rotation cannot bypass old buyer claim.' ); $request->route = '/mobishop/v1/customer/checkout-attempts/fixture-key-A'; $request->method = 'GET'; $request->body = array( 'key' => 'fixture-key-A' ); check50( 202 === status50( $api->recover( $request ) ), 'Old exact attempt still reachable after reauth.' ); unset( $GLOBALS['salt50'] ); } );
	test50( 'orphan unresolved row blocks a new key even if buyer pointer is missing', function () { [ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, null, 'throw_before_order' ) ); $store->buyers = array(); check50( 409 === status50( dispatch50( $api, request50( 'new-key' ), core50( $api ) ) ), 'Orphan row not treated as absent.' ); check50( 1 === $GLOBALS['core_calls50'], 'No new core callback.' ); } );
	test50( 'missing durable callback-completion proof cannot unlock a created order', function () { [ $api, $store ] = fixture50(); $store->finish = false; check50( 503 === status50( dispatch50( $api, request50(), core50( $api ) ) ), 'Completion write failed.' ); $store->empty = true; $recovery = recover50( $api ); check50( 200 === status50( $recovery ) && true === $recovery->get_data()['checkout_locked'], 'Actual receipt visible but blocker retained.' ); check50( count( $store->buyers ) === 1, 'No timeout cleanup.' ); } );
	test50( 'late order-processed amount change fails before payment without early-rejection reset', function () { [ $api, $store ] = fixture50(); $callback = function ( $request ) use ( $api ) { ++$GLOBALS['core_calls50']; $order = new WC_Order( 0, 7 ); $api->before_save( $order ); $order->id = 202; $GLOBALS['orders50'][202] = clone $order; $api->after_save( $order ); $api->validate_final( $order, new WP_Error() ); ++$GLOBALS['stock50']; $order->status = 'pending'; $order->total = '1.00'; $GLOBALS['orders50'][202] = clone $order; $api->validate_before_gateway( $order ); ++$GLOBALS['payment50']; return new WP_REST_Response( array() ); }; check50( 503 === status50( dispatch50( $api, request50(), $callback ) ), 'Late mismatch remains uncertain.' ); check50( 0 === $GLOBALS['payment50'] && count( $store->buyers ) === 1, 'Payment stopped, uncertain hold not erased.' ); } );
	test50( 'canonical origin and subdirectory changes cannot bypass old buyer/cart scopes', function () { [ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, null, 'throw_before_order' ) ); $GLOBALS['origin50'] = 'https://renamed.example.invalid/subdirectory'; $next = new MobiShop_Native_Checkout_Safety50( $store ); $next->register(); check50( 409 === status50( dispatch50( $next, request50( 'new-key' ), core50( $next ) ) ), 'No new namespace through home_url change.' ); check50( 202 === status50( recover50( $next ) ), 'Exact old attempt still found.' ); unset( $GLOBALS['origin50'] ); } );

	test50( 'WP validation errors persist exact rejection and skip permission dispatch and order callback', function () {
		foreach ( array( array( 'rest_invalid_param', 400 ), array( 'rest_missing_callback_param', 400 ), array( 'rest_invalid_param', 422 ) ) as $case ) {
			[ $api, $store ] = fixture50(); $request = request50(); $request->validation = new WP_Error( $case[0], 'PRIVATE-VALIDATION', array( 'status' => $case[1] ) );
			add_filter( 'rest_dispatch_request', function ( $result ) { throw new RuntimeException( 'WP must skip dispatch on its error.' ); }, 900, 4 );
			$result = wp_dispatch50( $request, core50( $api ) ); $data = $result->get_data();
			check50( 409 === status50( $result ) && 50 === $data['protocol'] && 'mobishop_native_checkout50_rejected_before_dispatch' === $data['code'] && 'rejected_before_dispatch' === $data['state'] && false === $data['checkout_dispatched'] && 'fixture-key-A' === $data['attempt_key'] && 7 === $data['customer_id'] && false === $data['automatic_replay'], 'Exact flat own-key own-buyer proof.' );
			check50( 0 === $GLOBALS['core_calls50'] && ! $GLOBALS['orders50'] && ! $store->buyers && ! $store->carts, 'No callback/order/cart adoption.' );
			check50( str_contains( $result->headers['Cache-Control'], 'no-store' ), 'Private rejection no-store.' );
			check50( $data === recover50( $api )->get_data(), 'Lost rejection response has same durable recovery proof.' );
		}
	} );
	test50( 'before-callback interception always keeps WP_Error until callback-blocking boundary passed', function () {
		[ $api ] = fixture50(); $request = request50(); $error = new WP_Error( 'rest_invalid_param', '', array( 'status' => 400 ) );
		$result = $api->before_callbacks( $error, array( 'callback' => core50( $api ) ), $request );
		check50( $result instanceof WP_Error && 409 === status50( $result ) && false === $result->data['checkout_dispatched'], 'Never Response before WP dispatch check.' );
		check50( 1000 === has_action( 'rest_request_before_callbacks', array( $api, 'before_callbacks' ) ) && 1000 === has_action( 'rest_dispatch_request', array( $api, 'dispatch' ) ), 'Safety hook priority pinned, QA900 compatible.' );
		$flat = $api->after_callbacks( $result, array( 'callback' => core50( $api ) ), $request );
		check50( $flat instanceof WP_REST_Response && false === $flat->get_data()['checkout_dispatched'] && 50 === $flat->get_data()['protocol'], 'Internal REST dispatch also gets exact flat envelope only after gate.' );
		check50( 1000 === has_action( 'rest_request_after_callbacks', array( $api, 'after_callbacks' ) ), 'Actual after-callback hook registered.' );
	} );
	test50( 'after-callback flattener never manufactures proof from generic or altered late errors', function () {
		[ $api ] = fixture50(); $request = request50(); $error = new WP_Error( 'rest_invalid_param', '', array( 'status' => 400 ) );
		$original = $api->before_callbacks( $error, array( 'callback' => core50( $api ) ), $request );
		$changed = new WP_Error( 'gateway_late_error', '', array( 'status' => 400 ) );
		check50( $changed === $api->after_callbacks( $changed, array(), $request ), 'Changed code is not upgraded to authoritative rejection.' );
		$other_request = request50( 'other-key' );
		check50( $original === $api->after_callbacks( $original, array(), $other_request ), 'Same code without private same-request proof cannot flatten.' );
		check50( 0 === $GLOBALS['core_calls50'], 'No callback executed by response processing.' );
	} );
	test50( 'nonvalidation late-looking errors unknown JSON invalid keys and wrong buyers never fabricate proof', function () {
		foreach ( array( 'late_code', 'wrong_status', 'invalid_key', 'expired_auth', 'admin_cookie', 'unknown_json', 'website', 'unsupported' ) as $case ) {
			[ $api, $store ] = fixture50(); $request = request50(); $error = new WP_Error( 'rest_invalid_param', '', array( 'status' => 400 ) );
			if ( 'late_code' === $case ) { $error->code = 'woocommerce_gateway_error'; }
			if ( 'wrong_status' === $case ) { $error->data['status'] = 500; }
			if ( 'invalid_key' === $case ) { $request->headers['idempotency-key'] = "bad\nkey"; }
			if ( 'expired_auth' === $case ) { $GLOBALS['auth50'] = array(); }
			if ( 'admin_cookie' === $case ) { $GLOBALS['user50'] = 99; }
			if ( 'unknown_json' === $case ) { $request->invalid_json = true; }
			if ( 'website' === $case ) { unset( $request->body['extensions'] ); }
			if ( 'unsupported' === $case ) { $store->available = false; }
			$result = $api->before_callbacks( $error, array( 'callback' => core50( $api ) ), $request );
			check50( $result instanceof WP_Error && ! isset( $result->data['checkout_dispatched'] ) && ! $store->attempts, 'No definitive proof: ' . $case );
		}
	} );
	test50( 'rejection-winning race forbids later valid same key and permits only newly confirmed different key', function () {
		[ $api, $store ] = fixture50(); $request = request50(); $request->body['extensions'][ MobiShop_Native_Checkout_Safety50::NAMESPACE ]['protocol'] = 49;
		check50( 'rejected_before_dispatch' === dispatch50( $api, $request, core50( $api ) )->get_data()['state'], 'Rejection committed first.' );
		$next = new MobiShop_Native_Checkout_Safety50( $store ); $next->register();
		check50( 'rejected_before_dispatch' === dispatch50( $next, request50(), core50( $next ) )->get_data()['state'] && 0 === $GLOBALS['core_calls50'], 'Corrected same key is still immutable, no replay.' );
		check50( 200 === status50( dispatch50( $next, request50( 'new-explicit-confirmation' ), core50( $next ) ) ) && 1 === $GLOBALS['core_calls50'], 'Only new explicit attempt executes.' );
	} );
	test50( 'claim-winning race never overwrites unknown same key or releases active other key', function () {
		[ $first, $store ] = fixture50(); $second = new MobiShop_Native_Checkout_Safety50( $store ); $second->register();
		$callback = function ( $request ) use ( $first, $second, $store ) {
			++$GLOBALS['core_calls50']; $before = serialize( array( $store->attempts, $store->buyers ) );
			foreach ( array( 'fixture-key-A', 'different-key' ) as $key ) {
				$invalid = request50( $key ); $invalid->body['extensions'][ MobiShop_Native_Checkout_Safety50::NAMESPACE ]['confirmed']['total_price'] = -1;
				$result = dispatch50( $second, $invalid, core50( $second ) );
				check50( ! isset( $result->get_data()['checkout_dispatched'] ) && ! isset( $result->get_data()['state'] ), 'No false no-dispatch proof for existing/unresolved buyer.' );
				$error = $second->before_callbacks( new WP_Error( 'rest_invalid_param', '', array( 'status' => 400 ) ), array( 'callback' => core50( $second ) ), $invalid );
				check50( $error instanceof WP_Error && ! isset( $error->data['checkout_dispatched'] ), 'WP path also preserves original claim.' );
			}
			check50( $before === serialize( array( $store->attempts, $store->buyers ) ), 'No row or buyer lock changed by either invalid request.' );
			throw new RuntimeException( 'Original callback outcome unresolved.' );
		};
		check50( 503 === status50( dispatch50( $first, request50(), $callback ) ) && 1 === $GLOBALS['core_calls50'], 'Exactly one original callback.' );
		check50( 202 === status50( recover50( $second ) ) && 409 === status50( dispatch50( $second, request50( 'new-key' ), core50( $second ) ) ), 'Unknown remains blocked after race.' );
	} );
	test50( 'completed or rejected-before-payment existing keys cannot become no-dispatch proof', function () {
		foreach ( array( 'completed', 'rejected_before_payment' ) as $case ) {
			[ $api, $store ] = fixture50(); dispatch50( $api, request50(), core50( $api, new WC_Order( 0, 7, 'rejected_before_payment' === $case ? '1.00' : '0.00' ) ) );
			$before = serialize( array( $store->attempts, $store->buyers ) ); $request = request50(); $request->body['extensions'][ MobiShop_Native_Checkout_Safety50::NAMESPACE ]['protocol'] = 49;
			$result = dispatch50( $api, $request, core50( $api ) );
			check50( 503 === status50( $result ) && ! isset( $result->get_data()['checkout_dispatched'] ) && $before === serialize( array( $store->attempts, $store->buyers ) ), 'Existing lifecycle is never overwritten: ' . $case );
		}
	} );
	test50( 'pre-dispatch storage failure and tampered proof fail closed without missing-row retry permission', function () {
		[ $api, $store ] = fixture50(); $store->pre_rejection = false; $request = request50(); $request->body['extensions'][ MobiShop_Native_Checkout_Safety50::NAMESPACE ]['protocol'] = 49;
		check50( 503 === status50( dispatch50( $api, $request, core50( $api ) ) ) && 'unknown' === recover50( $api )->get_data()['state'], 'Unpersisted rejection remains unknown, absent row not safe.' );
		foreach ( array( 'order_id', 'guard_passed', 'dispatch_finished', 'customer_id', 'payload_hash', 'cart_scope' ) as $field ) {
			[ $api, $store ] = fixture50(); dispatch50( $api, $request, core50( $api ) ); $buyer = array_key_first( $store->attempts ); $attempt = array_key_first( $store->attempts[ $buyer ] );
			$store->attempts[ $buyer ][ $attempt ][ $field ] = in_array( $field, array( 'payload_hash', 'cart_scope' ), true ) ? str_repeat( '0', 64 ) : ( 'dispatch_finished' === $field ? 0 : 1 );
			$result = recover50( $api ); check50( in_array( status50( $result ), array( 404, 503 ), true ) && ! isset( $result->get_data()['checkout_dispatched'] ), 'All durable proof fields verified: ' . $field );
		}
	} );
	test50( 'pre-dispatch proof is exact buyer and key with no PII tokens or validation snapshot persisted', function () {
		[ $api, $store ] = fixture50(); $request = request50(); $request->validation = new WP_Error( 'rest_invalid_param', 'PRIVATE-VALIDATION', array( 'status' => 400 ) );
		wp_dispatch50( $request, core50( $api ) ); $GLOBALS['user50'] = 9;
		$result = recover50( $api, 'fixture-key-A', 9 ); check50( 404 === status50( $result ) && ! isset( $result->get_data()['attempt_key'] ), 'Foreign buyer cannot recover rejection proof.' );
		$GLOBALS['user50'] = 7; check50( 404 === status50( recover50( $api, 'absent-key' ) ), 'Different key has no inferred proof.' );
		$persisted = json_encode( $store->attempts ); foreach ( array( 'PRIVATE-', 'SESSION-', 'CART-', 'billing_address', 'private@example.invalid', 'fixture-key-A' ) as $private ) { check50( ! str_contains( $persisted, $private ), 'No raw ' . $private . ' persisted.' ); }
	} );

	/** SQL-shape/fault stub exercises production storage, NOT real DB locking. */
	final class Sql_Db50 {
		public string $prefix = 'fixture_'; public string $last_error = '';
		public bool $transaction = false; public bool $wrong_engine = false; public bool $wrong_pk = false; public bool $wrong_key = false; public bool $commit_uncertain = false;
		public string $fail_statement = ''; public array $buyers = array(); public array $attempts = array(); public array $carts = array(); public array $sessions = array(); public array $log = array();
		private array $prepared = array(); private array $snapshot = array();
		public function prepare( string $sql, ...$args ): string { $key = 'prepared-' . count( $this->prepared ); $this->prepared[$key] = array( $sql, $args ); return $key; }
		private function unpack( string $sql ): array { return $this->prepared[$sql] ?? array( $sql, array() ); }
		public function get_var( string $sql ) { [ $text, $args ] = $this->unpack($sql); $this->last_error = ''; if ( 'SELECT @@in_transaction' === $text ) { return $this->transaction ? '1' : '0'; } if ( str_contains($text, 'SELECT key_fingerprint') ) { return $this->wrong_key ? str_repeat('0',64) : hash('sha256',MOBISHOP_NATIVE_CHECKOUT50_HMAC_KEY); } if ( str_contains($text, 'SELECT buyer_scope') ) { return $this->carts[$args[0]] ?? null; } throw new RuntimeException('Unexpected get_var shape.'); }
		public function get_row( string $sql, $mode ) { [ $text, $args ] = $this->unpack($sql); $this->last_error = ''; if ( str_starts_with($text, 'SHOW TABLE STATUS') ) { return array('Name'=>$args[0],'Engine'=>$this->wrong_engine?'MyISAM':'InnoDB'); } if ( str_contains($text,'SELECT session_value') ) { return $this->sessions[$args[0]] ?? null; } if ( str_contains($text,'SELECT active_attempt') ) { return array_key_exists($args[0],$this->buyers)?array('active_attempt'=>$this->buyers[$args[0]]):null; } if ( str_contains($text,'SELECT *') ) { return $this->attempts[$args[0]][$args[1]] ?? null; } if ( str_contains($text,'SELECT attempt_hash') ) { foreach ($this->attempts[$args[0]] ?? array() as $row) { if ('in_progress'===$row['state']) { return array('attempt_hash'=>$row['attempt_hash']); } } return null; } if ( str_contains($text,'SELECT buyer_scope') ) { return isset($this->carts[$args[0]])?array('buyer_scope'=>$this->carts[$args[0]]):null; } throw new RuntimeException('Unexpected get_row shape.'); }
		public function get_results( string $sql, $mode ): array {
			$this->last_error=''; preg_match('/`fixture_mobishop_native_checkout50_(\w+)`/',$sql,$match); $name=$match[1];
			$spec=array('buyers'=>array('buyer_scope'=>'char(64)','active_attempt'=>'char(64)'), 'attempts'=>array('buyer_scope'=>'char(64)','attempt_hash'=>'char(64)','payload_hash'=>'char(64)','cart_scope'=>'char(64)','customer_id'=>'bigint unsigned','order_id'=>'bigint unsigned','state'=>'varchar(32)','payment_status'=>'varchar(16)','guard_passed'=>'tinyint unsigned','dispatch_finished'=>'tinyint unsigned','created_at'=>'datetime'), 'carts'=>array('cart_scope'=>'char(64)','buyer_scope'=>'char(64)'), 'config'=>array('id'=>'tinyint unsigned','key_fingerprint'=>'char(64)'));
			if(str_starts_with($sql,'SHOW FULL COLUMNS')) { $rows=array(); foreach($spec[$name] as $field=>$type) { $rows[]=array('Field'=>$field,'Type'=>$type,'Collation'=>str_contains($type,'char(')?'ascii_bin':null,'Null'=>'active_attempt'===$field?'YES':'NO','Default'=>in_array($field,array('order_id','guard_passed','dispatch_finished'),true)?'0':('payment_status'===$field?'':null)); } return $rows; }
			$keys='attempts'===$name?array('buyer_scope','attempt_hash'):array('buyers'===$name?'buyer_scope':('carts'===$name?'cart_scope':'id')); $rows=array(); foreach($keys as $index=>$field) { $rows[]=array('Key_name'=>$this->wrong_pk?'WRONG':'PRIMARY','Non_unique'=>0,'Sub_part'=>null,'Seq_in_index'=>$index+1,'Column_name'=>$field); } return $rows;
		}
		public function query( string $sql ) {
			[ $text,$args ]=$this->unpack($sql); $this->log[]=$text; $this->last_error='';
			if($this->fail_statement && str_contains($text,$this->fail_statement)) { $this->last_error='fixture write failure'; return false; }
			if('START TRANSACTION'===$text) { check50(!$this->transaction,'No nested transaction.'); $this->snapshot=array($this->buyers,$this->attempts,$this->carts); $this->transaction=true; return 0; }
			if('COMMIT'===$text) { $this->transaction=false; return $this->commit_uncertain?false:0; }
			if('ROLLBACK'===$text) { if($this->transaction) { [$this->buyers,$this->attempts,$this->carts]=$this->snapshot; } $this->transaction=false; return 0; }
			if(str_contains($text,'INSERT IGNORE') && str_contains($text,'_buyers')) { if(array_key_exists($args[0],$this->buyers)) { return 0; } $this->buyers[$args[0]]=null; return 1; }
			if(str_contains($text,'INSERT IGNORE') && str_contains($text,'_carts')) { if(isset($this->carts[$args[0]])) { return 0; } $this->carts[$args[0]]=$args[1]; return 1; }
			if(str_contains($text,'INSERT INTO') && str_contains($text,'_attempts')) { check50($this->transaction,'Attempt insert inside transaction.'); check50(!isset($this->attempts[$args[0]][$args[1]]),'Unique attempt enforced.'); $rejected=str_contains($text,"'rejected_before_dispatch'"); $this->attempts[$args[0]][$args[1]]=array('buyer_scope'=>$args[0],'attempt_hash'=>$args[1],'payload_hash'=>$args[2],'cart_scope'=>$args[3],'customer_id'=>$args[4],'order_id'=>0,'state'=>$rejected?'rejected_before_dispatch':'in_progress','payment_status'=>'','guard_passed'=>0,'dispatch_finished'=>$rejected?1:0); return 1; }
			if(str_contains($text,'SET active_attempt = %s')) { check50(str_contains($text,'active_attempt IS NULL'),'Conditional buyer claim.'); if(null!==$this->buyers[$args[1]]) { return 0; } $this->buyers[$args[1]]=$args[0]; return 1; }
			if(str_contains($text,'SET active_attempt = NULL')) { if(($this->buyers[$args[0]]??null)!==$args[1]) { return 0; } $this->buyers[$args[0]]=null; return 1; }
			if(str_contains($text,'SET order_id')) { $row=&$this->attempts[$args[1]][$args[2]]; if(!in_array($row['order_id'],array(0,$args[3]),true)||'in_progress'!==$row['state']) { return 0; } $row['order_id']=$args[0]; return 1; }
			if(str_contains($text,'SET guard_passed')) { $row=&$this->attempts[$args[0]][$args[1]]; if('in_progress'!==$row['state']||$row['order_id']<=0) { return 0; } $row['guard_passed']=1; return 1; }
			if(str_contains($text,'SET dispatch_finished')) { $row=&$this->attempts[$args[0]][$args[1]]; if('in_progress'!==$row['state']) { return 0; } $row['dispatch_finished']=1; return 1; }
			if(str_contains($text,'SET state')) { $row=&$this->attempts[$args[2]][$args[3]]; if('in_progress'!==$row['state']) { return 0; } $row['state']=$args[0]; $row['payment_status']=$args[1]; return 1; }
			throw new RuntimeException('Unexpected SQL query shape.');
		}
	}
	function sql_claim50( string $key='a', string $buyer='b', string $cart='c' ): array { return array('buyer_scope'=>str_repeat($buyer,64),'attempt_hash'=>str_repeat($key,64),'payload_hash'=>str_repeat('d',64),'cart_scope'=>str_repeat($cart,64),'customer_id'=>7); }
	test50( 'production storage capability verifies exact InnoDB PKs and immutable key fingerprint', function () { $db=new Sql_Db50(); $store=new MobiShop_Native_Checkout_Wpdb50($db); check50($store->ready(),'Exact schema ready.'); foreach(array('wrong_engine','wrong_pk','wrong_key','transaction') as $fault) { $db->$fault=true; check50(!$store->ready(),'Fault fails capability: '.$fault); $db->$fault=false; } check50(!$db->log,'Readiness/DDL getter perform no writes.'); } );
	test50( 'production SQL claims preserve uniqueness buyer blockers and orphan blockers', function () { $db=new Sql_Db50(); $store=new MobiShop_Native_Checkout_Wpdb50($db); $claim=sql_claim50(); check50('claimed'===$store->claim($claim)['result'],'First claimed.'); check50('existing'===$store->claim($claim)['result'],'Duplicate no second execution.'); $changed=$claim; $changed['payload_hash']=str_repeat('e',64); check50('conflict'===$store->claim($changed)['result'],'Changed body conflict.'); check50('blocked'===$store->claim(sql_claim50('f','b','g'))['result'],'New key/cart samebuyer blocked.'); $db->buyers[$claim['buyer_scope']]=null; check50('blocked'===$store->claim(sql_claim50('f','b','g'))['result'],'Orphan protected.'); } );
	test50( 'production SQL failure rolls back before callback while uncertain commit stays durable', function () { $db=new Sql_Db50(); $store=new MobiShop_Native_Checkout_Wpdb50($db); $db->fail_statement='INSERT INTO'; check50('unavailable'===$store->claim(sql_claim50())['result'],'Failed insert unavailable.'); check50(!$db->attempts&&!$db->buyers&&!$db->carts,'Transaction rolled back.'); $db->fail_statement=''; $db->commit_uncertain=true; check50('unavailable'===$store->claim(sql_claim50())['result'],'Uncertain commit unavailable.'); $db->commit_uncertain=false; check50('blocked'===$store->claim(sql_claim50('f','b','g'))['result'],'Committed uncertainty remains blocked.'); } );
	test50( 'production SQL cart binding and final settlement require durable execution completion', function () { $db=new Sql_Db50(); $store=new MobiShop_Native_Checkout_Wpdb50($db); $claim=sql_claim50(); $store->claim($claim); check50($store->associate($claim['buyer_scope'],$claim['attempt_hash'],301),'Own order associated.'); check50($store->passed($claim['buyer_scope'],$claim['attempt_hash']),'Guard persisted.'); check50(!$store->settle($claim['buyer_scope'],$claim['attempt_hash'],'order_created','unknown'),'In-flight cannot settle.'); check50($store->finished($claim['buyer_scope'],$claim['attempt_hash']),'Dispatch complete.'); check50($store->settle($claim['buyer_scope'],$claim['attempt_hash'],'order_created','success'),'Settle after completion.'); check50('cart_conflict'===$store->claim(sql_claim50('f','g','c'))['result'],'Other buyer cannot adopt claimed cart.'); } );
	test50( 'production SQL pending settlement requires an existing guarded finished order', function () {
		foreach(['valid','unassociated','unguarded','unfinished','wrong_state','invalid_payment','wrong_active_attempt'] as $case) {
			$db=new Sql_Db50();$store=new MobiShop_Native_Checkout_Wpdb50($db);$claim=sql_claim50();$store->claim($claim);
			if($case!=='unassociated')$store->associate($claim['buyer_scope'],$claim['attempt_hash'],301);
			if($case!=='unguarded')$store->passed($claim['buyer_scope'],$claim['attempt_hash']);
			if($case!=='unfinished')$store->finished($claim['buyer_scope'],$claim['attempt_hash']);
			if($case==='wrong_active_attempt')$db->buyers[$claim['buyer_scope']]=str_repeat('0',64);
			$state=$case==='wrong_state'?'rejected_before_payment':'order_created';$payment=$case==='invalid_payment'?'failed':'pending';
			$result=$store->settle($claim['buyer_scope'],$claim['attempt_hash'],$state,$payment);
			check50($result===($case==='valid'),'SQL settlement must validate pending receipt proof: '.$case);
			$row=$store->find($claim['buyer_scope'],$claim['attempt_hash']);
			check50($row['state']===($case==='valid'?'order_created':'in_progress'),'Rejected settlement must retain original attempt.');
			if($case==='valid') {
				check50($row['payment_status']==='pending','SQL record must preserve awaiting payment, never success.');
				$replay=$store->claim($claim);
				check50($replay['result']==='existing' && $replay['attempt']['payment_status']==='pending','Exact replay resolves existing SQL receipt without claiming another dispatch.');
			}
		}
	});

	test50( 'production stored session decoder rejects objects malformed PII containers and foreign buyers', function () { $db=new Sql_Db50(); $store=new MobiShop_Native_Checkout_Wpdb50($db); $db->sessions['7']=array('session_value'=>serialize(array('customer'=>serialize(array('id'=>'7')), 'cart'=>serialize(array()))),'session_expiry'=>time()+60); check50(7===$store->cart_customer('7')&&$store->cart_empty('7'),'Valid stored own session.'); $db->sessions['7']['session_value']=serialize(array('customer'=>(object)array('id'=>7))); check50(null===$store->cart_customer('7'),'No PHP object restored.'); check50(null===$store->cart_customer('absent'),'Missing source ownership unknown.'); $db->sessions['7']['session_value']='malformed'; check50(null===$store->cart_customer('7')&&!$store->cart_empty('7'),'Malformed not trusted.'); } );
	test50( 'production pre-dispatch tombstones serialize with checkout claims without adopting carts or clearing buyers', function () {
		$db = new Sql_Db50(); $store = new MobiShop_Native_Checkout_Wpdb50( $db ); $claim = sql_claim50();
		$rejected = $store->reject_before_dispatch( $claim ); $row = $rejected['attempt'];
		check50( 'rejected' === $rejected['result'] && 'rejected_before_dispatch' === $row['state'] && 0 === $row['order_id'] && 0 === $row['guard_passed'] && 1 === $row['dispatch_finished'], 'Terminal no-dispatch row persisted under buyer lock.' );
		check50( ! $db->carts && null === $db->buyers[ $claim['buyer_scope'] ], 'No cart binding or buyer active claim.' );
		check50( 'existing' === $store->claim( $claim )['result'] && 'existing' === $store->reject_before_dispatch( $claim )['result'], 'Neither claim nor rejection may replay or overwrite same key.' );
		check50( 'claimed' === $store->claim( sql_claim50( 'f' ) )['result'], 'Different fresh attempt can be claimed.' );
		$before = serialize( array( $db->attempts, $db->buyers, $db->carts ) );
		check50( 'existing' === $store->reject_before_dispatch( sql_claim50( 'f' ) )['result'] && 'blocked' === $store->reject_before_dispatch( sql_claim50( 'g' ) )['result'], 'Unknown same key returned unchanged; other key blocked.' );
		check50( $before === serialize( array( $db->attempts, $db->buyers, $db->carts ) ), 'No unresolved state changed.' );
		$db->buyers[ $claim['buyer_scope'] ] = null;
		check50( 'blocked' === $store->reject_before_dispatch( sql_claim50( 'g' ) )['result'], 'Orphan in-progress row also blocks tombstone insertion.' );
		check50( ! array_filter( $db->log, fn( $sql ) => str_contains( $sql, 'SET active_attempt = NULL' ) ), 'Pre-dispatch path never releases a buyer lock.' );
	} );
	test50( 'production pre-dispatch failed insert rolls back and uncertain commit gives no immediate proof', function () {
		$db = new Sql_Db50(); $store = new MobiShop_Native_Checkout_Wpdb50( $db ); $claim = sql_claim50();
		$db->fail_statement = 'INSERT INTO';
		check50( 'unavailable' === $store->reject_before_dispatch( $claim )['result'] && ! $db->attempts && ! $db->buyers, 'Failed rejection rolled back, no safe result.' );
		$db->fail_statement = ''; $db->commit_uncertain = true;
		check50( 'unavailable' === $store->reject_before_dispatch( $claim )['result'], 'Uncertain COMMIT not definitive rejection.' );
		$db->commit_uncertain = false; $row = $store->find( $claim['buyer_scope'], $claim['attempt_hash'] );
		check50( 'rejected_before_dispatch' === $row['state'] && 'existing' === $store->claim( $claim )['result'], 'If committed, recovery can verify tombstone and same key cannot run.' );
		check50( 'existing' === $store->reject_before_dispatch( $claim )['result'], 'A subsequent durable read sees exact original terminal row.' );
	} );
	test50( 'missing registered WP rejection boundary makes capability false without storage mutations', function () {
		[ $api, $store ] = fixture50(); unset( $GLOBALS['hooks50']['rest_request_before_callbacks'] );
		check50( false === $api->capabilities()['enforced'] && ! $store->attempts, 'Cannot promise rejection protocol without actual boundary registration.' );
	} );

	echo 'LOCAL_NATIVE_CHECKOUT50_STUB_TESTS=' . $GLOBALS['count50'] . "\n";
	echo "NOT_CERTIFIED=installed SQL concurrency, deployed hooks/schema, payment gateways, QA outbound isolation, Native checkout\n";
}
