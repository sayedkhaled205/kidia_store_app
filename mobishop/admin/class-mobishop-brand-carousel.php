<?php
/**
 * Brand Carousels admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Brand_Carousel', false ) ) {
	return;
}

final class MobiShop_Brand_Carousel {

	private MobiShop_Library $library;

	public function __construct() {
		$this->library = new MobiShop_Library(
			'mobishop_brand_carousels',
			__( 'Brand Carousels', 'mobishop' ),
			'mobishop-brand-carousels',
			'brand-carousel',
			'mobishop_create_brand_carousel',
			'mobishop_save_brand_carousel',
			'mobishop_duplicate_brand_carousel',
			'mobishop_delete_brand_carousel'
		);
	}

	public function register(): void {
		$this->library->register();
	}
}