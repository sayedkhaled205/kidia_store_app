<?php
/**
 * Product Carousels admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Product_Carousel', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Product_Carousel {

	private Kidia_Mobile_Library $library;

	public function __construct() {
		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_product_carousels',
			__( 'Product Carousels', 'kidia-mobile-cms' ),
			'kidia-mobile-product-carousels',
			'product-carousel',
			'kidia_mobile_create_product_carousel',
			'kidia_mobile_save_product_carousel',
			'kidia_mobile_duplicate_product_carousel',
			'kidia_mobile_delete_product_carousel'
		);
	}

	public function register(): void {
		$this->library->register();
	}
}