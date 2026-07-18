<?php
/**
 * Plugin Name:       Woo Mobile CMS
 * Plugin URI:        https://wordpress.org/
 * Description:       Server-driven mobile content management and REST API platform for WooCommerce stores.
 * Version:           1.17.6
 * Requires at least: 6.4
 * Requires PHP:      8.0
 * Author:            Woo Mobile CMS
 * Author URI:        https://woocommerce.com/
 * Text Domain:       kidia-mobile-cms
 * Domain Path:       /languages
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 */

defined( 'ABSPATH' ) || exit;

define(
	'KIDIA_MOBILE_CMS_VERSION',
	'1.17.6'
);

define(
	'KIDIA_MOBILE_CMS_FILE',
	__FILE__
);

define(
	'KIDIA_MOBILE_CMS_BASENAME',
	plugin_basename( __FILE__ )
);

define(
	'KIDIA_MOBILE_CMS_PATH',
	plugin_dir_path( __FILE__ )
);

define(
	'KIDIA_MOBILE_CMS_URL',
	plugin_dir_url( __FILE__ )
);

require_once KIDIA_MOBILE_CMS_PATH .
	'includes/class-kidia-mobile-cms-activator.php';

require_once KIDIA_MOBILE_CMS_PATH .
	'includes/class-kidia-mobile-cms-deactivator.php';

require_once KIDIA_MOBILE_CMS_PATH .
	'includes/class-kidia-mobile-cms.php';

register_activation_hook(
	KIDIA_MOBILE_CMS_FILE,
	array(
		'Kidia_Mobile_CMS_Activator',
		'activate',
	)
);

register_deactivation_hook(
	KIDIA_MOBILE_CMS_FILE,
	array(
		'Kidia_Mobile_CMS_Deactivator',
		'deactivate',
	)
);

/**
 * Starts the plugin.
 *
 * @return void
 */
function kidia_mobile_cms_run(): void {

	$plugin = new Kidia_Mobile_CMS();

	$plugin->run();
}

add_action(
	'plugins_loaded',
	'kidia_mobile_cms_run'
);
