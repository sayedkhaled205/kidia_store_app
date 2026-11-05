<?php
/** Exercise final catalog SQL against synthetic product/variation records; run with PDO SQLite. */
define( 'ABSPATH', __DIR__ );
$api = ($argv[1] ?? '') === 'api';
define( 'REST_REQUEST', $api );
$root = getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: __DIR__ . '/../source';
require $argv[2] ?? $root . '/api/class-attribute-stock-filter.php';

function check( $ok, $message ) {
	if ( ! $ok ) throw new RuntimeException( $message );
	echo "PASS $message\n";
}
function is_admin() { return $GLOBALS['admin'] ?? false; }
function wp_doing_ajax() { return false; }
function get_option( $name ) { return 'woocommerce_hide_out_of_stock_items' === $name ? $GLOBALS['hide'] : ( $GLOBALS['display'] ?? 'excl' ); }
function wc_tax_enabled() { return $GLOBALS['taxes'] ?? false; }
function wc_get_price_decimals() { return $GLOBALS['decimals'] ?? 2; }
function wc_prices_include_tax() { return $GLOBALS['prices_include_tax'] ?? false; }
class WC_Tax {
	public static function get_tax_class_slugs() { return array( 'reduced' ); }
	public static function get_rates( $class ) { return array( 'reduced' === $class ? 0.1 : 0.2 ); }
	public static function get_base_tax_rates( $class ) { return self::get_rates( $class ); }
	public static function calc_tax( $amount, $rates, $inclusive ) { return array( $inclusive ? $amount - $amount / (1 + $rates[0]) : $amount * $rates[0] ); }
	public static function calc_inclusive_tax( $amount, $rates ) { return self::calc_tax( $amount, $rates, true ); }
	public static function get_tax_total( $taxes ) { return array_sum( $taxes ); }
}
function wp_unslash( $v ) { return $v; }
function get_taxonomies() { return array( 'pa_size', 'pa_color' ); }
function get_object_taxonomies( $v ) { return array( 'product_cat', 'pa_size', 'pa_color' ); }
function wc_attribute_label( $t ) { return $t; }
function absint( $v ) { return abs( (int) $v ); }
function sanitize_title( $v ) { return strtolower( $v ); }
function is_wp_error( $v ) { return false; }
function get_term_by( $field, $value, $tax ) {
	if ( 'product_type' === $tax && 'variable' === $value ) return (object) array( 'term_taxonomy_id' => 99 );
	if ( 'pa_size' === $tax && in_array( $value, array( 21, 'm' ), true ) ) return (object) array( 'term_id' => 21, 'slug' => 'm' );
	return false;
}
function get_term( $id, $tax ) { return get_term_by( 'id', $id, $tax ); }
function add_filter( $hook, $callback, $priority, $args = 1 ) { $GLOBALS['hooks'][$hook][$priority][] = $callback; }
function add_action( $hook, $callback, $priority = 10, $args = 1 ) { add_filter( $hook, $callback, $priority, $args ); }
function apply_filters( $hook, $value, ...$args ) {
	$priorities = $GLOBALS['hooks'][$hook] ?? array();
	ksort( $priorities );
	foreach ( $priorities as $callbacks ) foreach ( $callbacks as $callback ) $value = $callback( $value, ...$args );
	return $value;
}

class CatalogStockFixtureQuery {
	public $main = false;
	public function __construct( private array $vars ) {}
	public function get( $key ) { return $this->vars[$key] ?? ''; }
	public function set( $key, $value ) { $this->vars[$key] = $value; }
	public function is_post_type_archive( $type ) { return $this->main && 'product' === $type; }
	public function is_tax( $tax = null ) { return false; }
	public function is_main_query() { return $this->main; }
}

