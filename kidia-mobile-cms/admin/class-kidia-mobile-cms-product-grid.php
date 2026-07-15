<?php
/**
 * Product Grids admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Product_Grid', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Product_Grid {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_product_grids',
			__( 'Product Grids', 'kidia-mobile-cms' ),
			'kidia-mobile-product-grids',
			'product-grid',
			'kidia_mobile_create_product_grid',
			'kidia_mobile_save_product_grid',
			'kidia_mobile_duplicate_product_grid',
			'kidia_mobile_delete_product_grid'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}