<?php
/**
 * Standalone harness: stubs just enough of WordPress/WooCommerce/FlyCart to exercise
 * MobiShop_Discount_Rules_Catalogue_Query without a real WP/WC/FlyCart install. The stub
 * WP_Query/ProductQuery pair intentionally mirrors real call shapes (same class/function names)
 * so debug_backtrace()-based scoping in the class under test is genuinely exercised.
 */

namespace {
	define( 'ABSPATH', __DIR__ );

	// --- Minimal WP hook system -------------------------------------------------
	$GLOBALS['hooks'] = array();
	function add_filter( $hook, $cb, $priority = 10, $args = 1 ) {
		$GLOBALS['hooks'][ $hook ][] = $cb;
	}
	function add_action( $hook, $cb, $priority = 10, $args = 1 ) {
		add_filter( $hook, $cb, $priority, $args );
	}
	function remove_filter( $hook, $cb, $priority = 10 ) {
		foreach ( $GLOBALS['hooks'][ $hook ] ?? array() as $i => $registered ) {
			if ( $registered === $cb ) {
				unset( $GLOBALS['hooks'][ $hook ][ $i ] );
			}
		}
	}
	function remove_action( $hook, $cb, $priority = 10 ) {
		remove_filter( $hook, $cb, $priority );
	}
	function has_filter( $hook, $cb = false ) {
		return ! empty( $GLOBALS['hooks'][ $hook ] );
	}
	function apply_filters( $hook, $value, ...$rest ) {
		foreach ( $GLOBALS['hooks'][ $hook ] ?? array() as $cb ) {
			$value = call_user_func( $cb, $value, ...$rest );
		}
		return $value;
	}
	function do_action( $hook, ...$args ) {
		foreach ( $GLOBALS['hooks'][ $hook ] ?? array() as $cb ) {
			call_user_func( $cb, ...$args );
		}
	}

	// --- Minimal WP/WC primitives ------------------------------------------------
	function is_wp_error( $thing ) {
		return false;
	}
	function wp_parse_url($url,$component=-1) { return parse_url($url,$component); }
	function _prime_post_caches( $ids, $a = true, $b = true ) {
		$GLOBALS['test_primed'] = array_values( array_unique( array_merge( $GLOBALS['test_primed'] ?? array(), $ids ) ) );
	}
	function taxonomy_exists( $tax ) {
		return in_array( $tax, array( 'product_cat', 'product_tag', 'custom_tax' ), true );
	}
	function get_taxonomies( $args, $output ) {
		return array( 'custom_tax' );
	}
	function get_objects_in_term( $term_ids, $taxonomy ) {
		$map = $GLOBALS['test_term_members'][ $taxonomy ] ?? array();
		$out = array();
		foreach ( $term_ids as $term_id ) {
			$out = array_merge( $out, $map[ $term_id ] ?? array() );
		}
		return array_values( array_unique( $out ) );
	}
	function wp_get_post_parent_id( $id ) {
		return $GLOBALS['test_parent_of'][ $id ] ?? 0;
	}
	function wc_get_product( $id ) {
		return $GLOBALS['test_products'][ $id ] ?? false;
	}
	function wc_get_product_ids_on_sale() {
		return $GLOBALS['test_stored_on_sale'] ?? array();
	}
	function wc_get_price_decimals() {
		return 2;
	}
	function wc_format_decimal( $amount, $decimals ) {
		return (string) round( (float) $amount, $decimals );
	}
	function get_option( $key ) {
		return 'excl';
	}
	function wc_get_price_excluding_tax( $product, $args ) {
		return $args['price'];
	}
	$GLOBALS['wpdb'] = new class {
		public $posts = 'posts';
		public function get_results( $sql ) {
			preg_match('/IN \(([^)]+)\)/', $sql, $match);
			return array_map(static fn($id)=>(object)['ID'=>(int)$id,'post_parent'=>$GLOBALS['test_parent_of'][(int)$id]??0], explode(',', $match[1]));
		}
	};

