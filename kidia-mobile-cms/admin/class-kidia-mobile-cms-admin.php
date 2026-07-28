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

	/** @var array<string,string> */
	private const PAGE_BUILDER_SLUGS = array(
		'kidia-mobile-catalog-builder'  => 'catalog',
		'kidia-mobile-product-builder'  => 'product',
		'kidia-mobile-size-chart-builder' => 'size_chart',
		'kidia-mobile-wishlist-builder' => 'wishlist',
		'kidia-mobile-account-builder'  => 'account',
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
			add_action( 'admin_post_kidia_mobile_build_ai_action', array( $this, 'build_ai_action' ) );
			add_action( 'admin_post_kidia_mobile_review_ai_result', array( $this, 'review_ai_result' ) );
		add_action( 'admin_post_kidia_mobile_toggle_product_channel', array( $this, 'toggle_product_channel' ) );
		add_action( 'admin_post_kidia_mobile_set_coupon_channel', array( $this, 'set_coupon_channel' ) );
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
		);

		if (
			! $license_active
			&& 0 === strpos( $action, 'kidia_mobile_' )
			&& ! in_array( $action, $allowed, true )
		) {
			if ( wp_doing_ajax() ) {
				wp_send_json_error(
					array(
						'message' => __( 'Activate your website license before changing Woo Mobile CMS settings.', 'kidia-mobile-cms' ),
					),
					403
				);
			}

			wp_die(
				esc_html__( 'Activate your website license before changing Woo Mobile CMS settings.', 'kidia-mobile-cms' ),
				esc_html__( 'License required', 'kidia-mobile-cms' ),
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
		$page = isset( $_GET['page'] )
			? sanitize_key( wp_unslash( $_GET['page'] ) )
			: '';
		$builder_pages = array_merge(
			array(
				'kidia-mobile-home-builder',
				'kidia-mobile-category-builder',
				'kidia-mobile-splash-screen',
			),
			array_keys( self::PAGE_BUILDER_SLUGS )
		);

		if ( in_array( $page, $builder_pages, true ) ) {
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

	/**
	 * Keeps third-party and WordPress notices outside the unified CMS workspace.
	 *
	 * @return void
	 */
	public function suppress_external_admin_notices(): void {
		$page = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : '';
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
			wp_send_json_error( array( 'message' => __( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_apply_product_icon_settings', 'nonce' );
		$scope = isset( $_POST['scope'] ) ? sanitize_key( wp_unslash( $_POST['scope'] ) ) : '';
		if ( ! in_array( $scope, array( 'quick_add', 'wishlist' ), true ) ) {
			wp_send_json_error( array( 'message' => __( 'Unknown settings group.', 'kidia-mobile-cms' ) ), 400 );
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
			wp_send_json_error( array( 'message' => __( 'Some settings are missing.', 'kidia-mobile-cms' ) ), 400 );
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
				'message' => sprintf( __( 'Applied to %d saved product elements.', 'kidia-mobile-cms' ), $changed ),
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
    			__( 'Woo Mobile CMS', 'kidia-mobile-cms' ),
    			__( 'Woo Mobile CMS', 'kidia-mobile-cms' ),
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
				__( 'Home Page', 'kidia-mobile-cms' ),
				__( 'Home Page', 'kidia-mobile-cms' ),
    			self::CAPABILITY,
    			'kidia-mobile-home-builder',
    			array(
    				$this,
    				'home_builder_page',
    			)
    		);

		add_submenu_page(
			null,
			__( 'Category Page', 'kidia-mobile-cms' ),
			__( 'Category Page', 'kidia-mobile-cms' ),
			self::CAPABILITY,
			'kidia-mobile-category-builder',
			array( $this, 'category_builder_page' )
		);

		foreach ( self::PAGE_BUILDER_SLUGS as $slug => $page ) {
			$labels = Kidia_Mobile_Page_Layout_Store::pages();
			$label = $labels[ $page ];
			add_submenu_page(
				null,
				$label . ' ' . __( 'Builder', 'kidia-mobile-cms' ),
				$label,
				self::CAPABILITY,
				$slug,
				array( $this, 'page_builder_page' )
			);
		}

		add_submenu_page( null, __( 'Splash Screen', 'kidia-mobile-cms' ), __( 'Splash Screen', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-splash-screen', array( $this, 'splash_screen_page' ) );
		add_submenu_page( null, __( 'Similar Products', 'kidia-mobile-cms' ), __( 'Similar Products', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-similar-products', array( $this, 'similar_products_page' ) );
		add_submenu_page( null, __( 'Checkout Suggestions', 'kidia-mobile-cms' ), __( 'Checkout Suggestions', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-checkout-suggestions', array( $this, 'checkout_suggestions_page' ) );
		add_submenu_page( null, __( 'Setup & Themes', 'kidia-mobile-cms' ), __( 'Setup & Themes', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-setup', array( $this, 'setup_wizard_page' ) );
		add_submenu_page( null, __( 'Saved Themes', 'kidia-mobile-cms' ), __( 'Saved Themes', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-saved-themes', array( $this, 'saved_themes_page' ) );
		add_submenu_page( null, __( 'Store Data', 'kidia-mobile-cms' ), __( 'Store Data', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-store-data', array( $this, 'store_data_page' ) );
		add_submenu_page( null, __( 'AI Offer Studio', 'kidia-mobile-cms' ), __( 'AI Offer Studio', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-ai-insights', array( $this, 'ai_insights_page' ) );
		add_submenu_page( null, __( 'Push Notifications', 'kidia-mobile-cms' ), __( 'Push Notifications', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-push-notifications', array( $this, 'push_notifications_page' ) );

	}

	/** Renders the guided first-run setup and reusable theme gallery. */
	public function setup_wizard_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$wizard       = new Kidia_Mobile_Setup_Wizard();
		$identity     = $wizard->identity();
		$themes       = Kidia_Mobile_Setup_Wizard::themes();
		$setup_pages  = Kidia_Mobile_Setup_Wizard::setup_pages();
		$push_export_config = Kidia_Mobile_Push_Service::client_configuration();
		$app_export_state   = Kidia_Mobile_App_Exporter::state();
		$catalog_stats  = array( 'products' => 0, 'categories' => 0, 'images' => 0 );
		$catalog_images = array();
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
					if ( count( $catalog_images ) < 3 ) {
						$image_url = wp_get_attachment_image_url( absint( $product->get_image_id() ), 'woocommerce_thumbnail' );
						if ( $image_url ) {
							$catalog_images[] = (string) $image_url;
						}
					}
				}
			}
		}
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/setup-wizard.php';
	}

	/** Renders the reusable saved-theme library. */
	public function saved_themes_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$wizard       = new Kidia_Mobile_Setup_Wizard();
		$saved_themes = $wizard->saved_themes();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/saved-themes.php';
	}

	/** Central WooCommerce data workspace backed by the current site. */
	public function store_data_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$store_tab    = isset( $_GET['store_tab'] ) ? sanitize_key( wp_unslash( $_GET['store_tab'] ) ) : 'products';
		$store_source = isset( $_GET['store_source'] ) ? sanitize_key( wp_unslash( $_GET['store_source'] ) ) : 'all';
		$store_source = in_array( $store_source, array( 'all', 'website', 'mobile' ), true ) ? $store_source : 'all';
		$allowed      = array( 'products', 'categories', 'discounts', 'customers', 'orders', 'reports', 'analytics', 'abandoned-carts' );
		$store_tab    = in_array( $store_tab, $allowed, true ) ? $store_tab : 'products';

		$date_default = in_array( $store_tab, array( 'customers', 'abandoned-carts' ), true ) ? 'all_time' : 'last_30_days';
		$date_preset = isset( $_GET['date_preset'] ) ? sanitize_key( wp_unslash( $_GET['date_preset'] ) ) : $date_default;
		$date_range  = $this->store_data_date_range( $date_preset );
		$date_from   = $date_range['from'];
		$date_to     = $date_range['to'];
		$date_preset = $date_range['preset'];
		$previous_to = $date_from - 1;
		$previous_from = $previous_to - ( $date_to - $date_from );

		$product_page     = max( 1, absint( $_GET['product_page'] ?? 1 ) );
		$product_per_page = 20;
		$product_search   = isset( $_GET['product_search'] )
			? sanitize_text_field( wp_unslash( $_GET['product_search'] ) )
			: '';
		$product_visibility = isset( $_GET['product_visibility'] )
			? sanitize_key( wp_unslash( $_GET['product_visibility'] ) )
			: 'all';
		$product_visibility = in_array( $product_visibility, array( 'all', 'shown', 'hidden_mobile', 'hidden_website', 'hidden_both' ), true )
			? $product_visibility
			: 'all';
		$product_query    = null;
		$products         = array();
		$product_total    = 0;
		$product_pages    = 1;
		if ( 'products' === $store_tab && function_exists( 'wc_get_product' ) ) {
			$product_query_args = array(
				'post_type'              => 'product',
				'post_status'            => array( 'publish', 'draft', 'pending', 'private', 'future' ),
				'posts_per_page'         => $product_per_page,
				'paged'                  => $product_page,
				'orderby'                => 'date',
				'order'                  => 'DESC',
				'fields'                 => 'ids',
				'no_found_rows'          => false,
				'update_post_meta_cache' => true,
				'update_post_term_cache' => false,
			);
			if ( '' !== $product_search ) {
				$product_query_args['s'] = $product_search;
				$sku_product_id = function_exists( 'wc_get_product_id_by_sku' )
					? absint( wc_get_product_id_by_sku( $product_search ) )
					: 0;
				if ( $sku_product_id > 0 ) {
					unset( $product_query_args['s'] );
					$product_query_args['post__in'] = array( $sku_product_id );
				}
			}
			if ( 'hidden_mobile' === $product_visibility ) {
				$product_query_args['meta_query'] = array( array( 'key' => Kidia_Mobile_Product_Channel_Visibility::MOBILE_META, 'value' => 'yes' ) );
			} elseif ( 'hidden_website' === $product_visibility ) {
				$product_query_args['meta_query'] = array( array( 'key' => Kidia_Mobile_Product_Channel_Visibility::WEBSITE_META, 'value' => 'yes' ) );
			} elseif ( 'hidden_both' === $product_visibility ) {
				$product_query_args['meta_query'] = array(
					'relation' => 'AND',
					array( 'key' => Kidia_Mobile_Product_Channel_Visibility::MOBILE_META, 'value' => 'yes' ),
					array( 'key' => Kidia_Mobile_Product_Channel_Visibility::WEBSITE_META, 'value' => 'yes' ),
				);
			} elseif ( 'shown' === $product_visibility ) {
				$product_query_args['meta_query'] = array(
					'relation' => 'AND',
					array(
						'relation' => 'OR',
						array( 'key' => Kidia_Mobile_Product_Channel_Visibility::MOBILE_META, 'compare' => 'NOT EXISTS' ),
						array( 'key' => Kidia_Mobile_Product_Channel_Visibility::MOBILE_META, 'value' => 'yes', 'compare' => '!=' ),
					),
					array(
						'relation' => 'OR',
						array( 'key' => Kidia_Mobile_Product_Channel_Visibility::WEBSITE_META, 'compare' => 'NOT EXISTS' ),
						array( 'key' => Kidia_Mobile_Product_Channel_Visibility::WEBSITE_META, 'value' => 'yes', 'compare' => '!=' ),
					),
				);
			}
			$product_query = new WP_Query( $product_query_args );
			foreach ( $product_query->posts as $product_id ) {
				$product = wc_get_product( $product_id );
				if ( $product instanceof WC_Product ) {
					$products[] = $product;
				}
			}
			$product_total = absint( $product_query->found_posts );
			$product_pages = max( 1, absint( $product_query->max_num_pages ) );
		}
		$coupon_page   = max( 1, absint( $_GET['coupon_page'] ?? 1 ) );
		$coupon_search = isset( $_GET['coupon_search'] ) ? sanitize_text_field( wp_unslash( $_GET['coupon_search'] ) ) : '';
		$coupon_status = isset( $_GET['coupon_status'] ) ? sanitize_key( wp_unslash( $_GET['coupon_status'] ) ) : 'all';
		$coupon_type   = isset( $_GET['coupon_type'] ) ? sanitize_key( wp_unslash( $_GET['coupon_type'] ) ) : 'all';
		$coupon_scope  = isset( $_GET['coupon_scope'] ) ? sanitize_key( wp_unslash( $_GET['coupon_scope'] ) ) : 'all';
		$coupon_channel = isset( $_GET['coupon_channel'] ) ? sanitize_key( wp_unslash( $_GET['coupon_channel'] ) ) : 'any';
		$coupon_query  = null;
		$coupons       = array();
		$coupon_total  = 0;
		$coupon_pages  = 1;
		if ( 'discounts' === $store_tab ) {
			$coupon_args = array(
				'post_type'              => 'shop_coupon',
				'post_status'            => array( 'publish', 'draft', 'pending', 'private', 'future' ),
				'posts_per_page'         => 24,
				'paged'                  => $coupon_page,
				'orderby'                => 'date',
				'order'                  => 'DESC',
				'no_found_rows'          => false,
				'update_post_meta_cache' => true,
			);
			if ( '' !== $coupon_search ) {
				$coupon_args['s'] = $coupon_search;
			}
			if ( in_array( $coupon_status, array( 'draft', 'scheduled' ), true ) ) {
				$coupon_args['post_status'] = 'scheduled' === $coupon_status ? 'future' : 'draft';
			}
			$meta_query = array( 'relation' => 'AND' );
			$now        = time();
			if ( 'active' === $coupon_status ) {
				$coupon_args['post_status'] = 'publish';
				$meta_query[] = array(
					'relation' => 'OR',
					array( 'key' => '_date_expires', 'compare' => 'NOT EXISTS' ),
					array( 'key' => '_date_expires', 'value' => '', 'compare' => '=' ),
					array( 'key' => '_date_expires', 'value' => $now, 'compare' => '>=', 'type' => 'NUMERIC' ),
				);
			} elseif ( 'expired' === $coupon_status ) {
				$coupon_args['post_status'] = 'publish';
				$meta_query[] = array( 'key' => '_date_expires', 'value' => $now, 'compare' => '<', 'type' => 'NUMERIC' );
			}
			if ( in_array( $coupon_type, array( 'percent', 'fixed_cart', 'fixed_product' ), true ) ) {
				$meta_query[] = array( 'key' => '_discount_type', 'value' => $coupon_type );
			}
			if ( 'individual' === $coupon_scope ) {
				$meta_query[] = array( 'key' => '_individual_use', 'value' => 'yes' );
			} elseif ( 'product' === $coupon_scope ) {
				$meta_query[] = array( 'key' => '_product_ids', 'value' => '', 'compare' => '!=' );
			} elseif ( 'category' === $coupon_scope ) {
				$meta_query[] = array( 'key' => '_product_categories', 'value' => 'a:0:{}', 'compare' => '!=' );
			}
			if ( 'all' === $coupon_channel ) {
				$meta_query[] = array(
					'relation' => 'OR',
					array( 'key' => Kidia_Mobile_Coupon_Channel::META_KEY, 'compare' => 'NOT EXISTS' ),
					array( 'key' => Kidia_Mobile_Coupon_Channel::META_KEY, 'value' => 'all' ),
				);
			} elseif ( in_array( $coupon_channel, array( 'website', 'mobile' ), true ) ) {
				$meta_query[] = array( 'key' => Kidia_Mobile_Coupon_Channel::META_KEY, 'value' => $coupon_channel );
			}
			if ( count( $meta_query ) > 1 ) {
				$coupon_args['meta_query'] = $meta_query;
			}
			$coupon_query = new WP_Query( $coupon_args );
			$coupons      = $coupon_query->posts;
			$coupon_total = absint( $coupon_query->found_posts );
			$coupon_pages = max( 1, absint( $coupon_query->max_num_pages ) );
		}

		$category_terms = 'categories' === $store_tab && taxonomy_exists( 'product_cat' )
			? get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false, 'orderby' => 'name', 'order' => 'ASC' ) )
			: array();
		$parent_categories = array();
		$subcategory_groups = array();
		if ( ! is_wp_error( $category_terms ) ) {
			foreach ( $category_terms as $category ) {
				if ( 0 === (int) $category->parent ) {
					$parent_categories[] = $category;
					$subcategory_groups[ $category->term_id ] = array();
				}
			}
			foreach ( $category_terms as $category ) {
				if ( 0 !== (int) $category->parent ) {
					$root = $this->store_data_root_category( $category, $category_terms );
					$subcategory_groups[ $root ][] = $category;
				}
			}
		}

		$order_args = array(
			'limit'        => in_array( $store_tab, array( 'reports', 'analytics' ), true ) ? -1 : 60,
			'orderby'      => 'date',
			'order'        => 'DESC',
			'date_created' => gmdate( 'Y-m-d H:i:s', $date_from ) . '...' . gmdate( 'Y-m-d H:i:s', $date_to ),
		);
		$order_args = $this->store_data_order_source_args( $order_args, $store_source );
		$orders     = in_array( $store_tab, array( 'orders', 'reports' ), true ) && function_exists( 'wc_get_orders' )
			? wc_get_orders( $order_args )
			: array();

		$customer_page = max( 1, absint( $_GET['customer_page'] ?? 1 ) );
		$customer_args = array(
			'role__in'    => array( 'customer', 'subscriber' ),
			'number'      => 24,
			'paged'       => $customer_page,
			'orderby'     => 'registered',
			'order'       => 'DESC',
			'count_total' => true,
		);
		if ( 'all_time' !== $date_preset ) {
			$customer_args['date_query'] = array(
				array(
					'after'     => gmdate( 'Y-m-d H:i:s', $date_from ),
					'before'    => gmdate( 'Y-m-d H:i:s', $date_to ),
					'inclusive' => true,
				),
			);
		}
		if ( 'mobile' === $store_source ) {
			$customer_args['meta_query'] = array(
				'relation' => 'OR',
				array( 'key' => '_kidia_mobile_customer', 'value' => '1' ),
				array( 'key' => '_kidia_mobile_customer_sessions_v1', 'compare' => 'EXISTS' ),
			);
		}
		$customer_query = 'customers' === $store_tab ? new WP_User_Query( $customer_args ) : null;
		$customers      = $customer_query instanceof WP_User_Query ? $customer_query->get_results() : array();
		if ( ! empty( $customers ) ) {
			update_meta_cache( 'user', wp_list_pluck( $customers, 'ID' ) );
		}
		if ( 'website' === $store_source ) {
			$customers = array_values(
				array_filter(
					$customers,
					static fn( WP_User $customer ): bool => Kidia_Mobile_Analytics::customer_sources( $customer->ID )['website']
				)
			);
		}
		$customer_total = $customer_query instanceof WP_User_Query ? absint( $customer_query->get_total() ) : 0;
		$customer_pages = max( 1, (int) ceil( $customer_total / 24 ) );

		$order_revenue = 0.0;
		$order_units   = 0;
		$paid_order_count = 0;
		$order_statuses = array();
		$product_performance = array();
		$paid_statuses = function_exists( 'wc_get_is_paid_statuses' ) ? wc_get_is_paid_statuses() : array( 'processing', 'completed' );
		foreach ( $orders as $order ) {
			if ( ! is_object( $order ) || ! method_exists( $order, 'get_total' ) ) {
				continue;
			}
			$status = (string) $order->get_status();
			$order_statuses[ $status ] = ( $order_statuses[ $status ] ?? 0 ) + 1;
			if ( ! in_array( $status, $paid_statuses, true ) ) {
				continue;
			}
			++$paid_order_count;
			$order_revenue += (float) $order->get_total();
			foreach ( $order->get_items() as $item ) {
				$product_id = absint( $item->get_product_id() );
				if ( ! isset( $product_performance[ $product_id ] ) ) {
					$product_performance[ $product_id ] = array(
						'name'    => $item->get_name(),
						'units'   => 0,
						'revenue' => 0.0,
					);
				}
				$product_performance[ $product_id ]['units'] += absint( $item->get_quantity() );
				$product_performance[ $product_id ]['revenue'] += (float) $item->get_total();
				$order_units += absint( $item->get_quantity() );
			}
		}
		uasort( $product_performance, static fn( $left, $right ) => $right['revenue'] <=> $left['revenue'] );
		$product_performance = array_slice( $product_performance, 0, 10, true );

		$analytics = Kidia_Mobile_Analytics::empty_summary();
		$analytics_previous = Kidia_Mobile_Analytics::empty_summary();
		if ( 'analytics' === $store_tab ) {
			$analytics = Kidia_Mobile_Analytics::summary( $date_from, $date_to, $store_source, true );
			$analytics_previous = Kidia_Mobile_Analytics::summary( $previous_from, $previous_to, $store_source );
		}
		$abandoned_carts = 'abandoned-carts' === $store_tab
			? Kidia_Mobile_Analytics::abandoned_carts( $date_from, $date_to, $store_source, 150 )
			: array();
		$abandoned_summary = 'abandoned-carts' === $store_tab
			? Kidia_Mobile_Analytics::abandoned_summary( $date_from, $date_to, $store_source )
			: array();
		$abandoned_import = 'abandoned-carts' === $store_tab
			? Kidia_Mobile_Analytics::website_session_import_status()
			: array();
		$recovery_stats = 'abandoned-carts' === $store_tab ? Kidia_Mobile_Recovery_Campaigns::stats() : array();
		$recovery_campaigns = 'abandoned-carts' === $store_tab ? Kidia_Mobile_Recovery_Campaigns::recent( 50 ) : array();

		$category_count = taxonomy_exists( 'product_cat' )
			? wp_count_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false ) )
			: 0;
		$user_counts = count_users();
		$role_counts = is_array( $user_counts['avail_roles'] ?? null ) ? $user_counts['avail_roles'] : array();
		$post_counts = wp_count_posts( 'product' );
		$counts = array(
			'products'         => is_object( $post_counts ) ? absint( $post_counts->publish ?? 0 ) : 0,
			'categories'       => is_wp_error( $category_count ) ? 0 : absint( $category_count ),
			'discounts'        => is_object( wp_count_posts( 'shop_coupon' ) ) ? absint( wp_count_posts( 'shop_coupon' )->publish ?? 0 ) : count( $coupons ),
			'customers'        => absint( $role_counts['customer'] ?? 0 ) + absint( $role_counts['subscriber'] ?? 0 ),
			'orders'           => function_exists( 'wc_orders_count' ) ? absint( wc_orders_count( 'processing' ) + wc_orders_count( 'completed' ) + wc_orders_count( 'on-hold' ) ) : count( $orders ),
			'abandoned-carts'  => Kidia_Mobile_Analytics::abandoned_count(),
		);
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/store-data.php';
	}

	/** Toggle a product's visibility on the website or mobile app. */
	public function toggle_product_channel(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to change product visibility.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_toggle_product_channel' );

		$product_id = absint( $_POST['product_id'] ?? 0 );
		$channel    = isset( $_POST['channel'] ) ? sanitize_key( wp_unslash( $_POST['channel'] ) ) : '';
		$hidden     = isset( $_POST['hidden'] ) && '1' === (string) wp_unslash( $_POST['hidden'] );
		if ( $product_id <= 0 || ! in_array( $channel, array( 'website', 'mobile' ), true ) || 'product' !== get_post_type( $product_id ) ) {
			wp_die( esc_html__( 'The product visibility request is invalid.', 'kidia-mobile-cms' ) );
		}

		$meta_key = 'mobile' === $channel
			? Kidia_Mobile_Product_Channel_Visibility::MOBILE_META
			: Kidia_Mobile_Product_Channel_Visibility::WEBSITE_META;
		if ( $hidden ) {
			update_post_meta( $product_id, $meta_key, 'yes' );
		} else {
			delete_post_meta( $product_id, $meta_key );
		}
		clean_post_cache( $product_id );

		$redirect = wp_get_referer();
		$redirect = $redirect ? $redirect : add_query_arg(
			array( 'page' => 'kidia-mobile-store-data', 'store_tab' => 'products' ),
			admin_url( 'admin.php' )
		);
		wp_safe_redirect( add_query_arg( 'channel_visibility_updated', '1', $redirect ) );
		exit;
	}

	/**
	 * Resolves the selected reporting period in the site's timezone.
	 *
	 * @return array{preset:string,from:int,to:int}
	 */
	private function store_data_date_range( string $preset, ?array $request = null ): array {
		$allowed = array( 'all_time', 'today', 'yesterday', 'last_7_days', 'last_30_days', 'this_month', 'previous_month', 'last_year', 'custom' );
		$preset  = in_array( $preset, $allowed, true ) ? $preset : 'last_30_days';
		$zone    = wp_timezone();
		$today   = new DateTimeImmutable( 'today', $zone );
		$from    = $today->modify( '-29 days' );
		$to      = $today->modify( '+1 day -1 second' );

		switch ( $preset ) {
			case 'all_time':
				$from = ( new DateTimeImmutable( '@1' ) )->setTimezone( $zone );
				break;
			case 'today':
				$from = $today;
				break;
			case 'yesterday':
				$from = $today->modify( '-1 day' );
				$to   = $today->modify( '-1 second' );
				break;
			case 'last_7_days':
				$from = $today->modify( '-6 days' );
				break;
			case 'this_month':
				$from = $today->modify( 'first day of this month' );
				break;
			case 'previous_month':
				$from = $today->modify( 'first day of previous month' );
				$to   = $today->modify( 'first day of this month -1 second' );
				break;
			case 'last_year':
				$from = $today->modify( '-1 year +1 day' );
				break;
			case 'custom':
				$request     = null === $request ? $_GET : $request;
				$custom_from = isset( $request['date_from'] ) ? sanitize_text_field( wp_unslash( $request['date_from'] ) ) : '';
				$custom_to   = isset( $request['date_to'] ) ? sanitize_text_field( wp_unslash( $request['date_to'] ) ) : '';
				$parsed_from = DateTimeImmutable::createFromFormat( '!Y-m-d', $custom_from, $zone );
				$parsed_to   = DateTimeImmutable::createFromFormat( '!Y-m-d', $custom_to, $zone );
				if ( false !== $parsed_from && false !== $parsed_to && $parsed_to >= $parsed_from ) {
					$from = $parsed_from;
					$to   = $parsed_to->modify( '+1 day -1 second' );
				} else {
					$preset = 'last_30_days';
				}
				break;
		}

		return array( 'preset' => $preset, 'from' => $from->getTimestamp(), 'to' => $to->getTimestamp() );
	}

	/**
	 * Adds the mobile/website source to a WooCommerce order query.
	 *
	 * @param array<string,mixed> $args Query arguments.
	 * @return array<string,mixed>
	 */
	private function store_data_order_source_args( array $args, string $source ): array {
		if ( 'mobile' === $source ) {
			$args['meta_query'] = array( array( 'key' => '_kidia_order_source', 'value' => 'mobile' ) );
		} elseif ( 'website' === $source ) {
			$args['meta_query'] = array(
				'relation' => 'OR',
				array( 'key' => '_kidia_order_source', 'compare' => 'NOT EXISTS' ),
				array( 'key' => '_kidia_order_source', 'value' => 'website' ),
			);
		}
		return $args;
	}

	/**
	 * Finds the top-level category for a nested term.
	 *
	 * @param WP_Term[] $terms All product category terms.
	 */
	private function store_data_root_category( WP_Term $category, array $terms ): int {
		$parents = array();
		foreach ( $terms as $term ) {
			$parents[ $term->term_id ] = (int) $term->parent;
		}
		$root = (int) $category->parent;
		while ( isset( $parents[ $root ] ) && 0 !== $parents[ $root ] ) {
			$root = $parents[ $root ];
		}
		return $root;
	}

	/** Renders the independent explainable growth and recommendation workspace. */
	public function ai_insights_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$date_preset = isset( $_GET['date_preset'] ) ? sanitize_key( wp_unslash( $_GET['date_preset'] ) ) : 'all_time';
		$date_range  = $this->store_data_date_range( $date_preset );
		$date_from   = $date_range['from'];
		$date_to     = $date_range['to'];
		$date_preset = $date_range['preset'];
		$ai_source   = isset( $_GET['ai_source'] ) ? sanitize_key( wp_unslash( $_GET['ai_source'] ) ) : 'all';
		$ai_source   = in_array( $ai_source, array( 'all', 'website', 'mobile' ), true ) ? $ai_source : 'all';
		$ai_generated = isset( $_GET['ai_ready'] )
			&& '1' === sanitize_text_field( wp_unslash( $_GET['ai_ready'] ) )
			&& Kidia_Mobile_Analytics::has_commerce_snapshot( $date_from, $date_to, $ai_source );
		$ai_kind     = isset( $_GET['ai_kind'] ) ? sanitize_key( wp_unslash( $_GET['ai_kind'] ) ) : 'all';
		$kind_keys   = array( 'all', 'campaign', 'merchandising', 'inventory', 'funnel', 'timing' );
		$ai_kind     = in_array( $ai_kind, $kind_keys, true ) ? $ai_kind : 'all';
		$ai_summary         = Kidia_Mobile_Analytics::empty_summary();
		$all_recommendations = array();
		$ai_rotation_segments = array( 'fast' => array(), 'medium' => array(), 'slow' => array(), 'poor' => array() );
		if ( $ai_generated ) {
			$ai_summary         = Kidia_Mobile_Analytics::summary( $date_from, $date_to, $ai_source );
			$all_recommendations = Kidia_Mobile_AI_Offer_Engine::recommendations( $date_from, $date_to, $ai_source );
			$ai_rotation_segments = Kidia_Mobile_AI_Offer_Engine::rotation_segments( $date_from, $date_to, $ai_source );
		}
		$ai_recommendations  = array_values(
			array_filter(
				$all_recommendations,
				static function ( array $item ) use ( $ai_kind ): bool {
					return 'all' === $ai_kind || $ai_kind === ( $item['kind'] ?? '' );
				}
			)
		);
		$ai_signal_volume = array_sum(
			array_map(
				static fn( $event ) => absint( $event['count'] ?? 0 ),
				$ai_summary['events']
			)
		);
		$ai_signal_count = count( Kidia_Mobile_AI_Offer_Engine::signal_catalog() );
		$ai_action_history = get_option( 'kidia_mobile_ai_action_history_v1', array() );
		$ai_action_history = is_array( $ai_action_history )
			? array_reverse( array_slice( $ai_action_history, -100, null, true ), true )
			: array();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/ai-insights.php';
	}

	/** Starts a bounded, measurable AI Studio analysis job. */
	public function start_ai_analysis(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to analyse this store.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_ai_analysis', 'nonce' );
		$preset = sanitize_key( (string) wp_unslash( $_POST['date_preset'] ?? 'all_time' ) );
		$range  = $this->store_data_date_range( $preset, $_POST );
		$from   = absint( $range['from'] );
		$to     = absint( $range['to'] );
		$source = sanitize_key( (string) wp_unslash( $_POST['source'] ?? 'all' ) );
		$source = in_array( $source, array( 'all', 'website', 'mobile' ), true ) ? $source : 'all';
		$result = Kidia_Mobile_AI_Analysis_Job::start( $from, $to, $source, get_current_user_id() );
		if ( isset( $result['error'] ) ) {
			wp_send_json_error( array( 'message' => $result['error'] ), 400 );
		}
		wp_send_json_success( $result );
	}

	/** Processes one real analysis batch and reports completed records. */
	public function step_ai_analysis(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to analyse this store.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_ai_analysis', 'nonce' );
		$job_id = sanitize_text_field( (string) wp_unslash( $_POST['job_id'] ?? '' ) );
		$result = Kidia_Mobile_AI_Analysis_Job::step( $job_id, get_current_user_id() );
		if ( isset( $result['error'] ) ) {
			wp_send_json_error( array( 'message' => $result['error'] ), 400 );
		}
		wp_send_json_success( $result );
	}

	/** Moves an active analysis from browser-driven batches to the server queue. */
	public function background_ai_analysis(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to analyse this store.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_ai_analysis', 'nonce' );
		$job_id = sanitize_text_field( (string) wp_unslash( $_POST['job_id'] ?? '' ) );
		$result = Kidia_Mobile_AI_Analysis_Job::continue_in_background( $job_id, get_current_user_id() );
		if ( isset( $result['error'] ) ) {
			wp_send_json_error( array( 'message' => $result['error'] ), 400 );
		}
		wp_send_json_success( $result );
	}

	/** Cancels an active analysis without storing its partial accumulator. */
	public function cancel_ai_analysis(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to analyse this store.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_ai_analysis', 'nonce' );
		$job_id = sanitize_text_field( (string) wp_unslash( $_POST['job_id'] ?? '' ) );
		$result = Kidia_Mobile_AI_Analysis_Job::cancel( $job_id, get_current_user_id() );
		if ( isset( $result['error'] ) ) {
			wp_send_json_error( array( 'message' => $result['error'] ), 400 );
		}
		wp_send_json_success( $result );
	}

	/** Reads progress and optionally advances one self-healing browser batch. */
	public function ai_analysis_status(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to analyse this store.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_ai_analysis', 'nonce' );
		$job_id = sanitize_text_field( (string) wp_unslash( $_POST['job_id'] ?? '' ) );
		$advance = ! empty( $_POST['advance'] );
		$result  = Kidia_Mobile_AI_Analysis_Job::status( $job_id, get_current_user_id(), $advance );
		if ( isset( $result['error'] ) ) {
			wp_send_json_error( array( 'message' => $result['error'] ), 404 );
		}
		wp_send_json_success( $result );
	}

	/** Hides a finished background-analysis notice for the current user. */
	public function dismiss_ai_analysis(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_send_json_error( array( 'message' => __( 'You do not have permission to analyse this store.', 'kidia-mobile-cms' ) ), 403 );
		}
		check_ajax_referer( 'kidia_mobile_ai_analysis', 'nonce' );
		$job_id = sanitize_text_field( (string) wp_unslash( $_POST['job_id'] ?? '' ) );
		Kidia_Mobile_AI_Analysis_Job::dismiss( $job_id, get_current_user_id() );
		wp_send_json_success( array( 'dismissed' => true ) );
	}

	/** Turns one reviewed AI recommendation into an owner-approved draft or live action. */
	public function build_ai_action(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to build AI actions.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_build_ai_action', 'kidia_mobile_ai_action_nonce' );
		$id     = sanitize_text_field( (string) wp_unslash( $_POST['ai_offer_id'] ?? '' ) );
		$source = sanitize_key( (string) wp_unslash( $_POST['ai_source'] ?? 'all' ) );
		$source = in_array( $source, array( 'all', 'website', 'mobile' ), true ) ? $source : 'all';
		$from   = absint( $_POST['ai_from'] ?? 0 );
		$to     = absint( $_POST['ai_to'] ?? 0 );
		$recommendation = null;
		foreach ( Kidia_Mobile_AI_Offer_Engine::recommendations( $from, $to, $source ) as $candidate ) {
			if ( $id === (string) ( $candidate['id'] ?? '' ) ) {
				$recommendation = $candidate;
				break;
			}
		}
		if ( ! is_array( $recommendation ) ) {
			wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-ai-insights', 'ai_action_error' => 'not_found' ), admin_url( 'admin.php' ) ) );
			exit;
		}
		$recommended_product_ids = array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) );
		if ( $recommended_product_ids ) {
			$available_product_ids = array();
			foreach ( $recommended_product_ids as $product_id ) {
				$product = function_exists( 'wc_get_product' ) ? wc_get_product( $product_id ) : null;
				if ( $product instanceof WC_Product && $product->is_in_stock() ) {
					$available_product_ids[] = $product_id;
				}
			}
			if ( empty( $available_product_ids ) ) {
				wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-ai-insights', 'ai_action_error' => 'stock_changed' ), admin_url( 'admin.php' ) ) );
				exit;
			}
			$recommendation['product_ids'] = $available_product_ids;
			$recommendation['products'] = array_values(
				array_filter(
					(array) ( $recommendation['products'] ?? array() ),
					static fn( $product ) => in_array( absint( $product['id'] ?? 0 ), $available_product_ids, true )
				)
			);
		}
		$action_type = sanitize_key( (string) wp_unslash( $_POST['ai_action_type'] ?? $recommendation['implementation'] ?? 'store_action' ) );
		$allowed = array( 'coupon', 'bundle', 'placement', 'merchandising', 'shipping_rule', 'store_action', 'schedule' );
		$action_type = in_array( $action_type, $allowed, true ) ? $action_type : 'store_action';
		$status = 'publish' === sanitize_key( (string) wp_unslash( $_POST['ai_action_status'] ?? 'draft' ) ) ? 'publish' : 'draft';
		$channel = sanitize_key( (string) wp_unslash( $_POST['ai_action_channel'] ?? $source ) );
		$channel = in_array( $channel, array( 'all', 'website', 'mobile' ), true ) ? $channel : 'all';
		$placement = sanitize_key( (string) wp_unslash( $_POST['ai_placement'] ?? $recommendation['recommended_placement'] ?? 'home' ) );
		$placement = in_array( $placement, array( 'home', 'product', 'category', 'search', 'cart', 'checkout', 'confirmation' ), true ) ? $placement : 'home';
		$created_id = '';
		if ( 'coupon' === $action_type && class_exists( 'WC_Coupon' ) ) {
			$type = sanitize_key( (string) wp_unslash( $_POST['ai_discount_type'] ?? $recommendation['discount_type'] ?? 'percent' ) );
			$type = in_array( $type, array( 'percent', 'fixed_cart', 'fixed_product' ), true ) ? $type : 'percent';
			$value = max( 0, (float) ( $_POST['ai_discount_value'] ?? $recommendation['discount_value'] ?? 0 ) );
			$value = 'percent' === $type ? min( 100, $value ) : $value;
			if ( $value > 0 ) {
				$coupon = new WC_Coupon();
				$coupon->set_code( 'KIDIA-AI-' . strtoupper( wp_generate_password( 8, false, false ) ) );
				$coupon->set_discount_type( $type );
				$coupon->set_amount( $value );
				$coupon->set_individual_use( true );
				$coupon->set_usage_limit_per_user( 1 );
				$coupon->set_date_expires( time() + max( 1, min( 720, absint( $_POST['ai_duration_hours'] ?? 48 ) ) ) * HOUR_IN_SECONDS );
				$coupon->set_description( sprintf( __( 'AI Studio action: %s', 'kidia-mobile-cms' ), (string) $recommendation['title'] ) );
				$coupon->set_product_ids( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) );
				$coupon->set_status( 'publish' === $status ? 'publish' : 'draft' );
				$coupon_id = $coupon->save();
				if ( $coupon_id > 0 ) {
					Kidia_Mobile_Coupon_Channel::set( $coupon_id, $channel );
					$created_id = (string) $coupon_id;
				}
			}
		} elseif ( 'bundle' === $action_type ) {
			$created_id = Kidia_Mobile_Bundle_Recipes::store(
				array(
					'name'            => sanitize_text_field( (string) wp_unslash( $_POST['ai_action_name'] ?? $recommendation['title'] ) ),
					'description'     => (string) $recommendation['summary'],
					'type'            => sanitize_key( (string) wp_unslash( $_POST['ai_bundle_type'] ?? 'frequently_bought' ) ),
					'channel'         => $channel,
					'status'          => 'publish' === $status ? 'published' : 'draft',
					'product_ids'     => implode( ',', array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ),
					'minimum_items'   => absint( $_POST['ai_bundle_minimum'] ?? 2 ),
					'maximum_items'   => absint( $_POST['ai_bundle_maximum'] ?? 2 ),
					'pricing'         => sanitize_key( (string) wp_unslash( $_POST['ai_bundle_pricing'] ?? 'percentage' ) ),
					'discount_value'  => (float) ( $_POST['ai_discount_value'] ?? $recommendation['discount_value'] ?? 0 ),
					'allow_variants'  => ! empty( $_POST['ai_bundle_variants'] ),
					'allow_repeats'   => ! empty( $_POST['ai_bundle_repeats'] ),
					'stock_policy'    => sanitize_key( (string) wp_unslash( $_POST['ai_bundle_stock_policy'] ?? 'all_components' ) ),
					'coupon_stacking' => ! empty( $_POST['ai_coupon_stacking'] ),
					'ai_source'       => 'co_purchase',
				)
			);
		} else {
			$actions = get_option( 'kidia_mobile_ai_action_drafts', array() );
			$actions = is_array( $actions ) ? $actions : array();
			$created_id = wp_generate_uuid4();
			$actions[ $created_id ] = array(
				'id'          => $created_id,
				'type'        => $action_type,
				'status'      => $status,
				'channel'     => $channel,
				'placement'   => sanitize_key( (string) wp_unslash( $_POST['ai_placement'] ?? $recommendation['recommended_placement'] ?? 'home' ) ),
				'name'        => sanitize_text_field( (string) wp_unslash( $_POST['ai_action_name'] ?? $recommendation['title'] ) ),
				'recommendation' => $recommendation,
				'created_at'  => time(),
			);
			update_option( 'kidia_mobile_ai_action_drafts', array_slice( $actions, -200, null, true ), false );
		}
		$publication = $this->publish_ai_action_placement(
			$action_type,
			$created_id,
			$recommendation,
			$channel,
			$placement,
			'publish' === $status
		);
		$args = array(
			'page'            => 'kidia-mobile-ai-insights',
			'ai_generate'     => '1',
			'ai_ready'        => '1',
			'ai_action_saved' => '1',
			'ai_action_id'    => $created_id,
			'ai_source'       => $source,
			'date_preset'     => 'custom',
			'date_from'       => wp_date( 'Y-m-d', $from ),
			'date_to'         => wp_date( 'Y-m-d', $to ),
		);
		if ( ! empty( $_POST['ai_promote_push'] ) ) {
			$args = array(
				'page'        => 'kidia-mobile-push-notifications',
				'ai_offer_id' => $id,
				'ai_source'   => $source,
				'ai_from'     => $from,
				'ai_to'       => $to,
				'optional_promotion' => '1',
			);
		}
		$history = get_option( 'kidia_mobile_ai_action_history_v1', array() );
		$history = is_array( $history ) ? $history : array();
		$history_id = wp_generate_uuid4();
		$history[ $history_id ] = array(
			'id'                => $history_id,
			'offer_id'          => $id,
			'analysis_from'     => $from,
			'analysis_to'       => $to,
			'analysis_source'   => $source,
			'created_reference' => $created_id,
			'type'              => $action_type,
			'status'            => $status,
			'channel'           => $channel,
			'placement'         => $placement,
			'publication'       => $publication,
			'name'              => sanitize_text_field( (string) wp_unslash( $_POST['ai_action_name'] ?? $recommendation['title'] ) ),
			'recommendation'    => $recommendation,
			'duration_hours'    => max( 1, min( 720, absint( $_POST['ai_duration_hours'] ?? $recommendation['duration_hours'] ?? 48 ) ) ),
			'owner_decision'    => 'publish' === $status ? 'approved' : 'draft',
			'created_at'        => time(),
			'updated_at'        => time(),
		);
		update_option( 'kidia_mobile_ai_action_history_v1', array_slice( $history, -200, null, true ), false );
		wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) );
		exit;
	}

	/** Applies an owner-approved continue or stop decision from Actions & Results. */
	public function review_ai_result(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to review AI actions.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_review_ai_result', 'kidia_mobile_ai_result_nonce' );
		$history_id = sanitize_text_field( (string) wp_unslash( $_POST['history_id'] ?? '' ) );
		$decision   = sanitize_key( (string) wp_unslash( $_POST['result_decision'] ?? '' ) );
		$decision   = in_array( $decision, array( 'continue', 'stop' ), true ) ? $decision : '';
		$history    = get_option( 'kidia_mobile_ai_action_history_v1', array() );
		$history    = is_array( $history ) ? $history : array();
		if ( '' === $decision || ! is_array( $history[ $history_id ] ?? null ) ) {
			wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-ai-insights', 'ai_result_error' => 'not_found' ), admin_url( 'admin.php' ) ) );
			exit;
		}
		$row       = $history[ $history_id ];
		$type      = sanitize_key( (string) ( $row['type'] ?? '' ) );
		$reference = sanitize_text_field( (string) ( $row['created_reference'] ?? '' ) );
		if ( 'stop' === $decision ) {
			if ( 'coupon' === $type && class_exists( 'WC_Coupon' ) && absint( $reference ) > 0 ) {
				$coupon = new WC_Coupon( absint( $reference ) );
				if ( $coupon->get_id() > 0 ) {
					$coupon->set_status( 'draft' );
					$coupon->save();
				}
			} elseif ( 'bundle' === $type && '' !== $reference ) {
				Kidia_Mobile_Bundle_Recipes::set_status( $reference, 'draft' );
			}
			$this->set_ai_home_placement_enabled( (string) ( $row['publication']['block_id'] ?? '' ), false );
			$history[ $history_id ]['status'] = 'stopped';
		} else {
			if ( 'coupon' === $type && class_exists( 'WC_Coupon' ) && absint( $reference ) > 0 ) {
				$coupon = new WC_Coupon( absint( $reference ) );
				if ( $coupon->get_id() > 0 ) {
					$coupon->set_status( 'publish' );
					$coupon->save();
				}
			} elseif ( 'bundle' === $type && '' !== $reference ) {
				Kidia_Mobile_Bundle_Recipes::set_status( $reference, 'published' );
			} else {
				$actions = get_option( 'kidia_mobile_ai_action_drafts', array() );
				$actions = is_array( $actions ) ? $actions : array();
				if ( is_array( $actions[ $reference ] ?? null ) ) {
					$actions[ $reference ]['status'] = 'publish';
					update_option( 'kidia_mobile_ai_action_drafts', $actions, false );
				}
			}
			$existing_block_id = (string) ( $row['publication']['block_id'] ?? '' );
			if ( '' !== $existing_block_id ) {
				$this->set_ai_home_placement_enabled( $existing_block_id, true );
				$publication = (array) $row['publication'];
			} else {
				$publication = $this->publish_ai_action_placement(
					$type,
					$reference,
					is_array( $row['recommendation'] ?? null ) ? $row['recommendation'] : array(),
					(string) ( $row['channel'] ?? 'all' ),
					(string) ( $row['placement'] ?? 'home' ),
					true
				);
			}
			$history[ $history_id ]['publication'] = $publication;
			$history[ $history_id ]['status']      = 'publish';
		}
		$history[ $history_id ]['owner_decision'] = $decision;
		$history[ $history_id ]['updated_at']     = time();
		update_option( 'kidia_mobile_ai_action_history_v1', $history, false );
		$redirect_args = array(
			'page'            => 'kidia-mobile-ai-insights',
			'ai_result_saved' => '1',
			'ai_generate'     => '1',
			'ai_ready'        => '1',
			'ai_source'       => (string) ( $row['analysis_source'] ?? 'all' ),
			'date_preset'     => 'custom',
			'date_from'       => wp_date( 'Y-m-d', absint( $row['analysis_from'] ?? time() ) ),
			'date_to'         => wp_date( 'Y-m-d', absint( $row['analysis_to'] ?? time() ) ),
		);
		wp_safe_redirect( add_query_arg( $redirect_args, admin_url( 'admin.php' ) ) );
		exit;
	}

	/**
	 * Publishes an approved decision into a runtime target. Home placements become
	 * real Home Builder blocks; other targets are exported as approved runtime rules.
	 *
	 * @return array{target:string,block_id:string}
	 */
	private function publish_ai_action_placement(
		string $type,
		string $reference,
		array $recommendation,
		string $channel,
		string $placement,
		bool $approved
	): array {
		$result = array( 'target' => $approved ? $placement : 'draft', 'block_id' => '' );
		if ( ! $approved || '' === $reference ) {
			return $result;
		}

		$runtime = get_option( 'kidia_mobile_ai_published_actions_v1', array() );
		$runtime = is_array( $runtime ) ? $runtime : array();
		$runtime[ $reference ] = array(
			'id'             => $reference,
			'type'           => sanitize_key( $type ),
			'channel'        => in_array( $channel, array( 'website', 'mobile' ), true ) ? $channel : 'all',
			'placement'      => sanitize_key( $placement ),
			'product_ids'    => array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) ),
			'discount_type'  => sanitize_key( (string) ( $recommendation['discount_type'] ?? '' ) ),
			'discount_value' => max( 0, (float) ( $recommendation['discount_value'] ?? 0 ) ),
			'published_at'   => time(),
		);
		update_option( 'kidia_mobile_ai_published_actions_v1', array_slice( $runtime, -200, null, true ), false );
		if ( 'home' !== $placement || ! class_exists( 'Kidia_Mobile_Layout_Store' ) ) {
			return $result;
		}

		$layout = ( new Kidia_Mobile_Layout_Store() )->get_layout();
		foreach ( $layout as $existing ) {
			$settings = is_array( $existing['settings'] ?? null ) ? $existing['settings'] : array();
			$is_match = ( 'bundle' === $type && in_array( $reference, array_filter( explode( ',', (string) ( $settings['bundle_ids'] ?? '' ) ) ), true ) )
				|| ( 'coupon' === $type && $reference === (string) ( $settings['ai_coupon_id'] ?? '' ) )
				|| $reference === (string) ( $settings['ai_action_reference'] ?? '' );
			if ( $is_match ) {
				$result['block_id'] = sanitize_key( (string) ( $existing['id'] ?? '' ) );
				return $result;
			}
		}

		$block_type = 'bundle' === $type
			? 'bundle_collection'
			: ( 'coupon' === $type ? 'coupon_banner' : 'product_carousel' );
		$block = Kidia_Mobile_Block_Registry::create( $block_type, count( $layout ) + 1 );
		if ( ! is_array( $block ) ) {
			return $result;
		}
		$block['name']    = sanitize_text_field( 'AI: ' . (string) ( $recommendation['title'] ?? __( 'Approved offer', 'kidia-mobile-cms' ) ) );
		$block['enabled'] = true;
		$block['status']  = 'published';
		if ( 'bundle' === $type ) {
			$block['settings'] = array_merge(
				(array) $block['settings'],
				array(
					'title'      => (string) ( $recommendation['title'] ?? __( 'Selected bundle', 'kidia-mobile-cms' ) ),
					'subtitle'   => (string) ( $recommendation['summary'] ?? '' ),
					'source'     => 'manual',
					'bundle_ids' => $reference,
					'channel'    => $channel,
				)
			);
		} elseif ( 'coupon' === $type && class_exists( 'WC_Coupon' ) ) {
			$coupon = new WC_Coupon( absint( $reference ) );
			$product_ids = array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) );
			$block['settings'] = array_merge(
				(array) $block['settings'],
				array(
					'title'               => (string) ( $recommendation['title'] ?? __( 'Limited offer', 'kidia-mobile-cms' ) ),
					'description'         => (string) ( $recommendation['summary'] ?? '' ),
					'coupon_code'         => $coupon->get_code(),
					'action_type'         => 1 === count( $product_ids ) ? 'product' : '',
					'action_value'        => 1 === count( $product_ids ) ? (string) $product_ids[0] : '',
					'ai_coupon_id'        => $reference,
					'ai_action_reference' => $reference,
				)
			);
		} else {
			$product_ids = array_values( array_filter( array_map( 'absint', (array) ( $recommendation['product_ids'] ?? array() ) ) ) );
			$block['settings'] = array_merge(
				(array) $block['settings'],
				array(
					'title'               => (string) ( $recommendation['title'] ?? __( 'Recommended products', 'kidia-mobile-cms' ) ),
					'subtitle'            => (string) ( $recommendation['summary'] ?? '' ),
					'source'              => 'manual',
					'product_ids'         => implode( ',', $product_ids ),
					'limit'               => max( 1, count( $product_ids ) ),
					'ai_action_reference' => $reference,
				)
			);
		}
		$layout[] = $block;
		if ( ( new Kidia_Mobile_Layout_Store() )->save_layout( $layout ) ) {
			$result['block_id'] = sanitize_key( (string) ( $block['id'] ?? '' ) );
		}
		return $result;
	}

	/** Enables or disables the exact Home Builder block owned by one AI action. */
	private function set_ai_home_placement_enabled( string $block_id, bool $enabled ): void {
		$block_id = sanitize_key( $block_id );
		if ( '' === $block_id || ! class_exists( 'Kidia_Mobile_Layout_Store' ) ) {
			return;
		}
		$store  = new Kidia_Mobile_Layout_Store();
		$layout = $store->get_layout();
		foreach ( $layout as &$block ) {
			if ( $block_id === sanitize_key( (string) ( $block['id'] ?? '' ) ) ) {
				$block['enabled'] = $enabled;
				break;
			}
		}
		unset( $block );
		$store->save_layout( $layout );
	}

	/** Push composer, provider status and delivery history. */
	public function push_notifications_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$history = get_option( 'kidia_mobile_push_history', array() );
		$history = is_array( $history ) ? array_slice( $history, 0, 30 ) : array();
		$provider_status = Kidia_Mobile_Push_Service::connection_status();
		$provider_connected = ! empty( $provider_status['connected'] );
		$provider_settings = Kidia_Mobile_Push_Service::settings();
		$push_client_config = Kidia_Mobile_Push_Service::client_configuration();
		$push_metrics = Kidia_Mobile_Push_Service::aggregate_metrics();
		$subscribed_customers = absint( get_option( 'kidia_mobile_push_subscribed_customers', 0 ) );
		$registered_devices = absint( get_option( 'kidia_mobile_push_registered_devices', 0 ) );
		$automations = get_option( 'kidia_mobile_push_automations', array() );
		$automations = is_array( $automations ) ? $automations : array();
		$selected_push_type = 'broadcast';
		$prefill_offer      = null;
		$prefill_id = isset( $_GET['ai_offer_id'] ) ? sanitize_text_field( wp_unslash( $_GET['ai_offer_id'] ) ) : '';
		if ( '' !== $prefill_id ) {
			$prefill_source = isset( $_GET['ai_source'] ) ? sanitize_key( wp_unslash( $_GET['ai_source'] ) ) : 'all';
			$prefill_source = in_array( $prefill_source, array( 'all', 'website', 'mobile' ), true ) ? $prefill_source : 'all';
			$prefill_from   = max( 0, absint( $_GET['ai_from'] ?? 0 ) );
			$prefill_to     = max( $prefill_from, absint( $_GET['ai_to'] ?? 0 ) );
			if ( $prefill_from > 0 && $prefill_to >= $prefill_from ) {
				foreach ( Kidia_Mobile_AI_Offer_Engine::recommendations( $prefill_from, $prefill_to, $prefill_source ) as $candidate ) {
					if ( $prefill_id === (string) ( $candidate['id'] ?? '' ) ) {
						$prefill_offer      = $candidate;
						$selected_push_type = 'offer';
						break;
					}
				}
			}
		}
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/push-notifications.php';
	}

	/** Updates one coupon's website/mobile availability from Store Data. */
	public function set_coupon_channel(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to update coupons.', 'kidia-mobile-cms' ) );
		}
		$coupon_id = absint( $_POST['coupon_id'] ?? 0 );
		check_admin_referer( 'kidia_mobile_set_coupon_channel_' . $coupon_id, 'kidia_mobile_coupon_channel_nonce' );
		if ( $coupon_id <= 0 || 'shop_coupon' !== get_post_type( $coupon_id ) ) {
			wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-store-data', 'store_tab' => 'discounts', 'coupon_error' => 'missing' ), admin_url( 'admin.php' ) ) );
			exit;
		}
		$channel = sanitize_key( (string) wp_unslash( $_POST['coupon_channel'] ?? 'all' ) );
		Kidia_Mobile_Coupon_Channel::set( $coupon_id, $channel );
		$redirect = wp_get_referer();
		wp_safe_redirect( $redirect ? add_query_arg( 'coupon_updated', '1', $redirect ) : add_query_arg( array( 'page' => 'kidia-mobile-store-data', 'store_tab' => 'discounts', 'coupon_updated' => '1' ), admin_url( 'admin.php' ) ) );
		exit;
	}

	/** Validates, records and dispatches one notification through the configured provider hook. */
	public function send_push_notification(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_send_push_notification', 'kidia_mobile_push_nonce' );
		$title   = sanitize_text_field( (string) wp_unslash( $_POST['push_title'] ?? '' ) );
		$message = sanitize_textarea_field( (string) wp_unslash( $_POST['push_message'] ?? '' ) );
		if ( '' === $title || '' === $message ) {
			wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-push-notifications', 'push_error' => 'missing' ), admin_url( 'admin.php' ) ) );
			exit;
		}
		$type = sanitize_key( wp_unslash( $_POST['push_type'] ?? 'broadcast' ) );
		$type = in_array( $type, array( 'broadcast', 'offer', 'ai_offer', 'order', 'restock', 'abandoned_cart', 'welcome', 'custom' ), true ) ? $type : 'broadcast';
		$delivery = sanitize_key( wp_unslash( $_POST['push_delivery'] ?? 'now' ) );
		$delivery = in_array( $delivery, array( 'now', 'scheduled', 'automation' ), true ) ? $delivery : 'now';
		$audience = sanitize_key( wp_unslash( $_POST['push_audience'] ?? 'all' ) );
		$audience = in_array( $audience, array( 'all', 'customers', 'guests', 'segment', 'test' ), true ) ? $audience : 'all';
		$payload = array(
			'id'         => wp_generate_uuid4(),
			'type'       => $type,
			'title'      => mb_substr( $title, 0, 100 ),
			'message'    => mb_substr( $message, 0, 500 ),
			'audience'   => $audience,
			'action_url' => esc_url_raw( wp_unslash( $_POST['push_action_url'] ?? '' ) ),
			'image_url'  => esc_url_raw( wp_unslash( $_POST['push_image_url'] ?? '' ) ),
			'cta_label'  => sanitize_text_field( wp_unslash( $_POST['push_cta_label'] ?? '' ) ),
			'coupon'     => sanitize_text_field( wp_unslash( $_POST['push_coupon'] ?? '' ) ),
			'product_id' => absint( $_POST['push_product_id'] ?? 0 ),
			'order_status' => sanitize_key( wp_unslash( $_POST['push_order_status'] ?? '' ) ),
			'priority'   => 'high' === sanitize_key( wp_unslash( $_POST['push_priority'] ?? '' ) ) ? 'high' : 'normal',
			'sound'      => ! empty( $_POST['push_sound'] ),
			'badge'      => absint( $_POST['push_badge'] ?? 0 ),
			'expiry_hours' => max( 1, min( 168, absint( $_POST['push_expiry_hours'] ?? 24 ) ) ),
			'destination' => in_array( sanitize_key( wp_unslash( $_POST['push_destination'] ?? 'home' ) ), array( 'home', 'product', 'category', 'subcategory', 'collection', 'cart', 'checkout', 'wishlist', 'order', 'account', 'offers', 'search', 'custom', 'external' ), true )
				? sanitize_key( wp_unslash( $_POST['push_destination'] ?? 'home' ) )
				: 'home',
			'destination_id' => sanitize_text_field( wp_unslash( $_POST['push_destination_id'] ?? '' ) ),
			'action_style' => 'button' === sanitize_key( wp_unslash( $_POST['push_action_style'] ?? 'link' ) ) ? 'button' : 'link',
			'segment'    => array(
				'min_orders' => absint( $_POST['push_min_orders'] ?? 0 ),
				'min_spent' => (float) ( $_POST['push_min_spent'] ?? 0 ),
				'inactive_days' => absint( $_POST['push_inactive_days'] ?? 0 ),
			),
			'delivery'   => $delivery,
			'automation' => array(
				'enabled'       => 'automation' === $delivery,
				'trigger'       => sanitize_key( wp_unslash( $_POST['push_trigger'] ?? $type ) ),
				'delay_minutes' => min( 43200, absint( $_POST['push_delay_minutes'] ?? 30 ) ),
				'max_sends'     => min( 20, max( 1, absint( $_POST['push_max_sends'] ?? 3 ) ) ),
				'cooldown_hours'=> min( 8760, max( 1, absint( $_POST['push_cooldown_hours'] ?? 24 ) ) ),
				'allowed_from'  => sanitize_text_field( wp_unslash( $_POST['push_allowed_from'] ?? '09:00' ) ),
				'allowed_to'    => sanitize_text_field( wp_unslash( $_POST['push_allowed_to'] ?? '21:00' ) ),
				'stop_on_purchase' => ! empty( $_POST['push_stop_on_purchase'] ),
			),
			'created_at' => time(),
			'status'     => 'saved',
		);
		if ( 'ai_offer' === $type ) {
			$payload['ai_offer'] = array(
				'scheme'       => sanitize_key( wp_unslash( $_POST['ai_offer_scheme'] ?? '' ) ),
				'confidence'   => max( 0, min( 100, absint( $_POST['ai_offer_confidence'] ?? 0 ) ) ),
				'source'       => in_array( sanitize_key( wp_unslash( $_POST['ai_offer_source'] ?? 'all' ) ), array( 'all', 'website', 'mobile' ), true ) ? sanitize_key( wp_unslash( $_POST['ai_offer_source'] ?? 'all' ) ) : 'all',
				'product_ids'  => array_values( array_filter( array_map( 'absint', explode( ',', sanitize_text_field( wp_unslash( $_POST['ai_offer_product_ids'] ?? '' ) ) ) ) ) ),
			);
			if ( ! empty( $_POST['ai_create_coupon'] ) ) {
				$generated = $this->create_ai_offer_coupon( $payload['ai_offer'] );
				if ( '' !== $generated ) {
					$payload['coupon'] = $generated;
				}
			}
		}
		if ( 'scheduled' === $delivery ) {
			$scheduled_raw = sanitize_text_field( wp_unslash( $_POST['push_schedule_at'] ?? '' ) );
			$timestamp = $scheduled_raw ? strtotime( $scheduled_raw . ' ' . wp_timezone_string() ) : false;
			if ( ! $timestamp || $timestamp <= time() ) {
				wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-push-notifications', 'push_error' => 'schedule' ), admin_url( 'admin.php' ) ) );
				exit;
			}
			$payload['scheduled_at'] = $timestamp;
			$payload['status'] = 'scheduled';
			wp_schedule_single_event( $timestamp, 'kidia_mobile_dispatch_scheduled_push', array( $payload ) );
		} elseif ( 'automation' === $delivery ) {
			$payload['status'] = 'automation_saved';
			$automations = get_option( 'kidia_mobile_push_automations', array() );
			$automations = is_array( $automations ) ? $automations : array();
			$automation_key = sanitize_key( (string) ( $payload['automation']['trigger'] ?? $type ) );
			$automations[ $automation_key ] = $payload;
			update_option( 'kidia_mobile_push_automations', $automations, false );
		} else {
			$payload = $this->dispatch_push_payload( $payload );
		}
		$history = get_option( 'kidia_mobile_push_history', array() );
		$history = is_array( $history ) ? $history : array();
		array_unshift( $history, $payload );
		update_option( 'kidia_mobile_push_history', array_slice( $history, 0, 100 ), false );
		wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-push-notifications', 'push_sent' => '1' ), admin_url( 'admin.php' ) ) );
		exit;
	}

	/** Sends a scheduled payload and refreshes its history status. */
	public function dispatch_scheduled_push( array $payload ): void {
		$payload = $this->dispatch_push_payload( $payload );
		$history = get_option( 'kidia_mobile_push_history', array() );
		$history = is_array( $history ) ? $history : array();
		foreach ( $history as &$item ) {
			if ( ( $item['id'] ?? '' ) === ( $payload['id'] ?? '' ) ) {
				$item = $payload;
				break;
			}
		}
		unset( $item );
		update_option( 'kidia_mobile_push_history', array_slice( $history, 0, 100 ), false );
	}

	/**
	 * Creates the admin-approved coupon attached to an explainable AI offer.
	 *
	 * @param array<string,mixed> $offer Normalized recommendation context.
	 */
	private function create_ai_offer_coupon( array $offer ): string {
		if ( ! class_exists( 'WC_Coupon' ) ) {
			return '';
		}
		$type = sanitize_key( wp_unslash( $_POST['ai_discount_type'] ?? 'percent' ) );
		$type = in_array( $type, array( 'percent', 'fixed_cart', 'fixed_product' ), true ) ? $type : 'percent';
		$value = max( 0, (float) ( $_POST['ai_discount_value'] ?? 0 ) );
		$value = 'percent' === $type ? min( 100, $value ) : $value;
		if ( $value <= 0 ) {
			return '';
		}
		$duration = max( 1, min( 720, absint( $_POST['ai_duration_hours'] ?? 48 ) ) );
		$code     = 'KIDIA-AI-' . strtoupper( wp_generate_password( 8, false, false ) );
		$coupon   = new WC_Coupon();
		$coupon->set_code( $code );
		$coupon->set_discount_type( $type );
		$coupon->set_amount( $value );
		$coupon->set_individual_use( true );
		$coupon->set_usage_limit_per_user( 1 );
		$coupon->set_date_expires( time() + $duration * HOUR_IN_SECONDS );
		$coupon->set_description(
			sprintf(
				__( 'Kidia AI Offer Studio: %1$s (%2$d%% confidence)', 'kidia-mobile-cms' ),
				sanitize_text_field( (string) ( $offer['scheme'] ?? 'offer' ) ),
				absint( $offer['confidence'] ?? 0 )
			)
		);
		if ( ! empty( $offer['product_ids'] ) ) {
			$coupon->set_product_ids( array_map( 'absint', (array) $offer['product_ids'] ) );
		}
		return $coupon->save() > 0 ? $code : '';
	}

	/** Passes one normalized payload to the configured push provider. */
	private function dispatch_push_payload( array $payload ): array {
		return Kidia_Mobile_Push_Service::dispatch( $payload );
	}

	/** Applies a complete application preset. */
	public function apply_setup_wizard(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_apply_setup_wizard', 'kidia_mobile_setup_nonce' );
		if ( ! ( new Kidia_Mobile_License_Manager() )->is_active() ) {
			wp_safe_redirect(
				add_query_arg(
					array(
						'page'          => 'kidia-mobile-cms',
						'license_error' => 'required',
					),
					admin_url( 'admin.php' )
				)
			);
			exit;
		}
		$submitted = isset( $_POST['setup'] ) && is_array( $_POST['setup'] ) ? wp_unslash( $_POST['setup'] ) : array();
		$theme     = ( new Kidia_Mobile_Setup_Wizard() )->apply( is_array( $submitted ) ? $submitted : array() );
		if ( ! empty( $_POST['build_after_apply'] ) || ! empty( $_POST['export_after_apply'] ) ) {
			$result = ( new Kidia_Mobile_App_Exporter() )->start_build();
			$args   = array(
				'page'         => 'kidia-mobile-cms',
				'setup_done'   => '1',
				'theme'        => $theme,
				'build_notice' => is_wp_error( $result ) ? 'error' : 'started',
			);
			if ( is_wp_error( $result ) ) {
				$args['build_message'] = $result->get_error_message();
			}
			wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) );
			exit;
		}
		wp_safe_redirect(
			add_query_arg(
				array(
					'page'       => 'kidia-mobile-home-builder',
					'setup_done' => '1',
					'theme'      => $theme,
				),
				admin_url( 'admin.php' )
			)
		);
		exit;
	}

	/** Saves, restores, imports and exports reusable application themes. */
	public function manage_saved_theme(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_manage_saved_theme', 'kidia_mobile_theme_nonce' );
		if ( ! ( new Kidia_Mobile_License_Manager() )->is_active() ) {
			wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-cms', 'license_error' => 'required' ), admin_url( 'admin.php' ) ) );
			exit;
		}

		$wizard    = new Kidia_Mobile_Setup_Wizard();
		$operation = sanitize_key( (string) ( $_POST['theme_operation'] ?? '' ) );
		try {
			if ( 'save' === $operation ) {
				$wizard->save_current_theme( sanitize_text_field( wp_unslash( (string) ( $_POST['theme_name'] ?? '' ) ) ) );
			} elseif ( 'apply' === $operation ) {
				if ( ! $wizard->apply_saved_theme( sanitize_key( (string) ( $_POST['theme_id'] ?? '' ) ) ) ) {
					throw new InvalidArgumentException( 'saved_theme_not_found' );
				}
			} elseif ( 'delete' === $operation ) {
				if ( ! $wizard->delete_saved_theme( sanitize_key( (string) ( $_POST['theme_id'] ?? '' ) ) ) ) {
					throw new InvalidArgumentException( 'saved_theme_not_found' );
				}
			} elseif ( 'blank' === $operation ) {
				$wizard->start_blank();
			} elseif ( 'import' === $operation ) {
				$file = isset( $_FILES['theme_file'] ) && is_array( $_FILES['theme_file'] ) ? $_FILES['theme_file'] : array();
				if ( UPLOAD_ERR_OK !== (int) ( $file['error'] ?? UPLOAD_ERR_NO_FILE ) || empty( $file['tmp_name'] ) || (int) ( $file['size'] ?? 0 ) > 2097152 ) {
					throw new InvalidArgumentException( 'invalid_theme_file' );
				}
				$contents = file_get_contents( (string) $file['tmp_name'] );
				$wizard->import_saved_theme( is_string( $contents ) ? $contents : '' );
			} elseif ( 'export' === $operation ) {
				$theme_id = sanitize_key( (string) ( $_POST['theme_id'] ?? '' ) );
				$export   = $wizard->export_saved_theme( $theme_id );
				if ( null === $export ) {
					throw new InvalidArgumentException( 'saved_theme_not_found' );
				}
				nocache_headers();
				header( 'Content-Type: application/json; charset=utf-8' );
				header( 'Content-Disposition: attachment; filename="woomobile-theme-' . sanitize_file_name( $theme_id ) . '.json"' );
				echo wp_json_encode( $export, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES );
				exit;
			} else {
				throw new InvalidArgumentException( 'unknown_theme_operation' );
			}
			$args = array( 'page' => 'kidia-mobile-saved-themes', 'theme_notice' => $operation );
		} catch ( Throwable $error ) {
			$args = array( 'page' => 'kidia-mobile-saved-themes', 'theme_error' => sanitize_key( $error->getMessage() ) ?: 'failed' );
		}
		wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) );
		exit;
	}

	public function splash_screen_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$defaults = array( 'enabled' => true, 'image_url' => '', 'background_color' => '#2F806E', 'background_color_end' => '#236B59', 'duration_ms' => 2000, 'image_width' => 140, 'image_height' => 140, 'image_fit' => 'contain', 'image_shape' => 'none', 'show_store_name' => true, 'store_name' => get_bloginfo( 'name' ), 'text_color' => '#FFFFFF', 'show_loader' => true, 'loader_color' => '#FFFFFF' );
		$saved = get_option( 'kidia_mobile_splash_screen', array() );
		$settings = array_merge( $defaults, is_array( $saved ) ? $saved : array() );
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/splash-screen.php';
	}

	public function save_splash_screen(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) { wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) ); }
		check_admin_referer( 'kidia_mobile_save_splash_screen', 'kidia_mobile_splash_nonce' );
		$row = isset( $_POST['splash'] ) && is_array( $_POST['splash'] ) ? wp_unslash( $_POST['splash'] ) : array();
		$clean = array(
			'enabled' => ! empty( $row['enabled'] ),
			'image_url' => esc_url_raw( (string) ( $row['image_url'] ?? '' ) ),
			'background_color' => sanitize_hex_color( $row['background_color'] ?? '' ) ?: '#2F806E',
			'background_color_end' => sanitize_hex_color( $row['background_color_end'] ?? '' ) ?: '#236B59',
			'duration_ms' => min( 10000, max( 500, absint( $row['duration_ms'] ?? 2000 ) ) ),
			'image_width' => min( 320, max( 40, absint( $row['image_width'] ?? 140 ) ) ),
			'image_height' => min( 320, max( 40, absint( $row['image_height'] ?? 140 ) ) ),
			'image_fit' => in_array( $row['image_fit'] ?? '', array( 'contain', 'cover', 'fill' ), true ) ? sanitize_key( $row['image_fit'] ) : 'contain',
			'image_shape' => in_array( $row['image_shape'] ?? '', array( 'none', 'rounded', 'circle' ), true ) ? sanitize_key( $row['image_shape'] ) : 'none',
			'show_store_name' => ! empty( $row['show_store_name'] ), 'store_name' => sanitize_text_field( (string) ( $row['store_name'] ?? '' ) ),
			'text_color' => sanitize_hex_color( $row['text_color'] ?? '' ) ?: '#FFFFFF', 'show_loader' => ! empty( $row['show_loader'] ), 'loader_color' => sanitize_hex_color( $row['loader_color'] ?? '' ) ?: '#FFFFFF',
		);
		update_option( 'kidia_mobile_splash_screen', $clean, false );
		$fallback = add_query_arg( array( 'page' => 'kidia-mobile-splash-screen', 'updated' => '1', 'saved_at' => time() ), admin_url( 'admin.php' ) );
		wp_safe_redirect( $this->saved_theme_redirect( $fallback ) ); exit;
	}

	public function similar_products_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) { wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) ); }
		$store = new Kidia_Mobile_Page_Layout_Store(); $layout = $store->get_layout( 'product' );
		$definition = null; foreach ( Kidia_Mobile_Page_Layout_Store::element_definitions( 'product' ) as $item ) { if ( 'related_products' === $item['id'] ) { $definition = $item; break; } }
		$element = null; foreach ( $layout['elements'] as $item ) { if ( 'related_products' === $item['id'] ) { $element = $item; break; } }
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/similar-products.php';
	}

	public function save_similar_products(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) { wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) ); }
		check_admin_referer( 'kidia_mobile_save_similar_products', 'kidia_mobile_similar_nonce' );
		$store = new Kidia_Mobile_Page_Layout_Store(); $layout = $store->get_layout( 'product' ); $submitted = isset( $_POST['related'] ) && is_array( $_POST['related'] ) ? wp_unslash( $_POST['related'] ) : array();
		foreach ( $layout['elements'] as &$element ) { if ( 'related_products' === $element['id'] ) { $element['enabled'] = ! empty( $submitted['enabled'] ); $element['settings'] = is_array( $submitted['settings'] ?? null ) ? $submitted['settings'] : array(); } } unset( $element );
		$store->save_layout( 'product', $layout );
		$fallback = add_query_arg( array( 'page' => 'kidia-mobile-similar-products', 'updated' => '1', 'saved_at' => time() ), admin_url( 'admin.php' ) );
		wp_safe_redirect( $this->saved_theme_redirect( $fallback ) ); exit;
	}

	public function checkout_suggestions_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) { wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) ); }
		$defaults=array('enabled'=>true,'title'=>__('You may also need','kidia-mobile-cms'),'source'=>'featured','category_id'=>0,'manual_product_ids'=>'','limit'=>6,'columns'=>2,'card_style'=>'outlined','card_radius'=>14,'image_ratio'=>1,'show_price'=>true,'show_regular_price'=>true,'show_rating'=>false,'button_label'=>__('Add','kidia-mobile-cms'),'button_color'=>'#2F806E','button_text_color'=>'#FFFFFF'); $saved=get_option('kidia_mobile_checkout_suggestions',array()); $settings=array_merge($defaults,is_array($saved)?$saved:array());
		$checkout_fields = ( new Kidia_Mobile_Checkout_Fields_Store() )->get();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/checkout-suggestions.php';
	}

	public function save_checkout_suggestions(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_save_checkout_suggestions', 'kidia_mobile_checkout_suggestions_nonce' );
		$field_store = new Kidia_Mobile_Checkout_Fields_Store();
		if ( isset( $_POST['restore_checkout_fields'] ) ) {
			$field_store->reset_from_site();
			wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-checkout-suggestions', 'fields_restored' => '1' ), admin_url( 'admin.php' ) ) );
			exit;
		}
		$checkout = isset( $_POST['checkout'] ) && is_array( $_POST['checkout'] ) ? wp_unslash( $_POST['checkout'] ) : array();
		$field_store->save( is_array( $checkout ) ? $checkout : array() );
		$row    = isset( $_POST['suggestions'] ) && is_array( $_POST['suggestions'] ) ? wp_unslash( $_POST['suggestions'] ) : array();
		$source = in_array( $row['source'] ?? '', array( 'latest', 'featured', 'on_sale', 'category', 'manual' ), true ) ? sanitize_key( $row['source'] ) : 'featured';
		$clean  = array(
			'enabled'            => ! empty( $row['enabled'] ),
			'title'              => sanitize_text_field( (string) ( $row['title'] ?? '' ) ),
			'source'             => $source,
			'category_id'        => absint( $row['category_id'] ?? 0 ),
			'manual_product_ids' => sanitize_text_field( (string) ( $row['manual_product_ids'] ?? '' ) ),
			'limit'              => min( 20, max( 1, absint( $row['limit'] ?? 6 ) ) ),
			'columns'            => min( 3, max( 1, absint( $row['columns'] ?? 2 ) ) ),
			'card_style'         => in_array( $row['card_style'] ?? '', array( 'minimal', 'no_shadow', 'outlined', 'elevated' ), true ) ? sanitize_key( $row['card_style'] ) : 'outlined',
			'card_radius'        => min( 40, absint( $row['card_radius'] ?? 14 ) ),
			'image_ratio'        => min( 2, max( .5, (float) ( $row['image_ratio'] ?? 1 ) ) ),
			'show_price'         => ! empty( $row['show_price'] ),
			'show_regular_price' => ! empty( $row['show_regular_price'] ),
			'show_rating'        => ! empty( $row['show_rating'] ),
			'button_label'       => sanitize_text_field( (string) ( $row['button_label'] ?? '' ) ),
			'button_color'       => sanitize_hex_color( $row['button_color'] ?? '' ) ?: '#2F806E',
			'button_text_color'  => sanitize_hex_color( $row['button_text_color'] ?? '' ) ?: '#FFFFFF',
		);
		update_option( 'kidia_mobile_checkout_suggestions', $clean, false );
		$fallback = add_query_arg( array( 'page' => 'kidia-mobile-checkout-suggestions', 'updated' => '1', 'saved_at' => time() ), admin_url( 'admin.php' ) );
		wp_safe_redirect( $this->saved_theme_redirect( $fallback ) );
		exit;
	}

	/** Renders one of the shared application page builders. */
	public function page_builder_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}
		$slug = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : '';
		$page = self::PAGE_BUILDER_SLUGS[ $slug ] ?? '';
		if ( '' === $page ) {
			wp_die( esc_html__( 'Unknown application page.', 'kidia-mobile-cms' ) );
		}
		$store = new Kidia_Mobile_Page_Layout_Store();
		$layout = $store->get_layout( $page );
		$page_labels = Kidia_Mobile_Page_Layout_Store::pages();
		$page_label = $page_labels[ $page ];
		$element_definitions = Kidia_Mobile_Page_Layout_Store::element_definitions( $page );
		$header_fields = Kidia_Mobile_Page_Layout_Store::header_fields();
		$footer_fields = Kidia_Mobile_Page_Layout_Store::footer_fields();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/page-builder.php';
	}

	/** Saves a shared application page layout. */
	public function save_page_builder(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_save_page_builder', 'kidia_mobile_page_builder_nonce' );
		$page = isset( $_POST['builder_page'] ) ? sanitize_key( wp_unslash( $_POST['builder_page'] ) ) : '';
		if ( ! Kidia_Mobile_Page_Layout_Store::is_page( $page ) ) {
			wp_die( esc_html__( 'Unknown application page.', 'kidia-mobile-cms' ) );
		}
		if ( 'product' === $page && isset( $_POST['restore_product_defaults'] ) ) {
			( new Kidia_Mobile_Page_Layout_Store() )->reset_layout( 'product' );
			$slug = array_search( $page, self::PAGE_BUILDER_SLUGS, true );
			if ( function_exists( 'nocache_headers' ) ) {
				nocache_headers();
			}
			wp_safe_redirect( add_query_arg( array( 'page' => $slug, 'restored' => '1', 'restored_at' => time() ), admin_url( 'admin.php' ) ) );
			exit;
		}
		$submitted = isset( $_POST['layout'] ) ? wp_unslash( $_POST['layout'] ) : array();
		( new Kidia_Mobile_Page_Layout_Store() )->save_layout( $page, is_array( $submitted ) ? $submitted : array() );
		$slug = array_search( $page, self::PAGE_BUILDER_SLUGS, true );
		if ( function_exists( 'nocache_headers' ) ) {
			nocache_headers();
		}
		$fallback = add_query_arg( array( 'page' => $slug, 'updated' => '1', 'saved_at' => time() ), admin_url( 'admin.php' ) );
		wp_safe_redirect( $this->requested_builder_redirect( $fallback ) );
		exit;
	}

	/** Keeps the plugin menu limited to its three public work areas. */
	public function hide_element_library_menus(): void {
		foreach ( self::EDITOR_PAGES as $page_slug ) {
			remove_submenu_page( 'kidia-mobile-cms', $page_slug );
		}
	}

	/** Renders the shared top navigation on every public CMS screen. */
	public function render_cms_shell(): void {
		$page = isset( $_GET['page'] ) ? sanitize_key( wp_unslash( $_GET['page'] ) ) : '';
		if ( ! current_user_can( self::CAPABILITY ) || ! $this->is_public_cms_page( $page ) ) {
			return;
		}
		$tab = static function ( string $label, string $page_slug, string $icon ): array {
			return array( 'label' => $label, 'icon' => $icon, 'url' => add_query_arg( 'page', $page_slug, admin_url( 'admin.php' ) ) );
		};
		$tabs = array(
			'overview'   => $tab( __( 'Overview', 'kidia-mobile-cms' ), 'kidia-mobile-cms', 'dashicons-chart-area' ),
			'splash'     => $tab( __( 'Splash', 'kidia-mobile-cms' ), 'kidia-mobile-splash-screen', 'dashicons-format-image' ),
			'home'       => $tab( __( 'Home', 'kidia-mobile-cms' ), 'kidia-mobile-home-builder', 'dashicons-admin-home' ),
			'category'   => $tab( __( 'Categories', 'kidia-mobile-cms' ), 'kidia-mobile-category-builder', 'dashicons-category' ),
			'catalog'    => $tab( __( 'Catalog', 'kidia-mobile-cms' ), 'kidia-mobile-catalog-builder', 'dashicons-grid-view' ),
			'product'    => $tab( __( 'Product', 'kidia-mobile-cms' ), 'kidia-mobile-product-builder', 'dashicons-products' ),
			'wishlist'   => $tab( __( 'Wishlist', 'kidia-mobile-cms' ), 'kidia-mobile-wishlist-builder', 'dashicons-heart' ),
			'account'    => $tab( __( 'Account', 'kidia-mobile-cms' ), 'kidia-mobile-account-builder', 'dashicons-admin-users' ),
			'checkout'   => $tab( __( 'Checkout', 'kidia-mobile-cms' ), 'kidia-mobile-checkout-suggestions', 'dashicons-cart' ),
		);
		$active_map = array(
			'kidia-mobile-cms'                  => 'overview',
			'kidia-mobile-home-builder'         => 'home',
			'kidia-mobile-category-builder'     => 'category',
			'kidia-mobile-catalog-builder'      => 'catalog',
			'kidia-mobile-product-builder'      => 'product',
			'kidia-mobile-wishlist-builder'     => 'wishlist',
			'kidia-mobile-account-builder'      => 'account',
			'kidia-mobile-size-chart-builder'   => 'size_chart',
			'kidia-mobile-splash-screen'        => 'splash',
			'kidia-mobile-similar-products'     => 'similar',
			'kidia-mobile-checkout-suggestions'=> 'checkout',
			'kidia-mobile-setup'                => 'setup',
			'kidia-mobile-saved-themes'         => 'saved_themes',
			'kidia-mobile-store-data'           => 'store_data',
			'kidia-mobile-ai-insights'           => 'ai_insights',
			'kidia-mobile-push-notifications'   => 'push',
		);
		$active_tab = $active_map[ $page ] ?? 'overview';
		$store_data_tab = isset( $_GET['store_tab'] ) ? sanitize_key( wp_unslash( $_GET['store_tab'] ) ) : '';
		if ( 'kidia-mobile-store-data' === $page && 'abandoned-carts' === $store_data_tab ) {
			$active_tab = 'abandoned_carts';
		}
		if ( 'kidia-mobile-cms' === $page && ! ( new Kidia_Mobile_Setup_Wizard() )->is_complete() ) {
			$active_tab = 'setup';
		}
		$builder_tabs = array( 'splash', 'home', 'category', 'catalog', 'product', 'wishlist', 'account', 'checkout' );
		$show_page_tabs = in_array( $active_tab, $builder_tabs, true );
		$sidebar_items = array(
			'overview' => $tab( __( 'Overview', 'kidia-mobile-cms' ), 'kidia-mobile-cms', 'dashicons-chart-area' ),
			'setup'    => $tab( __( 'Setup Wizard', 'kidia-mobile-cms' ), 'kidia-mobile-setup', 'dashicons-admin-customizer' ),
			'pages'    => $tab( __( 'Customize Your Pages', 'kidia-mobile-cms' ), 'kidia-mobile-splash-screen', 'dashicons-admin-appearance' ),
			'saved_themes' => $tab( __( 'Saved Themes', 'kidia-mobile-cms' ), 'kidia-mobile-saved-themes', 'dashicons-portfolio' ),
			'store_data' => $tab( __( 'Store Data', 'kidia-mobile-cms' ), 'kidia-mobile-store-data', 'dashicons-database' ),
			'ai_insights' => $tab( __( 'AI Offer Studio', 'kidia-mobile-cms' ), 'kidia-mobile-ai-insights', 'dashicons-lightbulb' ),
			'abandoned_carts' => array(
				'label' => __( 'Abandoned Carts', 'kidia-mobile-cms' ),
				'icon'  => 'dashicons-cart',
				'url'   => add_query_arg(
					array(
						'page'         => 'kidia-mobile-store-data',
						'store_tab'    => 'abandoned-carts',
						'store_source' => 'all',
					),
					admin_url( 'admin.php' )
				),
			),
			'push' => $tab( __( 'Push Notifications', 'kidia-mobile-cms' ), 'kidia-mobile-push-notifications', 'dashicons-megaphone' ),
		);
		$active_sidebar = $show_page_tabs
			? 'pages'
			: ( in_array( $active_tab, array( 'setup', 'saved_themes', 'store_data', 'ai_insights', 'abandoned_carts', 'push' ), true ) ? $active_tab : 'overview' );
		$license_status = ( new Kidia_Mobile_License_Manager() )->status();
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/cms-shell.php';
	}

	private function is_public_cms_page( string $page ): bool {
		return in_array(
			$page,
			array_merge(
				array(
					'kidia-mobile-cms',
					'kidia-mobile-home-builder',
					'kidia-mobile-category-builder',
					'kidia-mobile-splash-screen',
					'kidia-mobile-similar-products',
					'kidia-mobile-checkout-suggestions',
					'kidia-mobile-setup',
					'kidia-mobile-saved-themes',
					'kidia-mobile-store-data',
					'kidia-mobile-ai-insights',
					'kidia-mobile-push-notifications',
				),
				array_keys( self::PAGE_BUILDER_SLUGS )
			),
			true
		);
	}

	/** Renders the WooCommerce category hierarchy editor. */
	public function category_builder_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) );
		}

		$terms = taxonomy_exists( 'product_cat' )
			? get_terms( array( 'taxonomy' => 'product_cat', 'hide_empty' => false ) )
			: array();
		if ( is_wp_error( $terms ) ) {
			$terms = array();
		}
		$category_page    = ( new Kidia_Mobile_Category_Page_Store() )->get_settings();
		$settings         = $category_page['categories'];
		$category_general = $category_page['general'];
		$category_enabled = ! empty( $category_page['enabled'] );
		$page_layout_store = new Kidia_Mobile_Page_Layout_Store();
		$category_layout   = $page_layout_store->get_layout( 'category' );
		$header_fields     = Kidia_Mobile_Page_Layout_Store::header_fields();
		$footer_fields     = Kidia_Mobile_Page_Layout_Store::footer_fields();

		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/category-builder.php';
	}

	/** Saves the Category element plus app-only term order, visibility, name and image overrides. */
	public function save_category_builder(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_save_category_builder', 'kidia_mobile_category_builder_nonce' );

		$rows = isset( $_POST['categories'] ) ? wp_unslash( $_POST['categories'] ) : array();
		$clean = array();
		if ( is_array( $rows ) ) {
			foreach ( $rows as $term_id => $row ) {
				$id = absint( $term_id );
				if ( 0 === $id || ! is_array( $row ) || ! term_exists( $id, 'product_cat' ) ) {
					continue;
				}
				$clean[ $id ] = array(
					'order'    => max( 0, absint( $row['order'] ?? 0 ) ),
					'hidden'   => ! empty( $row['hidden'] ),
					'image_id' => absint( $row['image_id'] ?? 0 ),
					'name'     => sanitize_text_field( (string) ( $row['name'] ?? '' ) ),
				);
			}
		}
		$general = isset( $_POST['category_general'] ) ? wp_unslash( $_POST['category_general'] ) : array();
		( new Kidia_Mobile_Category_Page_Store() )->save_settings(
			array(
				'enabled'    => ! empty( $_POST['category_element_enabled'] ),
				'general'    => is_array( $general ) ? $general : array(),
				'categories' => $clean,
			)
		);
		$layout = isset( $_POST['layout'] ) ? wp_unslash( $_POST['layout'] ) : array();
		( new Kidia_Mobile_Page_Layout_Store() )->save_layout( 'category', is_array( $layout ) ? $layout : array() );
		$fallback = add_query_arg( array( 'page' => 'kidia-mobile-category-builder', 'updated' => '1' ), admin_url( 'admin.php' ) );
		wp_safe_redirect( $this->requested_builder_redirect( $fallback ) );
		exit;
	}

    	/**
    	 * Dashboard.
    	 *
    	 * @return void
    	 */
    	public function dashboard_page(): void {

    		if (
    			! current_user_can(
    				self::CAPABILITY
    			)
    		) {
    			wp_die(
    				esc_html__(
    					'You do not have permission to access this page.',
    					'kidia-mobile-cms'
    				)
    			);
    		}

    		$monitor = new Kidia_Mobile_CMS_API_Monitor();

    		$api = $monitor->get_status();
			$license_manager = new Kidia_Mobile_License_Manager();
			$license         = $license_manager->status();
			$setup_complete  = ( new Kidia_Mobile_Setup_Wizard() )->is_complete();
			$website_connected = ! empty( $license['active'] )
				|| '1' === (string) get_option( 'kidia_mobile_website_connected', '0' );

			if (
				isset( $_GET['woomobile_connected'], $_GET['woomobile_connect_nonce'] )
				&& '1' === sanitize_key( wp_unslash( $_GET['woomobile_connected'] ) )
				&& wp_verify_nonce(
					sanitize_text_field( wp_unslash( $_GET['woomobile_connect_nonce'] ) ),
					'kidia_mobile_connect_return'
				)
			) {
				update_option( 'kidia_mobile_website_connected', '1', false );
				$website_connected = true;
			}

			$connect_return_url = add_query_arg(
				array(
					'page'                     => 'kidia-mobile-cms',
					'woomobile_connected'      => '1',
					'woomobile_connect_nonce'  => wp_create_nonce( 'kidia_mobile_connect_return' ),
				),
				admin_url( 'admin.php' )
			) . '#kidia-license-key';
			$connect_url = apply_filters(
				'kidia_mobile_customer_connect_url',
				add_query_arg(
					array(
						'platform'         => 'wordpress',
						'plugin_installed' => '1',
						'site_url'         => home_url( '/' ),
						'return_url'       => $connect_return_url,
					),
					'https://woomobile.app/connect'
				)
			);
			$app_export_state   = Kidia_Mobile_App_Exporter::state();
			$app_export_current = Kidia_Mobile_App_Exporter::is_current();
			$push_export_config = Kidia_Mobile_Push_Service::client_configuration();

    		require
    			KIDIA_MOBILE_CMS_PATH .
    			'admin/pages/dashboard.php';
    	}

	/**
	 * Activates the submitted license key.
	 */
	public function activate_license(): void {
		$this->assert_license_action();
		$key    = isset( $_POST['license_key'] ) ? sanitize_text_field( wp_unslash( $_POST['license_key'] ) ) : '';
		$result = ( new Kidia_Mobile_License_Manager() )->activate( $key );
		$this->redirect_license_result( $result, 'activated' );
	}

	/**
	 * Forces an immediate license verification.
	 */
	public function verify_license(): void {
		$this->assert_license_action();
		$result = ( new Kidia_Mobile_License_Manager() )->verify( true );
		$this->redirect_license_result( $result, 'verified' );
	}

	private function assert_license_action(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) {
			wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) );
		}
		check_admin_referer( 'kidia_mobile_license_action', 'kidia_mobile_license_nonce' );
	}

	/**
	 * @param true|WP_Error $result Action result.
	 */
	private function redirect_license_result( $result, string $success ): void {
		$args = array( 'page' => 'kidia-mobile-cms' );
		if ( is_wp_error( $result ) ) {
			$args['license_error'] = $result->get_error_message();
		} else {
			$args['license_updated'] = $success;
		}
		wp_safe_redirect( add_query_arg( $args, admin_url( 'admin.php' ) ) );
		exit;
	}
    		/**
        	 * Home Builder.
        	 *
        	 * @return void
        	 */
        	public function home_builder_page(): void {

        		if (
        			! current_user_can(
        				self::CAPABILITY
        			)
        		) {
        			wp_die(
        				esc_html__(
        					'You do not have permission to access this page.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

        		$store = new Kidia_Mobile_Layout_Store();

        		$blocks = $store->get_layout();

				$definitions =
					Kidia_Mobile_Block_Registry::picker_definitions();
				$page_layout_store = new Kidia_Mobile_Page_Layout_Store();
				$home_chrome       = $page_layout_store->get_layout( 'home' );
				$header_fields     = Kidia_Mobile_Page_Layout_Store::header_fields();
				$footer_fields     = Kidia_Mobile_Page_Layout_Store::footer_fields();

        		require
        			KIDIA_MOBILE_CMS_PATH .
        			'admin/pages/home-builder.php';
        	}

        	/**
        	 * Saves Home Builder.
        	 *
        	 * @return void
        	 */
        	public function save_home_builder(): void {

        		if (
        			! current_user_can(
        				self::CAPABILITY
        			)
        		) {
        			wp_die(
        				esc_html__(
        					'You do not have permission to perform this action.',
        					'kidia-mobile-cms'
        				)
        			);
        		}

				check_admin_referer(
        			'kidia_mobile_save_home_builder',
        			'kidia_mobile_home_builder_nonce'
        		);

				$payload = isset( $_POST['blocks_payload'] )
					? wp_unslash( $_POST['blocks_payload'] )
					: '';
				$encoding = isset( $_POST['blocks_payload_encoding'] )
					? sanitize_key( wp_unslash( $_POST['blocks_payload_encoding'] ) )
					: '';

				$submitted_blocks = Kidia_Mobile_Layout_Store::decode_submission(
					$payload,
					$encoding
				);

				$fallback_blocks = isset( $_POST['blocks'] )
					? wp_unslash( $_POST['blocks'] )
					: array();

				if ( empty( $submitted_blocks ) && is_array( $fallback_blocks ) && ! empty( $fallback_blocks ) ) {
					$submitted_blocks = $fallback_blocks;
				}

        		if (
        			! is_array(
        				$submitted_blocks
        			)
        		) {
        			$submitted_blocks = array();
        		}

        		$store = new Kidia_Mobile_Layout_Store();

		$store->save_layout(
				$submitted_blocks
			);

			$chrome = isset( $_POST['layout'] ) ? wp_unslash( $_POST['layout'] ) : array();
			( new Kidia_Mobile_Page_Layout_Store() )->save_layout( 'home', is_array( $chrome ) ? $chrome : array() );

			$edit_type = isset( $_POST['edit_after_save_type'] )
				? sanitize_key( wp_unslash( $_POST['edit_after_save_type'] ) )
				: '';

			$edit_id = isset( $_POST['edit_after_save_id'] )
				? sanitize_key( wp_unslash( $_POST['edit_after_save_id'] ) )
				: '';

			if (
				'' !== $edit_id
				&& isset( self::EDITOR_PAGES[ $edit_type ] )
				&& $this->library_item_exists( $edit_type, $edit_id )
			) {
				wp_safe_redirect(
					add_query_arg(
						array(
							'page'    => self::EDITOR_PAGES[ $edit_type ],
							'id'      => $edit_id,
							'created' => '1',
						),
						admin_url( 'admin.php' )
					)
				);

				exit;
			}

				$fallback = add_query_arg(
						array(
							'page'    =>
								'kidia-mobile-home-builder',
							'updated' => '1',
							'saved_at' => time(),
						),
						admin_url(
							'admin.php'
						)
					);
				wp_safe_redirect( $this->requested_builder_redirect( $fallback ) );

				exit;
			}

			/** Returns a validated post-save destination requested by the unsaved-changes dialog. */
			private function requested_builder_redirect( string $fallback ): string {
				$requested = isset( $_POST['kidia_redirect_to'] )
					? esc_url_raw( wp_unslash( $_POST['kidia_redirect_to'] ) )
					: '';
				$destination = '' === $requested ? $fallback : wp_validate_redirect( $requested, $fallback );
				return $this->saved_theme_redirect( $destination );
			}

			/** Saves the just-submitted builder state as a named theme when requested. */
			private function saved_theme_redirect( string $fallback ): string {
				$name = isset( $_POST['kidia_save_theme_name'] )
					? sanitize_text_field( wp_unslash( (string) $_POST['kidia_save_theme_name'] ) )
					: '';
				if ( '' === $name ) {
					return $fallback;
				}
				( new Kidia_Mobile_Setup_Wizard() )->save_current_theme( $name );
				return add_query_arg(
					array(
						'page'         => 'kidia-mobile-saved-themes',
						'theme_notice' => 'save',
					),
					admin_url( 'admin.php' )
				);
			}

			/**
			 * Checks that a Library item exists before an editor redirect.
			 *
			 * @param string $type Element type.
			 * @param string $id   Library item ID.
			 *
			 * @return bool
			 */
			private function library_item_exists( string $type, string $id ): bool {
				if ( ! isset( self::LIBRARY_OPTIONS[ $type ] ) ) {
					return false;
				}

				$items = get_option( self::LIBRARY_OPTIONS[ $type ], array() );

				if ( ! is_array( $items ) ) {
					return false;
				}

				foreach ( $items as $item ) {
					if (
						is_array( $item )
						&& sanitize_key( (string) ( $item['id'] ?? '' ) ) === $id
					) {
						return true;
					}
				}

				return false;
			}
				/**
            	 * Loads Home Builder assets.
            	 *
            	 * @param string $hook_suffix Current admin page hook.
            	 *
            	 * @return void
            	 */
			public function enqueue_assets(
					string $hook_suffix
				): void {
					$page = isset( $_GET['page'] )
						? sanitize_key( wp_unslash( $_GET['page'] ) )
						: '';
					$is_kidia_page = 0 === strpos( $page, 'kidia-mobile-' )
						|| 'kidia-mobile-cms_page_kidia-mobile-home-builder' === $hook_suffix;

					if ( ! $is_kidia_page ) {
						return;
					}

					wp_enqueue_style(
						'kidia-mobile-admin-theme',
						KIDIA_MOBILE_CMS_URL . 'admin/assets/admin-theme.css',
						array(),
						KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/admin-theme.css' )
					);
					wp_enqueue_style( 'kidia-mobile-cms-shell', KIDIA_MOBILE_CMS_URL . 'admin/assets/cms-shell.css', array( 'kidia-mobile-admin-theme' ), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/cms-shell.css' ) );
					wp_enqueue_script( 'kidia-mobile-cms-shell', KIDIA_MOBILE_CMS_URL . 'admin/assets/cms-shell.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/cms-shell.js' ), true );
					wp_localize_script(
						'kidia-mobile-cms-shell',
						'kidiaCMSBackground',
						array(
							'ajaxUrl'     => admin_url( 'admin-ajax.php' ),
							'aiNonce'     => wp_create_nonce( 'kidia_mobile_ai_analysis' ),
							'activeAiJob' => Kidia_Mobile_AI_Analysis_Job::active_job_id( get_current_user_id() ),
							'aiUrl'       => add_query_arg( array( 'page' => 'kidia-mobile-ai-insights' ), admin_url( 'admin.php' ) ),
						)
					);
					if ( in_array( $page, array( 'kidia-mobile-cms', 'kidia-mobile-setup' ), true ) ) {
						wp_enqueue_script(
							'kidia-mobile-app-builder',
							KIDIA_MOBILE_CMS_URL . 'admin/assets/app-builder.js',
							array(),
							KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/app-builder.js' ),
							true
						);
						wp_localize_script(
							'kidia-mobile-app-builder',
							'kidiaAppBuilder',
							array(
								'ajaxUrl'     => admin_url( 'admin-ajax.php' ),
								'nonce'       => wp_create_nonce( 'kidia_mobile_app_build_status' ),
								'downloadUrl' => wp_nonce_url(
									add_query_arg(
										array( 'action' => 'kidia_mobile_download_apk' ),
										admin_url( 'admin-post.php' )
									),
									'kidia_mobile_download_apk',
									'kidia_mobile_download_nonce'
								),
								'labels'      => array(
									'queued'   => __( 'APK build queued…', 'kidia-mobile-cms' ),
									'building' => __( 'Building your APK…', 'kidia-mobile-cms' ),
									'ready'    => __( 'Your APK is ready to install.', 'kidia-mobile-cms' ),
									'failed'   => __( 'The APK build failed.', 'kidia-mobile-cms' ),
									'download' => __( 'Download APK', 'kidia-mobile-cms' ),
									'retry'    => __( 'Try Again', 'kidia-mobile-cms' ),
								),
							)
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
								'title'       => __( 'Preview mode', 'kidia-mobile-cms' ),
								'message'     => __( 'The default theme remains available to browse. Activate your website license to edit or save any setting.', 'kidia-mobile-cms' ),
								'actionLabel' => __( 'Connect or activate', 'kidia-mobile-cms' ),
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
									'errorLabel'              => __( 'The real preview could not be loaded. Try opening it again.', 'kidia-mobile-cms' ),
								)
							);
						} else {
							wp_enqueue_script( 'kidia-mobile-setup-wizard', KIDIA_MOBILE_CMS_URL . 'admin/assets/setup-wizard.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/setup-wizard.js' ), true );
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
								'apply'   => __( 'Apply to all', 'kidia-mobile-cms' ),
								'working' => __( 'Applying…', 'kidia-mobile-cms' ),
								'error'   => __( 'Could not apply these settings.', 'kidia-mobile-cms' ),
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
									'title'   => __( 'Unsaved changes', 'kidia-mobile-cms' ),
									'message' => __( 'You have changes that have not been saved. What would you like to do?', 'kidia-mobile-cms' ),
									'save'    => __( 'Save Changes', 'kidia-mobile-cms' ),
									'discard' => __( 'Discard Changes', 'kidia-mobile-cms' ),
									'cancel'  => __( 'Cancel', 'kidia-mobile-cms' ),
								),
							)
						);
					}

					if ( 'kidia-mobile-splash-screen' === $page ) {
						wp_enqueue_script( 'kidia-mobile-splash-screen', KIDIA_MOBILE_CMS_URL . 'admin/assets/splash-screen.js', array(), KIDIA_MOBILE_CMS_VERSION . '-' . (string) filemtime( KIDIA_MOBILE_CMS_PATH . 'admin/assets/splash-screen.js' ), true ); return;
					}
					if ( in_array( $page, array( 'kidia-mobile-similar-products', 'kidia-mobile-checkout-suggestions' ), true ) ) {
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
								'labels' => array( 'hidden' => __( 'Hidden', 'kidia-mobile-cms' ), 'visible' => __( 'Visible', 'kidia-mobile-cms' ) ),
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
            						'kidia-mobile-cms'
            					),
							'untitled'      => __(
								'Untitled Element',
								'kidia-mobile-cms'
							),
							'createPrefix'   => __( 'Create', 'kidia-mobile-cms' ),
							'draft'          => __( 'Draft', 'kidia-mobile-cms' ),
							'published'      => __( 'Published', 'kidia-mobile-cms' ),
							'copySuffix'     => __( ' Copy', 'kidia-mobile-cms' ),
							'noElements'     => __( 'No elements on the Home Page', 'kidia-mobile-cms' ),
							'noElementsDescription' => __(
								'Add an element to start building the application Home Page.',
								'kidia-mobile-cms'
							),
							'addFirst'       => __( 'Add First Element', 'kidia-mobile-cms' ),
							'chooseDestination' => __( 'Choose destination', 'kidia-mobile-cms' ),
							'currentDestination' => __( 'Current value', 'kidia-mobile-cms' ),
							'externalUrl' => __( 'External URL', 'kidia-mobile-cms' ),
							'searchTerm' => __( 'Search term', 'kidia-mobile-cms' ),
							'productId' => __( 'Product ID', 'kidia-mobile-cms' ),
							'actionValue' => __( 'Action Value', 'kidia-mobile-cms' ),
							'onSaleProducts' => __( 'Products on sale', 'kidia-mobile-cms' ),
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
				array( 'value' => 'latest', 'label' => __( 'Latest products', 'kidia-mobile-cms' ) ),
				array( 'value' => 'featured', 'label' => __( 'Featured products', 'kidia-mobile-cms' ) ),
				array( 'value' => 'on_sale', 'label' => __( 'Products on sale', 'kidia-mobile-cms' ) ),
				array( 'value' => 'best_selling', 'label' => __( 'Best selling', 'kidia-mobile-cms' ) ),
				array( 'value' => 'top_rated', 'label' => __( 'Top rated', 'kidia-mobile-cms' ) ),
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
