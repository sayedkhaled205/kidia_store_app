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
	private const SAVED_THEMES_OPTION = 'kidia_mobile_saved_themes';

	/** @return array<string,array<string,mixed>> */
	public static function themes(): array {
		return array(
			'fashion' => self::theme(
				__( 'Fashion Editorial', 'kidia-mobile-cms' ),
				__( 'A premium fashion storefront with editorial banners, spacious collections and modern product cards.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#2C2926', 'soft' => '#F2E9DF', 'ink' => '#211F1D', 'surface' => '#FCFAF7',
					'card_style' => 'no_shadow', 'hero_asset' => 'fashion.webp', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'fashion',
					'product_columns' => 2, 'radius' => 8, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 42,
					'blocks' => array( 'hero_slider', 'category_grid', 'text_block', 'product_carousel', 'banner_grid', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'The new edit', 'kidia-mobile-cms' ), __( 'Shop the collections', 'kidia-mobile-cms' ), __( 'Trending now', 'kidia-mobile-cms' ) ),
				)
			),
			'beauty' => self::theme(
				__( 'Beauty & Wellness', 'kidia-mobile-cms' ),
				__( 'A soft beauty store with calming color, rounded product cards and ingredient-led discovery.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#A45E70', 'soft' => '#FBE9ED', 'ink' => '#3F2930', 'surface' => '#FFF9FA',
					'card_style' => 'elevated', 'hero_asset' => 'beauty.webp', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'beauty',
					'product_columns' => 2, 'radius' => 20, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 32,
					'blocks' => array( 'hero_slider', 'quick_links', 'category_grid', 'product_carousel', 'image_banner', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Glow every day', 'kidia-mobile-cms' ), __( 'Shop by concern', 'kidia-mobile-cms' ), __( 'Self-care favorites', 'kidia-mobile-cms' ) ),
				)
			),
			'electronics' => self::theme(
				__( 'Electronics Pro', 'kidia-mobile-cms' ),
				__( 'A sharp technology store with dark hero media, compact navigation and deal-focused sections.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#0878E5', 'soft' => '#E8F3FF', 'ink' => '#101A2A', 'surface' => '#F6F9FD',
					'card_style' => 'outlined', 'hero_asset' => 'electronics.webp', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'electronics',
					'product_columns' => 2, 'radius' => 12, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 28,
					'blocks' => array( 'promo_strip', 'hero_slider', 'quick_links', 'category_grid', 'product_grid', 'countdown', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Upgrade your everyday', 'kidia-mobile-cms' ), __( 'Top tech categories', 'kidia-mobile-cms' ), __( 'Smart deals', 'kidia-mobile-cms' ) ),
				)
			),
			'home_living' => self::theme(
				__( 'Home & Living', 'kidia-mobile-cms' ),
				__( 'A warm interior store with natural tones, editorial storytelling and curated room collections.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#786248', 'soft' => '#F3ECE2', 'ink' => '#342C23', 'surface' => '#FBF8F3',
					'card_style' => 'no_shadow', 'hero_asset' => 'home-living.webp', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'home_living',
					'product_columns' => 2, 'radius' => 6, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 24,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'banner_grid', 'product_carousel', 'image_banner', 'product_grid' ),
					'sample_copy' => array( __( 'Make space feel yours', 'kidia-mobile-cms' ), __( 'Shop by room', 'kidia-mobile-cms' ), __( 'Curated for home', 'kidia-mobile-cms' ) ),
				)
			),
			'kids_baby' => self::theme(
				__( 'Kids & Baby', 'kidia-mobile-cms' ),
				__( 'A bright family store with playful color, friendly shapes and easy age-based browsing.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#2E8EC7', 'soft' => '#E8F7FC', 'ink' => '#253A46', 'surface' => '#FAFDFE',
					'card_style' => 'elevated', 'hero_asset' => 'kids-baby.webp', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'kids_baby',
					'product_columns' => 2, 'radius' => 22, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 18,
					'blocks' => array( 'hero_slider', 'quick_links', 'category_grid', 'promo_strip', 'product_carousel', 'banner_grid', 'product_grid' ),
					'sample_copy' => array( __( 'Big joy for little ones', 'kidia-mobile-cms' ), __( 'Shop by age', 'kidia-mobile-cms' ), __( 'Loved by families', 'kidia-mobile-cms' ) ),
				)
			),
			'sports_fitness' => self::theme(
				__( 'Sports & Fitness', 'kidia-mobile-cms' ),
				__( 'A high-energy performance store with bold contrast, quick departments and promotional drops.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#F15A24', 'soft' => '#FFF0E8', 'ink' => '#17191B', 'surface' => '#F7F7F7',
					'card_style' => 'outlined', 'hero_asset' => 'sports-fitness.webp', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'sports_fitness',
					'product_columns' => 2, 'radius' => 10, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 38,
					'blocks' => array( 'promo_strip', 'hero_slider', 'quick_links', 'category_grid', 'countdown', 'product_grid', 'product_carousel' ),
					'sample_copy' => array( __( 'Built to move', 'kidia-mobile-cms' ), __( 'Train by category', 'kidia-mobile-cms' ), __( 'Performance picks', 'kidia-mobile-cms' ) ),
				)
			),
			'grocery' => self::theme(
				__( 'Grocery Fresh', 'kidia-mobile-cms' ),
				__( 'A practical grocery store with fast categories, offer strips and dense everyday product discovery.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#238447', 'soft' => '#E9F7ED', 'ink' => '#21362A', 'surface' => '#FBFDFB',
					'card_style' => 'elevated', 'hero_asset' => 'grocery.webp', 'category_layout' => 'compact_grid', 'category_shape' => 'circle',
					'layout_profile' => 'grocery',
					'product_columns' => 3, 'radius' => 14, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 16,
					'blocks' => array( 'promo_strip', 'hero_slider', 'quick_links', 'category_grid', 'countdown', 'product_carousel', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Fresh for today', 'kidia-mobile-cms' ), __( 'Shop essentials', 'kidia-mobile-cms' ), __( 'Weekly value', 'kidia-mobile-cms' ) ),
				)
			),
			'luxury' => self::theme(
				__( 'Luxury Boutique', 'kidia-mobile-cms' ),
				__( 'A refined dark boutique with dramatic imagery, minimal chrome and gallery-style products.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#B58A45', 'soft' => '#F3E9D6', 'ink' => '#17130E', 'surface' => '#FCFAF6',
					'card_style' => 'no_shadow', 'hero_asset' => 'luxury.webp', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'luxury',
					'product_columns' => 2, 'radius' => 2, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 50,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'image_banner', 'product_carousel', 'banner_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Objects of distinction', 'kidia-mobile-cms' ), __( 'The collections', 'kidia-mobile-cms' ), __( 'Signature pieces', 'kidia-mobile-cms' ) ),
				)
			),
			'coffee' => self::theme(
				__( 'Coffee & Gourmet', 'kidia-mobile-cms' ),
				__( 'A crafted food store with rich imagery, story sections and specialty product collections.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#8A4B2A', 'soft' => '#F5E9DE', 'ink' => '#33231A', 'surface' => '#FCF8F3',
					'card_style' => 'elevated', 'hero_asset' => 'coffee.webp', 'category_layout' => 'visual_grid', 'category_shape' => 'circle',
					'layout_profile' => 'coffee',
					'product_columns' => 2, 'radius' => 16, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 36,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'promo_strip', 'product_carousel', 'image_banner', 'product_grid' ),
					'sample_copy' => array( __( 'Crafted for slow mornings', 'kidia-mobile-cms' ), __( 'Explore the roast', 'kidia-mobile-cms' ), __( 'Gourmet favorites', 'kidia-mobile-cms' ) ),
				)
			),
			'multi_store' => self::theme(
				__( 'Multi Store', 'kidia-mobile-cms' ),
				__( 'A flexible marketplace for large mixed catalogs with fast navigation, offers and compact grids.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#195BC7', 'soft' => '#EAF1FF', 'ink' => '#16243A', 'surface' => '#F7F9FC',
					'card_style' => 'outlined', 'hero_asset' => 'multi-store.webp', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'multi_store',
					'product_columns' => 3, 'radius' => 12, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 12,
					'blocks' => array( 'quick_links', 'hero_slider', 'promo_strip', 'category_grid', 'countdown', 'product_grid', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Everything in one place', 'kidia-mobile-cms' ), __( 'Browse departments', 'kidia-mobile-cms' ), __( 'Best value today', 'kidia-mobile-cms' ) ),
				)
			),
		);
	}

	/** @return array<string,mixed> */
	private static function theme( string $name, string $description, array $config ): array {
		return array_merge(
			array(
				'name' => $name,
				'description' => $description,
				'surface' => '#FFFFFF',
				'category_layout' => 'visual_grid',
				'category_shape' => 'rounded',
				'product_columns' => 2,
				'radius' => 14,
				'header_style' => 'standard',
				'search_style' => 'bar',
				'overlay' => 32,
				'layout_profile' => 'fashion',
				'blocks' => array(),
				'sample_copy' => array(),
			),
			$config
		);
	}

	/** @param array<string,mixed> $theme */
	public static function hero_url( array $theme ): string {
		$file = sanitize_file_name( (string) ( $theme['hero_asset'] ?? '' ) );
		return '' !== $file ? KIDIA_MOBILE_CMS_URL . 'admin/assets/theme-previews/' . $file : '';
	}

	/**
	 * Returns the exact layouts that a built-in theme would install, without
	 * changing the current application. The Setup Wizard preview consumes this.
	 *
	 * @return array<string,mixed>
	 */
	public function preview_snapshot( string $theme_key ): array {
		$themes = self::themes();
		$theme_key = $this->normalize_theme_key( $theme_key, $themes );
		$theme = $themes[ $theme_key ];
		$app_name = (string) $theme['name'];
		$pages = array();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$pages[ $page ] = $this->build_page_layout( $page, $theme, (string) $theme['primary'], (string) $theme['soft'], $app_name, '' );
		}
		$category_store = new Kidia_Mobile_Category_Page_Store();
		return array(
			'theme' => $theme_key,
			'home' => $this->build_home( $theme, (string) $theme['primary'], (string) $theme['soft'], $app_name, '' ),
			'pages' => $pages,
			'category' => $this->build_category_settings( $theme, $category_store->get_settings() ),
			'identity' => array(
				'app_name' => $app_name,
				'primary_color' => $theme['primary'],
				'secondary_color' => $theme['soft'],
				'theme' => $theme_key,
			),
		);
	}

	/** @return array<string,array<string,mixed>> */
	public static function setup_pages(): array {
		return array(
			'home'     => array( 'name' => __( 'Storefront', 'kidia-mobile-cms' ), 'description' => __( 'Home page sections, promotions and product discovery.', 'kidia-mobile-cms' ), 'icon' => 'dashicons-store', 'required' => true ),
			'category' => array( 'name' => __( 'Categories', 'kidia-mobile-cms' ), 'description' => __( 'Category navigation, cards and subcategory presentation.', 'kidia-mobile-cms' ), 'icon' => 'dashicons-category', 'required' => false ),
			'catalog'  => array( 'name' => __( 'Catalog', 'kidia-mobile-cms' ), 'description' => __( 'Product browsing, filters, sorting and product cards.', 'kidia-mobile-cms' ), 'icon' => 'dashicons-grid-view', 'required' => false ),
			'product'  => array( 'name' => __( 'Product', 'kidia-mobile-cms' ), 'description' => __( 'Product information, gallery, actions, tabs and recommendations.', 'kidia-mobile-cms' ), 'icon' => 'dashicons-products', 'required' => true ),
			'wishlist' => array( 'name' => __( 'Wishlist', 'kidia-mobile-cms' ), 'description' => __( 'Sign-in, empty and saved-product wishlist states.', 'kidia-mobile-cms' ), 'icon' => 'dashicons-heart', 'required' => false ),
			'account'  => array( 'name' => __( 'Account', 'kidia-mobile-cms' ), 'description' => __( 'Customer profile, orders and account navigation.', 'kidia-mobile-cms' ), 'icon' => 'dashicons-admin-users', 'required' => false ),
		);
	}

	public function is_complete(): bool {
		$state = get_option( self::STATE_OPTION, array() );
		return is_array( $state ) && ! empty( $state['completed'] );
	}

	/** @return array<string,array<string,mixed>> */
	public function saved_themes(): array {
		$themes = get_option( self::SAVED_THEMES_OPTION, array() );
		return is_array( $themes ) ? $themes : array();
	}

	/**
	 * Returns lightweight, display-only data for a saved-theme preview.
	 *
	 * The preview is derived from the saved snapshot itself so two saved themes
	 * with different banners, branding or colors never share a generic mockup.
	 *
	 * @param array<string,mixed> $saved_theme Saved theme record.
	 * @return array<string,mixed>
	 */
	public function saved_theme_preview( array $saved_theme ): array {
		$snapshot  = is_array( $saved_theme['snapshot'] ?? null ) ? $saved_theme['snapshot'] : array();
		$identity  = is_array( $snapshot['identity'] ?? null ) ? $snapshot['identity'] : array();
		$home      = is_array( $snapshot['home'] ?? null ) ? $snapshot['home'] : array();
		$image_urls = array();
		$this->collect_preview_image_urls( $home, $image_urls );

		if ( empty( $image_urls ) ) {
			$this->collect_preview_image_urls( $snapshot['splash'] ?? array(), $image_urls );
		}

		$primary = sanitize_hex_color( (string) ( $identity['primary_color'] ?? '' ) ) ?: '#2F806E';
		$soft    = sanitize_hex_color( (string) ( $identity['secondary_color'] ?? '' ) ) ?: '#EAF6F2';
		$ink     = '#182D28';
		$blocks  = array();

		foreach ( $home as $block ) {
			if ( ! is_array( $block ) || false === (bool) ( $block['enabled'] ?? true ) ) {
				continue;
			}
			$type = sanitize_key( (string) ( $block['type'] ?? '' ) );
			if ( '' !== $type ) {
				$blocks[] = $type;
			}
			$settings = is_array( $block['settings'] ?? null ) ? $block['settings'] : array();
			if ( '#2F806E' === strtoupper( $primary ) ) {
				$primary = sanitize_hex_color( (string) ( $settings['primary_color'] ?? '' ) ) ?: $primary;
			}
			if ( '#EAF6F2' === strtoupper( $soft ) ) {
				$soft = sanitize_hex_color( (string) ( $settings['accent_color'] ?? '' ) ) ?: $soft;
			}
			if ( '#182D28' === strtoupper( $ink ) ) {
				$ink = sanitize_hex_color( (string) ( $settings['text_color'] ?? '' ) ) ?: $ink;
			}
		}

		return array(
			'app_name'  => sanitize_text_field( (string) ( $identity['app_name'] ?? $saved_theme['name'] ?? __( 'Saved theme', 'kidia-mobile-cms' ) ) ),
			'primary'   => $primary,
			'soft'      => $soft,
			'ink'       => $ink,
			'logo_url'  => esc_url_raw( (string) ( $identity['logo_url'] ?? '' ) ),
			'images'    => array_slice( array_values( array_unique( $image_urls ) ), 0, 5 ),
			'blocks'    => array_values( array_unique( $blocks ) ),
			'direction' => 'rtl' === ( $identity['direction'] ?? '' ) ? 'rtl' : 'ltr',
		);
	}

	public function save_current_theme( string $name ): string {
		$name = sanitize_text_field( $name );
		if ( '' === $name ) {
			$name = __( 'Saved theme', 'kidia-mobile-cms' );
		}
		$id     = function_exists( 'wp_generate_uuid4' ) ? wp_generate_uuid4() : str_replace( '.', '-', uniqid( 'theme_', true ) );
		$themes = $this->saved_themes();
		$themes[ $id ] = array(
			'id'         => $id,
			'name'       => $name,
			'created_at' => time(),
			'snapshot'   => $this->sanitize_snapshot( $this->current_snapshot() ),
		);
		update_option( self::SAVED_THEMES_OPTION, $themes, false );
		return $id;
	}

	public function apply_saved_theme( string $id ): bool {
		$themes = $this->saved_themes();
		if ( empty( $themes[ $id ]['snapshot'] ) || ! is_array( $themes[ $id ]['snapshot'] ) ) {
			return false;
		}
		$this->restore_snapshot( $themes[ $id ]['snapshot'], 'saved_theme' );
		return true;
	}

	public function delete_saved_theme( string $id ): bool {
		$themes = $this->saved_themes();
		if ( ! isset( $themes[ $id ] ) ) {
			return false;
		}
		unset( $themes[ $id ] );
		update_option( self::SAVED_THEMES_OPTION, $themes, false );
		return true;
	}

	/** @return array<string,mixed>|null */
	public function export_saved_theme( string $id ): ?array {
		$themes = $this->saved_themes();
		if ( ! isset( $themes[ $id ] ) ) {
			return null;
		}
		return array(
			'schema' => 'woomobileapp-saved-theme',
			'version' => 1,
			'theme' => $themes[ $id ],
		);
	}

	public function import_saved_theme( string $json ): string {
		$payload = json_decode( $json, true );
		if ( ! is_array( $payload ) || 'woomobileapp-saved-theme' !== ( $payload['schema'] ?? '' ) || ! is_array( $payload['theme']['snapshot'] ?? null ) ) {
			throw new InvalidArgumentException( __( 'The selected file is not a valid WooMobile saved theme.', 'kidia-mobile-cms' ) );
		}
		$id     = function_exists( 'wp_generate_uuid4' ) ? wp_generate_uuid4() : uniqid( 'theme_', true );
		$themes = $this->saved_themes();
		$themes[ $id ] = array(
			'id'         => $id,
			'name'       => sanitize_text_field( (string) ( $payload['theme']['name'] ?? __( 'Imported theme', 'kidia-mobile-cms' ) ) ),
			'created_at' => time(),
			'snapshot'   => $this->sanitize_snapshot( $payload['theme']['snapshot'] ),
		);
		update_option( self::SAVED_THEMES_OPTION, $themes, false );
		return $id;
	}

	public function start_blank(): void {
		$snapshot = $this->current_snapshot();
		$snapshot['home'] = array();
		$page_store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$snapshot['pages'][ $page ] = $page_store->default_layout( $page );
		}
		$this->restore_snapshot( $snapshot, 'manual' );
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
				'primary_color' => '#2C2926',
				'secondary_color' => '#F2E9DF',
				'theme'         => 'fashion',
				'page_themes'   => array_fill_keys( array_keys( self::setup_pages() ), 'fashion' ),
				'enabled_pages' => array_keys( self::setup_pages() ),
			)
		);
	}

	/** @param array<string,mixed> $submitted */
	public function apply( array $submitted ): string {
		$themes    = self::themes();
		$theme_key = $this->normalize_theme_key( (string) ( $submitted['theme'] ?? 'fashion' ), $themes );
		$theme     = $themes[ $theme_key ];
		$page_themes = array_fill_keys( array_keys( self::setup_pages() ), $theme_key );
		$primary   = sanitize_hex_color( (string) ( $submitted['primary_color'] ?? '' ) ) ?: $theme['primary'];
		$secondary = sanitize_hex_color( (string) ( $submitted['secondary_color'] ?? '' ) ) ?: $theme['soft'];
		$app_name  = sanitize_text_field( (string) ( $submitted['app_name'] ?? get_bloginfo( 'name' ) ) );
		$app_name  = '' !== $app_name ? $app_name : get_bloginfo( 'name' );
		$logo_id   = absint( $submitted['logo_id'] ?? 0 );
		$logo_url  = $logo_id ? (string) wp_get_attachment_image_url( $logo_id, 'full' ) : esc_url_raw( (string) ( $submitted['logo_url'] ?? '' ) );
		$language  = sanitize_key( (string) ( $submitted['language'] ?? ( is_rtl() ? 'ar' : 'en' ) ) );
		$direction = 'rtl' === ( $submitted['direction'] ?? '' ) ? 'rtl' : 'ltr';
		$enabled_pages = $this->sanitize_enabled_pages( $submitted['enabled_pages'] ?? null );

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
				'secondary_color' => $secondary,
				'theme'         => $theme_key,
				'page_themes'   => $page_themes,
				'enabled_pages' => $enabled_pages,
			),
			false
		);

		$this->apply_home( $theme, $primary, $secondary, $app_name, $logo_url );
		$this->apply_pages( $theme, $enabled_pages, $primary, $secondary, $app_name, $logo_url );
		$this->apply_category( $theme, in_array( 'category', $enabled_pages, true ) );
		$this->apply_extras( $theme, $theme, $primary, $app_name, $logo_url );

		update_option(
			self::STATE_OPTION,
			array(
				'completed'    => true,
				'theme'        => $theme_key,
				'page_themes'  => $page_themes,
				'enabled_pages'=> $enabled_pages,
				'completed_at' => time(),
				'source'       => 'built_in',
				'build_required' => true,
				'build_requested_at' => time(),
			),
			false
		);
		return $theme_key;
	}

	/**
	 * Converts removed page-by-page presets to the closest complete store theme.
	 *
	 * @param array<string,array<string,mixed>> $themes
	 */
	private function normalize_theme_key( string $theme_key, array $themes ): string {
		$theme_key = sanitize_key( $theme_key );
		$legacy = array(
			'aurora' => 'fashion',
			'bloom' => 'beauty',
			'canvas' => 'fashion',
			'pulse' => 'sports_fitness',
			'avenue' => 'luxury',
			'metro' => 'multi_store',
		);
		$theme_key = $legacy[ $theme_key ] ?? $theme_key;
		return isset( $themes[ $theme_key ] ) ? $theme_key : 'fashion';
	}

	/** @param array<string,mixed> $theme */
	private function build_home( array $theme, string $primary, string $secondary, string $app_name, string $logo_url ): array {
		$blocks = array();
		$slides = $this->catalog_slides( $theme );
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
					'accent_color'    => $secondary,
					'background_color'=> $theme['surface'],
					'text_color'      => $theme['ink'],
					'card_style'      => $theme['card_style'],
					'block_background'=> $theme['surface'],
					'card_radius'     => $theme['radius'],
					'border_radius'   => $theme['radius'],
				)
			);
			if ( 'app_header' === $type ) {
				$settings['title']    = $app_name;
				$settings['logo_url'] = $logo_url;
			}
			if ( 'hero_slider' === $type ) {
				$settings['items']            = $slides;
				$settings['border_radius']    = $theme['radius'];
				$settings['overlay_strength'] = $theme['overlay'];
				$settings['text_color']       = '#FFFFFF';
			}
			if ( 'category_grid' === $type ) {
				$settings['title']       = $theme['sample_copy'][1] ?? __( 'Shop by category', 'kidia-mobile-cms' );
				$settings['columns']     = 3 <= (int) $theme['product_columns'] ? 4 : 3;
				$settings['limit']       = 9;
				$settings['image_shape'] = $theme['category_shape'];
			}
			if ( 'image_banner' === $type ) {
				$settings['image_url']       = self::hero_url( $theme );
				$settings['title']           = $theme['sample_copy'][0] ?? '';
				$settings['subtitle']        = $theme['description'];
				$settings['button_label']    = __( 'Shop now', 'kidia-mobile-cms' );
				$settings['aspect_ratio']    = 1.8;
				$settings['border_radius']   = $theme['radius'];
				$settings['overlay_strength']= $theme['overlay'];
			}
			if ( 'banner_grid' === $type ) {
				$settings['title']         = $theme['sample_copy'][1] ?? '';
				$settings['layout']        = 'featured';
				$settings['columns']       = 2;
				$settings['border_radius'] = $theme['radius'];
				$settings['items']         = array();
				foreach ( array_slice( $slides, 0, 3 ) as $slide_index => $slide ) {
					$settings['items'][] = array(
						'id'           => 'setup_theme_banner_' . ( $slide_index + 1 ),
						'enabled'      => true,
						'image_url'    => (string) ( $slide['image_url'] ?? '' ),
						'title'        => (string) ( $theme['sample_copy'][ $slide_index ] ?? $slide['title'] ?? '' ),
						'subtitle'     => '',
						'button_label' => __( 'Shop now', 'kidia-mobile-cms' ),
						'action_type'  => (string) ( $slide['action_type'] ?? '' ),
						'action_value' => (string) ( $slide['action_value'] ?? '' ),
					);
				}
			}
			if ( in_array( $type, array( 'product_grid', 'product_carousel' ), true ) ) {
				$settings['title']          = $theme['sample_copy'][2] ?? __( 'Products for you', 'kidia-mobile-cms' );
				$settings['source']         = 'latest';
				$settings['columns']        = $theme['product_columns'];
				$settings['card_radius']    = $theme['radius'];
				$settings['show_price']     = true;
				$settings['show_wishlist']  = true;
				$settings['quick_add_enabled'] = true;
			}
			$block['settings'] = $settings;
			$block['name']     = $this->block_name( (string) $type, (array) $theme['sample_copy'] );
			$blocks[]          = $block;
		}
		return $blocks;
	}

	/** @param array<string,mixed> $theme */
	private function apply_home( array $theme, string $primary, string $secondary, string $app_name, string $logo_url ): void {
		( new Kidia_Mobile_Layout_Store() )->save_layout( $this->build_home( $theme, $primary, $secondary, $app_name, $logo_url ) );
	}

	/** @return array<int,array<string,mixed>> */
	private function catalog_slides( array $theme ): array {
		$copy = (array) ( $theme['sample_copy'] ?? array() );
		$slides = array(
			array(
				'id'           => 'setup_theme_hero',
				'enabled'      => true,
				'image_url'    => self::hero_url( $theme ),
				'title'        => $copy[0] ?? __( 'Discover the collection', 'kidia-mobile-cms' ),
				'subtitle'     => $theme['description'] ?? '',
				'button_label' => __( 'Shop now', 'kidia-mobile-cms' ),
				'action_type'  => '',
				'action_value' => '',
			),
		);
		if ( function_exists( 'wc_get_products' ) ) {
			foreach ( wc_get_products( array( 'status' => 'publish', 'limit' => 2, 'orderby' => 'date', 'order' => 'DESC' ) ) as $product ) {
				if ( ! is_object( $product ) || ! method_exists( $product, 'get_image_id' ) ) {
					continue;
				}
				$image_url = $product->get_image_id() ? wp_get_attachment_image_url( absint( $product->get_image_id() ), 'full' ) : '';
				if ( ! $image_url ) {
					continue;
				}
				$product_id = method_exists( $product, 'get_id' ) ? absint( $product->get_id() ) : 0;
				$slides[]   = array(
					'id'           => 'setup_product_slide_' . count( $slides ),
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
	 * Applies one coherent store theme to every page selected during setup.
	 *
	 * @param array<string,mixed> $theme Complete theme definition.
	 * @param array<int,string> $enabled_pages Pages selected during setup.
	 */
	private function apply_pages( array $theme, array $enabled_pages, string $primary, string $secondary, string $app_name, string $logo_url ): void {
		$store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$setup_page = 'size_chart' === $page ? 'product' : $page;
			$page_enabled = in_array( $setup_page, $enabled_pages, true );
			if ( ! $page_enabled ) {
				$layout = $store->get_layout( $page );
				$layout['enabled'] = false;
				$store->save_layout( $page, $layout );
				continue;
			}
			$store->save_layout( $page, $this->build_page_layout( $page, $theme, $primary, $secondary, $app_name, $logo_url ) );
		}
	}

	/**
	 * Builds one page from the selected theme without writing any option. This is
	 * shared by installation and the real Flutter preview so both stay identical.
	 *
	 * @param array<string,mixed> $theme
	 * @return array<string,mixed>
	 */
	private function build_page_layout( string $page, array $theme, string $primary, string $secondary, string $app_name, string $logo_url ): array {
		$layout = ( new Kidia_Mobile_Page_Layout_Store() )->default_layout( $page );
		$design = $this->theme_page_design( (string) ( $theme['layout_profile'] ?? 'fashion' ) );
		$layout['enabled'] = true;
		$layout['settings']['page_background_color'] = $theme['surface'];
		foreach ( array( 'header', 'footer' ) as $chrome ) {
			if ( ! isset( $layout[ $chrome ]['settings'] ) || ! is_array( $layout[ $chrome ]['settings'] ) ) {
				continue;
			}
			$layout[ $chrome ]['settings']['background_color'] = $theme['surface'];
			$layout[ $chrome ]['settings']['border_color'] = $theme['soft'];
			$layout[ $chrome ]['settings']['corner_radius'] = 'transparent' === $theme['header_style'] ? 0 : $theme['radius'];
			if ( 'header' === $chrome ) {
				$layout[ $chrome ]['settings']['icon_color'] = $theme['ink'];
				$layout[ $chrome ]['settings']['title_color'] = $theme['ink'];
				$layout[ $chrome ]['settings']['logo_text_color'] = $theme['ink'];
				$layout[ $chrome ]['settings']['style'] = $theme['header_style'];
				$layout[ $chrome ]['settings']['height'] = (int) $design['chrome']['header_height'];
				$layout[ $chrome ]['settings']['shadow'] = (string) $design['chrome']['header_shadow'];
				$layout[ $chrome ]['settings']['search_style'] = $theme['search_style'];
				$layout[ $chrome ]['settings']['search_background'] = $theme['soft'];
				$layout[ $chrome ]['settings']['search_border_color'] = $theme['soft'];
				$layout[ $chrome ]['settings']['search_radius'] = (int) $design['chrome']['search_radius'];
				$layout[ $chrome ]['settings']['logo_text'] = $app_name;
				$layout[ $chrome ]['settings']['logo_url'] = $logo_url;
			} else {
				$layout[ $chrome ]['settings']['height'] = (int) $design['chrome']['footer_height'];
				$layout[ $chrome ]['settings']['shadow'] = (string) $design['chrome']['footer_shadow'];
				$layout[ $chrome ]['settings']['active_color'] = $primary;
				$layout[ $chrome ]['settings']['button_color'] = $primary;
				$layout[ $chrome ]['settings']['button_radius'] = (int) $design['chrome']['button_radius'];
				$layout[ $chrome ]['settings']['button_shape'] = (string) $design['chrome']['button_shape'];
			}
		}
		foreach ( $layout['elements'] as &$element ) {
			if ( ! is_array( $element['settings'] ?? null ) ) {
				continue;
			}
			$element['settings']['primary_color'] = $primary;
			$element['settings']['background_color'] = $theme['surface'];
			$element['settings']['text_color'] = $theme['ink'];
			if ( array_key_exists( 'accent_color', $element['settings'] ) ) {
				$element['settings']['accent_color'] = $secondary;
			}
			if ( array_key_exists( 'card_style', $element['settings'] ) ) {
				$element['settings']['card_style'] = $theme['card_style'];
			}
			foreach ( array( 'card_radius', 'corner_radius', 'image_radius', 'button_radius', 'chip_radius' ) as $radius_key ) {
				if ( array_key_exists( $radius_key, $element['settings'] ) ) {
					$element['settings'][ $radius_key ] = $theme['radius'];
				}
			}
		}
		unset( $element );

		if ( 'catalog' === $page ) {
			$this->configure_element( $layout, 'filter_bar', array(
				'sticky' => $design['catalog']['filter_sticky'],
				'show_result_count' => $design['catalog']['show_result_count'],
				'block_height' => $design['catalog']['filter_height'],
				'button_radius' => $design['catalog']['filter_radius'],
				'background_color' => $theme['surface'],
				'icon_color' => $theme['ink'],
				'border_color' => $theme['soft'],
			) );
			$this->configure_element( $layout, 'product_grid', array(
				'columns' => $design['catalog']['columns'],
				'gap' => $design['catalog']['gap'],
				'card_style' => $design['catalog']['card_style'],
				'card_radius' => $design['catalog']['card_radius'],
				'image_ratio' => $design['catalog']['image_ratio'],
				'enable_image_swipe' => $design['catalog']['image_swipe'],
				'show_rating' => $design['catalog']['show_rating'],
				'show_badge' => $design['catalog']['show_badge'],
				'quick_add_icon_style' => $design['catalog']['quick_add_style'],
				'show_wishlist' => $design['catalog']['show_wishlist'],
				'pagination_mode' => $design['catalog']['pagination'],
				'products_per_page' => $design['catalog']['per_page'],
				'pagination_color' => $primary,
			) );
		}
		if ( 'product' === $page ) {
			$this->configure_element( $layout, 'product_tabs', array( 'sticky' => $design['product']['tabs_sticky'], 'active_color' => $primary ), $design['product']['tabs_enabled'] );
			$this->configure_element( $layout, 'image_gallery', array(
				'aspect_ratio' => $design['product']['gallery_ratio'],
				'fit' => $design['product']['gallery_fit'],
				'show_thumbnails' => $design['product']['thumbnails'],
				'show_indicators' => $design['product']['indicators'],
				'show_counter' => $design['product']['counter'],
				'enable_zoom' => $design['product']['zoom'],
				'background_color' => $theme['surface'],
			) );
			$this->configure_element( $layout, 'product_summary', array( 'show_rating' => $design['product']['show_rating'], 'show_badge' => $design['product']['show_badge'], 'price_size' => $design['product']['price_size'], 'name_size' => $design['product']['name_size'] ) );
			$this->configure_element( $layout, 'variations', array( 'style' => $design['product']['variation_style'], 'chip_radius' => $design['product']['chip_radius'] ) );
			$this->configure_element( $layout, 'description', array( 'accordion' => $design['product']['accordion'] ) );
			$this->configure_element( $layout, 'reviews', array(), $design['product']['reviews_enabled'] );
			$this->configure_element( $layout, 'related_products', array( 'columns' => $design['product']['related_columns'], 'gap' => $design['product']['related_gap'], 'image_ratio' => $design['product']['related_ratio'] ) );
			$layout['footer']['settings']['button_width_percent'] = $design['product']['button_width'];
			$layout['footer']['settings']['button_height'] = $design['product']['button_height'];
		}
		if ( 'wishlist' === $page ) {
			$layout['settings']['wishlist_access_mode'] = $design['wishlist']['access'];
			foreach ( array( 'sign_in_state', 'empty_state' ) as $state_id ) {
				$this->configure_element( $layout, $state_id, array( 'button_style' => $design['wishlist']['button_style'], 'button_radius' => $design['wishlist']['button_radius'], 'top_spacing' => $design['wishlist']['top_spacing'] ) );
			}
			foreach ( array( 'sign_in_recommendations', 'empty_recommendations', 'products_recommendations' ) as $recommendation_id ) {
				$this->configure_element( $layout, $recommendation_id, array( 'layout_style' => $design['wishlist']['recommendation_layout'], 'columns' => $design['wishlist']['columns'], 'card_radius' => $design['wishlist']['card_radius'] ) );
			}
			$this->configure_element( $layout, 'wishlist_grid', array(
				'columns' => $design['wishlist']['columns'],
				'gap' => $design['wishlist']['gap'],
				'card_style' => $design['wishlist']['card_style'],
				'card_radius' => $design['wishlist']['card_radius'],
				'image_ratio' => $design['wishlist']['image_ratio'],
				'show_name' => $design['wishlist']['show_name'],
				'show_wishlist' => true,
			) );
		}
		if ( 'account' === $page ) {
			$this->configure_element( $layout, 'account_summary', array( 'avatar_size' => $design['account']['avatar_size'], 'card_style' => $design['account']['summary_style'], 'background_color' => $theme['surface'] ) );
			$this->configure_element( $layout, 'account_menu', array( 'show_addresses' => $design['account']['show_addresses'], 'show_support' => $design['account']['show_support'] ) );
			$this->configure_element( $layout, 'logout_button', array( 'background_color' => $theme['surface'] ), $design['account']['show_logout'] );
		}
		if ( 'size_chart' === $page ) {
			$this->configure_element( $layout, 'size_chart_content', array( 'layout_style' => $design['product']['size_chart'], 'row_color' => $theme['soft'], 'text_color' => $theme['ink'], 'accent_color' => $primary ) );
		}
		return $layout;
	}

	/**
	 * @param array<string,mixed> $layout
	 * @param array<string,mixed> $settings
	 */
	private function configure_element( array &$layout, string $id, array $settings, ?bool $enabled = null ): void {
		foreach ( $layout['elements'] as &$element ) {
			if ( $id !== (string) ( $element['id'] ?? '' ) ) {
				continue;
			}
			$element['settings'] = array_merge( (array) ( $element['settings'] ?? array() ), $settings );
			if ( null !== $enabled ) {
				$element['enabled'] = $enabled;
			}
			break;
		}
		unset( $element );
	}

	/** @return array<string,array<string,mixed>> */
	private function theme_page_design( string $profile ): array {
		$base = array(
			'chrome' => array( 'header_height' => 72, 'header_shadow' => 'subtle', 'search_radius' => 14, 'footer_height' => 64, 'footer_shadow' => 'subtle', 'button_radius' => 16, 'button_shape' => 'custom' ),
			'catalog' => array( 'filter_sticky' => true, 'show_result_count' => false, 'filter_height' => 56, 'filter_radius' => 12, 'columns' => 2, 'gap' => 12, 'card_style' => 'outlined', 'card_radius' => 14, 'image_ratio' => 1, 'image_swipe' => false, 'show_rating' => true, 'show_badge' => true, 'quick_add_style' => 'outline', 'show_wishlist' => true, 'pagination' => 'load_more', 'per_page' => 12 ),
			'product' => array( 'tabs_enabled' => true, 'tabs_sticky' => true, 'gallery_ratio' => .75, 'gallery_fit' => 'contain', 'thumbnails' => false, 'indicators' => false, 'counter' => true, 'zoom' => false, 'show_rating' => true, 'show_badge' => false, 'price_size' => 25, 'name_size' => 18, 'variation_style' => 'chips', 'chip_radius' => 18, 'accordion' => true, 'reviews_enabled' => true, 'related_columns' => 2, 'related_gap' => 8, 'related_ratio' => .82, 'button_width' => 62, 'button_height' => 56, 'size_chart' => 'list' ),
			'wishlist' => array( 'access' => 'sign_in_required', 'button_style' => 'outline', 'button_radius' => 22, 'top_spacing' => 52, 'recommendation_layout' => 'grid', 'columns' => 2, 'gap' => 8, 'card_style' => 'minimal', 'card_radius' => 8, 'image_ratio' => .82, 'show_name' => false ),
			'account' => array( 'avatar_size' => 66, 'summary_style' => 'elevated', 'show_addresses' => true, 'show_support' => true, 'show_logout' => true ),
		);
		$profiles = array(
			'fashion' => array(
				'chrome' => array( 'header_height' => 84, 'header_shadow' => 'none', 'search_radius' => 2, 'footer_height' => 70, 'footer_shadow' => 'none', 'button_radius' => 2, 'button_shape' => 'rectangle' ),
				'catalog' => array( 'filter_sticky' => false, 'filter_height' => 48, 'filter_radius' => 2, 'gap' => 20, 'card_style' => 'no_shadow', 'card_radius' => 2, 'image_ratio' => 1.35, 'show_rating' => false, 'pagination' => 'numbers', 'per_page' => 10 ),
				'product' => array( 'tabs_sticky' => false, 'gallery_ratio' => 1.2, 'gallery_fit' => 'cover', 'indicators' => true, 'counter' => false, 'price_size' => 22, 'name_size' => 22, 'chip_radius' => 2, 'accordion' => false, 'related_gap' => 20, 'related_ratio' => 1.3, 'button_width' => 72, 'button_height' => 52, 'size_chart' => 'table' ),
				'wishlist' => array( 'button_radius' => 2, 'top_spacing' => 72, 'recommendation_layout' => 'carousel', 'gap' => 18, 'card_style' => 'no_shadow', 'card_radius' => 2, 'image_ratio' => 1.25, 'show_name' => true ),
				'account' => array( 'avatar_size' => 58, 'summary_style' => 'minimal', 'show_support' => false ),
			),
			'beauty' => array(
				'chrome' => array( 'header_height' => 76, 'search_radius' => 24, 'footer_height' => 68, 'button_radius' => 28, 'button_shape' => 'pill' ),
				'catalog' => array( 'filter_radius' => 22, 'card_style' => 'elevated', 'card_radius' => 20, 'image_ratio' => 1, 'quick_add_style' => 'rounded', 'pagination' => 'automatic' ),
				'product' => array( 'gallery_ratio' => 1, 'indicators' => true, 'zoom' => true, 'show_badge' => true, 'chip_radius' => 24, 'related_gap' => 12, 'related_ratio' => 1, 'button_width' => 68 ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 28, 'top_spacing' => 44, 'card_style' => 'elevated', 'card_radius' => 20, 'image_ratio' => 1, 'show_name' => true ),
				'account' => array( 'avatar_size' => 82, 'summary_style' => 'elevated' ),
			),
			'electronics' => array(
				'chrome' => array( 'header_height' => 68, 'header_shadow' => 'strong', 'search_radius' => 10, 'footer_height' => 60, 'button_radius' => 10 ),
				'catalog' => array( 'show_result_count' => true, 'filter_height' => 52, 'filter_radius' => 8, 'columns' => 2, 'gap' => 10, 'card_radius' => 10, 'image_ratio' => .9, 'image_swipe' => true, 'quick_add_style' => 'filled', 'pagination' => 'load_more', 'per_page' => 16 ),
				'product' => array( 'gallery_ratio' => .85, 'thumbnails' => true, 'counter' => true, 'zoom' => true, 'show_badge' => true, 'variation_style' => 'dropdown', 'accordion' => true, 'related_gap' => 10, 'button_width' => 64, 'button_height' => 58 ),
				'wishlist' => array( 'button_radius' => 10, 'top_spacing' => 36, 'recommendation_layout' => 'compact', 'gap' => 10, 'card_style' => 'outlined', 'card_radius' => 10, 'show_name' => true ),
				'account' => array( 'avatar_size' => 64, 'summary_style' => 'outlined' ),
			),
			'home_living' => array(
				'chrome' => array( 'header_height' => 88, 'header_shadow' => 'none', 'search_radius' => 6, 'footer_height' => 72, 'footer_shadow' => 'none', 'button_radius' => 6 ),
				'catalog' => array( 'filter_sticky' => false, 'filter_radius' => 6, 'gap' => 18, 'card_style' => 'no_shadow', 'card_radius' => 6, 'image_ratio' => 1.2, 'show_rating' => false, 'show_badge' => false, 'pagination' => 'numbers', 'per_page' => 8 ),
				'product' => array( 'tabs_enabled' => false, 'gallery_ratio' => 1.15, 'gallery_fit' => 'cover', 'thumbnails' => true, 'counter' => false, 'show_rating' => false, 'name_size' => 21, 'chip_radius' => 6, 'accordion' => false, 'reviews_enabled' => false, 'related_gap' => 18, 'related_ratio' => 1.15, 'button_width' => 76, 'size_chart' => 'table' ),
				'wishlist' => array( 'button_radius' => 6, 'top_spacing' => 64, 'recommendation_layout' => 'carousel', 'gap' => 16, 'card_style' => 'no_shadow', 'card_radius' => 6, 'image_ratio' => 1.15, 'show_name' => true ),
				'account' => array( 'avatar_size' => 72, 'summary_style' => 'no_shadow', 'show_support' => false ),
			),
			'kids_baby' => array(
				'chrome' => array( 'header_height' => 80, 'search_radius' => 26, 'footer_height' => 72, 'button_radius' => 30, 'button_shape' => 'pill' ),
				'catalog' => array( 'filter_radius' => 24, 'gap' => 14, 'card_style' => 'elevated', 'card_radius' => 22, 'image_ratio' => 1, 'quick_add_style' => 'rounded', 'show_rating' => false, 'pagination' => 'automatic' ),
				'product' => array( 'gallery_ratio' => 1, 'indicators' => true, 'counter' => false, 'show_rating' => false, 'show_badge' => true, 'name_size' => 20, 'chip_radius' => 24, 'related_gap' => 14, 'related_ratio' => 1, 'button_width' => 70, 'button_height' => 60, 'size_chart' => 'chips' ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 30, 'top_spacing' => 34, 'recommendation_layout' => 'grid', 'gap' => 12, 'card_style' => 'elevated', 'card_radius' => 22, 'image_ratio' => 1, 'show_name' => true ),
				'account' => array( 'avatar_size' => 88, 'summary_style' => 'elevated' ),
			),
			'sports_fitness' => array(
				'chrome' => array( 'header_height' => 66, 'header_shadow' => 'strong', 'search_radius' => 4, 'footer_height' => 58, 'button_radius' => 4, 'button_shape' => 'rectangle' ),
				'catalog' => array( 'show_result_count' => true, 'filter_height' => 50, 'filter_radius' => 4, 'gap' => 8, 'card_style' => 'outlined', 'card_radius' => 4, 'image_ratio' => 1.1, 'image_swipe' => true, 'quick_add_style' => 'filled', 'pagination' => 'automatic', 'per_page' => 18 ),
				'product' => array( 'gallery_ratio' => 1.1, 'gallery_fit' => 'cover', 'indicators' => true, 'counter' => false, 'show_badge' => true, 'price_size' => 27, 'name_size' => 20, 'chip_radius' => 4, 'related_gap' => 8, 'related_ratio' => 1.1, 'button_width' => 70, 'button_height' => 60 ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 4, 'top_spacing' => 32, 'recommendation_layout' => 'compact', 'gap' => 8, 'card_style' => 'outlined', 'card_radius' => 4, 'image_ratio' => 1.1, 'show_name' => true ),
				'account' => array( 'avatar_size' => 60, 'summary_style' => 'outlined', 'show_addresses' => false ),
			),
			'grocery' => array(
				'chrome' => array( 'header_height' => 74, 'search_radius' => 16, 'footer_height' => 62, 'button_radius' => 14 ),
				'catalog' => array( 'show_result_count' => true, 'filter_height' => 48, 'filter_radius' => 14, 'columns' => 3, 'gap' => 8, 'card_style' => 'elevated', 'card_radius' => 14, 'image_ratio' => .86, 'show_rating' => false, 'quick_add_style' => 'filled', 'pagination' => 'automatic', 'per_page' => 24 ),
				'product' => array( 'tabs_enabled' => false, 'gallery_ratio' => .9, 'counter' => true, 'show_rating' => false, 'price_size' => 28, 'variation_style' => 'dropdown', 'accordion' => true, 'reviews_enabled' => false, 'related_columns' => 3, 'related_gap' => 8, 'related_ratio' => .88, 'button_width' => 66 ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 14, 'top_spacing' => 30, 'recommendation_layout' => 'compact', 'columns' => 3, 'gap' => 8, 'card_style' => 'elevated', 'card_radius' => 14, 'image_ratio' => .86 ),
				'account' => array( 'avatar_size' => 62, 'summary_style' => 'elevated' ),
			),
			'luxury' => array(
				'chrome' => array( 'header_height' => 92, 'header_shadow' => 'none', 'search_radius' => 0, 'footer_height' => 76, 'footer_shadow' => 'none', 'button_radius' => 0, 'button_shape' => 'rectangle' ),
				'catalog' => array( 'filter_sticky' => false, 'filter_height' => 48, 'filter_radius' => 0, 'gap' => 24, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.45, 'show_rating' => false, 'show_badge' => false, 'quick_add_style' => 'outline', 'pagination' => 'numbers', 'per_page' => 8 ),
				'product' => array( 'tabs_enabled' => false, 'gallery_ratio' => 1.35, 'gallery_fit' => 'cover', 'thumbnails' => false, 'indicators' => false, 'counter' => false, 'show_rating' => false, 'price_size' => 24, 'name_size' => 24, 'chip_radius' => 0, 'accordion' => false, 'reviews_enabled' => false, 'related_gap' => 24, 'related_ratio' => 1.4, 'button_width' => 80, 'button_height' => 50, 'size_chart' => 'table' ),
				'wishlist' => array( 'button_radius' => 0, 'top_spacing' => 86, 'recommendation_layout' => 'carousel', 'gap' => 24, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.4, 'show_name' => true ),
				'account' => array( 'avatar_size' => 54, 'summary_style' => 'minimal', 'show_support' => false ),
			),
			'coffee' => array(
				'chrome' => array( 'header_height' => 86, 'header_shadow' => 'none', 'search_radius' => 18, 'footer_height' => 70, 'button_radius' => 18 ),
				'catalog' => array( 'filter_sticky' => false, 'filter_radius' => 18, 'gap' => 16, 'card_style' => 'elevated', 'card_radius' => 16, 'image_ratio' => 1.08, 'show_rating' => true, 'show_badge' => false, 'pagination' => 'load_more', 'per_page' => 10 ),
				'product' => array( 'tabs_sticky' => false, 'gallery_ratio' => 1.08, 'gallery_fit' => 'cover', 'indicators' => true, 'counter' => false, 'show_rating' => true, 'name_size' => 21, 'chip_radius' => 18, 'accordion' => false, 'related_gap' => 16, 'related_ratio' => 1.08, 'button_width' => 72 ),
				'wishlist' => array( 'button_radius' => 18, 'top_spacing' => 58, 'recommendation_layout' => 'carousel', 'gap' => 16, 'card_style' => 'elevated', 'card_radius' => 16, 'image_ratio' => 1.08, 'show_name' => true ),
				'account' => array( 'avatar_size' => 76, 'summary_style' => 'no_shadow' ),
			),
			'multi_store' => array(
				'chrome' => array( 'header_height' => 70, 'header_shadow' => 'subtle', 'search_radius' => 12, 'footer_height' => 60, 'button_radius' => 12 ),
				'catalog' => array( 'show_result_count' => true, 'filter_height' => 50, 'filter_radius' => 10, 'columns' => 3, 'gap' => 8, 'card_style' => 'outlined', 'card_radius' => 10, 'image_ratio' => .9, 'image_swipe' => true, 'quick_add_style' => 'filled', 'pagination' => 'automatic', 'per_page' => 24 ),
				'product' => array( 'tabs_sticky' => true, 'gallery_ratio' => .9, 'thumbnails' => true, 'counter' => true, 'zoom' => true, 'show_badge' => true, 'variation_style' => 'dropdown', 'related_columns' => 3, 'related_gap' => 8, 'related_ratio' => .9, 'button_width' => 64 ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 12, 'top_spacing' => 28, 'recommendation_layout' => 'compact', 'columns' => 3, 'gap' => 8, 'card_style' => 'outlined', 'card_radius' => 10, 'image_ratio' => .9, 'show_name' => true ),
				'account' => array( 'avatar_size' => 64, 'summary_style' => 'outlined' ),
			),
		);
		return array_replace_recursive( $base, $profiles[ $profile ] ?? $profiles['fashion'] );
	}

	/** @param array<string,mixed> $theme */
	private function apply_category( array $theme, bool $enabled ): void {
		$store    = new Kidia_Mobile_Category_Page_Store();
		$current  = $store->get_settings();
		if ( ! $enabled ) {
			$current['enabled'] = false;
			$store->save_settings( $current );
			return;
		}
		$store->save_settings( $this->build_category_settings( $theme, $current ) );
	}

	/**
	 * @param array<string,mixed> $theme
	 * @param array<string,mixed> $current
	 * @return array<string,mixed>
	 */
	private function build_category_settings( array $theme, array $current ): array {
		$general = array_merge(
			$current['general'],
			array(
				'category_layout'         => $theme['category_layout'],
				'grid_columns'            => 3 <= (int) $theme['product_columns'] ? 4 : 3,
				'card_style'              => $theme['card_style'],
				'card_radius'             => $theme['radius'],
				'card_background_color'   => $theme['surface'],
				'page_background_color'   => $theme['surface'],
				'element_background_color'=> $theme['surface'],
				'image_shape'             => $theme['category_shape'],
				'image_radius'            => $theme['radius'],
				'font_color'              => $theme['ink'],
				'border_color'            => $theme['soft'],
			)
		);
		return array( 'enabled' => true, 'general' => $general, 'categories' => $current['categories'] );
	}

	/**
	 * Keeps required commerce pages enabled and accepts only known optional pages.
	 *
	 * @param mixed $submitted Raw enabled page map from the setup form.
	 * @return array<int,string>
	 */
	private function sanitize_enabled_pages( $submitted ): array {
		$pages = self::setup_pages();
		if ( ! is_array( $submitted ) ) {
			return array_keys( $pages );
		}
		$enabled = array();
		foreach ( $pages as $page => $details ) {
			if ( ! empty( $details['required'] ) || ! empty( $submitted[ $page ] ) ) {
				$enabled[] = $page;
			}
		}
		return $enabled;
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
		$backup = $this->current_snapshot();
		$backup['created_at'] = time();
		update_option( self::BACKUP_OPTION, $backup, false );
	}

	/** @return array<string,mixed> */
	private function current_snapshot(): array {
		$backup = array(
			'created_at' => time(),
			'home'       => ( new Kidia_Mobile_Layout_Store() )->get_layout(),
			'pages'      => array(),
			'category'   => ( new Kidia_Mobile_Category_Page_Store() )->get_settings(),
			'splash'     => get_option( 'kidia_mobile_splash_screen', array() ),
			'checkout'   => get_option( 'kidia_mobile_checkout_suggestions', array() ),
			'checkout_fields' => get_option( Kidia_Mobile_Checkout_Fields_Store::OPTION, array() ),
			'identity'   => get_option( self::IDENTITY_OPTION, array() ),
		);
		$page_store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$backup['pages'][ $page ] = $page_store->get_layout( $page );
		}
		return $backup;
	}

	/** @param array<string,mixed> $snapshot */
	private function restore_snapshot( array $snapshot, string $source ): void {
		$this->create_backup();
		( new Kidia_Mobile_Layout_Store() )->save_layout( is_array( $snapshot['home'] ?? null ) ? $snapshot['home'] : array() );
		$page_store = new Kidia_Mobile_Page_Layout_Store();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			if ( is_array( $snapshot['pages'][ $page ] ?? null ) ) {
				$page_store->save_layout( $page, $snapshot['pages'][ $page ] );
			}
		}
		if ( is_array( $snapshot['category'] ?? null ) ) {
			( new Kidia_Mobile_Category_Page_Store() )->save_settings( $snapshot['category'] );
		}
		foreach ( array( 'splash' => 'kidia_mobile_splash_screen', 'checkout' => 'kidia_mobile_checkout_suggestions', 'checkout_fields' => Kidia_Mobile_Checkout_Fields_Store::OPTION, 'identity' => self::IDENTITY_OPTION ) as $key => $option ) {
			if ( is_array( $snapshot[ $key ] ?? null ) ) {
				update_option( $option, $snapshot[ $key ], false );
			}
		}
		update_option( self::STATE_OPTION, array(
			'completed' => true,
			'completed_at' => time(),
			'source' => $source,
			'build_required' => true,
			'build_requested_at' => time(),
		), false );
	}

	/** @param array<string,mixed> $snapshot @return array<string,mixed> */
	private function sanitize_snapshot( array $snapshot ): array {
		if ( isset( $snapshot['category']['categories'] ) && is_array( $snapshot['category']['categories'] ) ) {
			foreach ( $snapshot['category']['categories'] as &$category ) {
				if ( is_array( $category ) ) {
					$category['image_id'] = 0;
					$category['image_url'] = '';
				}
			}
			unset( $category );
		}
		$snapshot['home'] = $this->strip_catalog_images( $snapshot['home'] ?? array() );
		if ( isset( $snapshot['pages'] ) && is_array( $snapshot['pages'] ) ) {
			foreach ( $snapshot['pages'] as $page => $layout ) {
				$snapshot['pages'][ $page ] = $this->strip_catalog_images( $layout );
			}
		}
		return $snapshot;
	}

	/** @param mixed $value @return mixed */
	private function strip_catalog_images( $value, bool $catalog_context = false ) {
		if ( ! is_array( $value ) ) {
			return $value;
		}
		$type = strtolower( (string) ( $value['type'] ?? $value['source'] ?? '' ) );
		$catalog_context = $catalog_context || false !== strpos( $type, 'product' ) || false !== strpos( $type, 'category' );
		foreach ( $value as $key => $item ) {
			if ( $catalog_context && in_array( (string) $key, array( 'image_id', 'image_url', 'thumbnail', 'thumbnail_url', 'attachment_id' ), true ) ) {
				$value[ $key ] = is_int( $item ) ? 0 : '';
				continue;
			}
			$value[ $key ] = $this->strip_catalog_images( $item, $catalog_context || in_array( (string) $key, array( 'products', 'categories' ), true ) );
		}
		return $value;
	}

	/**
	 * Finds actual design artwork retained in a saved theme snapshot.
	 *
	 * @param mixed             $value Snapshot node.
	 * @param array<int,string> $image_urls Collected image URLs.
	 */
	private function collect_preview_image_urls( $value, array &$image_urls ): void {
		if ( ! is_array( $value ) || count( $image_urls ) >= 5 ) {
			return;
		}
		foreach ( $value as $key => $item ) {
			if ( count( $image_urls ) >= 5 ) {
				break;
			}
			if (
				is_string( $item )
				&& in_array( (string) $key, array( 'image_url', 'mobile_image_url', 'desktop_image_url', 'background_image', 'thumbnail_url' ), true )
			) {
				$image_url = esc_url_raw( $item );
				if ( '' !== $image_url ) {
					$image_urls[] = $image_url;
				}
				continue;
			}
			$this->collect_preview_image_urls( $item, $image_urls );
		}
	}
}
