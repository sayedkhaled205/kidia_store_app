<?php
/**
 * Brand Carousels admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Brand_Carousel', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Brand_Carousel {

	private Kidia_Mobile_Library $library;

	public function __construct() {
		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_brand_carousels',
			__( 'Brand Carousels', 'kidia-mobile-cms' ),
			'kidia-mobile-brand-carousels',
			'brand-carousel',
			'kidia_mobile_create_brand_carousel',
			'kidia_mobile_save_brand_carousel',
			'kidia_mobile_duplicate_brand_carousel',
			'kidia_mobile_delete_brand_carousel'
		);
	}

	public function register(): void {
		$this->library->register();
	}
}