	final class WP_Query {
		public array $query_vars = array();
		public int $found_posts  = 0;
		public function get( $key ) {
			return $this->query_vars[ $key ] ?? null;
		}
		public function set( $key, $value ) {
			$this->query_vars[ $key ] = $value;
		}
		public function query( $args ) {
			$this->query_vars = $args;
			if(!empty($GLOBALS['test_nested_query']) && empty($GLOBALS['test_nesting'])) {
				$GLOBALS['test_nesting']=true;
				$GLOBALS['test_nested_result']=(new WP_Query())->query(['post_type'=>'product','fields'=>'ids','post__in'=>[999]]);
				$GLOBALS['test_nesting']=false;
			}
			do_action( 'pre_get_posts', $this );
			$all = $GLOBALS['test_all_product_ids'];
			$ids = ! empty( $this->query_vars['post__in'] )
				? array_values( array_intersect( $all, $this->query_vars['post__in'] ) )
				: $all;
			if ( ! empty( $this->query_vars['post__not_in'] ) ) {
				$ids = array_values( array_diff( $ids, $this->query_vars['post__not_in'] ) );
			}
			$this->found_posts = count( $ids );
			return $ids;
		}
	}

	final class WP_REST_Request implements \ArrayAccess {
		private array $params  = array();
		private array $headers = array();
		public function __construct( private string $method = 'GET', private string $route = '/wc/store/v1/products' ) {}
		public function get_method() {
			return $this->method;
		}
		public function get_route() {
			return $this->route;
		}
		public function set_header( $key, $value ) {
			$this->headers[ strtolower( $key ) ] = $value;
		}
		public function get_header( $key ) {
			return $this->headers[ strtolower( $key ) ] ?? null;
		}
		public function set_param( $key, $value ) {
			$this->params[ $key ] = $value;
		}
		public function get_param( $key ) {
			return $this->params[ $key ] ?? null;
		}
		public function offsetExists( $offset ): bool {
			return isset( $this->params[ $offset ] );
		}
		public function offsetGet( $offset ): mixed {
			return $this->params[ $offset ] ?? null;
		}
		public function offsetSet( $offset, $value ): void {
			$this->params[ $offset ] = $value;
		}
		public function offsetUnset( $offset ): void {
			unset( $this->params[ $offset ] );
		}
	}

	final class FakeProduct {
		public function __construct( private int $id, private string $type, private $regular, private $price, private array $children = array() ) {}
		public function get_id() {
			return $this->id;
		}
		public function is_type( $types ) {
			return in_array( $this->type, (array) $types, true );
		}
		public function get_regular_price() {
			return $this->regular;
		}
		public function get_price() {
			return $this->price;
		}
		public function get_parent_id() {
			return $GLOBALS['test_parent_of'][ $this->id ] ?? 0;
		}
		public function get_children() {
			return $this->children;
		}
		public function get_visible_children() { return $this->children; }
		public function is_on_sale() { return in_array($this->id,$GLOBALS['test_stored_on_sale'],true); }
		public function get_variation_prices( $for_display ) {
			$prices = array( 'price' => array() );
			foreach ( $this->children as $child_id ) {
				$prices['price'][ $child_id ] = true;
			}
			return $prices;
		}
	}

	final class FakeRule {
		private array $filters;
		public $rule;
		public function __construct( array $filters, string $channel = 'all' ) {
			$this->filters = $filters;
			$this->rule    = (object) array( 'additional' => json_encode( array( 'mobishop_channel' => $channel ) ) );
		}
		public function getFilter() {
			return $this->filters;
		}
	}

	final class UnsupportedRule {
		public $rule;
		public function __construct() {
			$this->rule = (object) array( 'additional' => json_encode( array( 'mobishop_channel' => 'all' ) ) );
		}
	}
}

