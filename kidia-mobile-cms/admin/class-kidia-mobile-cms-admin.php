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
		add_action( 'wp_ajax_kidia_mobile_apply_product_icon_settings', array( $this, 'apply_product_icon_settings' ) );

		add_action(
			'admin_menu',
			array( $this, 'hide_element_library_menus' ),
			999
		);

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
    			'kidia-mobile-cms',
    			__( 'Dashboard', 'kidia-mobile-cms' ),
    			__( 'Dashboard', 'kidia-mobile-cms' ),
    			self::CAPABILITY,
    			'kidia-mobile-cms',
    			array(
    				$this,
    				'dashboard_page',
    			)
		);

    		add_submenu_page(
    			'kidia-mobile-cms',
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
			'kidia-mobile-cms',
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
				'kidia-mobile-cms',
				$label . ' ' . __( 'Builder', 'kidia-mobile-cms' ),
				$label,
				self::CAPABILITY,
				$slug,
				array( $this, 'page_builder_page' )
			);
		}

		add_submenu_page( 'kidia-mobile-cms', __( 'Splash Screen', 'kidia-mobile-cms' ), __( 'Splash Screen', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-splash-screen', array( $this, 'splash_screen_page' ) );
		add_submenu_page( 'kidia-mobile-cms', __( 'Similar Products', 'kidia-mobile-cms' ), __( 'Similar Products', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-similar-products', array( $this, 'similar_products_page' ) );
		add_submenu_page( 'kidia-mobile-cms', __( 'Checkout Suggestions', 'kidia-mobile-cms' ), __( 'Checkout Suggestions', 'kidia-mobile-cms' ), self::CAPABILITY, 'kidia-mobile-checkout-suggestions', array( $this, 'checkout_suggestions_page' ) );

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
		wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-splash-screen', 'updated' => '1', 'saved_at' => time() ), admin_url( 'admin.php' ) ) ); exit;
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
		wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-similar-products', 'updated' => '1', 'saved_at' => time() ), admin_url( 'admin.php' ) ) ); exit;
	}

	public function checkout_suggestions_page(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) { wp_die( esc_html__( 'You do not have permission to access this page.', 'kidia-mobile-cms' ) ); }
		$defaults=array('enabled'=>true,'title'=>__('You may also need','kidia-mobile-cms'),'source'=>'featured','category_id'=>0,'manual_product_ids'=>'','limit'=>6,'columns'=>2,'card_style'=>'outlined','card_radius'=>14,'image_ratio'=>1,'show_price'=>true,'show_regular_price'=>true,'show_rating'=>false,'button_label'=>__('Add','kidia-mobile-cms'),'button_color'=>'#2F806E','button_text_color'=>'#FFFFFF'); $saved=get_option('kidia_mobile_checkout_suggestions',array()); $settings=array_merge($defaults,is_array($saved)?$saved:array());
		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/checkout-suggestions.php';
	}

	public function save_checkout_suggestions(): void {
		if ( ! current_user_can( self::CAPABILITY ) ) { wp_die( esc_html__( 'You do not have permission to perform this action.', 'kidia-mobile-cms' ) ); } check_admin_referer('kidia_mobile_save_checkout_suggestions','kidia_mobile_checkout_suggestions_nonce');
		$row=isset($_POST['suggestions'])&&is_array($_POST['suggestions'])?wp_unslash($_POST['suggestions']):array(); $source=in_array($row['source']??'',array('latest','featured','on_sale','category','manual'),true)?sanitize_key($row['source']):'featured';
		$clean=array('enabled'=>!empty($row['enabled']),'title'=>sanitize_text_field((string)($row['title']??'')),'source'=>$source,'category_id'=>absint($row['category_id']??0),'manual_product_ids'=>sanitize_text_field((string)($row['manual_product_ids']??'')),'limit'=>min(20,max(1,absint($row['limit']??6))),'columns'=>min(3,max(1,absint($row['columns']??2))),'card_style'=>in_array($row['card_style']??'',array('minimal','no_shadow','outlined','elevated'),true)?sanitize_key($row['card_style']):'outlined','card_radius'=>min(40,absint($row['card_radius']??14)),'image_ratio'=>min(2,max(.5,(float)($row['image_ratio']??1))),'show_price'=>!empty($row['show_price']),'show_regular_price'=>!empty($row['show_regular_price']),'show_rating'=>!empty($row['show_rating']),'button_label'=>sanitize_text_field((string)($row['button_label']??'')),'button_color'=>sanitize_hex_color($row['button_color']??'')?:'#2F806E','button_text_color'=>sanitize_hex_color($row['button_text_color']??'')?:'#FFFFFF'); update_option('kidia_mobile_checkout_suggestions',$clean,false); wp_safe_redirect(add_query_arg(array('page'=>'kidia-mobile-checkout-suggestions','updated'=>'1','saved_at'=>time()),admin_url('admin.php'))); exit;
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

    		require
    			KIDIA_MOBILE_CMS_PATH .
    			'admin/pages/dashboard.php';
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
				return '' === $requested ? $fallback : wp_validate_redirect( $requested, $fallback );
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
								rest_url( 'woo-mobile/v1/home-layout' )
							)
						),
					'livePreviewEndpoint' => esc_url_raw( rest_url( 'woo-mobile/v1/home-layout/preview' ) ),
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
