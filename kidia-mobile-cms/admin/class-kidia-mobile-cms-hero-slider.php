<?php
/**
 * Hero Sliders admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'Kidia_Mobile_CMS_Hero_Slider', false ) ) {
	return;
}

final class Kidia_Mobile_CMS_Hero_Slider {

	/**
	 * Hero Sliders library.
	 *
	 * @var Kidia_Mobile_Library
	 */
	private Kidia_Mobile_Library $library;

	/**
	 * Creates the Hero Sliders module.
	 */
	public function __construct() {
		$this->library = new Kidia_Mobile_Library(
			'kidia_mobile_hero_sliders',
			__( 'Hero Sliders', 'kidia-mobile-cms' ),
			'kidia-mobile-hero-sliders',
			'hero-slider',
			'kidia_mobile_create_hero_slider',
			'kidia_mobile_save_hero_slider',
			'kidia_mobile_duplicate_hero_slider',
			'kidia_mobile_delete_hero_slider'
		);
	}

	/**
	 * Registers the module.
	 *
	 * @return void
	 */
	public function register(): void {
		$this->library->register();
	}
}
