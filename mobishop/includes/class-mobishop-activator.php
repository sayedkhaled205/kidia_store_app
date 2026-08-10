<?php
/**
 * Handles plugin activation.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Activator {

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
				'mobishop_home_layout_v4',
				false
			)
		) {
			return;
		}

		require_once
			MOBISHOP_PATH .
			'includes/class-mobishop-layout-store.php';

		$store =
			new MobiShop_Layout_Store();

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
			'mobishop_version',
			MOBISHOP_VERSION,
			false
		);

	}
}
