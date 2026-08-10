<?php
/**
 * Section Headers admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Section_Header', false ) ) {
	return;
}

final class MobiShop_Section_Header {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_section_headers',
			__( 'Section Headers', 'mobishop' ),
			'mobishop-section-headers',
			'section-header',
			'mobishop_create_section_header',
			'mobishop_save_section_header',
			'mobishop_duplicate_section_header',
			'mobishop_delete_section_header'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}