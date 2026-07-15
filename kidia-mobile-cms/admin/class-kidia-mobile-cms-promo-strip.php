<?php
/**
 * Promo Strips admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Promo_Strip', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Promo_Strip {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_promo_strips',
			__( 'Promo Strips', 'kidia-mobile-cms' ),
			'kidia-mobile-promo-strips',
			'promo-strip',
			'kidia_mobile_create_promo_strip',
			'kidia_mobile_save_promo_strip',
			'kidia_mobile_duplicate_promo_strip',
			'kidia_mobile_delete_promo_strip'
		);
	}

	public function register(): void {

		$this->library->register();
	}
}