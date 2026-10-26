<?php
/** Run through WP-CLI eval-file in an isolated local WordPress + WooCommerce site. */
if ( ! defined( 'WP_CLI' ) || ! WP_CLI || 'local' !== wp_get_environment_type() || ! getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) ) {
	exit( 1 );
}
if ( class_exists( 'MobiShop_Product_Variation_Endpoint', false ) ) {
	throw new RuntimeException( 'Skip the installed connector; test the extracted release instead.' );
}
require getenv( 'MOBISHOP_CONNECTOR_TEST_ROOT' ) . '/api/class-product-variation-endpoint.php';
$endpoint = new MobiShop_Product_Variation_Endpoint();
$endpoint->register();
rest_get_server();
$endpoint->register_routes(); // WP-CLI/WooCommerce may have initialized REST before eval-file.
$checks = array();
$check = static function ( $condition, $label ) use ( &$checks ) {
	if ( ! $condition ) { throw new RuntimeException( $label ); }
	$checks[] = $label;
};
$admins = get_users( array( 'role' => 'administrator', 'number' => 1 ) );
$check( ! empty( $admins ), 'Isolated administrator exists.' );
global $wpdb;
$wpdb->query( 'START TRANSACTION' );
try {
	update_option( 'woocommerce_hide_out_of_stock_items', 'no' );
	$parent = new WC_Product_Variable();
	$parent->set_name( 'Public variation access regression fixture' );
	$parent->set_status( 'publish' );
	$parent->set_catalog_visibility( 'visible' );
	$parent_id = $parent->save();
	$child_ids = array();
	foreach ( array( 'publish', 'private' ) as $status ) {
		$child = new WC_Product_Variation();
		$child->set_parent_id( $parent_id );
		$child->set_status( $status );
		$child->set_regular_price( '100' );
		$child->set_attributes( array( 'size' => '26' ) );
		$child_ids[] = $child->save();
	}
	WC_Product_Variable::sync( $parent_id );
	$request = new WP_REST_Request( 'GET', '/mobishop/v1/products/' . $parent_id . '/variations' );
	foreach ( array( 0, $admins[0]->ID ) as $user_id ) {
		wp_set_current_user( $user_id );
		$context = $user_id ? 'administrator' : 'anonymous';
		foreach ( array( 'draft', 'private', 'pending', 'future', 'trash' ) as $status ) {
			$parent = wc_get_product( $parent_id );
			$parent->set_status( $status );
			if ( 'future' === $status ) { $parent->set_date_created( time() + DAY_IN_SECONDS ); }
			$parent->save();
			$response = rest_do_request( $request );
			$check( 404 === $response->get_status(), $context . ': reject ' . $status );
			$check( 'mobishop_product_not_found' === $response->get_data()['code'], 'Uniform unavailable response: ' . $context . ' ' . $status . ': ' . wp_json_encode( $response->get_data() ) );
		}
		$parent = wc_get_product( $parent_id );
		$parent->set_date_created( time() - DAY_IN_SECONDS );
		$parent->set_status( 'publish' );
		$parent->set_catalog_visibility( 'hidden' );
		$parent->save();
		$check( 404 === rest_do_request( $request )->get_status(), $context . ': reject hidden parent' );
		$parent->set_catalog_visibility( 'visible' );
		$parent->save();
		wp_update_post( array( 'ID' => $parent_id, 'post_password' => 'fixture-password' ) );
		$check( 404 === rest_do_request( $request )->get_status(), $context . ': reject password-protected parent' );
		wp_update_post( array( 'ID' => $parent_id, 'post_password' => '' ) );
		foreach ( array( 'visible', 'catalog', 'search' ) as $visibility ) {
			$parent = wc_get_product( $parent_id );
			$parent->set_catalog_visibility( $visibility );
			$parent->save();
			$response = rest_do_request( $request );
			$check( 200 === $response->get_status(), $context . ': published ' . $visibility . ' succeeds' );
			$rows = $response->get_data();
			$check( array( $child_ids[0] ) === array_column( $rows, 'id' ), $context . ': exclude disabled/private child for ' . $visibility );
			$check( '10000' === $rows[0]['prices']['price'], $context . ': public variation price intact' );
		}
	}
	wp_set_current_user( 0 );
	$hidden_filter = static fn( $visible, $id ) => $id === $parent_id ? false : $visible;
	add_filter( 'woocommerce_product_is_visible', $hidden_filter, 10, 2 );
	$check( 404 === rest_do_request( $request )->get_status(), 'Honor a storefront visibility extension.' );
	remove_filter( 'woocommerce_product_is_visible', $hidden_filter, 10 );
	$child = wc_get_product( $child_ids[0] );
	$child->set_stock_status( 'outofstock' );
	$child->save();
	WC_Product_Variable::sync( $parent_id );
	$rows = rest_do_request( $request )->get_data();
	$check( 1 === count( $rows ) && false === $rows[0]['is_in_stock'], 'Out-of-stock option remains visible when the store allows it.' );
	update_option( 'woocommerce_hide_out_of_stock_items', 'yes' );
	$check( array() === rest_do_request( $request )->get_data(), 'Hide the out-of-stock public child while the disabled sibling remains in stock.' );
	$disabled_child = wc_get_product( $child_ids[1] );
	$disabled_child->set_stock_status( 'outofstock' );
	$disabled_child->save();
	WC_Product_Variable::sync( $parent_id );
	$check( ! wc_get_product( $parent_id )->is_in_stock(), 'WooCommerce fixture parent is now out of stock.' );
	$check( 404 === rest_do_request( $request )->get_status(), 'Hide an out-of-stock parent when store settings require it.' );
	update_option( 'woocommerce_hide_out_of_stock_items', 'no' );
	$child->set_stock_status( 'instock' );
	$child->set_regular_price( '' );
	$child->set_price( '' );
	$child->save();
	WC_Product_Variable::sync( $parent_id );
	$check( array() === rest_do_request( $request )->get_data(), 'Exclude an invisible variation with no price.' );
	$check( 404 === rest_do_request( new WP_REST_Request( 'GET', '/mobishop/v1/products/2147483647/variations' ) )->get_status(), 'Missing parent returns 404.' );
	$check( 404 === rest_do_request( new WP_REST_Request( 'GET', '/mobishop/v1/products/' . $child_ids[0] . '/variations' ) )->get_status(), 'A variation ID cannot stand in for a variable parent.' );
} finally {
	$wpdb->query( 'ROLLBACK' );
	wp_set_current_user( 0 );
	wp_cache_flush();
}
echo wp_json_encode( array( 'passed' => count( $checks ), 'checks' => $checks, 'fixtures' => 'rolled back' ), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES ) . PHP_EOL;
