<?php
/**
 * Image Banners admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Image_Banner', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Image_Banner {

	/**
	 * Image Banners library.
	 *
	 * @var Kidia_Mobile_Library
	 */
	private Kidia_Mobile_Library $library;

	/**
	 * Creates the Image Banners module.
	 */
	public function __construct() {
		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_image_banners',
			__( 'Image Banners', 'kidia-mobile-cms' ),
			'kidia-mobile-image-banners',
			'image-banner',
			'kidia_mobile_create_image_banner',
			'kidia_mobile_save_image_banner',
			'kidia_mobile_duplicate_image_banner',
			'kidia_mobile_delete_image_banner'
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
