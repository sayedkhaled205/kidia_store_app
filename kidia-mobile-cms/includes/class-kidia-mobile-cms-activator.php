<?php
/**
 * Handles plugin activation.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Activator {

	/**
	 * Default home layout option name.
	 *
	 * @var string
	 */
	private const HOME_LAYOUT_OPTION = 'kidia_mobile_home_layout';

	/**
	 * Runs once when the plugin is activated.
	 *
	 * @return void
	 */
	public static function activate(): void {
		self::create_default_home_layout();
		self::store_plugin_version();
		flush_rewrite_rules();
	}

	/**
	 * Creates the initial Home Builder layout.
	 *
	 * @return void
	 */
	private static function create_default_home_layout(): void {
		if ( false !== get_option( self::HOME_LAYOUT_OPTION, false ) ) {
			return;
		}

		$default_layout = array(
			'version'    => 1,
			'page'       => 'home',
			'locale'     => 'ar',
			'updated_at' => gmdate( 'c' ),
			'blocks'     => array(),
		);

		add_option(
			self::HOME_LAYOUT_OPTION,
			$default_layout,
			'',
			false
		);
	}

	/**
	 * Stores the installed plugin version.
	 *
	 * @return void
	 */
	private static function store_plugin_version(): void {
		update_option(
			'kidia_mobile_cms_version',
			KIDIA_MOBILE_CMS_VERSION,
			false
		);
	}
}