$db = new PDO( 'sqlite::memory:' );
$wpdb = new class( $db ) {
	public $posts = 'posts', $prefix = '', $postmeta = 'postmeta', $term_relationships = 'term_relationships', $term_taxonomy = 'term_taxonomy';
	public function __construct( private PDO $db ) {}
	public function prepare( $sql, ...$args ) {
		return preg_replace_callback( '/%[sdf]/', function ( $match ) use ( &$args ) {
			$value = array_shift( $args );
			return '%s' === $match[0] ? $this->db->quote( (string) $value ) : (string) (float) $value;
		}, $sql );
	}
};
$db->exec( "CREATE TABLE posts(ID INTEGER PRIMARY KEY,post_type TEXT,post_parent INTEGER,post_status TEXT);
	CREATE TABLE postmeta(post_id INTEGER,meta_key TEXT,meta_value TEXT);
	CREATE TABLE wc_product_meta_lookup(product_id INTEGER,stock_status TEXT,tax_status TEXT DEFAULT 'taxable',tax_class TEXT DEFAULT '',min_price NUMERIC DEFAULT 0);
	CREATE TABLE term_relationships(object_id INTEGER,term_taxonomy_id INTEGER);
	CREATE TABLE term_taxonomy(term_taxonomy_id INTEGER,term_id INTEGER);
	INSERT INTO term_taxonomy VALUES (99,9),(121,21);" );
foreach ( range( 1, 8 ) as $id ) {
	$db->exec( "INSERT INTO posts VALUES ($id,'product',0,'publish'); INSERT INTO wc_product_meta_lookup(product_id,stock_status) VALUES ($id,'instock');" );
	if ( $id !== 7 ) $db->exec( "INSERT INTO term_relationships VALUES ($id,99),($id,121)" );
}
$variants = array(
	// Parent 1 is stale: the cheap variation is unavailable. Parent 2 has a genuine free variation.
	array( 11, 1, 'outofstock', '0', 'm' ), array( 12, 1, 'instock', '100', 'l' ),
	array( 21, 2, 'instock', '0', 'm' ), array( 31, 3, 'instock', '', 'm' ),
	array( 41, 4, 'outofstock', '0', 'm' ), array( 51, 5, 'onbackorder', '15', '' ),
	array( 61, 6, 'instock', '10', 'm' ), array( 81, 8, 'instock', '10', 'm' ),
);
foreach ( $variants as [$id,$parent,$stock,$price,$size] ) {
	$db->exec( "INSERT INTO posts VALUES ($id,'product_variation',$parent,'publish');
		INSERT INTO wc_product_meta_lookup(product_id,stock_status) VALUES ($id,'$stock');
		INSERT INTO postmeta VALUES ($id,'_price','$price'),($id,'attribute_pa_size','$size');" );
}
$db->exec( "UPDATE posts SET post_status='draft' WHERE ID=81" );
$wp = (object) array( 'query_vars' => array( 'rest_route' => '/wc/store/v1/products' ) );
$hide = 'yes';
$bridge = new MobiShop_Attribute_Stock_Filter();
$bridge->register();
$clauses = fn( $q ) => apply_filters( 'posts_clauses', array( 'where' => '' ), $q )['where'];
$base = array( 'post_type' => 'product', 'post_status' => 'publish', 'fields' => 'ids' );
if ( ! $api ) $base = apply_filters( 'woof_products_query', $base );
function ids( $q, $paging = '' ) {
	global $clauses, $db;
	$sql = "SELECT ID FROM posts WHERE post_type='product'" . $clauses( $q ) . " ORDER BY ID $paging";
	return array_map( 'intval', $db->query( $sql )->fetchAll( PDO::FETCH_COLUMN ) );
}
function catalog( $base, $limits = array(), $selected = array() ) {
	global $api;
	$_GET = $limits;
	if ( $api ) $base = array_merge( $base, $limits );
	$base['mobishop_stock_attributes'] = $selected;
	return new CatalogStockFixtureQuery( $base );
}
$all = catalog( $base );
check( array( 1,2,5,6,7 ) === ids( $all ), 'stale stock, draft and missing prices excluded; backorders and simple products retained' );
check( array( 1,2 ) === ids( $all,'LIMIT 2 OFFSET 0' ) && array( 5,6 ) === ids( $all,'LIMIT 2 OFFSET 2' ), 'filters run before pagination' );
check( array( 2,7 ) === ids( catalog( $base, array( 'max_price' => '0' ) ) ), 'a real zero price survives; an unavailable zero does not' );
$limits = array( 'min_price' => $api ? '1000' : '10', 'max_price' => $api ? '1500' : '15' );
$size = array( array( 'taxonomy' => 'pa_size', 'terms' => array(21) ) );
check( array( 5,6 ) === ids( catalog( $base, $limits, $size ) ), 'same available variation satisfies size and both inclusive price bounds' );
if ( $api ) {
	$decimals = 3;
	check( array( 5,6,7 ) === ids( catalog( $base, array( 'min_price'=>'10000', 'max_price'=>'15000' ) ) ), 'Store API honors merchant currency minor units' );
	$decimals = 2;
	$zero = catalog( $base );
	$_GET = array( 'max_price' => '0' );
	check( array(2,7) === ids( $zero ), 'Store API zero bound survives Woo dropping empty zero query var' );
	$db->exec( 'UPDATE wc_product_meta_lookup SET min_price=5 WHERE product_id=7' );
	check( array(2) === ids( $zero ), 'strict zero range also excludes a paid simple product' );
	$db->exec( 'UPDATE wc_product_meta_lookup SET min_price=0 WHERE product_id=7' );
	foreach ( ['/wc/store/v1/checkout', '/wc/store/v1/cart','/wc/store/v1/products/2','/mobishop/v1/customer/auth'] as $other ) {
		$wp->query_vars['rest_route'] = $other;
		check( '' === $clauses( catalog( $base ) ), 'scope excludes '.$other );
	}
	$wp->query_vars['rest_route'] = '/wc/store/v1/products';
	$taxes = true;
	$display = 'incl';
	$db->exec( "UPDATE wc_product_meta_lookup SET tax_class='reduced' WHERE product_id=6; UPDATE wc_product_meta_lookup SET tax_class='parent' WHERE product_id=61" );
	check( array(6,7) === ids( catalog( $base, array( 'min_price'=>'1100', 'max_price'=>'1100' ) ) ), 'tax-inclusive Store API range uses inherited variation tax class' );
	$display = 'excl';
	$prices_include_tax = true;
	$db->exec( "UPDATE postmeta SET meta_value='11' WHERE post_id=61 AND meta_key='_price'" );
	check( array(6,7) === ids( catalog( $base, array( 'min_price'=>'1000', 'max_price'=>'1000' ) ) ), 'tax-exclusive Store API range honors tax-inclusive stored price' );
	$taxes = false;
} else {
	$_GET = array();
	$normal = new CatalogStockFixtureQuery( array( 'post_type' => 'product' ) );
	check( '' === $clauses( $normal ), 'unmarked product widgets excluded' );
	$normal->main = true;
	check( array(1,2,5,6,7) === ids($normal), 'ordinary main Woo shop archive included' );
	$taxes = true;
	$display = 'incl';
	check( array(6,7) === ids( catalog( $base, array( 'min_price'=>'12', 'max_price'=>'12' ) ) ), 'catalog price widget inclusive-tax range' );
	$taxes = false;
	$_GET = array();
	$GLOBALS['WOOF'] = new class { public function get_request_data() { return array( 'max_price' => '0' ); } };
	check( array(2,7) === ids( new CatalogStockFixtureQuery( apply_filters( 'woof_products_query', $base ) ) ), 'WOOF parsed price survives SEO and AJAX filter paths' );
	unset( $GLOBALS['WOOF'] );
}
$hide = 'no';
check( '' === $clauses( catalog( $base ) ), 'hide-out-of-stock off preserves normal Woo results' );
check( array(2,3,6) === ids( catalog( $base, array(), $size ) ), 'original selected-size behavior preserved with option off' );
$admin = true;
check( '' === $clauses( catalog( $base, array(), $size ) ), 'administrator product lists excluded' );
