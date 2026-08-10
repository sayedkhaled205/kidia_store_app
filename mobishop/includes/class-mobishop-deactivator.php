<?php
/**
 * Handles plugin deactivation.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Deactivator {

	/**
	 * Runs once when the plugin is deactivated.
	 *
	 * The stored CMS content is intentionally preserved.
	 *
	 * @return void
	 */
	public static function deactivate(): void {
		require_once MOBISHOP_PATH . 'includes/class-mobishop-license-manager.php';
		MobiShop_License_Manager::deactivate_cron();

		delete_transient( 'mobishop_api_status' );
		delete_transient( 'mobishop_home_layout_cache' );

		flush_rewrite_rules();
	}
}
