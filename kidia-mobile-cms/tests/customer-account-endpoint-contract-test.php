<?php
/**
 * Customer account endpoint contract test with WordPress/WooCommerce stubs.
 *
 * Run with: php kidia-mobile-cms/tests/customer-account-endpoint-contract-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_account_routes']  = array();
$GLOBALS['kidia_current_user_id'] = 7;
$GLOBALS['kidia_user_meta']       = array(
	7 => array( 'billing_phone1' => '01100000000' ),
);
$GLOBALS['kidia_customer']        = array(
	'id'           => 7,
	'email'        => 'customer@example.com',
	'first_name'   => 'Kidia',
	'last_name'    => 'Customer',
	'display_name' => 'Kidia Customer',
	'billing'      => array(
		'first_name' => 'Kidia',
		'last_name'  => 'Customer',
		'address_1'  => '1 Test Street',
		'city'       => 'Cairo',
		'state'      => 'C',
		'country'    => 'EG',
		'phone'      => '01000000000',
	),
	'shipping'     => array(),
);

class WP_REST_Server {
	public const READABLE  = 'GET';
	public const CREATABLE = 'POST';
}

class WP_REST_Request {
	public function __construct(
		private array $params = array(),
		private array $json = array()
	) {}

	public function get_param( string $key ) {
		return $this->params[ $key ] ?? null;
	}

	public function get_json_params(): array {
		return $this->json;
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
	public function __construct(
		private string $code,
		private string $message,
		private array $data = array()
	) {}

	public function get_error_code(): string {
		return $this->code;
	}

	public function get_error_data(): array {
		return $this->data;
	}
}

class WC_Customer {
	private array $data;

	public function __construct( private int $id ) {
		$this->data = $GLOBALS['kidia_customer'];
	}

	public function get_id(): int {
		return $this->id;
	}

	public function get_email(): string {
		return (string) $this->data['email'];
	}

	public function get_first_name(): string {
		return (string) $this->data['first_name'];
	}

	public function get_last_name(): string {
		return (string) $this->data['last_name'];
	}

	public function get_display_name(): string {
		return (string) $this->data['display_name'];
	}

	public function __call( string $method, array $arguments ) {
		if ( preg_match( '/^get_(billing|shipping)_(.+)$/', $method, $matches ) ) {
			return $this->data[ $matches[1] ][ $matches[2] ] ?? '';
		}
		if ( preg_match( '/^set_(billing|shipping)_(.+)$/', $method, $matches ) ) {
			$this->data[ $matches[1] ][ $matches[2] ] = (string) ( $arguments[0] ?? '' );
			return null;
		}
		throw new BadMethodCallException( $method );
	}

	public function save(): void {
		$GLOBALS['kidia_customer'] = $this->data;
	}
}

function add_action( string $hook, $callback ): void {
	unset( $hook, $callback );
}

function register_rest_route( string $namespace, string $route, array $definition ): void {
	$GLOBALS['kidia_account_routes'][ $namespace . $route ] = $definition;
}

function __( string $text, string $domain = '' ): string {
	unset( $domain );
	return $text;
}

function get_current_user_id(): int {
	return (int) $GLOBALS['kidia_current_user_id'];
}

function is_wp_error( $value ): bool {
	return $value instanceof WP_Error;
}

function sanitize_text_field( $value ): string {
	return trim( strip_tags( (string) $value ) );
}

function sanitize_key( $value ): string {
	return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: '';
}

function sanitize_email( $value ): string {
	return filter_var( (string) $value, FILTER_SANITIZE_EMAIL ) ?: '';
}

function is_email( $value ): bool {
	return false !== filter_var( (string) $value, FILTER_VALIDATE_EMAIL );
}

function email_exists( string $email ) {
	return 'used@example.com' === $email ? 99 : false;
}

function wp_update_user( array $values ) {
	if ( isset( $values['first_name'] ) ) {
		$GLOBALS['kidia_customer']['first_name'] = $values['first_name'];
	}
	if ( isset( $values['last_name'] ) ) {
		$GLOBALS['kidia_customer']['last_name'] = $values['last_name'];
	}
	if ( isset( $values['display_name'] ) ) {
		$GLOBALS['kidia_customer']['display_name'] = $values['display_name'];
	}
	if ( isset( $values['user_email'] ) ) {
		$GLOBALS['kidia_customer']['email'] = $values['user_email'];
	}
	return (int) $values['ID'];
}

function get_user_meta( int $user_id, string $key, bool $single = false ) {
	unset( $single );
	return $GLOBALS['kidia_user_meta'][ $user_id ][ $key ] ?? '';
}

function update_user_meta( int $user_id, string $key, $value ): void {
	$GLOBALS['kidia_user_meta'][ $user_id ][ $key ] = (string) $value;
}

function get_option( string $key, $default = '' ) {
	return match ( $key ) {
		'admin_email' => 'support@example.com',
		'woocommerce_store_phone' => '+201000000000',
		default => $default,
	};
}

function apply_filters( string $hook, $value ) {
	unset( $hook );
	return $value;
}

function home_url( string $path = '' ): string {
	return 'https://shop.example.com' . $path;
}

function esc_url_raw( $value ): string {
	return (string) $value;
}

function wc_sanitize_phone_number( string $value ): string {
	return preg_replace( '/[^0-9+]/', '', $value ) ?: '';
}

function kidia_account_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/api/class-customer-account-endpoint.php';

$endpoint = new Kidia_Mobile_CMS_Customer_Account_Endpoint();
$endpoint->register_routes();
kidia_account_assert( 3 === count( $GLOBALS['kidia_account_routes'] ), 'All customer account routes must be registered.' );
kidia_account_assert(
	WP_REST_Server::READABLE === $GLOBALS['kidia_account_routes']['woo-mobile/v1/customer/account']['methods'],
	'Customer account reads must use GET.'
);

$GLOBALS['kidia_current_user_id'] = 0;
$unauthorized = $endpoint->authenticate_customer( new WP_REST_Request() );
kidia_account_assert( $unauthorized instanceof WP_Error, 'Signed-out account requests must be rejected.' );
kidia_account_assert( 401 === $unauthorized->get_error_data()['status'], 'Missing sessions must return HTTP 401.' );

$GLOBALS['kidia_current_user_id'] = 7;
$account = $endpoint->get_account();
kidia_account_assert( $account instanceof WP_REST_Response, 'Signed-in customers must receive account data.' );
kidia_account_assert( 'customer@example.com' === $account->data['profile']['email'], 'The WooCommerce profile must be returned.' );
kidia_account_assert( '01000000000' === $account->data['profile']['phone'], 'The billing phone must be returned with the profile.' );
kidia_account_assert( '01100000000' === $account->data['profile']['alternate_phone'], 'The website alternate phone must be returned with the profile.' );
kidia_account_assert( '1 Test Street' === $account->data['billing']['billing_address_1'], 'Saved billing values must be returned.' );
kidia_account_assert( 'support@example.com' === $account->data['support']['email'], 'Store-controlled support details must be returned.' );
kidia_account_assert( str_contains( $account->headers['Cache-Control'], 'no-store' ), 'Private account data must not be cached.' );

$profile = $endpoint->update_profile(
	new WP_REST_Request(
		array(),
		array(
			'first_name'   => 'Updated',
			'last_name'    => 'Customer',
			'display_name' => 'Updated Customer',
			'email'        => 'updated@example.com',
			'phone'        => '012-345-67890',
			'alternate_phone' => '015-555-55555',
		)
	)
);
kidia_account_assert( 'Updated' === $profile->data['profile']['first_name'], 'Profile updates must be persisted through WordPress.' );
kidia_account_assert( 'updated@example.com' === $profile->data['profile']['email'], 'Email updates must be persisted through WordPress.' );
kidia_account_assert( '01234567890' === $profile->data['profile']['phone'], 'Phone updates must be persisted through WooCommerce.' );
kidia_account_assert( '01555555555' === $profile->data['profile']['alternate_phone'], 'Alternate phone updates must use the website billing_phone1 field.' );

$address = $endpoint->update_address(
	new WP_REST_Request(
		array( 'type' => 'shipping' ),
		array(
			'shipping_first_name' => 'Updated',
			'shipping_address_1'  => '2 New Street',
			'shipping_city'       => 'Giza',
			'shipping_country'    => 'EG',
		)
	)
);
kidia_account_assert( '2 New Street' === $address->data['address']['shipping_address_1'], 'Shipping addresses must be saved in WooCommerce.' );
kidia_account_assert( 'Giza' === $address->data['address']['shipping_city'], 'Address fields must be returned after saving.' );

fwrite( STDOUT, "Customer account endpoint contract test passed.\n" );
