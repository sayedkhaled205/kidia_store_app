<?php
/**
 * Core plugin bootstrap.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

/*
|--------------------------------------------------------------------------
| Core
|--------------------------------------------------------------------------
*/

require_once MOBISHOP_PATH . 'includes/class-mobishop-block.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-block-registry.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-layout-store.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-page-layout-store.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-category-page-store.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-checkout-fields-store.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-setup-wizard.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-license-manager.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-analytics.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-product-channel-visibility.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-ai-offer-engine.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-ai-analysis-job.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-recovery-campaigns.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-push-service.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-app-exporter.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-coupon-channel.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-bundle-recipes.php';
require_once MOBISHOP_PATH . 'includes/class-mobishop-website-app-promotion.php';

/*
|--------------------------------------------------------------------------
| Blocks
|--------------------------------------------------------------------------
*/

require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-hero-slider-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-app-header-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-image-banner-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-product-carousel-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-brand-carousel-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-category-grid-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-product-grid-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-section-header-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-promo-strip-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-coupon-banner-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-countdown-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-video-banner-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-text-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-divider-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-spacer-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-quick-links-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-banner-grid-block.php';
require_once MOBISHOP_PATH . 'includes/blocks/class-mobishop-bundle-block.php';

/*
|--------------------------------------------------------------------------
| Admin
|--------------------------------------------------------------------------
*/

require_once MOBISHOP_PATH . 'admin/class-mobishop-admin.php';


/*
|--------------------------------------------------------------------------
| API
|--------------------------------------------------------------------------
*/

require_once MOBISHOP_PATH . 'api/class-home-layout-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-product-brand-bridge.php';
require_once MOBISHOP_PATH . 'api/class-product-variation-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-checkout-config-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-customer-auth-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-customer-orders-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-customer-account-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-category-page-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-page-layout-endpoint.php';
require_once MOBISHOP_PATH . 'api/class-splash-screen-endpoint.php';

final class MobiShop {

	private bool $started = false;

	public function run(): void {

		if ( $this->started ) {
			return;
		}

		$this->started = true;

		(new MobiShop_License_Manager())->register();
		(new MobiShop_Analytics())->register();
		MobiShop_AI_Analysis_Job::register();
		(new MobiShop_Product_Channel_Visibility())->register();
		(new MobiShop_Recovery_Campaigns())->register();
		(new MobiShop_Push_Service())->register();
		(new MobiShop_App_Exporter())->register();
		(new MobiShop_Coupon_Channel())->register();
		(new MobiShop_Bundle_Recipes())->register();
		(new MobiShop_Website_App_Promotion())->register();

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
			MOBISHOP_BASENAME,
			array(
				$this,
				'add_plugin_action_links',
			)
		);

	}

	private function register_blocks(): void {

		MobiShop_Block_Registry::register(
			new MobiShop_App_Header_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Hero_Slider_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Image_Banner_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Product_Carousel_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Brand_Carousel_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Category_Grid_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Product_Grid_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Section_Header_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Promo_Strip_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Coupon_Banner_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Countdown_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Video_Banner_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Text_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Divider_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Spacer_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Bundle_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Quick_Links_Block()
		);

		MobiShop_Block_Registry::register(
			new MobiShop_Banner_Grid_Block()
		);

	}

	private function register_admin_modules(): void {

		(new MobiShop_Admin())->register();

	}

	private function register_api_modules(): void {

		(new MobiShop_Home_Layout_Endpoint_V4())
			->register();

		(new MobiShop_Product_Brand_Bridge())
			->register();

		(new MobiShop_Product_Variation_Endpoint())
			->register();

		(new MobiShop_Checkout_Config_Endpoint())
			->register();

		(new MobiShop_Customer_Auth_Endpoint())
			->register();

		(new MobiShop_Customer_Orders_Endpoint())
			->register();

		(new MobiShop_Customer_Account_Endpoint())
			->register();

		(new MobiShop_Category_Page_Endpoint())
			->register();

		(new MobiShop_Page_Layout_Endpoint())
			->register();

		(new MobiShop_Splash_Screen_Endpoint())->register();

	}

	public function load_textdomain(): void {

		load_plugin_textdomain(
			'mobishop',
			false,
			dirname(
				MOBISHOP_BASENAME
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
						'admin.php?page=mobishop'
					)
				),
				esc_html__(
					'Dashboard',
					'mobishop'
				)
			)
		);

		return $links;
	}
}
