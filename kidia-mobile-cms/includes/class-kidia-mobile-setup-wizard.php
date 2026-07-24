<?php
/**
 * First-run setup wizard and complete application presets.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Setup_Wizard {
	private const STATE_OPTION    = 'kidia_mobile_setup_wizard_state';
	private const IDENTITY_OPTION = 'kidia_mobile_app_identity';
	private const BACKUP_OPTION   = 'kidia_mobile_setup_wizard_backup';

	/** @return array<string,array<string,mixed>> */
	public static function themes(): array {
		return array(
			'aurora' => self::theme(
				__( 'Aurora', 'kidia-mobile-cms' ),
				__( 'A polished, airy storefront with soft cards and editorial spacing.', 'kidia-mobile-cms' ),
				'#2F806E',
				'#EAF6F2',
				'#182D28',
				'rounded',
				array( 'hero_slider', 'category_grid', 'promo_strip', 'product_carousel', 'banner_grid', 'product_grid', 'brand_carousel' ),
				array( __( 'New season', 'kidia-mobile-cms' ), __( 'Shop by category', 'kidia-mobile-cms' ), __( 'Popular now', 'kidia-mobile-cms' ) )
			),
			'bloom' => self::theme(
				__( 'Bloom', 'kidia-mobile-cms' ),
				__( 'Warm lifestyle styling for fashion, beauty and family stores.', 'kidia-mobile-cms' ),
				'#B95D72',
				'#FFF0F3',
				'#40242C',
				'elevated',
				array( 'hero_slider', 'quick_links', 'category_grid', 'product_carousel', 'image_banner', 'product_grid', 'brand_carousel' ),
				array( __( 'Made for every day', 'kidia-mobile-cms' ), __( 'Collections', 'kidia-mobile-cms' ), __( 'You will love these', 'kidia-mobile-cms' ) )
			),
			'canvas' => self::theme(
				__( 'Canvas', 'kidia-mobile-cms' ),
				__( 'Minimal monochrome commerce with bold type and product-first layouts.', 'kidia-mobile-cms' ),
				'#171717',
				'#F4F4F2',
				'#111111',
				'minimal',
				array( 'hero_slider', 'category_grid', 'product_grid', 'image_banner', 'product_carousel', 'brand_carousel' ),
				array( __( 'The edit', 'kidia-mobile-cms' ), __( 'Browse collections', 'kidia-mobile-cms' ), __( 'Selected for you', 'kidia-mobile-cms' ) )
			),
			'pulse' => self::theme(
				__( 'Pulse', 'kidia-mobile-cms' ),
				__( 'High-energy promotional storefront for offers and fast-moving catalogs.', 'kidia-mobile-cms' ),
				'#6D36D8',
				'#F1ECFF',
				'#21143D',
				'elevated',
				array( 'promo_strip', 'hero_slider', 'countdown', 'quick_links', 'product_carousel', 'category_grid', 'product_grid' ),
				array( __( 'Limited drop', 'kidia-mobile-cms' ), __( 'Ending soon', 'kidia-mobile-cms' ), __( 'Trending today', 'kidia-mobile-cms' ) )
			),
			'avenue' => self::theme(
				__( 'Avenue', 'kidia-mobile-cms' ),
				__( 'Premium editorial composition for curated and luxury catalogs.', 'kidia-mobile-cms' ),
				'#9A7448',
				'#F7F1E8',
				'#30271E',
				'no_shadow',
				array( 'hero_slider', 'text_block', 'category_grid', 'banner_grid', 'product_carousel', 'image_banner', 'brand_carousel' ),
				array( __( 'The new collection', 'kidia-mobile-cms' ), __( 'Discover the story', 'kidia-mobile-cms' ), __( 'Curated pieces', 'kidia-mobile-cms' ) )
			),
			'metro' => self::theme(
				__( 'Metro', 'kidia-mobile-cms' ),
				__( 'Compact, practical navigation for large catalogs and marketplaces.', 'kidia-mobile-cms' ),
				'#1769AA',
				'#EAF4FC',
				'#142A3A',
				'outlined',
				array( 'quick_links', 'category_grid', 'promo_strip', 'product_grid', 'product_carousel', 'brand_carousel' ),
				array( __( 'Find it fast', 'kidia-mobile-cms' ), __( 'Top departments', 'kidia-mobile-cms' ), __( 'Best value', 'kidia-mobile-cms' ) )
			),
		);
	}

	/** @return array<string,mixed> */
	private static function theme( string $name, string $description, string $primary, string $soft, string $ink, string $card_style, array $blocks, array $sample_copy ): array {
		return compact( 'name', 'description', 'primary', 'soft', 'ink', 'card_style', 'blocks', 'sample_copy' );
	}

	/** @return array<string,array<string,string>> */
	public static function setup_pages(): array {
		return array(
			'home'     => array( 'name' => __( 'Storefront', 'kidia-mobile-cms' ), 'description' => __( 'Home page sections, promotions and product discovery.', 'kidia-mobile-cms' ) ),
			'category' => array( 'name' => __( 'Categories', 'kidia-mobile-cms' ), 'description' => __( 'Category navigation, cards and subcategory presentation.', 'kidia-mobile-cms' ) ),
			'catalog'  => array( 'name' => __( 'Catalog', 'kidia-mobile-cms' ), 'description' => __( 'Product browsing, filters, sorting and product cards.', 'kidia-mobile-cms' ) ),
			'product'  => array( 'name' => __( 'Product', 'kidia-mobile-cms' ), 'description' => __( 'Product information, gallery, actions, tabs and recommendations.', 'kidia-mobile-cms' ) ),
			'wishlist' => array( 'name' => __( 'Wishlist', 'kidia-mobile-cms' ), 'description' => __( 'Sign-in, empty and saved-product wishlist states.', 'kidia-mobile-cms' ) ),
			'account'  => array( 'name' => __( 'Account', 'kidia-mobile-cms' ), 'description' => __( 'Customer profile, orders and account navigation.', 'kidia-mobile-cms' ) ),
		);
	}

	public function is_complete(): bool {
		$state = get_option( self::STATE_OPTION, array() );
		return is_array( $state ) && ! empty( $state['completed'] );
	}

	/** @return array<string,mixed> */
	public function identity(): array {
		$saved = get_option( self::IDENTITY_OPTION, array() );
		return wp_parse_args(
			is_array( $saved ) ? $saved : array(),
			array(
				'app_name'      => get_bloginfo( 'name' ),
				'logo_id'       => 0,
				'logo_url'      => '',
				'language'      => is_rtl() ? 'ar' : 'en',
				'direction'     => is_rtl() ? 'rtl' : 'ltr',
				'primary_color' => '#2F806E',
				'theme'         => 'aurora',
				'page_themes'   => array_fill_keys( array_keys( self::setup_pages() ), 'aurora' ),
			)
		);
	}

	/** @param array<string,mixed> $submitted */
	public function apply( array $submitted ): string {
		$themes      = self::themes();
		$page_themes = array();
		$submitted_page_themes = is_array( $submitted['page_themes'] ?? null ) ? $submitted['page_themes'] : array();
		foreach ( array_keys( self::setup_pages() ) as $page ) {
			$theme_key = sanitize_key( (string) ( $submitted_page_themes[ $page ] ?? $submitted['theme'] ?? 'aurora' ) );
			$page_themes[ $page ] = isset( $themes[ $theme_key ] ) ? $theme_key : 'aurora';
		}
		$theme_key = $page_themes['home'];
		$theme     = $themes[ $theme_key ];
		$primary   = sanitize_hex_color( (string) ( $submitted['primary_color'] ?? '' ) ) ?: $theme['primary'];
		$app_name  = sanitize_text_field( (string) ( $submitted['app_name'] ?? get_bloginfo( 'name' ) ) );
		$app_name  = '' !== $app_name ? $app_name : get_bloginfo( 'name' );
		$logo_id   = absint( $submitted['logo_id'] ?? 0 );
		$logo_url  = $logo_id ? (string) wp_get_attachment_image_url( $logo_id, 'full' ) : esc_url_raw( (string) ( $submitted['logo_url'] ?? '' ) );
		$language  = sanitize_key( (string) ( $submitted['language'] ?? ( is_rtl() ? 'ar' : 'en' ) ) );
		$direction = 'rtl' === ( $submitted['direction'] ?? '' ) ? 'rtl' : 'ltr';

		$this->create_backup();
		update_option(
			self::IDENTITY_OPTION,
			array(
				'app_name'      => $app_name,
				'logo_id'       => $logo_id,
				'logo_url'      => $logo_url,
				'language'      => $language,
				'direction'     => $direction,
				'primary_color' => $primary,
				'theme'         => $theme_key,
				'page_themes'   => $page_themes,
			),
			false
		);

		$this->apply_home( $theme, $primary, $app_name, $logo_url );
		$this->apply_pages( $page_themes, $themes, $primary, $app_name, $logo_url );
		$this->apply_category( $themes[ $page_themes['category'] ] );
		$this->apply_extras( $theme, $themes[ $page_themes['product'] ], $primary, $app_name, $logo_url );

		update_option(
			self::STATE_OPTION,
			array(
				'completed'    => true,
				'theme'        => $theme_key,
				'page_themes'  => $page_themes,
				'completed_at' => time(),
			),
			false
		);
		return $theme_key;
	}

	/** @param array<string,mixed> $theme */
	private function apply_home( array $theme, string $primary, string $app_name, string $logo_url ): void {
		$blocks = array();
		$slides = $this->catalog_slides( (array) $theme['sample_copy'] );
		foreach ( $theme['blocks'] as $index => $type ) {
			$block = Kidia_Mobile_Block_Registry::create( (string) $type, $index + 1 );
			if ( ! is_array( $block ) ) {
				continue;
			}
			$settings = is_array( $block['settings'] ?? null ) ? $block['settings'] : array();
			$settings = array_merge(
				$settings,
				array(
					'primary_color'   => $primary,
					'accent_color'    => $theme['soft'],
					'background_color'=> '#FFFFFF',
					'text_color'      => $theme['ink'],
					'card_style'      => $theme['card_style'],
					'block_background'=> '#FFFFFF',
				)
			);
			if ( 'app_header' === $type ) {
				$settings['title']    = $app_name;
				$settings['logo_url'] = $logo_url;
			}
			if ( 'hero_slider' === $type ) {
				$settings['items']            = $slides;
				$settings['border_radius']    = 22;
				$settings['overlay_strength'] = 62;
				$settings['text_color']       = '#FFFFFF';
			}
			if ( 'category_grid' === $type ) {
				$settings['title']       = $theme['sample_copy'][1] ?? __( 'Shop by category', 'kidia-mobile-cms' );
				$settings['columns']     = 3;
				$settings['limit']       = 9;
				$settings['image_shape'] = 'circle';
			}
			if ( in_array( $type, array( 'product_grid', 'product_carousel' ), true ) ) {
				$settings['title']          = $theme['sample_copy'][2] ?? __( 'Products for you', 'kidia-mobile-cms' );
				$settings['source']         = 'latest';
				$settings['show_price']     = true;
				$settings['show_wishlist']  = true;
				$settings['quick_add_enabled'] = true;
			}
			$block['settings'] = $settings;
			$block['name']     = $this->block_name( (string) $type, (array) $theme['sample_copy'] );
			$blocks[]          = $block;
		}
		( new Kidia_Mobile_Layout_Store() )->save_layout( $blocks );
	}

	/** @return array<int,array<string,mixed>> */
	private function catalog_slides( array $copy ): array {
		$slides = array();
		if ( function_exists( 'wc_get_products' ) ) {
			foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => 3, 'orderby' => 'date', 'order' => 'DESC' ) ) as $product ) {
				if ( ! is_object( $product ) || ! method_exists( $product, 'get_image_id' ) ) {
					continue;
				}
				$image_url = $product->get_image_id() ? wp_get_attachment_image_url( absint( $product->get_image_id() ), 'full' ) : '';
				if ( ! $image_url ) {
					continue;
				}
				$product_id = method_exists( $product, 'get_id' ) ? absint( $product->get_id() ) : 0;
				$slides[]   = array(
					'id'           => 'setup_slide_' . ( count( $slides ) + 1 ),
					'enabled'      => true,
					'image_url'    => (string) $image_url,
					'title'        => method_exists( $product, 'get_name' ) ? sanitize_text_field( (string) $product->get_name() ) : ( $copy[0] ?? '' ),
					'subtitle'     => $copy[0] ?? __( 'Discover the collection', 'kidia-mobile-cms' ),
					'button_label' => __( 'Shop now', 'kidia-mobile-cms' ),
					'action_type'  => $product_id ? 'product' : '',
					'action_value' => $product_id ? (string) $product_id : '',
				);
			}
		}
		return $slides;
	}

	/**
	 * @param array<string,string> $page_themes Selected theme key for each setup page.
	 * @param array<string,array<string,mixed>> $themes Available theme definitions.
	 */
	private function apply_pages( array $page_themes, array $themes, string $primary, string $app_name, string $logo_url ): void {
		$store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$setup_page = 'size_chart' === $page ? 'product' : $page;
			$theme_key  = $page_themes[ $setup_page ] ?? $page_themes['home'] ?? 'aurora';
			$theme      = $themes[ $theme_key ] ?? $themes['aurora'];
			$layout = $store->default_layout( $page );
			foreach ( array( 'header', 'footer' ) as $chrome ) {
				if ( ! isset( $layout[ $chrome ]['settings'] ) || ! is_array( $layout[ $chrome ]['settings'] ) ) {
					continue;
				}
				$layout[ $chrome ]['settings']['background_color'] = '#FFFFFF';
				if ( 'header' === $chrome ) {
					$layout[ $chrome ]['settings']['icon_color'] = $theme['ink'];
					$layout[ $chrome ]['settings']['title_color'] = $theme['ink'];
				} else {
					$layout[ $chrome ]['settings']['active_color'] = $primary;
				}
			}
			if ( isset( $layout['header']['settings'] ) ) {
				$layout['header']['settings']['logo_text'] = $app_name;
				$layout['header']['settings']['logo_url']  = $logo_url;
			}
			if ( isset( $layout['elements'] ) && is_array( $layout['elements'] ) ) {
				foreach ( $layout['elements'] as &$element ) {
					if ( ! is_array( $element['settings'] ?? null ) ) {
						continue;
					}
					$element['settings']['primary_color']     = $primary;
					$element['settings']['background_color'] = '#FFFFFF';
					if ( array_key_exists( 'card_style', $element['settings'] ) ) {
						$element['settings']['card_style'] = $theme['card_style'];
					}
				}
				unset( $element );
			}
			$store->save_layout( $page, $layout );
		}
	}

	/** @param array<string,mixed> $theme */
	private function apply_category( array $theme ): void {
		$store    = new Kidia_Mobile_Category_Page_Store();
		$current  = $store->get_settings();
		$general  = array_merge(
			$current['general'],
			array(
				'category_layout'         => 'circular_grid',
				'grid_columns'            => 3,
				'card_style'              => $theme['card_style'],
				'card_background_color'   => '#FFFFFF',
				'page_background_color'   => '#FFFFFF',
				'element_background_color'=> '#FFFFFF',
				'font_color'              => $theme['ink'],
				'border_color'            => $theme['soft'],
			)
		);
		$store->save_settings( array( 'enabled' => true, 'general' => $general, 'categories' => $current['categories'] ) );
	}

	/**
	 * @param array<string,mixed> $home_theme Home/splash styling.
	 * @param array<string,mixed> $product_theme Product recommendation styling.
	 */
	private function apply_extras( array $home_theme, array $product_theme, string $primary, string $app_name, string $logo_url ): void {
		update_option(
			'kidia_mobile_splash_screen',
			array(
				'enabled'              => true,
				'image_url'            => $logo_url,
				'background_color'     => $primary,
				'background_color_end' => $home_theme['ink'],
				'duration_ms'          => 1800,
				'image_width'          => 140,
				'image_height'         => 140,
				'image_fit'            => 'contain',
				'image_shape'          => 'none',
				'show_store_name'      => true,
				'store_name'           => $app_name,
				'text_color'           => '#FFFFFF',
				'show_loader'          => true,
				'loader_color'         => '#FFFFFF',
			),
			false
		);
		update_option(
			'kidia_mobile_checkout_suggestions',
			array(
				'enabled'           => true,
				'title'             => __( 'You may also like', 'kidia-mobile-cms' ),
				'source'            => 'featured',
				'category_id'       => 0,
				'manual_product_ids'=> '',
				'limit'             => 6,
				'columns'           => 2,
				'card_style'        => $product_theme['card_style'],
				'card_radius'       => 16,
				'image_ratio'       => 1,
				'show_price'        => true,
				'show_regular_price'=> true,
				'show_rating'       => false,
				'button_label'      => __( 'Add', 'kidia-mobile-cms' ),
				'button_color'      => $primary,
				'button_text_color' => '#FFFFFF',
			),
			false
		);
	}

	private function block_name( string $type, array $copy ): string {
		$names = array(
			'hero_slider'     => $copy[0] ?? __( 'Featured collection', 'kidia-mobile-cms' ),
			'category_grid'   => $copy[1] ?? __( 'Shop by category', 'kidia-mobile-cms' ),
			'product_grid'    => $copy[2] ?? __( 'Products for you', 'kidia-mobile-cms' ),
			'product_carousel'=> $copy[2] ?? __( 'Popular products', 'kidia-mobile-cms' ),
			'promo_strip'     => __( 'Store benefits', 'kidia-mobile-cms' ),
			'quick_links'     => __( 'Quick links', 'kidia-mobile-cms' ),
			'brand_carousel'  => __( 'Featured brands', 'kidia-mobile-cms' ),
			'countdown'       => __( 'Flash sale', 'kidia-mobile-cms' ),
			'image_banner'    => __( 'Collection story', 'kidia-mobile-cms' ),
			'banner_grid'     => __( 'Seasonal collections', 'kidia-mobile-cms' ),
			'text_block'      => __( 'Brand story', 'kidia-mobile-cms' ),
		);
		return $names[ $type ] ?? ucwords( str_replace( '_', ' ', $type ) );
	}

	private function create_backup(): void {
		$backup = array(
			'created_at' => time(),
			'home'       => ( new Kidia_Mobile_Layout_Store() )->get_layout(),
			'pages'      => array(),
			'category'   => ( new Kidia_Mobile_Category_Page_Store() )->get_settings(),
			'splash'     => get_option( 'kidia_mobile_splash_screen', array() ),
			'checkout'   => get_option( 'kidia_mobile_checkout_suggestions', array() ),
			'identity'   => get_option( self::IDENTITY_OPTION, array() ),
		);
		$page_store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$backup['pages'][ $page ] = $page_store->get_layout( $page );
		}
		update_option( self::BACKUP_OPTION, $backup, false );
	}
}
