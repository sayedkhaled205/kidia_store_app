<?php
/**
 * Countdown admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Countdown', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Countdown {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_countdowns',
			__( 'Countdowns', 'kidia-mobile-cms' ),
			'kidia-mobile-countdowns',
			'countdown',
			'kidia_mobile_create_countdown',
			'kidia_mobile_save_countdown',
			'kidia_mobile_duplicate_countdown',
			'kidia_mobile_delete_countdown'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
