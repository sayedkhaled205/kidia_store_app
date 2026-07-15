<?php
/**
 * Handles plugin deactivation.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_CMS_Deactivator {

	/**
	 * Runs once when the plugin is deactivated.
	 *
	 * The stored CMS content is intentionally preserved.
	 *
	 * @return void
	 */
	public static function deactivate(): void {
		delete_transient( 'kidia_mobile_cms_api_status' );
		delete_transient( 'kidia_mobile_cms_home_layout_cache' );

		flush_rewrite_rules();
	}
}