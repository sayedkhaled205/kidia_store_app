<?php
/**
 * Text Blocks admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Text_Block', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Text_Block {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_text_blocks',
			__( 'Text Blocks', 'kidia-mobile-cms' ),
			'kidia-mobile-text-blocks',
			'text-block',
			'kidia_mobile_create_text_block',
			'kidia_mobile_save_text_block',
			'kidia_mobile_duplicate_text_block',
			'kidia_mobile_delete_text_block'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}
