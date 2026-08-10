<?php
/**
 * Category Grids admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Category_Grid', false ) ) {
	return;
}

final class MobiShop_Category_Grid {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_category_grids',
			__( 'Category Grids', 'mobishop' ),
			'mobishop-category-grids',
			'category-grid',
			'mobishop_create_category_grid',
			'mobishop_save_category_grid',
			'mobishop_duplicate_category_grid',
			'mobishop_delete_category_grid'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}