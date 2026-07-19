<?php
/** Category page endpoint contract test. */
declare( strict_types=1 );
define( 'ABSPATH', __DIR__ );

$GLOBALS['routes'] = array();
$GLOBALS['settings'] = array(
	'version' => 2,
	'enabled' => true,
	'general' => array( 'image_size' => 80, 'image_shape' => 'circle', 'font_size' => 18 ),
	'categories' => array(
		1 => array( 'order' => 1, 'hidden' => false, 'image_id' => 0, 'name' => '' ),
		2 => array( 'order' => 0, 'hidden' => false, 'image_id' => 99, 'name' => 'App First Root' ),
		3 => array( 'order' => 0, 'hidden' => true, 'image_id' => 0, 'name' => '' ),
	),
);

class WP_REST_Server { public const READABLE = 'GET'; }
class WP_REST_Request {
	public function __construct( private array $params ) {}
	public function get_param( string $key ) { return $this->params[ $key ] ?? null; }
}
class WP_REST_Response {
	public array $headers = array();
	public function __construct( public $data, public int $status = 200 ) {}
	public function header( string $name, string $value ): void { $this->headers[ $name ] = $value; }
}
class WP_Error {}
class WP_Term {
	public function __construct( public int $term_id, public string $name, public string $slug, public int $parent, public int $count = 1, public string $description = '' ) {}
}
function add_action( string $hook, $callback ): void {}
function register_rest_route( string $namespace, string $route, array $definition ): void { $GLOBALS['routes'][ $namespace . $route ] = $definition; }
function taxonomy_exists( string $taxonomy ): bool { return 'product_cat' === $taxonomy; }
function get_terms( array $args ): array {
	return array(
		new WP_Term( 1, 'Second root', 'second', 0 ),
		new WP_Term( 2, 'First root', 'first', 0 ),
		new WP_Term( 3, 'Hidden child', 'hidden', 2 ),
		new WP_Term( 4, 'Visible child', 'visible', 2 ),
	);
}
function is_wp_error( $value ): bool { return $value instanceof WP_Error; }
function get_option( string $name, $default ) { return $GLOBALS['settings']; }
function absint( $value ): int { return abs( (int) $value ); }
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_hex_color( $value ) { return preg_match( '/^#[0-9A-Fa-f]{6}$/', (string) $value ) ? strtoupper( (string) $value ) : null; }
function get_term_meta( int $id, string $key, bool $single ) { return 0; }
function wp_get_attachment_image_url( int $id, string $size ) { return 99 === $id ? 'https://example.com/' . $size . '.jpg' : false; }
function get_post_meta( int $id, string $key, bool $single ) { return 'Override'; }
function get_term_link( WP_Term $term ) { return 'https://example.com/' . $term->slug; }

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-category-page-store.php';
require dirname( __DIR__ ) . '/api/class-category-page-endpoint.php';
$endpoint = new Kidia_Mobile_CMS_Category_Page_Endpoint();
$endpoint->register_routes();
assert( isset( $GLOBALS['routes']['woo-mobile/v1/category-page'] ) );
$response = $endpoint->get_categories( new WP_REST_Request( array( 'page' => 1, 'per_page' => 100 ) ) );
assert( array_column( $response->data, 'id' ) === array( 2, 4, 1 ) );
assert( 'https://example.com/full.jpg' === $response->data[0]['image']['src'] );
assert( 'App First Root' === $response->data[0]['name'] );
assert( 'circle' === $response->data[0]['presentation']['image_shape'] );
assert( 80 === $response->data[0]['presentation']['image_size'] );
assert( 18 === $response->data[0]['presentation']['image_radius'] );
assert( 10 === $response->data[0]['presentation']['image_text_gap'] );
assert( 18 === $response->data[0]['presentation']['font_size'] );
assert( '3' === $response->headers['X-WP-Total'] );
echo "category-page-endpoint-contract-test: ok\n";
