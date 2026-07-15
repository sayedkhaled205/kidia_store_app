<?php
/**
 * Category Grids admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Category_Grid', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Category_Grid {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_category_grids',
			__( 'Category Grids', 'kidia-mobile-cms' ),
			'kidia-mobile-category-grids',
			'category-grid',
			'kidia_mobile_create_category_grid',
			'kidia_mobile_save_category_grid',
			'kidia_mobile_duplicate_category_grid',
			'kidia_mobile_delete_category_grid'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
