<?php
/**
 * Plugin Name:       Mobi2App Connector for WooCommerce
 * Plugin URI:        https://woomobile.app/
 * Description:       Connect WooCommerce to WooMobile. Manage your mobile application from the WooMobile dashboard.
 * Version:           1.46.85
 * Requires at least: 6.4
 * Requires PHP:      8.0
 * Requires Plugins:  woocommerce
 * Author:            WooMobile
 * Text Domain:       mobi2app-connector
 * License:           GPL-2.0-or-later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 */

defined( 'ABSPATH' ) || exit;

define(
	'MOBISHOP_VERSION',
	'1.46.85'
);

if ( ! defined( 'MOBISHOP_LICENSE_PUBLIC_KEY' ) ) {
	define(
		'MOBISHOP_LICENSE_PUBLIC_KEY',
		'pno+qR490JO/niHqlK82hXz0SwloDlwShxnmimmLQz0='
	);
}

define(
	'MOBISHOP_FILE',
	__FILE__
);

define(
	'MOBISHOP_BASENAME',
	plugin_basename( __FILE__ )
);

define(
	'MOBISHOP_PATH',
	plugin_dir_path( __FILE__ )
);

define(
	'MOBISHOP_URL',
	plugin_dir_url( __FILE__ )
);

require_once MOBISHOP_PATH .
	'includes/class-mobishop-activator.php';

require_once MOBISHOP_PATH .
	'includes/class-mobishop-deactivator.php';

require_once MOBISHOP_PATH .
	'includes/class-mobishop.php';

register_activation_hook(
	MOBISHOP_FILE,
	array(
		'MobiShop_Activator',
		'activate',
	)
);

register_deactivation_hook(
	MOBISHOP_FILE,
	array(
		'MobiShop_Deactivator',
		'deactivate',
	)
);

/**
 * Starts the plugin.
 *
 * @return void
 */
function mobishop_run(): void {

	$plugin = new MobiShop();

	$plugin->run();
}

add_action(
	'plugins_loaded',
	'mobishop_run'
);
