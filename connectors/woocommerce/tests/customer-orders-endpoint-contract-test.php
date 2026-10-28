<?php
/**
 * Customer order history endpoint contract test with WordPress/Woo stubs.
 *
 * Run with: php connectors/woocommerce/tests/customer-orders-endpoint-contract-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

function wp_parse_url( $url, $component = -1 ) {
	return parse_url( $url, $component );
}

$GLOBALS['mobishop_routes']          = array();
$GLOBALS['mobishop_current_user_id'] = 7;
$GLOBALS['mobishop_order_query']     = array();
$GLOBALS['mobishop_owned_order']     = null;

class WP_REST_Server {
	public const READABLE = 'GET';
	public const CREATABLE = 'POST';
}

class WP_REST_Request {
	private array $params;

	public function __construct( array $params = array() ) {
		$this->params = $params;
	}

	public function get_param( string $key ) {
		return $this->params[ $key ] ?? null;
	}
}

class WP_REST_Response {
	public $data;
	public int $status;
	public array $headers = array();

	public function __construct( $data, int $status = 200 ) {
		$this->data   = $data;
		$this->status = $status;
	}

	public function header( string $name, string $value ): void {
		$this->headers[ $name ] = $value;
	}
}

class WP_Error {
	private string $code;
	private string $message;
	private array $data;

	public function __construct( string $code, string $message, array $data = array() ) {
		$this->code    = $code;
		$this->message = $message;
		$this->data    = $data;
	}

	public function get_error_code(): string {
		return $this->code;
	}

	public function get_error_data(): array {
		return $this->data;
	}
}

final class MobiShop_Test_Order_Item {
	public function __construct(
		private string $name,
		private int $quantity
	) {}

	public function get_name(): string {
		return $this->name;
	}

	public function get_quantity(): int {
		return $this->quantity;
	}
}

final class MobiShop_Test_Order {
	public function __construct(
		private int $id,
		private int $customer_id,
		private string $number,
		private string $status,
		private string $total,
		private array $items
	) {}

	public function get_id(): int {
		return $this->id;
	}

	public function get_customer_id(): int {
		return $this->customer_id;
	}

	public function get_order_number(): string {
		return $this->number;
	}

	public function get_status(): string {
		return $this->status;
	}

	public function is_paid(): bool { return in_array($this->status, ['processing','completed'], true); }
	public function needs_payment(): bool { return in_array($this->status, ['pending','failed'], true); }
	public function get_payment_method(): string { return $GLOBALS['mobishop_payment_method'] ?? 'card'; }
	public function get_order_key(): string { return 'wc_order_fixture' . $this->id; }
	public function get_checkout_payment_url(): string { return $GLOBALS['mobishop_payment_url'] ?? ('https://shop.example/store/checkout/order-pay/' . $this->id . '/?pay_for_order=true&key=' . $this->get_order_key()); }

	public function get_payment_method_title(): string { return 'Cash on delivery'; }
	public function get_shipping_method(): string { return 'Standard delivery'; }
	public function get_total(): string {
		return $this->total;
	}

	public function get_currency(): string {
		return 'EGP';
	}

	public function get_date_created(): DateTimeImmutable {
		return new DateTimeImmutable( '2026-07-16T20:30:00+03:00' );
	}

	public function get_items( string $type ): array {
		return 'line_item' === $type ? $this->items : array();
	}

	public function get_item_count(): int {
		return array_sum(
			array_map(
				static fn( MobiShop_Test_Order_Item $item ): int => $item->get_quantity(),
				$this->items
			)
		);
	}

	public function update_status( string $status, string $note = '', bool $notify = false ): void {
		unset( $note, $notify );
		$this->status = $status;
	}
}

function add_action( string $hook, $callback ): void {
	unset( $hook, $callback );
}

function register_rest_route( string $namespace, string $route, array $definition ): void {
	$GLOBALS['mobishop_routes'][ $namespace . $route ] = $definition;
}

function __( string $text, string $domain = '' ): string {
	unset( $domain );
	return $text;
}

function absint( $value ): int {
	return abs( (int) $value );
}

function home_url(string $path = '/'): string { return 'https://shop.example/store/'; }
function wc_get_checkout_url(): string { return 'https://shop.example/store/checkout/'; }
function wc_get_endpoint_url(string $endpoint, $value, string $base): string {
	return $GLOBALS['mobishop_endpoint_url'] ?? ($base . $endpoint . '/' . $value . '/');
}

function get_current_user_id(): int {
	return (int) $GLOBALS['mobishop_current_user_id'];
}

function sanitize_text_field( $value ): string {
	return trim( strip_tags( (string) $value ) );
}

function sanitize_key( $value ): string {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: '';
}

function wp_strip_all_tags( $value ): string {
	return strip_tags( (string) $value );
}

function wc_get_price_decimals(): int {
	return 2;
}

function wc_format_decimal( $value, int $decimals ): string {
	return number_format( (float) $value, $decimals, '.', '' );
}

function wc_price( $value, array $args = array() ): string {
	$currency = (string) ( $args['currency'] ?? '' );
	return '<span>' . $currency . '&nbsp;' . number_format( (float) $value, 2, '.', ',' ) . '</span>';
}

function wc_get_order_status_name( string $status ): string {
	return match ( $status ) {
		'processing' => 'Processing',
		'cancel-request' => 'Cancellation requested',
		default => ucfirst( $status ),
	};
}

function wc_get_account_orders_actions( MobiShop_Test_Order $order ): array {
	return match ( $order->get_status() ) {
		'pending' => array( 'cancel' => array( 'name' => 'Cancel' ) ),
		default => array(),
	};
}

function wc_get_order_statuses(): array {
	return array(
		'wc-processing'     => 'Processing',
		'wc-cancel-request' => 'Cancellation requested',
		'wc-cancelled'      => 'Cancelled',
	);
}

function apply_filters( string $hook, $value ) {
	unset( $hook );
	return $value;
}

function wc_get_order( int $order_id ) {
	$order = $GLOBALS['mobishop_owned_order'];
	return $order instanceof MobiShop_Test_Order && $order->get_id() === $order_id
		? $order
		: false;
}

function wc_get_orders( array $args ): object {
	$GLOBALS['mobishop_order_query'] = $args;
	$GLOBALS['mobishop_owned_order'] = new MobiShop_Test_Order(
		101,
		7,
		'101',
		'processing',
		'1320',
		array(
			new MobiShop_Test_Order_Item( 'Kids chair', 1 ),
			new MobiShop_Test_Order_Item( 'Toy', 2 ),
		)
	);
	return (object) array(
		'orders'        => array(
			$GLOBALS['mobishop_owned_order'],
			// The endpoint must still reject a mismatched object even if a bad
			// extension ever injects it into WooCommerce's customer query.
			new MobiShop_Test_Order( 202, 8, '202', 'completed', '99', array() ),
		),
		'total'         => 1,
		'max_num_pages' => 1,
	);
}

function mobishop_orders_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$connector_root = rtrim(getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__) . '/source', '/\\');
require $connector_root . '/api/class-customer-orders-endpoint.php';

$endpoint = new MobiShop_Customer_Orders_Endpoint();
$endpoint->register_routes();
mobishop_orders_assert( 3 === count( $GLOBALS['mobishop_routes'] ), 'History, owned order refresh, and cancellation must be registered.' );
$route = $GLOBALS['mobishop_routes']['mobishop/v1/customer/orders'];
mobishop_orders_assert( WP_REST_Server::READABLE === $route['methods'], 'Order history must be read-only.' );
$cancel_route = $GLOBALS['mobishop_routes']['mobishop/v1/customer/orders/(?P<id>\d+)/cancel'];
mobishop_orders_assert( WP_REST_Server::CREATABLE === $cancel_route['methods'], 'Order cancellation must use POST.' );

$GLOBALS['mobishop_current_user_id'] = 0;
$unauthorized = $endpoint->authenticate_customer( new WP_REST_Request() );
mobishop_orders_assert( $unauthorized instanceof WP_Error, 'A signed-out request must be rejected.' );
mobishop_orders_assert( 401 === $unauthorized->get_error_data()['status'], 'A missing session must return HTTP 401.' );

$GLOBALS['mobishop_current_user_id'] = 7;
$response = $endpoint->get_orders(
	new WP_REST_Request(
		array(
			'page'     => 1,
			'per_page' => 20,
		)
	)
);
mobishop_orders_assert( $response instanceof WP_REST_Response, 'A customer must receive an order history response.' );
mobishop_orders_assert( 7 === $GLOBALS['mobishop_order_query']['customer'], 'WooCommerce must mirror the My Account customer query.' );
mobishop_orders_assert( true === $GLOBALS['mobishop_order_query']['paginate'], 'Order history must use WooCommerce pagination.' );
mobishop_orders_assert( 1 === count( $response->data['orders'] ), 'Only the current customer order may be returned.' );
$order = $response->data['orders'][0];
mobishop_orders_assert( 'Cash on delivery' === $order['payment_method_title'], 'The receipt must use the saved payment method title.' );
mobishop_orders_assert( 'Standard delivery' === $order['shipping_method'], 'The receipt must use the saved delivery method.' );
mobishop_orders_assert( 101 === $order['id'], 'The owned order must be serialized.' );
mobishop_orders_assert( 'Processing' === $order['status_name'], 'WooCommerce status labels must be preserved.' );
mobishop_orders_assert( str_starts_with( $order['date_created'], '2026-07-16T20:30:00' ), 'Order creation time must be included.' );
mobishop_orders_assert( 2 === $order['items'][1]['quantity'], 'Line-item quantities must be included.' );
mobishop_orders_assert( ! isset( $order['billing_address'], $order['shipping_address'] ), 'Private addresses must not be exposed.' );
mobishop_orders_assert( str_contains( $order['total_display'], 'EGP' ), 'The WooCommerce-formatted total must be included.' );
mobishop_orders_assert( true === $order['can_cancel'], 'The API must mirror WooCommerce My Account cancellation actions.' );
mobishop_orders_assert( 'request' === $order['cancellation_type'], 'Processing orders must expose the website cancellation request.' );
mobishop_orders_assert( str_contains( $response->headers['Cache-Control'], 'no-store' ), 'Customer order history must never be cached.' );
mobishop_orders_assert( '1' === $response->headers['X-WP-TotalPages'], 'Pagination headers must match the payload.' );

$cancelled = $endpoint->cancel_order( new WP_REST_Request( array( 'id' => 101 ) ) );
mobishop_orders_assert( $cancelled instanceof WP_REST_Response, 'An owned order must accept a cancellation request.' );
mobishop_orders_assert( 'cancel-request' === $cancelled->data['order']['status'], 'The website cancellation-request status must be returned.' );
mobishop_orders_assert( 'requested' === $cancelled->data['cancellation_result'], 'The API must distinguish a request from direct cancellation.' );
mobishop_orders_assert( false === $cancelled->data['order']['can_cancel'], 'A cancellation request must not be submitted twice.' );

$refresh_route = $GLOBALS['mobishop_routes']['mobishop/v1/customer/orders/(?P<id>\d+)'];
mobishop_orders_assert($refresh_route['methods'] === 'GET', 'Payment refresh must remain read-only.');
mobishop_orders_assert($refresh_route['permission_callback'] === [$endpoint,'authenticate_customer'], 'Payment refresh requires the existing session.');
$GLOBALS['mobishop_current_user_id'] = 0;
mobishop_orders_assert($endpoint->get_order(new WP_REST_Request(['id'=>101]))->get_error_data()['status'] === 401, 'Signed-out refresh must fail.');
$GLOBALS['mobishop_current_user_id'] = 8;
mobishop_orders_assert($endpoint->get_order(new WP_REST_Request(['id'=>101]))->get_error_data()['status'] === 404, 'Another customer cannot discover payment status or order key.');
$GLOBALS['mobishop_current_user_id'] = 7;
mobishop_orders_assert($endpoint->get_order(new WP_REST_Request(['id'=>999]))->get_error_data()['status'] === 404, 'Missing and foreign orders must have the same response.');
$GLOBALS['mobishop_owned_order'] = new MobiShop_Test_Order(101,7,'101','pending','1320',[]);
$refresh = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
mobishop_orders_assert($refresh->data['order']['is_paid'] === false && $refresh->data['order']['needs_payment'] === true, 'Actual Woo payment predicates must be booleans.');
$valid_url = 'https://shop.example/store/checkout/order-pay/101/?pay_for_order=true&key=wc_order_fixture101';
mobishop_orders_assert($refresh->data['order']['payment_url'] === $valid_url, 'Owned pending order receives canonical same-install payment URL.');
mobishop_orders_assert($refresh->data['order']['payment_endpoint_path'] === '/store/checkout/order-pay/101/', 'Configured Woo endpoint path is explicit.');
mobishop_orders_assert(str_contains($refresh->headers['Cache-Control'],'no-store'), 'Order keys and payment status must not cache.');
mobishop_orders_assert($GLOBALS['mobishop_owned_order']->get_status() === 'pending', 'Reading a payment continuation must not change order status.');
$invalid_urls = [
    str_replace('https:', 'http:', $valid_url),
    str_replace('shop.example','foreign.example',$valid_url),
    str_replace('shop.example','shop.example:444',$valid_url),
    str_replace('shop.example','user:pass@shop.example',$valid_url),
    str_replace('/checkout/', "/check\nout/", $valid_url),
    str_replace('/checkout/', "/check\\out/", $valid_url),
    $valid_url . '#fragment',
    str_replace('/store/', '/elsewhere/', $valid_url),
    str_replace('/101/', '/102/', $valid_url),
    str_replace('/order-pay/', '/pay-custom/', $valid_url),
    str_replace('/checkout/', '/%63heckout/', $valid_url),
    str_replace('/checkout/', '/../checkout/', $valid_url),
    str_replace('/checkout/', '/checkout/./', $valid_url),
    str_replace('wc_order_fixture101','wc_order_wrong',$valid_url),
    str_replace('pay_for_order=true','pay_for_order=false',$valid_url),
    $valid_url . '&key=wc_order_fixture101',
    $valid_url . '&redirect=https://foreign.example',
    str_replace('&key=', '&key[]=', $valid_url),
    str_replace('?pay_for_order=true&key=', '?pay_for_order=true&key=ignore&key=', $valid_url),
];
foreach($invalid_urls as $invalid_url) {
    $GLOBALS['mobishop_payment_url'] = $invalid_url;
    $result = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
    mobishop_orders_assert($result->data['order']['payment_url'] === '', 'Unsafe payment URL must not be exposed.');
    mobishop_orders_assert($result->data['order']['needs_payment'] === true, 'Unavailable browser link must not claim payment success.');
}
unset($GLOBALS['mobishop_payment_url']);
$GLOBALS['mobishop_endpoint_url'] = 'https://shop.example/store/%D8%AF%D9%81%D8%B9/complete-order/101/';
$GLOBALS['mobishop_payment_url'] = $GLOBALS['mobishop_endpoint_url'] . '?pay_for_order=true&key=wc_order_fixture101';
$localized = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
mobishop_orders_assert($localized->data['order']['payment_url'] === $GLOBALS['mobishop_payment_url'], 'Configured localized checkout and custom pay slug remain supported.');
mobishop_orders_assert($localized->data['order']['payment_endpoint_path'] === '/store/%D8%AF%D9%81%D8%B9/complete-order/101/', 'Endpoint path remains exact, without allowing another host.');
foreach(['https://foreign.example/store/custom/101/','https://shop.example/outside/custom/101/','https://shop.example/store/%2e%2e/custom/101/','https://shop.example/store/a%2fcustom/101/','https://shop.example/store/a%255ccustom/101/'] as $unsafe_endpoint) {
	$GLOBALS['mobishop_endpoint_url'] = $unsafe_endpoint;
	$GLOBALS['mobishop_payment_url'] = $unsafe_endpoint . '?pay_for_order=true&key=wc_order_fixture101';
	$localized = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
	mobishop_orders_assert($localized->data['order']['payment_url'] === '' && $localized->data['order']['payment_endpoint_path'] === '', 'Custom endpoint cannot expand host or install path scope.');
}
unset($GLOBALS['mobishop_payment_url'], $GLOBALS['mobishop_endpoint_url']);
$GLOBALS['mobishop_endpoint_url'] = 'https://shop.example/store/check_out/order-pay/101/';
$GLOBALS['mobishop_payment_url'] = "https://shop.example/store/check\nout/order-pay/101/?pay_for_order=true&key=wc_order_fixture101";
$normalized_control = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
mobishop_orders_assert($normalized_control->data['order']['payment_url'] === '', 'Raw control characters must fail before parse_url can normalize them into a matching path.');
unset($GLOBALS['mobishop_payment_url'], $GLOBALS['mobishop_endpoint_url']);
$GLOBALS['mobishop_payment_method'] = 'cod';
$cod_result = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
mobishop_orders_assert($cod_result->data['order']['payment_method'] === 'cod', 'Offline payment method must be explicit so order received is not confused with captured money.');
unset($GLOBALS['mobishop_payment_method']);
foreach(['processing','completed','cancelled','refunded'] as $status) {
    $GLOBALS['mobishop_owned_order'] = new MobiShop_Test_Order(101,7,'101',$status,'1320',[]);
    $result = $endpoint->get_order(new WP_REST_Request(['id'=>101]));
    mobishop_orders_assert($result->data['order']['payment_url'] === '', 'Paid or non-payable orders must not offer payment again.');
    mobishop_orders_assert($result->data['order']['is_paid'] === in_array($status,['processing','completed'],true), 'Payment success uses Woo predicate, not mere order existence.');
}
fwrite(STDOUT, "CUSTOMER_ORDERS_CONTRACT_OK history/cancel/read ownership, configured localized paths and unsafe payment URLs; no external effects.\n");
