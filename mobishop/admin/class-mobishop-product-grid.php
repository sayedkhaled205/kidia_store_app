<?php
/**
 * Product Grids admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Product_Grid', false ) ) {
	return;
}

final class MobiShop_Product_Grid {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_product_grids',
			__( 'Product Grids', 'mobishop' ),
			'mobishop-product-grids',
			'product-grid',
			'mobishop_create_product_grid',
			'mobishop_save_product_grid',
			'mobishop_duplicate_product_grid',
			'mobishop_delete_product_grid'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}