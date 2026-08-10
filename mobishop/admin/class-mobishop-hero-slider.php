<?php
/**
 * Hero Sliders admin module.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

require_once MOBISHOP_PATH .
	'admin/framework/class-library.php';

if ( class_exists( 'MobiShop_Hero_Slider', false ) ) {
	return;
}

final class MobiShop_Hero_Slider {

	/**
	 * Hero Sliders library.
	 *
	 * @var MobiShop_Library
	 */
	private MobiShop_Library $library;

	/**
	 * Creates the Hero Sliders module.
	 */
	public function __construct() {
		$this->library = new MobiShop_Library(
			'mobishop_hero_sliders',
			__( 'Hero Sliders', 'mobishop' ),
			'mobishop-hero-sliders',
			'hero-slider',
			'mobishop_create_hero_slider',
			'mobishop_save_hero_slider',
			'mobishop_duplicate_hero_slider',
			'mobishop_delete_hero_slider'
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