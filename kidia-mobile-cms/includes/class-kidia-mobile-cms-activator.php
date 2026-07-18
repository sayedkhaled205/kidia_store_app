<?php
/**
 * Handles plugin activation.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Activator {

	/**
	 * Runs once when the plugin is activated.
	 *
	 * @return void
	 */
	public static function activate(): void {

		self::create_default_layout();

		self::store_plugin_version();

		flush_rewrite_rules();

	}

	/**
	 * Creates the initial Home Builder layout.
	 *
	 * @return void
	 */
	private static function create_default_layout(): void {

		if (
			false !== get_option(
				'kidia_mobile_home_layout_v4',
				false
			)
		) {
			return;
		}

		require_once
			KIDIA_MOBILE_CMS_PATH .
			'includes/class-kidia-mobile-layout-store.php';

		$store =
			new Kidia_Mobile_Layout_Store();

		$store->save_layout(
			$store->get_default_layout()
		);

	}

	/**
	 * Stores installed version.
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
