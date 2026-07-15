<?php
/**
 * Spacer admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Spacer', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Spacer {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_spacers',
			__( 'Spacers', 'kidia-mobile-cms' ),
			'kidia-mobile-spacers',
			'spacer',
			'kidia_mobile_create_spacer',
			'kidia_mobile_save_spacer',
			'kidia_mobile_duplicate_spacer',
			'kidia_mobile_delete_spacer'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
