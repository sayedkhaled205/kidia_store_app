
<?php
/**
 * Admin module.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

require_once KIDIA_MOBILE_CMS_PATH . 'admin/class-api-monitor.php';

final class Kidia_Mobile_CMS_Admin {

	/**
	 * Required capability.
	 *
	 * @var string
	 */
	private const CAPABILITY = 'manage_options';

	/** One explicit Generate unlocks the automatically maintained reporting index. */
	private const REPORTING_READY_OPTION = 'kidia_mobile_store_reporting_ready_v1';

	/** @var array<string,string> */
	private const PAGE_BUILDER_SLUGS = array(
		'kidia-mobile-catalog-builder'  => 'catalog',
		'kidia-mobile-product-builder'  => 'product',
		'kidia-mobile-size-chart-builder' => 'size_chart',
		'kidia-mobile-wishlist-builder' => 'wishlist',
		'kidia-mobile-account-builder'  => 'account',
	);

	/** @var array<string,string> Public routes inside the single CMS screen. */
	private const CMS_VIEWS = array(
		'overview'=>'kidia-mobile-cms','setup'=>'kidia-mobile-setup','pages'=>'kidia-mobile-splash-screen','splash'=>'kidia-mobile-splash-screen','home'=>'kidia-mobile-home-builder','category'=>'kidia-mobile-category-builder','catalog'=>'kidia-mobile-catalog-builder','product'=>'kidia-mobile-product-builder','wishlist'=>'kidia-mobile-wishlist-builder','account'=>'kidia-mobile-account-builder','checkout'=>'kidia-mobile-checkout-suggestions','saved-themes'=>'kidia-mobile-saved-themes','store-data'=>'kidia-mobile-store-data','ai-insights'=>'kidia-mobile-ai-insights','push'=>'kidia-mobile-push-notifications','website-promotion'=>'kidia-mobile-website-app-promotion',
	);

	/**
	 * Library editor page slugs keyed by element type.
	 *
	 * @var array<string,string>
	 */
	private const EDITOR_PAGES = array(
		'app_header'       => 'kidia-mobile-app-headers',
		'hero_slider'     => 'kidia-mobile-hero-sliders',
		'image_banner'    => 'kidia-mobile-image-banners',
		'product_carousel' => 'kidia-mobile-product-carousels',
		'brand_carousel'  => 'kidia-mobile-brand-carousels',
		'category_grid'   => 'kidia-mobile-category-grids',
		'product_grid'    => 'kidia-mobile-product-grids',
		'section_header'  => 'kidia-mobile-section-headers',
		'promo_strip'     => 'kidia-mobile-promo-strips',
		'coupon_banner'   => 'kidia-mobile-coupon-banners',
		'countdown'       => 'kidia-mobile-countdowns',
		'video_banner'    => 'kidia-mobile-video-banners',
		'text_block'      => 'kidia-mobile-text-blocks',
		'divider'         => 'kidia-mobile-dividers',
		'spacer'          => 'kidia-mobile-spacers',
	);

	/**
	 * Library storage options keyed by element type.
	 *
	 * @var array<string,string>
	 */
	private const LIBRARY_OPTIONS = array(
		'app_header'       => 'kidia_mobile_app_headers',
		'hero_slider'      => 'kidia_mobile_hero_sliders',
		'image_banner'     => 'kidia_mobile_image_banners',
		'product_carousel' => 'kidia_mobile_product_carousels',
		'brand_carousel'   => 'kidia_mobile_brand_carousels',
		'category_grid'    => 'kidia_mobile_category_grids',
		'product_grid'     => 'kidia_mobile_product_grids',
		'section_header'   => 'kidia_mobile_section_headers',
		'promo_strip'      => 'kidia_mobile_promo_strips',
		'coupon_banner'    => 'kidia_mobile_coupon_banners',
		'countdown'        => 'kidia_mobile_countdowns',
		'video_banner'     => 'kidia_mobile_video_banners',
		'text_block'       => 'kidia_mobile_text_blocks',
		'divider'          => 'kidia_mobile_dividers',
		'spacer'           => 'kidia_mobile_spacers',
		'quick_links'      => 'kidia_mobile_quick_links',
		'banner_grid'      => 'kidia_mobile_banner_grids',
	);

	/**
	 * Registers hooks.
	 *
	 * @return void
	 */
	public function register(): void {

		add_action(
			'admin_menu',
			array(
				$this,
				'register_menu',
			)
		);

		add_action(
			'admin_enqueue_scripts',
			array(
				$this,
				'enqueue_assets',
			)
		);

		add_action( 'admin_init', array( $this, 'enforce_license_gate' ), 20 );

		add_filter(
			'admin_body_class',
			array(
				$this,
				'admin_body_class',
			)
		);

		add_action(
			'admin_post_kidia_mobile_save_home_builder',
			array(
				$this,
				'save_home_builder',
			)
		);

		add_action(
			'admin_post_kidia_mobile_save_category_builder',
			array( $this, 'save_category_builder' )
		);

		add_action(
			'admin_post_kidia_mobile_save_page_builder',
			array( $this, 'save_page_builder' )
		);

		add_action( 'admin_post_kidia_mobile_save_splash_screen', array( $this, 'save_splash_screen' ) );
		add_action( 'admin_post_kidia_mobile_save_similar_products', array( $this, 'save_similar_products' ) );
		add_action( 'admin_post_kidia_mobile_save_checkout_suggestions', array( $this, 'save_checkout_suggestions' ) );
		add_action( 'admin_post_kidia_mobile_apply_setup_wizard', array( $this, 'apply_setup_wizard' ) );
		add_action( 'admin_post_kidia_mobile_manage_saved_theme', array( $this, 'manage_saved_theme' ) );
			add_action( 'admin_post_kidia_mobile_send_push_notification', array( $this, 'send_push_notification' ) );
			add_action( 'admin_post_kidia_mobile_provision_push', array( $this, 'provision_push' ) );
			add_action( 'admin_post_kidia_mobile_test_push_connection', array( $this, 'test_push_connection' ) );
			add_action( 'admin_post_kidia_mobile_build_ai_action', array( $this, 'build_ai_action' ) );
			add_action( 'admin_post_kidia_mobile_review_ai_result', array( $this, 'review_ai_result' ) );
		add_action( 'admin_post_kidia_mobile_toggle_product_channel', array( $this, 'toggle_product_channel' ) );
		add_action( 'admin_post_kidia_mobile_set_coupon_channel', array( $this, 'set_coupon_channel' ) );
		add_action( 'admin_post_kidia_mobile_start_abandoned_cart_import', array( $this, 'start_abandoned_cart_import' ) );
		add_action( 'kidia_mobile_dispatch_scheduled_push', array( $this, 'dispatch_scheduled_push' ) );
		add_action( 'admin_post_kidia_mobile_activate_license', array( $this, 'activate_license' ) );
		add_action( 'admin_post_kidia_mobile_verify_license', array( $this, 'verify_license' ) );
		add_action( 'wp_ajax_kidia_mobile_apply_product_icon_settings', array( $this, 'apply_product_icon_settings' ) );
		add_action( 'wp_ajax_kidia_mobile_start_ai_analysis', array( $this, 'start_ai_analysis' ) );
		add_action( 'wp_ajax_kidia_mobile_step_ai_analysis', array( $this, 'step_ai_analysis' ) );
		add_action( 'wp_ajax_kidia_mobile_background_ai_analysis', array( $this, 'background_ai_analysis' ) );
		add_action( 'wp_ajax_kidia_mobile_cancel_ai_analysis', array( $this, 'cancel_ai_analysis' ) );
		add_action( 'wp_ajax_kidia_mobile_ai_analysis_status', array( $this, 'ai_analysis_status' ) );
		add_action( 'wp_ajax_kidia_mobile_dismiss_ai_analysis', array( $this, 'dismiss_ai_analysis' ) );
		add_action( 'wp_ajax_kidia_mobile_generate_store_reporting', array( $this, 'generate_store_reporting' ) );
		add_action( 'wp_ajax_kidia_mobile_abandoned_cart_details', array( $this, 'abandoned_cart_details' ) );
		add_action( 'wp_ajax_kidia_mobile_cms_view', array( $this, 'cms_view_fragment' ) );
		add_action( 'admin_notices', array( $this, 'render_cms_shell' ), 1 );
		add_action( 'current_screen', array( $this, 'suppress_external_admin_notices' ), 999 );

		add_action(
			'admin_menu',
			array( $this, 'hide_element_library_menus' ),
			999
		);

	}

	/**
	 * Prevents configuration writes until the site license is active.
	 *
	 * Inactive customers may browse every CMS screen in preview mode. The
	 * interface lock is applied by the admin assets, while this server-side
	 * guard remains the authority for every Kidia mutation.
	 */
	public function enforce_license_gate(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			return;
		}

		$license_active = ( new Kidia_Mobile_License_Manager() )->is_active();
		$action         = isset( $_REQUEST['action'] ) ? sanitize_key( wp_unslash( $_REQUEST['action'] ) ) : '';
		$allowed        = array(
			'kidia_mobile_activate_license',
			'kidia_mobile_verify_license',
			'kidia_mobile_cms_view',
		);

		if (
			! $license_active
			&& 0 === strpos( $action, 'kidia_mobile_' )
			&& ! in_array( $action, $allowed, true )
		) {
			if ( wp_doing_ajax() ) {
				wp_send_json_error(
					array(
						'message' => __( 'Activate your website license before changing MobiShop settings.', 'mobishop' ),
					),
					403
				);
			}

			wp_die(
				esc_html__( 'Activate your website license before changing MobiShop settings.', 'mobishop' ),
				esc_html__( 'License required', 'mobishop' ),
				array( 'response' => 403 )
			);
		}

	}

	/**
	 * Marks builder screens whose cards scroll inside the fixed CMS workspace.
	 *
	 * @param string $classes Existing admin body classes.
	 * @return string
	 */
	public function admin_body_class( string $classes ): string {
		$page = $this->effective_cms_page();

		if ( $this->is_builder_screen( $page ) ) {
			$classes .= ' kidia-cms-builder-screen';
		}
		if ( $this->is_public_cms_page( $page ) ) {
			$classes .= ' kidia-cms-plugin-page';
		}

		if (
			'kidia-mobile-cms' !== $page
			&& $this->is_public_cms_page( $page )
			&& ! ( new Kidia_Mobile_License_Manager() )->is_active()
		) {
			$classes .= ' kidia-cms-license-preview';
		}

		return $classes;
	}

	/** Returns whether the selected CMS view owns the fixed Builder workspace. */
	private function is_builder_screen( string $page ): bool {
		$builder_pages = array_merge(
			array(
				'kidia-mobile-home-builder',
				'kidia-mobile-category-builder',
				'kidia-mobile-splash-screen',
			),
			array_keys( self::PAGE_BUILDER_SLUGS )
		);

		return in_array( $page, $builder_pages, true );
	}

	/**
	 * Keeps third-party and WordPress notices outside the unified CMS workspace.
	 *
	 * @return void
	 */
	public function suppress_external_admin_notices(): void {
		$page = $this->effective_cms_page();
		if ( ! current_user_can( self::CAPABILITY ) || ! $this->is_public_cms_page( $page ) ) {
			return;
		}
		remove_all_actions( 'admin_notices' );
		remove_all_actions( 'all_admin_notices' );
		add_action( 'admin_notices', array( $this, 'render_cms_shell' ), 1 );
	}

	/**
	 * Copies one product-card icon profile to every saved product element.
	 *
	 * @return void
	 */
	public function apply_product_icon_settings(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to perform this action.', 'mobishop' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_apply_product_icon_settings', 'nonce' );
		$scope = isset( $_POST['scope'] ) ? sanitize_key( wp_unslash( $_POST['scope'] ) ) : '';
		if ( ! in_array( $scope, array( 'quick_add', 'wishlist' ), true ) ) {
			wp_send_json_error( array( 'message' => __( 'Unknown settings group.', 'mobishop' ) ), 400 );
		}
		$raw = isset( $_POST['settings'] ) ? json_decode( wp_unslash( $_POST['settings'] ), true ) : array();
		$raw = is_array( $raw ) ? $raw : array();
		$keys = 'quick_add' === $scope
			? array( 'quick_add_enabled', 'quick_add_icon_variant', 'quick_add_icon_style', 'quick_add_icon_size', 'quick_add_icon_color', 'quick_add_show_background', 'quick_add_background_color', 'quick_add_background_size', 'quick_add_radius', 'quick_add_position' )
			: array( 'show_wishlist', 'product_wishlist_icon_variant', 'product_wishlist_icon_style', 'product_wishlist_icon_size', 'product_wishlist_icon_color', 'product_wishlist_show_background', 'product_wishlist_background_color', 'product_wishlist_background_size', 'product_wishlist_radius', 'product_wishlist_position' );
		$booleans = array( 'quick_add_enabled', 'quick_add_show_background', 'show_wishlist', 'product_wishlist_show_background' );
		$numbers  = array( 'quick_add_icon_size', 'quick_add_background_size', 'quick_add_radius', 'product_wishlist_icon_size', 'product_wishlist_background_size', 'product_wishlist_radius' );
		$colors   = array( 'quick_add_icon_color', 'quick_add_background_color', 'product_wishlist_icon_color', 'product_wishlist_background_color' );
		$profile  = array();
		foreach ( $keys as $key ) {
			if ( ! array_key_exists( $key, $raw ) ) { continue; }
			if ( in_array( $key, $booleans, true ) ) {
				$profile[ $key ] = ! empty( $raw[ $key ] );
			} elseif ( in_array( $key, $numbers, true ) ) {
				$profile[ $key ] = (float) $raw[ $key ];
			} elseif ( in_array( $key, $colors, true ) ) {
				$profile[ $key ] = sanitize_hex_color( (string) $raw[ $key ] ) ?: '#FFFFFF';
			} else {
				$profile[ $key ] = sanitize_key( (string) $raw[ $key ] );
			}
		}
		if ( count( $profile ) !== count( $keys ) ) {
			wp_send_json_error( array( 'message' => __( 'Some settings are missing.', 'mobishop' ) ), 400 );
		}

		$changed = 0;
		$home_store = new Kidia_Mobile_Layout_Store();
		$home = $home_store->get_layout();
		foreach ( $home as &$block ) {
			if ( ! is_array( $block['settings'] ?? null ) || ! in_array( (string) ( $block['type'] ?? '' ), array( 'product_carousel', 'product_grid' ), true ) ) { continue; }
			$block['settings'] = array_merge( $block['settings'], $profile );
			++$changed;
		}
		unset( $block );
		if ( $changed > 0 ) { $home_store->save_layout( $home ); }

		$page_store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$layout = $page_store->get_layout( $page );
			if ( ! is_array( $layout['elements'] ?? null ) ) { continue; }
			$page_changed = false;
			foreach ( $layout['elements'] as &$element ) {
				if ( ! is_array( $element['settings'] ?? null ) || ! array_key_exists( $keys[0], $element['settings'] ) ) { continue; }
				$element['settings'] = array_merge( $element['settings'], $profile );
				$page_changed = true;
				++$changed;
			}
			unset( $element );
			if ( $page_changed ) { $page_store->save_layout( $page, $layout ); }
		}
		update_option( 'kidia_mobile_global_' . $scope . '_profile', $profile, false );
		wp_send_json_success(
			array(
				/* translators: Placeholder values are supplied at runtime. */
				'message' => sprintf( __( 'Applied to %d saved product elements.', 'mobishop' ), $changed ),
				'count'   => $changed,
			)
		);
	}
		/**
    	 * Registers admin pages.
    	 *
    	 * @return void
    	 */
    	public function register_menu(): void {

    		add_menu_page(
				__( 'MobiShop', 'mobishop' ),
				__( 'MobiShop', 'mobishop' ),
    			self::CAPABILITY,
    			'kidia-mobile-cms',
    			array(
    				$this,
    				'dashboard_page',
    			),
    			'dashicons-smartphone',
    			56
    		);

		add_submenu_page(
			null,
				__( 'Home Page', 'mobishop' ),
				__( 'Home Page', 'mobishop' ),
    			self::CAPABILITY,
    			'kidia-mobile-home-builder',
    			array(
    				$this,
    				'home_builder_page',
    			)
    		);

		add_submenu_page(
			null,
			__( 'Category Page', 'mobishop' ),
			__( 'Category Page', 'mobishop' ),
			self::CAPABILITY,
			'kidia-mobile-category-builder',
			array( $this, 'category_builder_page' )
		);

		foreach ( self::PAGE_BUILDER_SLUGS as $slug => $page ) {
			$labels = Kidia_Mobile_Page_Layout_Store::pages();
			$label = $labels[ $page ];
			add_submenu_page(
				null,
				$label . ' ' . __( 'Builder', 'mobishop' ),
				$label,
				self::CAPABILITY,
				$slug,
				array( $this, 'page_builder_page' )
			);
		}

		add_submenu_page( null, __( 'Splash Screen', 'mobishop' ), __( 'Splash Screen', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-splash-screen', array( $this, 'splash_screen_page' ) );
		add_submenu_page( null, __( 'Similar Products', 'mobishop' ), __( 'Similar Products', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-similar-products', array( $this, 'similar_products_page' ) );
		add_submenu_page( null, __( 'Checkout Suggestions', 'mobishop' ), __( 'Checkout Suggestions', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-checkout-suggestions', array( $this, 'checkout_suggestions_page' ) );
		add_submenu_page( null, __( 'Setup & Themes', 'mobishop' ), __( 'Setup & Themes', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-setup', array( $this, 'setup_wizard_page' ) );
		add_submenu_page( null, __( 'Saved Themes', 'mobishop' ), __( 'Saved Themes', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-saved-themes', array( $this, 'saved_themes_page' ) );
		add_submenu_page( null, __( 'Store Data', 'mobishop' ), __( 'Store Data', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-store-data', array( $this, 'store_data_page' ) );
		add_submenu_page( null, __( 'AI Offer Studio', 'mobishop' ), __( 'AI Offer Studio', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-ai-insights', array( $this, 'ai_insights_page' ) );
		add_submenu_page( null, __( 'Bundles', 'mobishop' ), __( 'Bundles', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-bundles', array( $this, 'bundles_page' ) );
		add_submenu_page( null, __( 'Push Notifications', 'mobishop' ), __( 'Push Notifications', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-push-notifications', array( $this, 'push_notifications_page' ) );
		add_submenu_page( null, __( 'Website App Promotion', 'mobishop' ), __( 'Website App Promotion', 'mobishop' ), self::CAPABILITY, 'kidia-mobile-website-app-promotion', array( $this, 'website_app_promotion_page' ) );

	}

	/** Renders website-to-app promotion campaigns and settings. */
	public function website_app_promotion_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'mobishop' ) );
		}
		$promotion_settings = Kidia_Mobile_Website_App_Promotion::settings();
		$promotion_metrics  = Kidia_Mobile_Website_App_Promotion::metrics();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/website-app-promotion.php';
	}

	/** Renders the guided first-run setup and reusable theme gallery. */
	public function setup_wizard_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'mobishop' ) );
		}
		$wizard       = new Kidia_Mobile_Setup_Wizard();
		$identity     = $wizard->identity();
		$themes       = Kidia_Mobile_Setup_Wizard::themes();
		$setup_pages  = Kidia_Mobile_Setup_Wizard::setup_pages();
		$push_export_config = Kidia_Mobile_Push_Service::client_configuration();
		$app_export_state   = Kidia_Mobile_App_Exporter::state();
		$catalog_stats  = array( 'products' => 0, 'categories' => 0, 'images' => 0 );
		if ( function_exists( 'wp_count_posts' ) ) {
			$count = wp_count_posts( 'product' );
			$catalog_stats['products'] = is_object( $count ) ? absint( $count->publish ?? 0 ) : 0;
		}
		if ( taxonomy_exists( 'product_cat' ) ) {
			$count = wp_count_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false ) );
			$catalog_stats['categories'] = is_wp_error( $count ) ? 0 : absint( $count );
		}
		if ( function_exists( 'wc_get_products' ) ) {
			foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => 100, 'return' => 'objects' ) ) as $product ) {
				if ( is_object( $product ) && method_exists( $product, 'get_image_id' ) && $product->get_image_id() ) {
					++$catalog_stats['images'];
				}
			}
		}
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/setup-wizard.php';
	}

	/** Renders the reusable saved-theme library. */
	public function saved_themes_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'mobishop' ) );
		}
		$wizard       = new Kidia_Mobile_Setup_Wizard();
		$saved_themes = $wizard->saved_themes();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/saved-themes.php';
	}

	/** Central WooCommerce data workspace backed by the current site. */
	public function store_data_page(): void {
	…27051 tokens truncated…MS_URL . 'public/assets/vendor/qrcode.min.js',
							array(),
							'1.0.0',
							true
						);
						wp_enqueue_script(
							'kidia-mobile-website-app-promotion-admin',
							KIDIA_MOBILE_CMS_URL . 'admin/assets/website-app-promotion.js',
							array( 'kidia-mobile-qrcode' ),
							KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/website-app-promotion.js' ),
							true
						);
					}
					if (
						'kidia-mobile-cms' !== $page
						&& $this->is_public_cms_page( $page )
						&& ! ( new Kidia_Mobile_License_Manager() )->is_active()
					) {
						wp_enqueue_style( 'kidia-mobile-license-preview', KIDIA_MOBILE_CMS_URL . 'admin/assets/license-preview.css', array( 'kidia-mobile-cms-shell' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/license-preview.css' ) );
						wp_enqueue_script( 'kidia-mobile-license-preview', KIDIA_MOBILE_CMS_URL . 'admin/assets/license-preview.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/license-preview.js' ), true );
						wp_localize_script(
							'kidia-mobile-license-preview',
							'kidiaLicensePreview',
							array(
								'title'       => __( 'Preview mode', 'mobishop' ),
								'message'     => __( 'The default theme remains available to browse. Activate your website license to edit or save any setting.', 'mobishop' ),
								'actionLabel' => __( 'Connect or activate', 'mobishop' ),
								'actionUrl'   => admin_url( 'admin.php?page=kidia-mobile-cms#kidia-license-key' ),
							)
						);
					}
					if ( in_array( $page, array( 'kidia-mobile-setup', 'kidia-mobile-saved-themes' ), true ) || ( 'kidia-mobile-cms' === $page && ! ( new Kidia_Mobile_Setup_Wizard() )->is_complete() ) ) {
						wp_enqueue_media();
						wp_enqueue_style( 'kidia-mobile-setup-wizard', KIDIA_MOBILE_CMS_URL . 'admin/assets/setup-wizard.css', array( 'kidia-mobile-cms-shell' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/setup-wizard.css' ) );
						if ( 'kidia-mobile-saved-themes' === $page ) {
							wp_enqueue_script( 'kidia-mobile-saved-themes', KIDIA_MOBILE_CMS_URL . 'admin/assets/saved-themes.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/saved-themes.js' ), true );
							$preview_product_id = 1;
							if ( function_exists( 'wc_get_products' ) ) {
								$preview_product_ids = wc_get_products( array( 'status' => 'publish', 'limit' => 1, 'return' => 'ids' ) );
								if ( ! empty( $preview_product_ids[0] ) ) {
									$preview_product_id = absint( $preview_product_ids[0] );
								}
							}
							wp_localize_script(
								'kidia-mobile-saved-themes',
								'kidiaSavedThemePreview',
								array(
									'flutterUrl'              => KIDIA_MOBILE_CMS_URL . 'admin/flutter-preview/index.html',
									'layoutPreviewBase'       => rest_url( 'woo-mobile/v1/page-layout/' ),
									'homePreviewEndpoint'     => rest_url( 'woomobileapp/v1/home-layout/preview' ),
									'categoryPreviewEndpoint' => rest_url( 'woo-mobile/v1/category-page/preview' ),
									'restNonce'               => wp_create_nonce( 'wp_rest' ),
									'productId'               => $preview_product_id,
									'version'                 => KIDIA_MOBILE_CMS_VERSION,
									'errorLabel'              => __( 'The real preview could not be loaded. Try opening it again.', 'mobishop' ),
								)
							);
						} else {
							wp_enqueue_script( 'kidia-mobile-setup-wizard', KIDIA_MOBILE_CMS_URL . 'admin/assets/setup-wizard.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/setup-wizard.js' ), true );
							$setup_preview_wizard = new Kidia_Mobile_Setup_Wizard();
							$setup_theme_snapshots = array();
							foreach ( array_keys( Kidia_Mobile_Setup_Wizard::themes() ) as $setup_theme_key ) {
								$setup_theme_snapshots[ $setup_theme_key ] = $setup_preview_wizard->preview_snapshot( (string) $setup_theme_key );
							}
							wp_localize_script(
								'kidia-mobile-setup-wizard',
								'kidiaSetupThemePreview',
								array(
									'flutterUrl' => KIDIA_MOBILE_CMS_URL . 'admin/flutter-preview/index.html',
									'layoutPreviewBase' => rest_url( 'woo-mobile/v1/page-layout/' ),
									'homePreviewEndpoint' => rest_url( 'woomobileapp/v1/home-layout/preview' ),
									'categoryPreviewEndpoint' => rest_url( 'woo-mobile/v1/category-page/preview' ),
									'restNonce' => wp_create_nonce( 'wp_rest' ),
									'productId' => 9001,
									'version' => KIDIA_MOBILE_CMS_VERSION,
									'themes' => $setup_theme_snapshots,
									'errorLabel' => __( 'The real theme preview could not be loaded. Try opening it again.', 'mobishop' ),
								)
							);
						}
						return;
					}

					if (
							'kidia-mobile-home-builder' !== $page
							&& 'kidia-mobile-category-builder' !== $page
							&& ! isset( self::PAGE_BUILDER_SLUGS[ $page ] )
							&& 'kidia-mobile-splash-screen' !== $page
							&& 'kidia-mobile-similar-products' !== $page
							&& 'kidia-mobile-checkout-suggestions' !== $page
							&& 'kidia-mobile-cms_page_kidia-mobile-home-builder'
								!== $hook_suffix
					) {
            			return;
            		}

					wp_enqueue_media();
					wp_enqueue_style( 'kidia-mobile-fixed-chrome', KIDIA_MOBILE_CMS_URL . 'admin/assets/page-builder.css', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/page-builder.css' ) );
					wp_enqueue_style( 'kidia-mobile-chrome-layout', KIDIA_MOBILE_CMS_URL . 'admin/assets/chrome-layout.css', array( 'kidia-mobile-fixed-chrome' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/chrome-layout.css' ) );
					if ( 'kidia-mobile-checkout-suggestions' === $page ) {
						wp_enqueue_script( 'kidia-mobile-checkout-fields', KIDIA_MOBILE_CMS_URL . 'admin/assets/checkout-fields-builder.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/checkout-fields-builder.js' ), true );
					}
					wp_enqueue_script( 'kidia-mobile-settings-sections', KIDIA_MOBILE_CMS_URL . 'admin/assets/settings-sections.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/settings-sections.js' ), true );
					wp_localize_script(
						'kidia-mobile-settings-sections',
						'kidiaProductApplyAll',
						array(
							'ajaxUrl' => admin_url( 'admin-ajax.php' ),
							'nonce'   => wp_create_nonce( 'kidia_mobile_apply_product_icon_settings' ),
							'labels'  => array(
								'apply'   => __( 'Apply to all', 'mobishop' ),
								'working' => __( 'Applying…', 'mobishop' ),
								'error'   => __( 'Could not apply these settings.', 'mobishop' ),
							),
						)
					);
					wp_enqueue_script( 'kidia-mobile-chrome-layout', KIDIA_MOBILE_CMS_URL . 'admin/assets/chrome-layout.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/chrome-layout.js' ), true );
					$category_footer = ( new Kidia_Mobile_Page_Layout_Store() )->get_layout( 'category' )['footer']['settings'];
					wp_localize_script(
						'kidia-mobile-chrome-layout',
						'kidiaChromePreviewConfig',
						array(
							'footerSize' => array(
								'height'         => $category_footer['height'],
								'iconSize'       => $category_footer['icon_size'],
								'labelSize'      => $category_footer['label_size'],
								'iconLabelGap'   => $category_footer['icon_label_gap'],
							),
						)
					);

					$is_layout_builder = 'kidia-mobile-home-builder' === $page
						|| 'kidia-mobile-category-builder' === $page
						|| isset( self::PAGE_BUILDER_SLUGS[ $page ] )
						|| 'kidia-mobile-cms_page_kidia-mobile-home-builder' === $hook_suffix;
					if ( $is_layout_builder ) {
						wp_enqueue_script( 'kidia-mobile-unsaved-changes', KIDIA_MOBILE_CMS_URL . 'admin/assets/unsaved-changes.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/unsaved-changes.js' ), true );
						wp_localize_script(
							'kidia-mobile-unsaved-changes',
							'kidiaUnsavedChanges',
							array(
								'labels' => array(
									'title'   => __( 'Unsaved changes', 'mobishop' ),
									'message' => __( 'You have changes that have not been saved. What would you like to do?', 'mobishop' ),
									'save'    => __( 'Save Changes', 'mobishop' ),
									'discard' => __( 'Discard Changes', 'mobishop' ),
									'cancel'  => __( 'Cancel', 'mobishop' ),
								),
							)
						);
					}

					if ( 'kidia-mobile-splash-screen' === $page ) {
						wp_enqueue_script( 'kidia-mobile-splash-screen', KIDIA_MOBILE_CMS_URL . 'admin/assets/splash-screen.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/splash-screen.js' ), true ); return;
					}
					if ( 'kidia-mobile-checkout-suggestions' === $page ) {
						wp_enqueue_script( 'kidia-mobile-commerce-preview', KIDIA_MOBILE_CMS_URL . 'admin/assets/commerce-preview.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/commerce-preview.js' ), true );
						return;
					}
					if ( 'kidia-mobile-similar-products' === $page ) {
						$preview_products = array();
						if ( function_exists( 'wc_get_products' ) ) {
							foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => 8, 'orderby' => 'date', 'order' => 'DESC' ) ) as $product ) {
								if ( ! is_object( $product ) || ! method_exists( $product, 'get_name' ) ) { continue; }
								$image_id = method_exists( $product, 'get_image_id' ) ? absint( $product->get_image_id() ) : 0;
								$preview_products[] = array( 'name' => sanitize_text_field( (string) $product->get_name() ), 'price' => wp_strip_all_tags( method_exists( $product, 'get_price_html' ) ? (string) $product->get_price_html() : '' ), 'image_url' => $image_id ? (string) wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' ) : '' );
							}
						}
						wp_enqueue_script( 'kidia-mobile-commerce-preview', KIDIA_MOBILE_CMS_URL . 'admin/assets/commerce-preview.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/commerce-preview.js' ), true );
						wp_localize_script( 'kidia-mobile-commerce-preview', 'kidiaCommercePreview', array( 'products' => $preview_products ) );
						return;
					}

					if ( 'kidia-mobile-category-builder' === $page ) {
						wp_enqueue_style( 'kidia-mobile-category-builder', KIDIA_MOBILE_CMS_URL . 'admin/assets/category-builder.css', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/category-builder.css' ) );
						wp_enqueue_script( 'kidia-mobile-category-builder', KIDIA_MOBILE_CMS_URL . 'admin/assets/category-builder.js', array( 'jquery', 'jquery-ui-sortable' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/category-builder.js' ), true );
						if ( file_exists( KIDIA_MOBILE_CMS_PATH . 'admin/flutter-preview/index.html' ) ) {
							wp_enqueue_script( 'kidia-mobile-flutter-category-preview-bridge', KIDIA_MOBILE_CMS_URL . 'admin/assets/flutter-category-preview-bridge.js', array( 'kidia-mobile-category-builder' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/flutter-category-preview-bridge.js' ), true );
							wp_localize_script( 'kidia-mobile-flutter-category-preview-bridge', 'kidiaFlutterPreview', array(
								'layoutPreviewEndpoint' => esc_url_raw( rest_url( 'woo-mobile/v1/page-layout/category/preview' ) ),
								'categoryPreviewEndpoint' => esc_url_raw( rest_url( 'woo-mobile/v1/category-page/preview' ) ),
								'restNonce' => wp_create_nonce( 'wp_rest' ),
							) );
						}
						return;
					}

					if ( isset( self::PAGE_BUILDER_SLUGS[ $page ] ) ) {
						$preview_products = array();
						if ( function_exists( 'wc_get_products' ) ) {
							foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => 6, 'orderby' => 'date', 'order' => 'DESC' ) ) as $product ) {
								if ( ! is_object( $product ) || ! method_exists( $product, 'get_name' ) ) {
									continue;
								}
								$image_id = method_exists( $product, 'get_image_id' ) ? absint( $product->get_image_id() ) : 0;
								$preview_products[] = array(
									'name'      => sanitize_text_field( (string) $product->get_name() ),
									'price'     => wp_strip_all_tags( method_exists( $product, 'get_price_html' ) ? (string) $product->get_price_html() : '' ),
									'image_url' => $image_id ? (string) wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' ) : '',
								);
							}
						}
						wp_enqueue_style( 'kidia-mobile-page-builder', KIDIA_MOBILE_CMS_URL . 'admin/assets/page-builder.css', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/page-builder.css' ) );
						wp_enqueue_script( 'kidia-mobile-page-builder', KIDIA_MOBILE_CMS_URL . 'admin/assets/page-builder.js', array( 'jquery', 'jquery-ui-sortable' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/page-builder.js' ), true );
						if ( file_exists( KIDIA_MOBILE_CMS_PATH . 'admin/flutter-preview/index.html' ) ) {
							wp_enqueue_script( 'kidia-mobile-flutter-preview-bridge', KIDIA_MOBILE_CMS_URL . 'admin/assets/flutter-preview-bridge.js', array( 'kidia-mobile-page-builder' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/flutter-preview-bridge.js' ), true );
							wp_localize_script( 'kidia-mobile-flutter-preview-bridge', 'kidiaFlutterPreview', array(
								'layoutPreviewEndpoint' => esc_url_raw( rest_url( 'woo-mobile/v1/page-layout/' . self::PAGE_BUILDER_SLUGS[ $page ] . '/preview' ) ),
								'restNonce' => wp_create_nonce( 'wp_rest' ),
							) );
						}
						wp_localize_script(
							'kidia-mobile-page-builder',
							'kidiaPageBuilder',
							array(
								'page' => self::PAGE_BUILDER_SLUGS[ $page ],
								'products' => $preview_products,
								'labels' => array( 'hidden' => __( 'Hidden', 'mobishop' ), 'visible' => __( 'Visible', 'mobishop' ) ),
							)
						);
						return;
					}

					wp_enqueue_style(
						'kidia-mobile-home-builder',
						KIDIA_MOBILE_CMS_URL .
						'admin/assets/home-builder.css',
						array(),
						KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/home-builder.css' )
					);

					wp_enqueue_script(
						'kidia-mobile-home-builder',
						KIDIA_MOBILE_CMS_URL .
						'admin/assets/home-builder.js',
						array(),
						KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/home-builder.js' ),
						true
					);
					if ( file_exists( KIDIA_MOBILE_CMS_PATH . 'admin/flutter-preview/index.html' ) ) {
						wp_enqueue_script( 'kidia-mobile-flutter-home-preview-bridge', KIDIA_MOBILE_CMS_URL . 'admin/assets/flutter-home-preview-bridge.js', array( 'kidia-mobile-home-builder' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/flutter-home-preview-bridge.js' ), true );
					}

					$preview_locale = sanitize_key( (string) get_locale() );
					if ( '' === $preview_locale ) {
						$preview_locale = 'en';
					}

            		wp_localize_script(
            			'kidia-mobile-home-builder',
            			'kidiaHomeBuilder',
            			array(
						'labels' => array(
            					'deleteConfirm' => __(
									'Remove this element from the Home page?',
            						'mobishop'
            					),
							'untitled'      => __(
								'Untitled Element',
								'mobishop'
							),
							'createPrefix'   => __( 'Create', 'mobishop' ),
							'draft'          => __( 'Draft', 'mobishop' ),
							'published'      => __( 'Published', 'mobishop' ),
							'copySuffix'     => __( ' Copy', 'mobishop' ),
							'noElements'     => __( 'No elements on the Home Page', 'mobishop' ),
							'noElementsDescription' => __(
								'Add an element to start building the application Home Page.',
								'mobishop'
							),
							'addFirst'       => __( 'Add First Element', 'mobishop' ),
							'chooseDestination' => __( 'Choose destination', 'mobishop' ),
							'currentDestination' => __( 'Current value', 'mobishop' ),
							'externalUrl' => __( 'External URL', 'mobishop' ),
							'searchTerm' => __( 'Search term', 'mobishop' ),
							'productId' => __( 'Product ID', 'mobishop' ),
							'actionValue' => __( 'Action Value', 'mobishop' ),
							'onSaleProducts' => __( 'Products on sale', 'mobishop' ),
						),
						'editorPages'     => self::EDITOR_PAGES,
						'actionChoices'    => $this->get_action_choices(),
						'previewEndpoint' => esc_url_raw(
							add_query_arg(
								'locale',
								$preview_locale,
								rest_url( 'woomobileapp/v1/home-layout' )
							)
						),
					'livePreviewEndpoint' => esc_url_raw( rest_url( 'woomobileapp/v1/home-layout/preview' ) ),
					'layoutPreviewEndpoint' => esc_url_raw( rest_url( 'woo-mobile/v1/page-layout/home/preview' ) ),
						'restNonce'           => wp_create_nonce( 'wp_rest' ),
					)
            		);
            	}

	/**
	 * Returns the real WooCommerce destinations used by Action Value controls.
	 *
	 * @return array<string,array<int,array<string,string>>>
	 */
	private function get_action_choices(): array {
		$choices = array(
			'collection' => array(
				array( 'value' => 'latest', 'label' => __( 'Latest products', 'mobishop' ) ),
				array( 'value' => 'featured', 'label' => __( 'Featured products', 'mobishop' ) ),
				array( 'value' => 'on_sale', 'label' => __( 'Products on sale', 'mobishop' ) ),
				array( 'value' => 'best_selling', 'label' => __( 'Best selling', 'mobishop' ) ),
				array( 'value' => 'top_rated', 'label' => __( 'Top rated', 'mobishop' ) ),
			),
			'product'    => array(),
			'category'   => array(),
			'brand'      => array(),
		);

		if ( post_type_exists( 'product' ) ) {
			$product_ids = get_posts(
				array(
					'post_type'      => 'product',
					'post_status'    => 'publish',
					'posts_per_page' => 500,
					'orderby'        => 'title',
					'order'          => 'ASC',
					'fields'         => 'ids',
				)
			);
			foreach ( $product_ids as $product_id ) {
				$choices['product'][] = array(
					'value' => (string) absint( $product_id ),
					'label' => sprintf( '%s — #%d', get_the_title( $product_id ), absint( $product_id ) ),
				);
			}
		}

		if ( taxonomy_exists( 'product_cat' ) ) {
			$terms = get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false, 'orderby' => 'name' ) );
			if ( ! is_wp_error( $terms ) ) {
				foreach ( $terms as $term ) {
					$choices['category'][] = array(
						'value' => (string) $term->term_id,
						'label' => sprintf( '%s — #%d', $term->name, $term->term_id ),
					);
				}
			}
		}

		foreach ( array( 'product_brand', 'pwb-brand', 'yith_product_brand' ) as $taxonomy ) {
			if ( ! taxonomy_exists( $taxonomy ) ) {
				continue;
			}
			$terms = get_terms( array( 'taxonomy' => $taxonomy, 'hide_empty' => false, 'orderby' => 'name' ) );
			if ( ! is_wp_error( $terms ) ) {
				foreach ( $terms as $term ) {
					$choices['brand'][] = array(
						'value' => (string) $term->term_id,
						'label' => sprintf( '%s — #%d', $term->name, $term->term_id ),
					);
				}
			}
			break;
		}

		return $choices;
	}
            }
