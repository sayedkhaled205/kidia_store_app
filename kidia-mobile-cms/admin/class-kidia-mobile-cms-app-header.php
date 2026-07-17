<?php
/** App Header admin module. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;
require_once KIDIA_MOBILE_CMS_PATH . 'admin/framework/class-library.php';

final class Kidia_Mobile_CMS_App_Header {
	private Kidia_Mobile_Library $library;
	public function __construct() {
		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_app_headers', __( 'App Headers', 'kidia-mobile-cms' ),
			'kidia-mobile-app-headers', 'app_header', 'kidia_mobile_create_app_header',
			'kidia_mobile_save_app_header', 'kidia_mobile_duplicate_app_header',
			'kidia_mobile_delete_app_header'
		);
	}
	public function register(): void { $this->library->register(); }
}