namespace Automattic\WooCommerce\StoreApi\Schemas { class ExtendSchema {} }
namespace Automattic\WooCommerce\StoreApi {
	class SchemaController {}
	class StoreApi { public static function container() { return new class { public function get($class) { return new $class(); } }; } }
}
namespace Automattic\WooCommerce\StoreApi\Schemas\V1 {
	class ProductSchema {
		public function __construct($extend,$controller) {}
		protected function prepare_product_price_response($product) {
			if(isset($GLOBALS['test_schema_prices'][$product->get_id()])) return $GLOBALS['test_schema_prices'][$product->get_id()];
			$price=$product->get_price(); $regular=$product->get_regular_price(); $range=null;
			if($product->is_type('variable')) {
				$children=array_map('wc_get_product',$product->get_visible_children());
				$values=array_map(static fn($p)=>(float)$p->get_price(),$children);
				$price=min($values); $regular=min(array_map(static fn($p)=>(float)$p->get_regular_price(),$children));
				if(min($values)!==max($values)) $range=(object)['min_amount'=>(string)(min($values)*100),'max_amount'=>(string)(max($values)*100)];
			}
			return ['currency_minor_unit'=>2,'price'=>(string)((float)$price*100),'regular_price'=>(string)((float)$regular*100),'sale_price'=>(string)((float)$price*100),'price_range'=>$range];
		}
	}
}

namespace Automattic\WooCommerce\StoreApi\Utilities {
	// Mirrors the real class's shape closely enough for debug_backtrace()-based scoping,
	// without reimplementing Woo's own query-building (not under test here).
	class ProductQuery {
		public static array $prepared_args  = array();
		public static int $prepare_calls    = 0;
		public function prepare_objects_query( $request ) {
			self::$prepare_calls++;
			$args            = self::$prepared_args;
			$args['fields']  = 'ids';
			$args['orderby'] = $args['orderby'] ?? 'title';
			$on_sale         = $request['on_sale'];
			if ( is_bool( $on_sale ) ) {
				$key          = $on_sale ? 'post__in' : 'post__not_in';
				$sale_ids     = \wc_get_product_ids_on_sale() ?: array( 0 );
				$args[ $key ] = array_merge( (array) ( $args[ $key ] ?? array() ), $sale_ids );
			}
			return $args;
		}
		public function add_query_clauses( $clauses, $query ) {
			return $clauses;
		}
		/** Shaped like Woo's own get_results(): paged retry on an out-of-range page. */
		public function get_results( $request ) {
			$args    = $this->prepare_objects_query( $request );
			$query   = new \WP_Query();
			$results = $query->query( $args );
			$total   = count( $results );
			if ( $total < 1 && (int) ( $args['paged'] ?? 1 ) > 1 ) {
				unset( $args['paged'] );
				$retry = new \WP_Query();
				$retry->query( $args );
				$total = $retry->found_posts;
			}
			return array( 'results' => $results, 'total' => $total );
		}
	}
}

namespace Wdr\App\Controllers {
	class ManageDiscount {
		public static array $rules = array();
		public function getDiscountRules() {
			return self::$rules;
		}
	}
}

namespace {
	$root = getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ?: __DIR__ . '/../source';
	require $root . '/includes/class-mobishop-discount-channel.php';
	require $root . '/api/class-discount-rules-prices.php';
	require $root . '/api/class-discount-rules-catalogue-query.php';

	$checks = array();
	$fail   = static function ( $label ) {
		throw new \RuntimeException( 'FAILED: ' . $label );
	};

	function reset_fixture() {
		$GLOBALS['hooks']               = array();
		$GLOBALS['test_all_product_ids'] = array();
		$GLOBALS['test_products']        = array();
		$GLOBALS['test_parent_of']       = array();
		$GLOBALS['test_stored_on_sale']  = array();
		$GLOBALS['test_term_members']    = array();
		$GLOBALS['test_primed']          = array();
		\Wdr\App\Controllers\ManageDiscount::$rules = array();
		\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array();
		\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepare_calls = 0;
		$GLOBALS['test_schema_prices']=array();
		$GLOBALS['test_nested_query']=false;
		$GLOBALS['test_nesting']=false;
		$_SERVER['HTTP_X_MOBISHOP_CHANNEL']='mobile';
		$_SERVER['REQUEST_URI']='/wp-json/wc/store/v1/products';
	}

