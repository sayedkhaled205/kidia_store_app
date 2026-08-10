<?php
/**
 * Video Banners admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Video_Banner', false ) ) {
	return;
}

final class MobiShop_Video_Banner {

	private MobiShop_Library $library;

	public function __construct() {

		$this->library = new MobiShop_Library(
			'mobishop_video_banners',
			__( 'Video Banners', 'mobishop' ),
			'mobishop-video-banners',
			'video-banner',
			'mobishop_create_video_banner',
			'mobishop_save_video_banner',
			'mobishop_duplicate_video_banner',
			'mobishop_delete_video_banner'
		);

	}

	public function register(): void {

		$this->library->register();

	}
}