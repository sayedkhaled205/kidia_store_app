<?php
/**
 * Video Banners admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Video_Banner', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Video_Banner {

	private Kidia_Mobile_Library $library;

	public function __construct() {

		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_video_banners',
			__( 'Video Banners', 'kidia-mobile-cms' ),
			'kidia-mobile-video-banners',
			'video-banner',
			'kidia_mobile_create_video_banner',
			'kidia_mobile_save_video_banner',
			'kidia_mobile_duplicate_video_banner',
			'kidia_mobile_delete_video_banner'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}