<?php
/** Public product matrix regression tests; run against source or extracted release. */
declare( strict_types=1 );
define( 'ABSPATH', __DIR__ );
class WP_REST_Server { const READABLE = 'GET'; }
class WP_REST_Request extends ArrayObject {}
class WP_Error {
	public function __construct( public string $code, public string $message, public array $data ) {}
}
class WC_Product_Variable {
	public string $status = 'publish';
	public string $visibility = 'visible';
	public bool $stock = true;
	public int $reads = 0;
	public array $children = array( 5801, 5802 );
	public function get_id() { return 58; }
	public function get_status() { return $this->status; }
	public function get_catalog_visibility() { return $this->visibility; }
	public function is_in_stock() { return $this->stock; }
	public function get_children() { ++$this->reads; return $this->children; }
	public function get_variation_attributes() { ++$this->reads; return array( 'pa_%d8%a7%d9%84%d9%85%d9%82%d8%a7%d8%b3' => array( '26', '27' ) ); }
}
class WC_Product_Variation {
	public string $status = 'publish';
	public bool $visible = true;
	public bool $stock = true;
	public int $parent = 58;
	public int $reads = 0;
	public function __construct( public int $id, public array $attributes ) {}
	public function get_id() { return $this->id; }
	public function get_parent_id() { return $this->parent; }
	public function get_status() { return $this->status; }
	public function variation_is_visible() { return $this->visible; }
	public function is_in_stock() { return $this->stock; }
	public function is_purchasable() { return $this->stock; }
	public function get_attributes() { ++$this->reads; return $this->attributes; }
	public function get_price() { ++$this->reads; return '100'; }
	public function get_regular_price() { return '100'; }
	public function get_sale_price() { return ''; }
	public function get_image_id() { return 0; }
}
function register_rest_route( $namespace, $path, $route ) { $GLOBALS['route'] = $route; }
function __( $text, $domain ) { return $text; }
function absint( $value ) { return abs( (int) $value ); }
function is_wp_error( $value ) { return $value instanceof WP_Error; }
function wc_get_product( $id ) { return $GLOBALS['products'][$id] ?? false; }
function get_post_field( $field, $id, $context ) { return $GLOBALS['passwords'][$id] ?? ''; }
function get_option( $name ) { return $GLOBALS['hide_stock'] ? 'yes' : 'no'; }
function apply_filters( $hook, $value, ...$args ) { return $GLOBALS['public_visibility']; }
function wp_strip_all_tags( $value ) { return strip_tags( (string) $value ); }
function sanitize_title( $value ) { return strtolower( trim( (string) $value ) ); }
function wc_attribute_label( $taxonomy, $product ) { return $taxonomy; }
function get_woocommerce_currency() { return 'EGP'; }
function get_woocommerce_currency_symbol( $currency ) { return $currency; }
function wc_get_price_decimals() { return 2; }
function wc_format_decimal( $value, $decimals ) { return number_format( (float) $value, $decimals, '.', '' ); }
function rest_ensure_response( $value ) { return $value; }
function check( $condition, $message ) {
	if ( ! $condition ) { throw new RuntimeException( $message ); }
	++$GLOBALS['checks'];
}
$GLOBALS['checks'] = 0;
$root = getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: dirname( __DIR__ ) . '/source';
require $root . '/api/class-product-variation-endpoint.php';
$endpoint = new MobiShop_Product_Variation_Endpoint();
$endpoint->register_routes();
$permission = $GLOBALS['route']['permission_callback'];
check( is_callable( $permission ) && '__return_true' !== $permission, 'Route must enforce public product access.' );
$request = new WP_REST_Request( array( 'id' => 58 ) );
$parent = new WC_Product_Variable();
$one = new WC_Product_Variation( 5801, array( 'pa_%d8%a7%d9%84%d9%85%d9%82%d8%a7%d8%b3' => '26' ) );
$two = new WC_Product_Variation( 5802, array( 'pa_' => '27' ) );
$GLOBALS['products'] = array( 58 => $parent, 5801 => $one, 5802 => $two );
$GLOBALS['passwords'] = array();
$GLOBALS['hide_stock'] = false;
$GLOBALS['public_visibility'] = true;
$deny = static function ( $label ) use ( $endpoint, $permission, $request, $parent ) {
	$before = $parent->reads;
	foreach ( array( $permission( $request ), $endpoint->get_variations( $request ) ) as $response ) {
		check( is_wp_error( $response ) && 404 === $response->data['status'] && 'mobishop_product_not_found' === $response->code, $label );
	}
	check( $before === $parent->reads, 'Denied parent must not reveal or read variation data: ' . $label );
};
foreach ( array( 'draft', 'private', 'pending', 'future', 'trash', 'auto-draft' ) as $status ) {
	$parent->status = $status;
	$deny( 'Reject ' . $status . ' regardless of user capability.' );
}
$parent->status = 'publish';
$parent->visibility = 'hidden'; $deny( 'Reject hidden parent.' );
$parent->visibility = 'visible';
$GLOBALS['passwords'][58] = 'protected'; $deny( 'Reject password-protected parent.' );
$GLOBALS['passwords'] = array();
$GLOBALS['public_visibility'] = false; $deny( 'Respect storefront visibility restriction.' );
$GLOBALS['public_visibility'] = true;
$GLOBALS['hide_stock'] = true; $parent->stock = false; $deny( 'Respect hidden out-of-stock parent.' );
$parent->stock = true; $GLOBALS['hide_stock'] = false;
foreach ( array( 'visible', 'catalog', 'search' ) as $visibility ) {
	$parent->visibility = $visibility;
	check( true === $permission( $request ), 'Allow published ' . $visibility . ' parent.' );
	$rows = $endpoint->get_variations( $request );
	check( 2 === count( $rows ), 'Public variations preserved.' );
	check( '10000' === $rows[0]['prices']['price'], 'Price contract preserved.' );
	check( $rows[0]['attributes'][0]['taxonomy'] === $rows[1]['attributes'][0]['taxonomy'], 'Repair Arabic attribute key from parent.' );
}
foreach ( array( 'draft', 'private', 'pending', 'future', 'trash' ) as $status ) {
	$two->status = $status; $before = $two->reads;
	check( 1 === count( $endpoint->get_variations( $request ) ), 'Exclude nonpublic child ' . $status );
	check( $before === $two->reads, 'Do not read protected child payload.' );
}
$two->status = 'publish';
$two->parent = 99; check( 1 === count( $endpoint->get_variations( $request ) ), 'Reject foreign child.' );
$two->parent = 58;
$GLOBALS['passwords'][5802] = 'protected'; check( 1 === count( $endpoint->get_variations( $request ) ), 'Reject password-protected child.' );
$GLOBALS['passwords'] = array();
$two->visible = false; check( 1 === count( $endpoint->get_variations( $request ) ), 'Respect variation visibility.' );
$two->visible = true; $two->stock = false;
$rows = $endpoint->get_variations( $request );
check( 2 === count( $rows ) && false === $rows[1]['is_in_stock'], 'Keep stock flags when out-of-stock display is enabled.' );
$GLOBALS['hide_stock'] = true;
check( 1 === count( $endpoint->get_variations( $request ) ), 'Respect hidden out-of-stock child.' );
unset( $GLOBALS['products'][58] ); $deny( 'Missing product uses the same 404.' );
$GLOBALS['products'][58] = new stdClass(); $deny( 'Non-variable product uses the same 404.' );
echo 'PASS: ' . $GLOBALS['checks'] . " public variation access assertions.\n";
