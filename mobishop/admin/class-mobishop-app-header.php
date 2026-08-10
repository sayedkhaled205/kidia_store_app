<?php
/** App Header admin module. @package MobiShop */
defined( 'ABSPATH' ) || exit;
require_once MOBISHOP_PATH . 'admin/framework/class-library.php';

final class MobiShop_App_Header {
	private MobiShop_Library $library;
	public function __construct() {
		$this->library = new MobiShop_Library(
			'mobishop_app_headers', __( 'App Headers', 'mobishop' ),
			'mobishop-app-headers', 'app_header', 'mobishop_create_app_header',
			'mobishop_save_app_header', 'mobishop_duplicate_app_header',
			'mobishop_delete_app_header'
		);
	}
	public function register(): void { $this->library->register(); }
}
