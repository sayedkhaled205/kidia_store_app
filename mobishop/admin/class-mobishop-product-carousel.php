<?php
/**
 * Product Carousels admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Product_Carousel', false ) ) {
	return;
}

final class MobiShop_Product_Carousel {

	private MobiShop_Library $library;

	public function __construct() {
		$this->library = new MobiShop_Library(
			'mobishop_product_carousels',
			__( 'Product Carousels', 'mobishop' ),
			'mobishop-product-carousels',
			'product-carousel',
			'mobishop_create_product_carousel',
			'mobishop_save_product_carousel',
			'mobishop_duplicate_product_carousel',
			'mobishop_delete_product_carousel'
		);
	}

	public function register(): void {
		$this->library->register();
	}
}