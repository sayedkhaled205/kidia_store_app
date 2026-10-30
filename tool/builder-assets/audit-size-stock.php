<?php
// Read-only audit: run with wp eval-file, outside the public web root.
require_once __DIR__ . '/class-attribute-stock-filter.php';
if ( ! defined('DOING_AJAX') ) define('DOING_AJAX', true);
$bridge = new MobiShop_Attribute_Stock_Filter();
$taxonomy = wc_attribute_taxonomy_name( 'المقاس' );
$term = get_term_by( 'slug', '3y', $taxonomy );
if ( ! $term ) throw new RuntimeException( 'Missing 3Y fixture' );
$args = array( 'post_type' => 'product', 'post_status' => 'publish', 'posts_per_page' => -1, 'fields' => 'ids', 'tax_query' => array( array( 'taxonomy' => $taxonomy, 'field' => 'term_id', 'terms' => array( $term->term_id ) ) ) );
$base = new WP_Query( $args );
$expected = array(); $excluded = array();
foreach ( $base->posts as $id ) {
	$p = wc_get_product( $id ); $matches = false;
	if ( $p->is_type( 'variable' ) ) {
		foreach ( $p->get_children() as $vid ) {
			$v = wc_get_product( $vid );
			if ( ! $v || 'publish' !== $v->get_status() || 'instock' !== $v->get_stock_status() ) continue;
			$attrs = array(); foreach ($v->get_attributes() as $key=>$value) $attrs[rawurldecode($key)]=$value;
			$taxonomy = rawurldecode($taxonomy);
			if ( isset( $attrs[$taxonomy] ) && ( '' === $attrs[$taxonomy] || '3y' === $attrs[$taxonomy] ) ) { $matches = true; break; }
		}
	} else $matches = 'instock' === $p->get_stock_status();
	if ( $matches ) $expected[] = (int) $id; else $excluded[] = (int) $id;
}
$request = new WP_REST_Request( 'GET', '/wc/store/v1/products' );
$request->set_param( 'attributes', array( array( 'attribute' => rawurldecode( $taxonomy ), 'slug' => '3y', 'operator' => 'in' ) ) );
$filteredArgs = $bridge->store_query( $args, $request );
add_filter( 'posts_clauses', array( $bridge, 'clauses' ), 40, 2 );
$start = microtime( true );
$filtered = new WP_Query( $filteredArgs );
$actual = array_map( 'intval', $filtered->posts );
$missing = array_values( array_diff( $expected, $actual ) );
$leaked = array_values( array_diff( $actual, $expected ) );
$pageArgs = array_merge( $filteredArgs, array( 'posts_per_page' => 12, 'paged' => 1 ) );
$page = new WP_Query( $pageArgs );
echo json_encode( array( 'unfiltered' => count($base->posts), 'expected' => count($expected), 'actual' => count($actual), 'found_posts' => $page->found_posts, 'page_count' => count($page->posts), 'seconds' => microtime(true)-$start, 'missing' => $missing, 'leaked' => $leaked, 'excluded_examples' => array_slice($excluded,0,4), 'available_examples' => array_slice($actual,0,4) ), JSON_PRETTY_PRINT ) . PHP_EOL;
if ( $missing || $leaked || (int) $page->found_posts !== count($expected) ) throw new RuntimeException('Stock filter mismatch');
$page2 = new WP_Query(array_merge($pageArgs, array('paged'=>2)));
$website = new WP_Query($args);
$websiteIds = array_map('intval', $website->posts);
if (array_diff($expected,$websiteIds) || array_diff($websiteIds,$expected) || array_intersect($page->posts,$page2->posts) || count($page2->posts)!==12) throw new RuntimeException('Website or pagination mismatch');
echo "WEBSITE_AND_PAGE_2_PASS\n";
