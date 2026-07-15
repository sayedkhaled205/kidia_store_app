<?php
/**
 * Coupon Banners admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Coupon_Banner', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Coupon_Banner {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_coupon_banners',
			__( 'Coupon Banners', 'kidia-mobile-cms' ),
			'kidia-mobile-coupon-banners',
			'coupon-banner',
			'kidia_mobile_create_coupon_banner',
			'kidia_mobile_save_coupon_banner',
			'kidia_mobile_duplicate_coupon_banner',
			'kidia_mobile_delete_coupon_banner'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
