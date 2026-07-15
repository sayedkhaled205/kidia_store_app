<?php
/**
 * Section Headers admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Section_Header', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Section_Header {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_section_headers',
			__( 'Section Headers', 'kidia-mobile-cms' ),
			'kidia-mobile-section-headers',
			'section-header',
			'kidia_mobile_create_section_header',
			'kidia_mobile_save_section_header',
			'kidia_mobile_duplicate_section_header',
			'kidia_mobile_delete_section_header'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
