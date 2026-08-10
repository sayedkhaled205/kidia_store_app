<?php
/**
 * Coupon Banners admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Coupon_Banner', false ) ) {
	return;
}

final class MobiShop_Coupon_Banner {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_coupon_banners',
			__( 'Coupon Banners', 'mobishop' ),
			'mobishop-coupon-banners',
			'coupon-banner',
			'mobishop_create_coupon_banner',
			'mobishop_save_coupon_banner',
			'mobishop_duplicate_coupon_banner',
			'mobishop_delete_coupon_banner'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}