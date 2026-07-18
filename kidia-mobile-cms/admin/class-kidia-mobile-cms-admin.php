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
			'admin_menu',
			array( $this, 'hide_element_library_menus' ),
			999
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
    			__( 'Home Builder', 'kidia-mobile-cms' ),
    			__( 'Home Builder', 'kidia-mobile-cms' ),
    			self::CAPABILITY,
    			'kidia-mobile-home-builder',
    			array(
    				$this,
    				'home_builder_page',
    			)
    		);

		add_submenu_page(
			'kidia-mobile-cms',
			__( 'Category Page Builder', 'kidia-mobile-cms' ),
			__( 'Category Page Builder', 'kidia-mobile-cms' ),
			self::CAPABILITY,
			'kidia-mobile-category-builder',
			array( $this, 'category_builder_page' )
		);

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
		$settings = get_option( 'kidia_mobile_category_page', array() );
		$settings = is_array( $settings ) ? $settings : array();

		require KIDIA_MOBILE_CMS_PATH . 'admin/pages/category-builder.php';
	}

	/** Saves order, visibility and image overrides keyed by WooCommerce term ID. */
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
					'image_size' => min( 120, max( 32, absint( $row['image_size'] ?? 68 ) ) ),
					'image_shape' => in_array( $row['image_shape'] ?? '', array( 'square', 'rounded', 'circle' ), true )
						? sanitize_key( $row['image_shape'] )
						: 'rounded',
					'image_radius' => min( 50, max( 0, absint( $row['image_radius'] ?? 18 ) ) ),
					'image_fit' => in_array( $row['image_fit'] ?? '', array( 'contain', 'cover' ), true )
						? sanitize_key( $row['image_fit'] )
						: 'contain',
					'image_effect' => in_array( $row['image_effect'] ?? '', array( 'none', 'shadow', 'grayscale' ), true )
						? sanitize_key( $row['image_effect'] )
						: 'none',
					'image_scale' => min( 150, max( 80, absint( $row['image_scale'] ?? 100 ) ) ),
					'image_position' => in_array( $row['image_position'] ?? '', array( 'center', 'top', 'bottom', 'left', 'right' ), true )
						? sanitize_key( $row['image_position'] )
						: 'center',
					'border_width' => min( 8, max( 0, absint( $row['border_width'] ?? 0 ) ) ),
					'border_color' => sanitize_hex_color( $row['border_color'] ?? '' ) ?: '#DDE5E2',
					'background_color' => sanitize_hex_color( $row['background_color'] ?? '' ) ?: '#FFFFFF',
					'image_text_gap' => min( 40, max( 0, absint( $row['image_text_gap'] ?? 10 ) ) ),
					'font_size' => min( 30, max( 10, absint( $row['font_size'] ?? 16 ) ) ),
					'font_color' => sanitize_hex_color( $row['font_color'] ?? '' ) ?: '#1F2933',
					'font_weight' => in_array( absint( $row['font_weight'] ?? 800 ), array( 400, 500, 600, 700, 800, 900 ), true ) ? absint( $row['font_weight'] ) : 800,
					'text_align' => in_array( $row['text_align'] ?? '', array( 'start', 'center', 'end' ), true ) ? sanitize_key( $row['text_align'] ) : 'start',
					'text_max_lines' => min( 3, max( 1, absint( $row['text_max_lines'] ?? 2 ) ) ),
					'line_height' => min( 200, max( 100, absint( $row['line_height'] ?? 125 ) ) ),
				);
			}
		}
		update_option( 'kidia_mobile_category_page', $clean, false );
		wp_safe_redirect( add_query_arg( array( 'page' => 'kidia-mobile-category-builder', 'updated' => '1' ), admin_url( 'admin.php' ) ) );
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

				$submitted_blocks = Kidia_Mobile_Layout_Store::decode_submission(
					$payload
				);

				if ( '' === $payload ) {
					$submitted_blocks = isset( $_POST['blocks'] )
						? wp_unslash( $_POST['blocks'] )
						: array();
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

        		wp_safe_redirect(
        			add_query_arg(
        				array(
        					'page'    =>
        						'kidia-mobile-home-builder',
        					'updated' => '1',
        				),
        				admin_url(
        					'admin.php'
        				)
        			)
        		);

				exit;
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

					if (
							'kidia-mobile-home-builder' !== $page
							&& 'kidia-mobile-category-builder' !== $page
							&& 'kidia-mobile-cms_page_kidia-mobile-home-builder'
								!== $hook_suffix
					) {
            			return;
            		}

					wp_enqueue_media();

					if ( 'kidia-mobile-category-builder' === $page ) {
						wp_enqueue_style( 'kidia-mobile-category-builder', KIDIA_MOBILE_CMS_URL . 'admin/assets/category-builder.css', array(), KIDIA_MOBILE_CMS_VERSION );
						wp_enqueue_script( 'kidia-mobile-category-builder', KIDIA_MOBILE_CMS_URL . 'admin/assets/category-builder.js', array( 'jquery', 'jquery-ui-sortable' ), KIDIA_MOBILE_CMS_VERSION, true );
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
						),
						'editorPages' => self::EDITOR_PAGES,
					)
            		);
            	}
            }
