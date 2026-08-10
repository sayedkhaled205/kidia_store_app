<?php
/**
 * Spacer admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Spacer', false ) ) {
	return;
}

final class MobiShop_Spacer {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_spacers',
			__( 'Spacers', 'mobishop' ),
			'mobishop-spacers',
			'spacer',
			'mobishop_create_spacer',
			'mobishop_save_spacer',
			'mobishop_duplicate_spacer',
			'mobishop_delete_spacer'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}