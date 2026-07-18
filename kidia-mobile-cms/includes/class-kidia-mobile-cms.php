<?php
/**
 * Core plugin bootstrap.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

/*
|--------------------------------------------------------------------------
| Core
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'includes/class-kidia-mobile-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/class-kidia-mobile-block-registry.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/class-kidia-mobile-layout-store.php';

/*
|--------------------------------------------------------------------------
| Blocks
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-hero-slider-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-app-header-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-image-banner-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-product-carousel-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-brand-carousel-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-category-grid-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-product-grid-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-section-header-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-promo-strip-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-coupon-banner-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-countdown-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-video-banner-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-text-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-divider-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-spacer-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-quick-links-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'includes/blocks/class-kidia-mobile-banner-grid-block.php';

/*
|--------------------------------------------------------------------------
| Admin
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-admin.php';


/*
|--------------------------------------------------------------------------
| API
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'api/class-home-layout-endpoint.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-product-brand-bridge.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-product-variation-endpoint.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-checkout-config-endpoint.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-customer-auth-endpoint.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-customer-orders-endpoint.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-customer-account-endpoint.php';
require_once KIDIA_MOBILE_CMS_PATH . 'api/class-category-page-endpoint.php';

final class Kidia_Mobile_CMS {

	private bool $started = false;

	public function run(): void {

		if ( $this->started ) {
			return;
		}

		$this->started = true;

		$this->register_blocks();

		$this->register_admin_modules();

		$this->register_api_modules();

		add_action(
			'init',
			array(
				$this,
				'load_textdomain',
			)
		);

		add_filter(
			'plugin_action_links_' .
			KIDIA_MOBILE_CMS_BASENAME,
			array(
				$this,
				'add_plugin_action_links',
			)
		);

	}

	private function register_blocks(): void {

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_App_Header_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Hero_Slider_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Image_Banner_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Product_Carousel_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Brand_Carousel_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Category_Grid_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Product_Grid_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Section_Header_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Promo_Strip_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Coupon_Banner_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Countdown_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Video_Banner_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Text_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Divider_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Spacer_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Quick_Links_Block()
		);

		Kidia_Mobile_Block_Registry::register(
			new Kidia_Mobile_Banner_Grid_Block()
		);

	}

	private function register_admin_modules(): void {

		(new Kidia_Mobile_CMS_Admin())->register();

	}

	private function register_api_modules(): void {

		(new Kidia_Mobile_CMS_Home_Layout_Endpoint_V4())
			->register();

		(new Kidia_Mobile_CMS_Product_Brand_Bridge())
			->register();

		(new Kidia_Mobile_CMS_Product_Variation_Endpoint())
			->register();

		(new Kidia_Mobile_CMS_Checkout_Config_Endpoint())
			->register();

		(new Kidia_Mobile_CMS_Customer_Auth_Endpoint())
			->register();

		(new Kidia_Mobile_CMS_Customer_Orders_Endpoint())
			->register();

		(new Kidia_Mobile_CMS_Customer_Account_Endpoint())
			->register();

		(new Kidia_Mobile_CMS_Category_Page_Endpoint())
			->register();

	}

	public function load_textdomain(): void {

		load_plugin_textdomain(
			'kidia-mobile-cms',
			false,
			dirname(
				KIDIA_MOBILE_CMS_BASENAME
			) . '/languages'
		);

	}

	public function add_plugin_action_links(
		array $links
	): array {

		array_unshift(
			$links,
			sprintf(
				'<a href="%s">%s</a>',
				esc_url(
					admin_url(
						'admin.php?page=kidia-mobile-cms'
					)
				),
				esc_html__(
					'Dashboard',
					'kidia-mobile-cms'
				)
			)
		);

		return $links;
	}
}
