<?php
/**
 * Countdown admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Countdown', false ) ) {
	return;
}

final class MobiShop_Countdown {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_countdowns',
			__( 'Countdowns', 'mobishop' ),
			'mobishop-countdowns',
			'countdown',
			'mobishop_create_countdown',
			'mobishop_save_countdown',
			'mobishop_duplicate_countdown',
			'mobishop_delete_countdown'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}