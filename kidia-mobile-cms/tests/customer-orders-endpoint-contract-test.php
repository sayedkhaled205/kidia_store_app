<?php
/**
 * Customer order history endpoint contract test with WordPress/Woo stubs.
 *
 * Run with: php kidia-mobile-cms/tests/customer-orders-endpoint-contract-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_routes']          = array();
$GLOBALS['kidia_current_user_id'] = 7;
$GLOBALS['kidia_order_query']     = array();
$GLOBALS['kidia_owned_order']     = null;

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

final class Kidia_Test_Order_Item {
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

final class Kidia_Test_Order {
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
				static fn( Kidia_Test_Order_Item $item ): int => $item->get_quantity(),
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
	$GLOBALS['kidia_routes'][ $namespace . $route ] = $definition;
}

function __( string $text, string $domain = '' ): string {
	unset( $domain );
	return $text;
}

function absint( $value ): int {
	return abs( (int) $value );
}

function get_current_user_id(): int {
	return (int) $GLOBALS['kidia_current_user_id'];
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

function wc_get_account_orders_actions( Kidia_Test_Order $order ): array {
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
	$order = $GLOBALS['kidia_owned_order'];
	return $order instanceof Kidia_Test_Order && $order->get_id() === $order_id
		? $order
		: false;
}

function wc_get_orders( array $args ): object {
	$GLOBALS['kidia_order_query'] = $args;
	$GLOBALS['kidia_owned_order'] = new Kidia_Test_Order(
		101,
		7,
		'101',
		'processing',
		'1320',
		array(
			new Kidia_Test_Order_Item( 'Kids chair', 1 ),
			new Kidia_Test_Order_Item( 'Toy', 2 ),
		)
	);
	return (object) array(
		'orders'        => array(
			$GLOBALS['kidia_owned_order'],
			// The endpoint must still reject a mismatched object even if a bad
			// extension ever injects it into WooCommerce's customer query.
			new Kidia_Test_Order( 202, 8, '202', 'completed', '99', array() ),
		),
		'total'         => 1,
		'max_num_pages' => 1,
	);
}

function kidia_orders_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/api/class-customer-orders-endpoint.php';

$endpoint = new Kidia_Mobile_CMS_Customer_Orders_Endpoint();
$endpoint->register_routes();
kidia_orders_assert( 2 === count( $GLOBALS['kidia_routes'] ), 'The history and cancellation routes must be registered.' );
$route = $GLOBALS['kidia_routes']['woo-mobile/v1/customer/orders'];
kidia_orders_assert( WP_REST_Server::READABLE === $route['methods'], 'Order history must be read-only.' );
$cancel_route = $GLOBALS['kidia_routes']['woo-mobile/v1/customer/orders/(?P<id>\d+)/cancel'];
kidia_orders_assert( WP_REST_Server::CREATABLE === $cancel_route['methods'], 'Order cancellation must use POST.' );

$GLOBALS['kidia_current_user_id'] = 0;
$unauthorized = $endpoint->authenticate_customer( new WP_REST_Request() );
kidia_orders_assert( $unauthorized instanceof WP_Error, 'A signed-out request must be rejected.' );
kidia_orders_assert( 401 === $unauthorized->get_error_data()['status'], 'A missing session must return HTTP 401.' );

$GLOBALS['kidia_current_user_id'] = 7;
$response = $endpoint->get_orders(
	new WP_REST_Request(
		array(
			'page'     => 1,
			'per_page' => 20,
		)
	)
);
kidia_orders_assert( $response instanceof WP_REST_Response, 'A customer must receive an order history response.' );
kidia_orders_assert( 7 === $GLOBALS['kidia_order_query']['customer'], 'WooCommerce must mirror the My Account customer query.' );
kidia_orders_assert( true === $GLOBALS['kidia_order_query']['paginate'], 'Order history must use WooCommerce pagination.' );
kidia_orders_assert( 1 === count( $response->data['orders'] ), 'Only the current customer order may be returned.' );
$order = $response->data['orders'][0];
kidia_orders_assert( 101 === $order['id'], 'The owned order must be serialized.' );
kidia_orders_assert( 'Processing' === $order['status_name'], 'WooCommerce status labels must be preserved.' );
kidia_orders_assert( str_starts_with( $order['date_created'], '2026-07-16T20:30:00' ), 'Order creation time must be included.' );
kidia_orders_assert( 2 === $order['items'][1]['quantity'], 'Line-item quantities must be included.' );
kidia_orders_assert( ! isset( $order['billing_address'], $order['shipping_address'] ), 'Private addresses must not be exposed.' );
kidia_orders_assert( str_contains( $order['total_display'], 'EGP' ), 'The WooCommerce-formatted total must be included.' );
kidia_orders_assert( true === $order['can_cancel'], 'The API must mirror WooCommerce My Account cancellation actions.' );
kidia_orders_assert( 'request' === $order['cancellation_type'], 'Processing orders must expose the website cancellation request.' );
kidia_orders_assert( str_contains( $response->headers['Cache-Control'], 'no-store' ), 'Customer order history must never be cached.' );
kidia_orders_assert( '1' === $response->headers['X-WP-TotalPages'], 'Pagination headers must match the payload.' );

$cancelled = $endpoint->cancel_order( new WP_REST_Request( array( 'id' => 101 ) ) );
kidia_orders_assert( $cancelled instanceof WP_REST_Response, 'An owned order must accept a cancellation request.' );
kidia_orders_assert( 'cancel-request' === $cancelled->data['order']['status'], 'The website cancellation-request status must be returned.' );
kidia_orders_assert( 'requested' === $cancelled->data['cancellation_result'], 'The API must distinguish a request from direct cancellation.' );
kidia_orders_assert( false === $cancelled->data['order']['can_cancel'], 'A cancellation request must not be submitted twice.' );

fwrite( STDOUT, "Customer orders endpoint contract test passed.\n" );
