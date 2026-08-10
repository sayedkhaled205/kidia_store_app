<?php
/**
 * Divider admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Divider', false ) ) {
	return;
}

final class MobiShop_Divider {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_dividers',
			__( 'Dividers', 'mobishop' ),
			'mobishop-dividers',
			'divider',
			'mobishop_create_divider',
			'mobishop_save_divider',
			'mobishop_duplicate_divider',
			'mobishop_delete_divider'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}