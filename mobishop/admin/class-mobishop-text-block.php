<?php
/**
 * Text Blocks admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Text_Block', false ) ) {
	return;
}

final class MobiShop_Text_Block {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_text_blocks',
			__( 'Text Blocks', 'mobishop' ),
			'mobishop-text-blocks',
			'text-block',
			'mobishop_create_text_block',
			'mobishop_save_text_block',
			'mobishop_duplicate_text_block',
			'mobishop_delete_text_block'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}