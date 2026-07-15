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

/*
|--------------------------------------------------------------------------
| Framework
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'admin/framework/class-library.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/framework/class-editor.php';

/*
|--------------------------------------------------------------------------
| Admin
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-admin.php';

require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-hero-slider.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-image-banner.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-product-carousel.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-brand-carousel.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-category-grid.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-product-grid.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-section-header.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-promo-strip.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-coupon-banner.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-countdown.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-video-banner.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-text-block.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-divider.php';
require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-kidia-mobile-cms-spacer.php';

/*
|--------------------------------------------------------------------------
| API
|--------------------------------------------------------------------------
*/

require_once KIDIA_MOBILE_CMS_PATH . 'api/class-home-layout-endpoint.php';

final class Kidia_Mobile_CMS {

	private bool $started = false;

	public function run(): void {

		if ( $this->started ) {
			return;
		}

		$this->started = true;

		$this->load_textdomain();

		$this->register_blocks();

		$this->register_admin_modules();

		$this->register_api_modules();

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

	}

	private function register_admin_modules(): void {

		(new Kidia_Mobile_CMS_Admin())->register();

		(new Kidia_Mobile_CMS_Hero_Slider())->register();

		(new Kidia_Mobile_CMS_Image_Banner())->register();

		(new Kidia_Mobile_CMS_Product_Carousel())->register();

		(new Kidia_Mobile_CMS_Brand_Carousel())->register();

		(new Kidia_Mobile_CMS_Category_Grid())->register();

		(new Kidia_Mobile_CMS_Product_Grid())->register();

		(new Kidia_Mobile_CMS_Section_Header())->register();

		(new Kidia_Mobile_CMS_Promo_Strip())->register();

		(new Kidia_Mobile_CMS_Coupon_Banner())->register();

		(new Kidia_Mobile_CMS_Countdown())->register();

		(new Kidia_Mobile_CMS_Video_Banner())->register();

		(new Kidia_Mobile_CMS_Text_Block())->register();

		(new Kidia_Mobile_CMS_Divider())->register();

		(new Kidia_Mobile_CMS_Spacer())->register();

	}

	private function register_api_modules(): void {

		(new Kidia_Mobile_CMS_Home_Layout_Endpoint_V4())
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
