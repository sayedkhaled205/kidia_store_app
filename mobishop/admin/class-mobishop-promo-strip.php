<?php
/**
 * Promo Strips admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Promo_Strip', false ) ) {
	return;
}

final class MobiShop_Promo_Strip {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_promo_strips',
			__( 'Promo Strips', 'mobishop' ),
			'mobishop-promo-strips',
			'promo-strip',
			'mobishop_create_promo_strip',
			'mobishop_save_promo_strip',
			'mobishop_duplicate_promo_strip',
			'mobishop_delete_promo_strip'
		);
	}

	public function register(): void {

		$this->library->register();
	}
}