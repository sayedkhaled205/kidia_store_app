<?php
/**
 * Image Banners admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Image_Banner', false ) ) {
	return;
}

final class MobiShop_Image_Banner {

	/**
	 * Image Banners library.
	 *
	 * @var MobiShop_Library
	 */
	private MobiShop_Library $library;

	/**
	 * Creates the Image Banners module.
	 */
	public function __construct() {
		$this->library = new MobiShop_Library(
			'mobishop_image_banners',
			__( 'Image Banners', 'mobishop' ),
			'mobishop-image-banners',
			'image-banner',
			'mobishop_create_image_banner',
			'mobishop_save_image_banner',
			'mobishop_duplicate_image_banner',
			'mobishop_delete_image_banner'
		);
	}

	/**
	 * Registers the module.
	 *
	 * @return void
	 */
	public function register(): void {
		$this->library->register();
	}
}