	function install_flycart( array $quote_by_id ) {
		add_filter(
			'advanced_woo_discount_rules_get_product_discount_price',
			function ( $default, $product, $qty, $tax ) use ( $quote_by_id ) {
				$GLOBALS['test_quote_calls'][] = $product->get_id();
				return $quote_by_id[ $product->get_id() ] ?? false;
			}
		);
	}

	/** Builds a Store API collection handler, exactly as rest_dispatch_request would receive it. */
	function make_handler( callable $callback ) {
		return array( 'callback' => $callback );
	}

	function run_products_handler( \WP_REST_Request $request, int $per_page = 10, int $paged = 1 ) {
		\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array(
			'post_type'      => 'product',
			'posts_per_page' => $per_page,
			'paged'          => $paged,
		);
		return ( new \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery() )->get_results( $request );
	}

	$make_request = static function ( bool $mobile = true, ?bool $on_sale = true, string $route = '/wc/store/v1/products' ) {
		$request = new \WP_REST_Request( 'GET', $route );
		if ( $mobile ) {
			$request->set_header( 'X-MobiShop-Channel', 'mobile' );
		}
		if ( null !== $on_sale ) {
			$request->set_param( 'on_sale', $on_sale );
		}
		return $request;
	};

	// 1. Scope guards: wrong method/route/header/missing bool/no FlyCart must add zero hooks
	//    and never invoke the candidate pipeline for an otherwise-matching request.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 1, 2, 3 );
	$handler_calls = 0;
	$handler       = make_handler(
		function ( $request ) use ( &$handler_calls ) {
			$handler_calls++;
			return 'handled';
		}
	);
	$wrong_method = new \WP_REST_Request( 'POST', '/wc/store/v1/products' );
	$wrong_method->set_header( 'X-MobiShop-Channel', 'mobile' );
	$wrong_method->set_param( 'on_sale', true );
	$guard_cases = array(
		'wrong method'  => $wrong_method,
		'wrong route'   => $make_request( true, true, '/wc/store/v1/products/5' ),
		'no header'     => $make_request( false, true ),
		'non-bool sale' => $make_request( true, null ),
	);
	foreach ( $guard_cases as $label => $request ) {
		$out = MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $request, $request->get_route(), $handler );
		$checks[ "guard: $label returns null" ] = null === $out;
	}
	$checks['guard: FlyCart unavailable skips'] = null === MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request(), '/wc/store/v1/products', $handler );
	$checks['guard: no extra work, handler never called'] = 0 === $handler_calls;
	$checks['guard: no stray pre_get_posts hooks left'] = empty( $GLOBALS['hooks']['pre_get_posts'] ?? array() );

	// 2. Include/exclude: WP_Query ignoring post__not_in once post__in is set must not happen;
	//    our own baseline resolution must intersect/subtract explicitly.
	reset_fixture();
	install_flycart( array() );
	$GLOBALS['test_all_product_ids'] = array( 1, 2, 3, 4, 5, 6 );
	$GLOBALS['test_stored_on_sale']  = array( 3, 5 );
	foreach ( array( 1, 2, 3, 4, 5, 6 ) as $id ) {
		$GLOBALS['test_products'][ $id ] = new FakeProduct( $id, 'simple', '100', '100' );
	}
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array(
		'post__in'       => array( 1, 2, 3, 4 ),
		'post__not_in'   => array( 2 ),
		'posts_per_page' => 10,
		'paged'          => 1,
	);
	$seen_true = null;
	$handler   = make_handler(
		function ( $request ) use ( &$seen_true ) {
			$result    = run_products_handler( $request );
			$seen_true = $result['results'];
			return $result;
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	// Q = {1,2,3,4} minus excluded {2} = {1,3,4}; stored on sale within Q = {3}; no rules => no quotes.
	sort( $seen_true );
	$checks['include/exclude: baseline respects both, on_sale=true yields stored sale within Q'] = array( 3 ) === $seen_true;

	$seen_false = null;
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array('post__in'=>array(1,2,3,4),'post__not_in'=>array(2),'posts_per_page'=>10,'paged'=>1);
	$handler    = make_handler(
		function ( $request ) use ( &$seen_false ) {
			$result     = run_products_handler( $request );
			$seen_false = $result['results'];
			return $result;
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, false ), '/wc/store/v1/products', $handler );
	sort( $seen_false );
	$checks['true/false set difference: on_sale=false is exactly Q minus the true set'] = array( 1, 4 ) === $seen_false;

	// 3. Stored-sale upward override + zero price: a rule-targeted candidate not stored on
	//    sale becomes on_sale via a dynamic quote, including a legitimate zero-price quote.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 10, 11, 12 );
	$GLOBALS['test_stored_on_sale']  = array();
	$GLOBALS['test_products'][10]    = new FakeProduct( 10, 'simple', '100', '100' );
	$GLOBALS['test_products'][11]    = new FakeProduct( 11, 'simple', '50', '50' );
	$GLOBALS['test_products'][12]    = new FakeProduct( 12, 'simple', '30', '30' );
	install_flycart(
		array(
			10 => 40.0, // upward override: not stored on sale, dynamic quote beats regular.
			11 => 0.0,  // legitimate zero price.
		)
	);
	\Wdr\App\Controllers\ManageDiscount::$rules = array(
		new FakeRule( array( (object) array( 'type' => 'products', 'method' => 'in_list', 'value' => array( 10, 11, 12 ) ) ) ),
	);
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	sort( $seen );
	$checks['stored-sale upward override + zero price: both quoted products are on sale'] = array( 10, 11 ) === $seen;

	// 4. Non-target: product 12 above was quoted (candidate, same rule) but had no discount,
	//    so it must be absent from on_sale=true and present for on_sale=false.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 10, 11, 12 );
	$GLOBALS['test_stored_on_sale']  = array();
	$GLOBALS['test_products'][10]    = new FakeProduct( 10, 'simple', '100', '100' );
	$GLOBALS['test_products'][11]    = new FakeProduct( 11, 'simple', '50', '50' );
	$GLOBALS['test_products'][12]    = new FakeProduct( 12, 'simple', '30', '30' );
	install_flycart( array( 10 => 40.0, 11 => 0.0 ) ); // 12 gets no quote: false from the filter default.
	\Wdr\App\Controllers\ManageDiscount::$rules = array(
		new FakeRule( array( (object) array( 'type' => 'products', 'method' => 'in_list', 'value' => array( 10, 11, 12 ) ) ) ),
	);
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, false ), '/wc/store/v1/products', $handler );
	sort( $seen );
	$checks['non-target: unquoted candidate with no discount is not treated as on sale'] = array( 12 ) === $seen;

	// 5. Variable result semantics: must match MobiShop_Discount_Rules_Prices::prices() exactly
	//    (cheapest visible child), not a first-child/any-child shortcut.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 20 );
	$GLOBALS['test_stored_on_sale']  = array();
	$GLOBALS['test_parent_of']       = array( 21 => 20, 22 => 20 );
	$GLOBALS['test_products'][20]    = new FakeProduct( 20, 'variable', '', '', array( 21, 22 ) );
	$GLOBALS['test_products'][21]    = new FakeProduct( 21, 'variation', '100', '100' );
	$GLOBALS['test_products'][22]    = new FakeProduct( 22, 'variation', '80', '80' );
	// First child (21) gets no discount; only the cheaper, later child (22) does.
	install_flycart( array( 22 => 60.0 ) );
	\Wdr\App\Controllers\ManageDiscount::$rules = array(
		new FakeRule( array( (object) array( 'type' => 'products', 'method' => 'in_list', 'value' => array( 20 ) ) ) ),
	);
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	$checks['variable result semantics: parent is on sale from a non-first cheaper child quote'] = array( 20 ) === $seen;

	// 6. Unknown filter broadening: an unsupported filter type must widen to the whole
	//    baseline set rather than silently excluding an eligible product.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 30, 31 );
	$GLOBALS['test_stored_on_sale']  = array();
	$GLOBALS['test_products'][30]    = new FakeProduct( 30, 'simple', '100', '100' );
	$GLOBALS['test_products'][31]    = new FakeProduct( 31, 'simple', '100', '100' );
	install_flycart( array( 31 => 50.0 ) ); // Only reachable if broadening includes product 31.
	\Wdr\App\Controllers\ManageDiscount::$rules = array(
		new FakeRule( array( (object) array( 'type' => 'product_attributes', 'method' => 'in_list', 'value' => array( 1 ) ) ) ),
	);
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	sort( $seen );
	$checks['unknown filter type broadens rather than discards'] = array( 31 ) === $seen;

	// 7. Category/tag targeting: direct term ids only, no include_children; non-members
	//    of the rule's categories are never quoted even if otherwise eligible.
	reset_fixture();
	$GLOBALS['test_all_product_ids']  = array( 40, 41 );
	$GLOBALS['test_stored_on_sale']   = array();
	$GLOBALS['test_products'][40]     = new FakeProduct( 40, 'simple', '100', '100' );
	$GLOBALS['test_products'][41]     = new FakeProduct( 41, 'simple', '100', '100' );
	$GLOBALS['test_term_members']     = array( 'product_cat' => array( 5 => array( 40 ) ) );
	install_flycart(
		array(
			40 => 50.0,
			41 => 50.0, // Would be on sale if (incorrectly) quoted; must never be called.
		)
	);
	\Wdr\App\Controllers\ManageDiscount::$rules = array(
		new FakeRule( array( (object) array( 'type' => 'product_category', 'method' => 'in_list', 'value' => array( 5 ) ) ) ),
	);
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$GLOBALS['test_quote_calls'] = array();
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	$checks['category targeting: only the category member is ever quoted']      = array( 40 ) === array_values( array_unique( $GLOBALS['test_quote_calls'] ) );
	$checks['category targeting: only the category member ends up on sale']     = array( 40 ) === $seen;

	// 8. Nested query isolation/cleanup: the temporary pre_get_posts hook must not affect an
	//    unrelated nested WP_Query, and must be fully removed once dispatch() returns.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 50, 51 );
	$GLOBALS['test_stored_on_sale']  = array( 50 );
	$GLOBALS['test_products'][50]    = new FakeProduct( 50, 'simple', '100', '100' );
	$GLOBALS['test_products'][51]    = new FakeProduct( 51, 'simple', '100', '100' );
	install_flycart( array() );
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$unrelated_ids = null;
	$handler       = make_handler(
		function ( $request ) use ( &$unrelated_ids ) {
			// A nested WP_Query with a different post_type/fields shape must pass through untouched.
			$nested              = new \WP_Query();
			$GLOBALS['test_all_product_ids_nested'] = array( 999 );
			$nested->set( 'post_type', 'shipping_class' );
			$nested->set( 'fields', 'all' );
			$unrelated_ids = ( function () use ( $nested ) {
				$all = $GLOBALS['test_all_product_ids'];
				$nested->query_vars = array( 'post_type' => 'shipping_class', 'fields' => 'all' );
				\do_action( 'pre_get_posts', $nested );
				return $nested->get( 'post__in' );
			} )();
			return run_products_handler( $request );
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	$checks['nested query isolation: unrelated query is never given a post__in override'] = null === $unrelated_ids;
	$checks['cleanup: pre_get_posts hook removed after dispatch returns']                 = empty( $GLOBALS['hooks']['pre_get_posts'] ?? array() );

	// 9. Reentrancy: dispatch() called again while already dispatching must be a strict no-op.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 60 );
	install_flycart( array() );
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$reentrant_result = 'unset';
	$handler = make_handler(
		function ( $request ) use ( &$reentrant_result ) {
			$reentrant_result = MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $request, '/wc/store/v1/products', make_handler( fn() => 'inner' ) );
			return run_products_handler( $request );
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	$checks['reentrancy: nested dispatch call returns null without recursing'] = null === $reentrant_result;

	// 10. Counts/retry: an out-of-range page retries with the same corrected ids, without
	//     recomputing the baseline/candidate pipeline a second time.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 70, 71 );
	$GLOBALS['test_stored_on_sale']  = array(); // Nothing stored on sale and no rules => truly empty on_sale=true result.
	$GLOBALS['test_products'][70]    = new FakeProduct( 70, 'simple', '100', '100' );
	$GLOBALS['test_products'][71]    = new FakeProduct( 71, 'simple', '100', '100' );
	install_flycart( array() );
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 1, 'paged' => 5 );
	$retry_result = null;
	$handler      = make_handler(
		function ( $request ) use ( &$retry_result ) {
			$retry_result = run_products_handler( $request, 1, 5 );
			return $retry_result;
		}
	);
	$prepare_calls_before = \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepare_calls;
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	// The candidate pipeline's own prepare_objects_query call (baseline) plus the handler's
	// single real-query prepare call: exactly 2, regardless of the handler's internal
	// out-of-range retry (which re-runs WP_Query, not prepare_objects_query).
	$checks['counts/retry: baseline/candidates computed exactly once, not repeated by retry'] = 2 === ( \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepare_calls - $prepare_calls_before );
	$checks['counts/retry: out-of-range page retry reuses the same corrected (empty) total']  = 0 === $retry_result['total'];

	// 11. No active allowed rules: no quotes at all, Q is governed purely by stored sale status.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 80, 81 );
	$GLOBALS['test_stored_on_sale']  = array( 80 );
	$GLOBALS['test_products'][80]    = new FakeProduct( 80, 'simple', '100', '100' );
	$GLOBALS['test_products'][81]    = new FakeProduct( 81, 'simple', '100', '100' );
	install_flycart( array( 81 => 10.0 ) ); // Must never be reached: no rules means no candidates.
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$GLOBALS['test_quote_calls'] = array();
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	$checks['no active allowed rules: no quotes, stored sale set used as-is'] = array( 80 ) === $seen && empty( $GLOBALS['test_quote_calls'] );

	// 12. Channel scoping: a rule scoped to 'website' must not apply on the mobile channel.
	reset_fixture();
	$GLOBALS['test_all_product_ids'] = array( 90 );
	$GLOBALS['test_stored_on_sale']  = array();
	$GLOBALS['test_products'][90]    = new FakeProduct( 90, 'simple', '100', '100' );
	install_flycart( array( 90 => 10.0 ) );
	\Wdr\App\Controllers\ManageDiscount::$rules = array(
		new FakeRule( array( (object) array( 'type' => 'products', 'method' => 'in_list', 'value' => array( 90 ) ) ), 'website' ),
	);
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args = array( 'post__in' => array(), 'posts_per_page' => 10, 'paged' => 1 );
	$seen = null;
	$handler = make_handler(
		function ( $request ) use ( &$seen ) {
			$seen = run_products_handler( $request )['results'];
			return array();
		}
	);
	MobiShop_Discount_Rules_Catalogue_Query::dispatch( null, $make_request( true, true ), '/wc/store/v1/products', $handler );
	$checks['channel scoping: a website-only rule does not apply to the mobile collection'] = array() === $seen;

	// Complete include exclusion must remain empty, rather than turn into an unrestricted query.
	reset_fixture(); install_flycart([]);
	$GLOBALS['test_all_product_ids']=[1,2]; $GLOBALS['test_stored_on_sale']=[2];
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args=['post__in'=>[1,2],'post__not_in'=>[1,2]];
	$out=MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',make_handler(fn($r)=>run_products_handler($r)));
	$checks['complete include/exclude stays empty']=$out['results']===[];

	// A real stored sale can be overridden up to regular price by a FlyCart rule.
	reset_fixture(); install_flycart([1=>100]);
	$GLOBALS['test_all_product_ids']=[1]; $GLOBALS['test_stored_on_sale']=[1];
	$GLOBALS['test_products'][1]=new FakeProduct(1,'simple','100','50');
	\Wdr\App\Controllers\ManageDiscount::$rules=[new FakeRule([(object)['type'=>'products','method'=>'in_list','value'=>[1]]])];
	$out=MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',make_handler(fn($r)=>run_products_handler($r)));
	$checks['stored sale overridden to regular is removed']=$out['results']===[];

	// Equal-price variations retain Woo's sale flag when every overlaid field is identical.
	reset_fixture(); install_flycart([22=>60]);
	$GLOBALS['test_all_product_ids']=[20]; $GLOBALS['test_stored_on_sale']=[20];
	$GLOBALS['test_parent_of']=[21=>20,22=>20];
	$GLOBALS['test_products'][20]=new FakeProduct(20,'variable','60','60',[21,22]);
	$GLOBALS['test_products'][21]=new FakeProduct(21,'variation','60','60');
	$GLOBALS['test_products'][22]=new FakeProduct(22,'variation','100','60');
	\Wdr\App\Controllers\ManageDiscount::$rules=[new FakeRule([(object)['type'=>'products','method'=>'in_list','value'=>[20]]])];
	$out=MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',make_handler(fn($r)=>run_products_handler($r)));
	$checks['tied unchanged variable display retains sale']=$out['results']===[20];

	// A directly requested variation inherits the product/category targets of its parent.
	foreach(['products','product_category'] as $target_type) {
		reset_fixture(); install_flycart([22=>50]);
		$GLOBALS['test_all_product_ids']=[22]; $GLOBALS['test_parent_of']=[22=>20];
		$GLOBALS['test_products'][22]=new FakeProduct(22,'variation','100','100');
		$GLOBALS['test_term_members']=['product_cat'=>[5=>[20]]];
		\Wdr\App\Controllers\ManageDiscount::$rules=[new FakeRule([(object)['type'=>$target_type,'method'=>'in_list','value'=>[$target_type==='products'?20:5]]])];
		$handler=make_handler(function($r) {
			\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args=['post_type'=>'product_variation'];
			return (new \Automattic\WooCommerce\StoreApi\Utilities\ProductQuery())->get_results($r);
		});
		$out=MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',$handler);
		$checks['variation parent target '.$target_type]=$out['results']===[22];
	}

	// Same-shape nested product query, with Woo get_results still on the call stack.
	reset_fixture(); install_flycart([]);
	$GLOBALS['test_all_product_ids']=[1,2,999]; $GLOBALS['test_stored_on_sale']=[1];
	$GLOBALS['test_nested_query']=true;
	\Automattic\WooCommerce\StoreApi\Utilities\ProductQuery::$prepared_args=['post__in'=>[1,2]];
	$out=MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',make_handler(fn($r)=>run_products_handler($r)));
	$checks['nested product query is not captured by outer Woo stack']=$out['results']===[1] && $GLOBALS['test_nested_result']===[999];

	// Throwing handlers cannot leave the temporary hook or dispatch guard attached.
	try { MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',make_handler(function(){throw new \RuntimeException('fixture');})); } catch(\RuntimeException $e) {}
	$checks['exception removes temporary hook']=empty($GLOBALS['hooks']['pre_get_posts']);
	$out=MobiShop_Discount_Rules_Catalogue_Query::dispatch(null,$make_request(),'/wc/store/v1/products',make_handler(fn()=>42));
	$checks['exception clears dispatch guard']=$out===42;

	foreach ( $checks as $label => $passed ) {
		if ( ! $passed ) {
			$fail( $label );
		}
	}
	echo 'PASS: ' . count( $checks ) . " catalogue on_sale filter repair invariants\n";
}
