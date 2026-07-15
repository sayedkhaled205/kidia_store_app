<?php
/**
 * Divider admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Divider', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Divider {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_dividers',
			__( 'Dividers', 'kidia-mobile-cms' ),
			'kidia-mobile-dividers',
			'divider',
			'kidia_mobile_create_divider',
			'kidia_mobile_save_divider',
			'kidia_mobile_duplicate_divider',
			'kidia_mobile_delete_divider'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
