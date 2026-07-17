<?php
/**
 * Product variation endpoint contract test with WooCommerce stubs.
 *
 * Run with: php kidia-mobile-cms/tests/product-variation-endpoint-contract-test.php
 */

declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_variation_routes'] = array();

class WP_REST_Server {
	public const READABLE = 'GET';
}

class WP_REST_Request implements ArrayAccess {
	public function __construct( private array $params = array() ) {}

	public function offsetExists( mixed $offset ): bool {
		return isset( $this->params[ $offset ] );
	}

	public function offsetGet( mixed $offset ): mixed {
		return $this->params[ $offset ] ?? null;
	}

	public function offsetSet( mixed $offset, mixed $value ): void {
		$this->params[ $offset ] = $value;
	}

	public function offsetUnset( mixed $offset ): void {
		unset( $this->params[ $offset ] );
	}
}

class WP_Error {
	public function __construct( public string $code, public string $message, public array $data = array() ) {}
}

class WC_Product_Variable {
	public function get_children(): array {
		return array( 5801, 5802 );
	}

	public function get_variation_attributes(): array {
		return array(
			'pa_%d8%a7%d9%84%d9%85%d9%82%d8%a7%d8%b3' => array( '26', '27' ),
		);
	}
}

class WC_Product_Variation {
	public function __construct( private int $id, private array $attributes ) {}

	public function get_id(): int {
		return $this->id;
	}

	public function get_attributes(): array {
		return $this->attributes;
	}

	public function is_purchasable(): bool {
		return true;
	}

	public function is_in_stock(): bool {
		return true;
	}

	public function get_price(): string {
		return '100';
	}

	public function get_regular_price(): string {
		return '100';
	}

	public function get_sale_price(): string {
		return '';
	}

	public function get_image_id(): int {
		return 0;
	}
}

function add_action( string $hook, $callback ): void {
	unset( $hook, $callback );
}

function register_rest_route( string $namespace, string $route, array $definition ): void {
	$GLOBALS['kidia_variation_routes'][ $namespace . $route ] = $definition;
}

function __( string $text, string $domain = '' ): string {
	unset( $domain );
	return $text;
}

function absint( $value ): int {
	return abs( (int) $value );
}

function wc_get_product( int $id ) {
	return match ( $id ) {
		58 => new WC_Product_Variable(),
		5801 => new WC_Product_Variation(
			5801,
			array( 'pa_%d8%a7%d9%84%d9%85%d9%82%d8%a7%d8%b3' => '26' )
		),
		5802 => new WC_Product_Variation( 5802, array( 'pa_' => '27' ) ),
		default => false,
	};
}

function wp_strip_all_tags( $value ): string {
	return strip_tags( (string) $value );
}

function sanitize_title( $value ): string {
	return strtolower( trim( (string) $value ) );
}

function wc_attribute_label( string $taxonomy, $product ): string {
	unset( $product );
	return $taxonomy;
}

function get_woocommerce_currency(): string {
	return 'EGP';
}

function wc_get_price_decimals(): int {
	return 2;
}

function get_woocommerce_currency_symbol( string $currency ): string {
	return $currency;
}

function wc_format_decimal( $value, int $decimals ): string {
	return number_format( (float) $value, $decimals, '.', '' );
}

function rest_ensure_response( $value ) {
	return $value;
}

function kidia_variation_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require dirname( __DIR__ ) . '/api/class-product-variation-endpoint.php';

$endpoint = new Kidia_Mobile_CMS_Product_Variation_Endpoint();
$endpoint->register_routes();
kidia_variation_assert( 1 === count( $GLOBALS['kidia_variation_routes'] ), 'The public variation route must be registered.' );

$variations = $endpoint->get_variations( new WP_REST_Request( array( 'id' => 58 ) ) );
kidia_variation_assert( 2 === count( $variations ), 'Every valid product variation must be returned.' );
$taxonomy = 'pa_%d8%a7%d9%84%d9%85%d9%82%d8%a7%d8%b3';
kidia_variation_assert( $taxonomy === $variations[0]['attributes'][0]['taxonomy'], 'Percent-encoded Arabic taxonomies must not be stripped.' );
kidia_variation_assert( $taxonomy === $variations[1]['attributes'][0]['taxonomy'], 'A uniquely resolvable pa_ key must use the parent taxonomy.' );
kidia_variation_assert( '27' === $variations[1]['attributes'][0]['value'], 'The repaired attribute value must be preserved.' );

fwrite( STDOUT, "Product variation endpoint contract test passed.\n" );
