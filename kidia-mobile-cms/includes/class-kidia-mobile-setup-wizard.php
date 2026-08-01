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
					'card_style' => 'no_shadow', 'asset_dir' => 'fashion', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
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
					'card_style' => 'elevated', 'asset_dir' => 'beauty', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
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
					'card_style' => 'outlined', 'asset_dir' => 'electronics', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
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
					'card_style' => 'no_shadow', 'asset_dir' => 'home_living', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
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
					'card_style' => 'elevated', 'asset_dir' => 'kids_baby', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
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
					'card_style' => 'outlined', 'asset_dir' => 'sports_fitness', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
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
					'card_style' => 'elevated', 'asset_dir' => 'grocery', 'category_layout' => 'compact_grid', 'category_shape' => 'circle',
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
					'card_style' => 'no_shadow', 'asset_dir' => 'luxury', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
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
					'card_style' => 'elevated', 'asset_dir' => 'coffee', 'category_layout' => 'visual_grid', 'category_shape' => 'circle',
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
					'card_style' => 'outlined', 'asset_dir' => 'multi_store', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'multi_store',
					'product_columns' => 3, 'radius' => 12, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 12,
					'blocks' => array( 'quick_links', 'hero_slider', 'promo_strip', 'category_grid', 'countdown', 'product_grid', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Everything in one place', 'kidia-mobile-cms' ), __( 'Browse departments', 'kidia-mobile-cms' ), __( 'Best value today', 'kidia-mobile-cms' ) ),
				)
			),
			'jewelry' => self::theme(
				__( 'Jewelry Atelier', 'kidia-mobile-cms' ),
				__( 'A luminous jewelry boutique with editorial collections, fine-detail product cards and elegant gifting.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#9A6A38', 'soft' => '#F5EBDD', 'ink' => '#2B2118', 'surface' => '#FFFDFC',
					'card_style' => 'no_shadow', 'asset_dir' => 'jewelry', 'category_layout' => 'visual_grid', 'category_shape' => 'circle',
					'layout_profile' => 'jewelry',
					'product_columns' => 2, 'radius' => 12, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 28,
					'blocks' => array( 'hero_slider', 'quick_links', 'text_block', 'category_grid', 'product_carousel', 'banner_grid', 'product_grid' ),
					'sample_copy' => array( __( 'Made to be remembered', 'kidia-mobile-cms' ), __( 'Shop fine collections', 'kidia-mobile-cms' ), __( 'New signatures', 'kidia-mobile-cms' ) ),
				)
			),
			'pet_care' => self::theme(
				__( 'Pet Care', 'kidia-mobile-cms' ),
				__( 'A friendly pet store with playful navigation, practical product discovery and warm lifestyle imagery.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#168578', 'soft' => '#E6F6F2', 'ink' => '#203A36', 'surface' => '#FBFEFD',
					'card_style' => 'elevated', 'asset_dir' => 'pet_care', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'pet_care',
					'product_columns' => 2, 'radius' => 18, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 20,
					'blocks' => array( 'hero_slider', 'quick_links', 'category_grid', 'promo_strip', 'product_carousel', 'image_banner', 'product_grid' ),
					'sample_copy' => array( __( 'Better days for every pet', 'kidia-mobile-cms' ), __( 'Shop by companion', 'kidia-mobile-cms' ), __( 'Pet parent favorites', 'kidia-mobile-cms' ) ),
				)
			),
			'family_pop' => self::theme(
				__( 'Family Pop', 'kidia-mobile-cms' ),
				__( 'A bright family-fashion storefront with quick circular discovery, friendly promotions and clean product-first shopping.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#F04F5F', 'soft' => '#E5F6F2', 'ink' => '#151515', 'surface' => '#FFFFFF',
					'card_style' => 'no_shadow', 'asset_dir' => 'family_pop', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'family_pop',
					'product_columns' => 2, 'radius' => 18, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 18,
					'blocks' => array( 'quick_links', 'hero_slider', 'category_grid', 'promo_strip', 'product_carousel', 'banner_grid', 'product_grid' ),
					'sample_copy' => array( __( 'Made for every family moment', 'kidia-mobile-cms' ), __( 'Shop by age', 'kidia-mobile-cms' ), __( 'Family favorites', 'kidia-mobile-cms' ) ),
					'home_design' => array(
						'hero_ratio' => 1.0, 'hero_radius' => 12, 'hero_padding' => 16, 'hero_indicators' => 'image_bottom',
						'category_layout' => 'grid', 'category_columns' => 3, 'category_size' => 64, 'category_gap' => 12,
						'quick_layout' => 'carousel', 'quick_columns' => 4, 'quick_size' => 64, 'quick_gap' => 12,
						'product_columns' => 2, 'product_ratio' => 1.1, 'product_radius' => 0, 'product_style' => 'minimal',
						'product_rating' => false, 'product_badge' => true, 'product_swipe' => true, 'product_quick_add' => true, 'product_wishlist' => true,
						'banner_layout' => 'featured', 'banner_ratio' => 1.33, 'banner_gap' => 10, 'image_banner_ratio' => 1.33,
					),
					'category_design' => array(
						'navigation_mode' => 'separate_page', 'card_gap' => 0, 'card_height' => 104, 'card_style' => 'no_shadow',
						'card_radius' => 0, 'image_size' => 64, 'image_shape' => 'circle', 'image_radius' => 32,
						'image_text_gap' => 16, 'font_size' => 16, 'font_weight' => 600, 'line_height' => 125,
						'text_align' => 'start', 'show_arrow' => true, 'arrow_size' => 24, 'horizontal_padding' => 16,
					),
				)
			),
			'marketplace_plus' => self::theme(
				__( 'Marketplace Plus', 'kidia-mobile-cms' ),
				__( 'A dense all-departments marketplace with persistent search, deal-led grids, compact navigation and information-rich products.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#F59B23', 'soft' => '#E7F3F5', 'ink' => '#132536', 'surface' => '#F5F6F6',
					'card_style' => 'outlined', 'asset_dir' => 'marketplace_plus', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'marketplace_plus',
					'product_columns' => 3, 'radius' => 8, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 8,
					'blocks' => array( 'quick_links', 'promo_strip', 'hero_slider', 'category_grid', 'countdown', 'product_grid', 'banner_grid', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Everything you need, one place', 'kidia-mobile-cms' ), __( 'Browse departments', 'kidia-mobile-cms' ), __( 'Deals for you', 'kidia-mobile-cms' ) ),
					'home_design' => array(
						'hero_ratio' => 2.35, 'hero_radius' => 6, 'hero_padding' => 8, 'hero_indicators' => 'image_bottom',
						'category_layout' => 'compact', 'category_columns' => 5, 'category_size' => 66, 'category_gap' => 7,
						'quick_layout' => 'grid', 'quick_columns' => 5, 'quick_size' => 64, 'quick_gap' => 7,
						'product_columns' => 3, 'product_ratio' => 0.88, 'product_radius' => 6, 'product_style' => 'outlined',
						'product_rating' => true, 'product_badge' => true, 'product_swipe' => true, 'product_quick_add' => true, 'product_wishlist' => false,
						'banner_layout' => 'equal', 'banner_ratio' => 1.15, 'banner_gap' => 7, 'image_banner_ratio' => 1.15,
					),
				)
			),
			'studio_fashion' => self::theme(
				__( 'Studio Fashion', 'kidia-mobile-cms' ),
				__( 'A minimal editorial fashion shop with quiet navigation, full-width campaigns and clean garment-led product grids.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#C4142B', 'soft' => '#F1F0EE', 'ink' => '#111111', 'surface' => '#FAF9F7',
					'card_style' => 'no_shadow', 'asset_dir' => 'studio_fashion', 'category_layout' => 'default', 'category_shape' => 'rounded',
					'layout_profile' => 'studio_fashion',
					'product_columns' => 2, 'radius' => 0, 'header_style' => 'standard', 'search_style' => 'icon', 'overlay' => 10,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'banner_grid', 'product_grid', 'image_banner', 'product_carousel' ),
					'sample_copy' => array( __( 'The new edit', 'kidia-mobile-cms' ), __( 'Shop by collection', 'kidia-mobile-cms' ), __( 'New arrivals', 'kidia-mobile-cms' ) ),
					'home_design' => array(
						'hero_ratio' => 1.18, 'hero_radius' => 0, 'hero_padding' => 0, 'hero_indicators' => 'image_bottom', 'hero_show_indicators' => true,
						'category_layout' => 'editorial_mosaic', 'category_columns' => 2, 'category_size' => 118, 'category_gap' => 2,
						'quick_layout' => 'grid', 'quick_columns' => 4, 'quick_size' => 72, 'quick_gap' => 4,
						'product_columns' => 2, 'product_ratio' => 1.35, 'product_radius' => 0, 'product_style' => 'minimal',
						'product_rating' => false, 'product_badge' => false, 'product_swipe' => true, 'product_quick_add' => true, 'product_wishlist' => true,
						'banner_layout' => 'mosaic', 'banner_ratio' => 1.35, 'banner_gap' => 2, 'image_banner_ratio' => 1.35,
						'text_alignment' => 'center', 'text_title_size' => 26, 'text_content_size' => 14, 'text_weight' => 'bold',
					),
					'category_design' => array(
						'navigation_mode' => 'separate_page', 'card_gap' => 0, 'card_height' => 58, 'card_style' => 'no_shadow',
						'image_size' => 32, 'image_text_gap' => 12, 'font_size' => 17, 'font_weight' => 500, 'show_arrow' => true,
					),
				)
			),
			'editorial_runway' => self::theme(
				__( 'Editorial Runway', 'kidia-mobile-cms' ),
				__( 'An immersive high-fashion gallery with full-bleed campaigns, near-invisible chrome and spacious monochrome commerce pages.', 'kidia-mobile-cms' ),
				array(
					'primary' => '#111111', 'soft' => '#EDEAE4', 'ink' => '#080808', 'surface' => '#FFFFFF',
					'card_style' => 'no_shadow', 'asset_dir' => 'editorial_runway', 'category_layout' => 'visual_grid', 'category_shape' => 'square',
					'layout_profile' => 'editorial_runway',
					'product_columns' => 2, 'radius' => 0, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 4,
					'blocks' => array( 'hero_slider', 'image_banner', 'category_grid', 'banner_grid', 'text_block', 'product_carousel' ),
					'sample_copy' => array( __( 'The collection', 'kidia-mobile-cms' ), __( 'Stories', 'kidia-mobile-cms' ), __( 'Selected pieces', 'kidia-mobile-cms' ) ),
					'home_design' => array(
						'hero_ratio' => 0.78, 'hero_radius' => 0, 'hero_padding' => 0, 'hero_indicators' => 'image_bottom', 'hero_show_indicators' => false,
						'category_layout' => 'full_width_banners', 'category_columns' => 2, 'category_size' => 140, 'category_gap' => 0,
						'quick_layout' => 'carousel', 'quick_columns' => 3, 'quick_size' => 96, 'quick_gap' => 0,
						'product_columns' => 2, 'product_ratio' => 1.5, 'product_radius' => 0, 'product_style' => 'minimal',
						'product_rating' => false, 'product_badge' => false, 'product_swipe' => true, 'product_quick_add' => false, 'product_wishlist' => true,
						'banner_layout' => 'equal', 'banner_ratio' => 0.82, 'banner_gap' => 0, 'image_banner_ratio' => 0.82,
						'text_alignment' => 'center', 'text_title_size' => 30, 'text_content_size' => 14, 'text_weight' => 'medium',
					),
					'category_design' => array(
						'navigation_mode' => 'separate_page', 'grid_columns' => 2, 'card_gap' => 0, 'card_width_percent' => 100,
						'card_style' => 'no_shadow', 'image_size' => 118, 'image_text_gap' => 8, 'font_size' => 14, 'font_weight' => 500,
						'text_align' => 'center', 'show_arrow' => false,
					),
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

	/** Returns the business-specific hero of each built-in storefront. */
	private function signature_feature( string $profile ): array {
		$features = array(
			'fashion'          => array( 'type' => 'banner_grid', 'title' => __( 'The runway edit', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'mosaic', 'columns' => 2, 'gap' => 2 ) ),
			'beauty'           => array( 'type' => 'quick_links', 'title' => __( 'Shop by skin concern', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'grid', 'columns' => 4, 'item_size' => 70 ) ),
			'electronics'      => array( 'type' => 'countdown', 'title' => __( 'Tech deal drop', 'kidia-mobile-cms' ), 'settings' => array( 'layout_style' => 'flip_clock', 'show_seconds' => true ) ),
			'home_living'      => array( 'type' => 'text_block', 'title' => __( 'Shop the room', 'kidia-mobile-cms' ), 'settings' => array( 'alignment' => 'left', 'title_size' => 30 ) ),
			'kids_baby'        => array( 'type' => 'quick_links', 'title' => __( 'Shop by age', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'carousel', 'columns' => 5, 'item_size' => 72 ) ),
			'sports_fitness'   => array( 'type' => 'countdown', 'title' => __( 'Next performance drop', 'kidia-mobile-cms' ), 'settings' => array( 'layout_style' => 'minimal_inline', 'show_seconds' => true ) ),
			'grocery'          => array( 'type' => 'promo_strip', 'title' => __( 'Fresh today', 'kidia-mobile-cms' ), 'settings' => array( 'enable_transition' => true, 'transition_effect' => 'slide_left', 'height' => 34 ) ),
			'luxury'           => array( 'type' => 'image_banner', 'title' => __( 'The private collection', 'kidia-mobile-cms' ), 'settings' => array( 'aspect_ratio' => .82, 'border_radius' => 0 ) ),
			'coffee'           => array( 'type' => 'text_block', 'title' => __( 'Meet the roast', 'kidia-mobile-cms' ), 'settings' => array( 'alignment' => 'center', 'title_size' => 28 ) ),
			'multi_store'      => array( 'type' => 'quick_links', 'title' => __( 'Browse every department', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'grid', 'columns' => 5, 'item_size' => 62 ) ),
			'jewelry'          => array( 'type' => 'text_block', 'title' => __( 'Find the perfect gift', 'kidia-mobile-cms' ), 'settings' => array( 'alignment' => 'center', 'title_size' => 27 ) ),
			'pet_care'         => array( 'type' => 'quick_links', 'title' => __( 'Shop by companion', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'carousel', 'columns' => 4, 'item_size' => 76 ) ),
			'family_pop'       => array( 'type' => 'quick_links', 'title' => __( 'Shop every age', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'carousel', 'columns' => 4, 'item_size' => 64 ) ),
			'marketplace_plus' => array( 'type' => 'countdown', 'title' => __( 'Today’s marketplace deals', 'kidia-mobile-cms' ), 'settings' => array( 'layout_style' => 'cards', 'show_seconds' => true ) ),
			'studio_fashion'   => array( 'type' => 'banner_grid', 'title' => __( 'The studio campaign', 'kidia-mobile-cms' ), 'settings' => array( 'layout' => 'mosaic', 'columns' => 2, 'gap' => 0 ) ),
			'editorial_runway' => array( 'type' => 'image_banner', 'title' => __( 'The campaign story', 'kidia-mobile-cms' ), 'settings' => array( 'aspect_ratio' => .72, 'border_radius' => 0 ) ),
		);
		return $features[ $profile ] ?? $features['fashion'];
	}

	/** Creates a visibly distinct home header composition for every theme. */
	private function theme_header_layout( string $profile ): array {
		$row = static fn ( array $columns ): array => array( 'columns' => $columns );
		$column = static fn ( float $width, array $items, string $align = 'center' ): array => compact( 'width', 'align', 'items' );
		$layouts = array(
			'fashion'          => array( $row( array( $column( 20, array( 'menu' ), 'left' ), $column( 60, array( 'logo' ) ), $column( 20, array( 'search', 'cart' ), 'right' ) ) ) ),
			'beauty'           => array( $row( array( $column( 55, array( 'logo' ), 'left' ), $column( 45, array( 'wishlist', 'cart' ), 'right' ) ) ), $row( array( $column( 100, array( 'search_bar' ) ) ) ) ),
			'electronics'      => array( $row( array( $column( 24, array( 'logo' ), 'left' ), $column( 60, array( 'search_bar' ) ), $column( 16, array( 'cart' ), 'right' ) ) ) ),
			'home_living'      => array( $row( array( $column( 25, array( 'search' ), 'left' ), $column( 50, array( 'logo' ) ), $column( 25, array( 'account', 'cart' ), 'right' ) ) ) ),
			'kids_baby'        => array( $row( array( $column( 60, array( 'logo' ), 'left' ), $column( 40, array( 'account', 'cart' ), 'right' ) ) ), $row( array( $column( 84, array( 'search_bar' ), 'left' ), $column( 16, array( 'wishlist' ), 'right' ) ) ) ),
			'sports_fitness'   => array( $row( array( $column( 18, array( 'menu' ), 'left' ), $column( 44, array( 'logo' ), 'left' ), $column( 38, array( 'search', 'account', 'cart' ), 'right' ) ) ) ),
			'grocery'          => array( $row( array( $column( 34, array( 'logo' ), 'left' ), $column( 50, array( 'search_bar' ) ), $column( 16, array( 'cart' ), 'right' ) ) ) ),
			'luxury'           => array( $row( array( $column( 25, array( 'menu' ), 'left' ), $column( 50, array( 'logo' ) ), $column( 25, array( 'search', 'cart' ), 'right' ) ) ) ),
			'coffee'           => array( $row( array( $column( 70, array( 'logo' ), 'left' ), $column( 30, array( 'search', 'cart' ), 'right' ) ) ) ),
			'multi_store'      => array( $row( array( $column( 18, array( 'menu' ), 'left' ), $column( 66, array( 'search_bar' ) ), $column( 16, array( 'cart' ), 'right' ) ) ) ),
			'jewelry'          => array( $row( array( $column( 30, array( 'search' ), 'left' ), $column( 40, array( 'logo' ) ), $column( 30, array( 'wishlist', 'cart' ), 'right' ) ) ) ),
			'pet_care'         => array( $row( array( $column( 52, array( 'logo' ), 'left' ), $column( 48, array( 'search', 'account', 'cart' ), 'right' ) ) ), $row( array( $column( 100, array( 'search_bar' ) ) ) ) ),
			'family_pop'       => array( $row( array( $column( 50, array( 'logo' ), 'left' ), $column( 50, array( 'cart' ), 'right' ) ) ), $row( array( $column( 100, array( 'search_bar' ) ) ) ) ),
			'marketplace_plus' => array( $row( array( $column( 16, array( 'menu' ), 'left' ), $column( 68, array( 'search_bar' ) ), $column( 16, array( 'cart' ), 'right' ) ) ), $row( array( $column( 65, array( 'logo' ), 'left' ), $column( 35, array( 'account', 'orders' ), 'right' ) ) ) ),
			'studio_fashion'   => array( $row( array( $column( 50, array( 'logo' ), 'left' ), $column( 50, array( 'search', 'account', 'cart' ), 'right' ) ) ) ),
			'editorial_runway' => array( $row( array( $column( 25, array( 'menu' ), 'left' ), $column( 50, array( 'logo' ) ), $column( 25, array( 'cart' ), 'right' ) ) ) ),
		);
		return array( 'rows' => $layouts[ $profile ] ?? $layouts['fashion'] );
	}

	/** @param array<string,mixed> $theme */
	public static function asset_url( array $theme, string $role, int $index = 1 ): string {
		$directory = sanitize_key( (string) ( $theme['asset_dir'] ?? '' ) );
		$role      = sanitize_key( $role );
		$index     = max( 1, min( 6, $index ) );
		if ( '' === $directory || ! in_array( $role, array( 'hero', 'banner', 'category', 'product' ), true ) ) {
			return '';
		}
		return KIDIA_MOBILE_CMS_URL . 'admin/assets/theme-previews/' . $directory . '/' . $role . '-' . $index . '.webp';
	}

	/** @param array<string,mixed> $theme */
	public static function hero_url( array $theme ): string {
		return self::asset_url( $theme, 'hero', 1 );
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
		$identity = $this->identity();
		$app_name = (string) ( $identity['app_name'] ?? $theme['name'] );
		$primary = sanitize_hex_color( (string) ( $identity['primary_color'] ?? '' ) ) ?: (string) $theme['primary'];
		$secondary = sanitize_hex_color( (string) ( $identity['secondary_color'] ?? '' ) ) ?: (string) $theme['soft'];
		$logo_url = esc_url_raw( (string) ( $identity['logo_url'] ?? '' ) );
		$pages = array();
		foreach ( array_keys( Kidia_Mobile_Page_Layout_Store::pages() ) as $page ) {
			$pages[ $page ] = $this->build_page_layout( $page, $theme, $primary, $secondary, $app_name, $logo_url );
		}
		$preview_category = array(
			'enabled'    => true,
			'general'    => Kidia_Mobile_Category_Page_Store::sanitize_general( array() ),
			'categories' => array(),
		);
		return array(
			'theme' => $theme_key,
			'home' => $this->build_home( $theme, $primary, $secondary, $app_name, $logo_url ),
			'pages' => $pages,
			'category' => $this->build_category_settings( $theme, $preview_category ),
			'demo_catalog' => $this->build_demo_catalog( $theme ),
			'identity' => array(
				'app_name' => $app_name,
				'primary_color' => $primary,
				'secondary_color' => $secondary,
				'logo_url' => $logo_url,
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
	public function export_saved_theme( string $id, bool $include_images = false ): ?array {
		$themes = $this->saved_themes();
		if ( ! isset( $themes[ $id ] ) ) {
			return null;
		}
		$payload = array(
			'schema'      => 'woomobileapp-saved-theme',
			'version'     => 2,
			'export_mode' => $include_images ? 'settings_and_images' : 'settings',
			'theme'       => $themes[ $id ],
		);
		if ( $include_images ) {
			$payload['assets'] = $this->export_theme_images( (array) ( $themes[ $id ]['snapshot'] ?? array() ) );
		}
		return $payload;
	}

	public function import_saved_theme( string $json ): string {
		$payload = json_decode( $json, true );
		if ( ! is_array( $payload ) || 'woomobileapp-saved-theme' !== ( $payload['schema'] ?? '' ) || ! is_array( $payload['theme']['snapshot'] ?? null ) ) {
			throw new InvalidArgumentException( __( 'The selected file is not a valid WooMobile saved theme.', 'kidia-mobile-cms' ) );
		}
		$snapshot = $payload['theme']['snapshot'];
		if ( ! empty( $payload['assets'] ) && is_array( $payload['assets'] ) ) {
			$image_map = $this->import_theme_images( $payload['assets'] );
			$snapshot  = $this->replace_theme_image_urls( $snapshot, $image_map );
		}
		$id     = function_exists( 'wp_generate_uuid4' ) ? wp_generate_uuid4() : uniqid( 'theme_', true );
		$themes = $this->saved_themes();
		$themes[ $id ] = array(
			'id'         => $id,
			'name'       => sanitize_text_field( (string) ( $payload['theme']['name'] ?? __( 'Imported theme', 'kidia-mobile-cms' ) ) ),
			'created_at' => time(),
			'snapshot'   => $this->sanitize_snapshot( $snapshot ),
		);
		update_option( self::SAVED_THEMES_OPTION, $themes, false );
		return $id;
	}

	/**
	 * Embeds all portable theme artwork while deliberately excluding product
	 * catalog images. Each asset retains its original URL so import can rewrite
	 * every matching setting to the newly uploaded media URL.
	 *
	 * @param array<string,mixed> $snapshot Saved theme snapshot.
	 * @return array<int,array<string,string>>
	 */
	private function export_theme_images( array $snapshot ): array {
		$image_urls = array();
		$this->collect_theme_image_urls( $snapshot, $image_urls );
		$assets = array();
		$total_bytes = 0;
		foreach ( array_values( array_unique( $image_urls ) ) as $image_url ) {
			$asset = $this->read_theme_image( $image_url );
			if ( null === $asset ) {
				continue;
			}
			$asset_bytes = strlen( base64_decode( $asset['data'], true ) ?: '' );
			if ( $asset_bytes < 1 || $total_bytes + $asset_bytes > 41943040 ) {
				continue;
			}
			$total_bytes += $asset_bytes;
			$assets[] = $asset;
		}
		return $assets;
	}

	/**
	 * @param mixed             $value Snapshot node.
	 * @param array<int,string> $image_urls Collected image URLs.
	 */
	private function collect_theme_image_urls( $value, array &$image_urls, bool $product_context = false ): void {
		if ( ! is_array( $value ) ) {
			return;
		}
		$node_type = strtolower( (string) ( $value['type'] ?? $value['source'] ?? $value['action_type'] ?? '' ) );
		$product_context = $product_context || false !== strpos( $node_type, 'product' );
		foreach ( $value as $key => $item ) {
			$key = (string) $key;
			$child_product_context = $product_context || 'products' === $key;
			if (
				! $child_product_context
				&& is_string( $item )
				&& preg_match( '/(?:image|logo|thumbnail|background|banner|splash|icon)(?:_url)?$/i', $key )
			) {
				$image_url = esc_url_raw( $item );
				if ( '' !== $image_url && preg_match( '#^https?://#i', $image_url ) ) {
					$image_urls[] = $image_url;
				}
				continue;
			}
			$this->collect_theme_image_urls( $item, $image_urls, $child_product_context );
		}
	}

	/** @return array<string,string>|null */
	private function read_theme_image( string $image_url ): ?array {
		$contents = '';
		$mime     = '';
		$local_path = $this->theme_image_local_path( $image_url );
		if ( '' !== $local_path && is_readable( $local_path ) ) {
			$size = filesize( $local_path );
			if ( false === $size || $size < 1 || $size > 12582912 ) {
				return null;
			}
			$contents = file_get_contents( $local_path );
			if ( function_exists( 'wp_get_image_mime' ) ) {
				$mime = (string) wp_get_image_mime( $local_path );
			}
		} else {
			$response = wp_safe_remote_get(
				$image_url,
				array(
					'timeout'             => 20,
					'redirection'         => 3,
					'limit_response_size' => 12582912,
				)
			);
			if ( is_wp_error( $response ) || 200 !== (int) wp_remote_retrieve_response_code( $response ) ) {
				return null;
			}
			$contents = wp_remote_retrieve_body( $response );
			$mime     = strtolower( trim( (string) strtok( (string) wp_remote_retrieve_header( $response, 'content-type' ), ';' ) ) );
		}
		if ( ! is_string( $contents ) || '' === $contents || strlen( $contents ) > 12582912 ) {
			return null;
		}
		if ( '' === $mime && function_exists( 'finfo_open' ) ) {
			$finfo = finfo_open( FILEINFO_MIME_TYPE );
			$mime  = $finfo ? (string) finfo_buffer( $finfo, $contents ) : '';
			if ( $finfo ) {
				finfo_close( $finfo );
			}
		}
		$allowed_mimes = array( 'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif' );
		if ( ! in_array( $mime, $allowed_mimes, true ) ) {
			return null;
		}
		$path = (string) parse_url( $image_url, PHP_URL_PATH );
		$filename = sanitize_file_name( (string) wp_basename( rawurldecode( $path ) ) );
		if ( '' === $filename ) {
			$filename = 'theme-image.' . $this->image_extension_for_mime( $mime );
		}
		if ( '' === pathinfo( $filename, PATHINFO_EXTENSION ) ) {
			$filename .= '.' . $this->image_extension_for_mime( $mime );
		}
		return array(
			'source'   => $image_url,
			'filename' => $filename,
			'mime'     => $mime,
			'data'     => base64_encode( $contents ),
		);
	}

	private function theme_image_local_path( string $image_url ): string {
		$clean_url = (string) strtok( $image_url, '?#' );
		$locations = array(
			array( trailingslashit( KIDIA_MOBILE_CMS_URL ), trailingslashit( KIDIA_MOBILE_CMS_PATH ) ),
		);
		$uploads = wp_upload_dir();
		if ( empty( $uploads['error'] ) && ! empty( $uploads['baseurl'] ) && ! empty( $uploads['basedir'] ) ) {
			$locations[] = array( trailingslashit( (string) $uploads['baseurl'] ), trailingslashit( (string) $uploads['basedir'] ) );
		}
		if ( defined( 'WP_CONTENT_DIR' ) ) {
			$locations[] = array( trailingslashit( content_url() ), trailingslashit( WP_CONTENT_DIR ) );
		}
		foreach ( $locations as $location ) {
			if ( 0 !== strpos( $clean_url, $location[0] ) ) {
				continue;
			}
			$base_path = realpath( $location[1] );
			$candidate = realpath( $location[1] . ltrim( rawurldecode( substr( $clean_url, strlen( $location[0] ) ) ), '/\\' ) );
			if ( false !== $base_path && false !== $candidate && ( $candidate === $base_path || 0 === strpos( $candidate, $base_path . DIRECTORY_SEPARATOR ) ) ) {
				return $candidate;
			}
		}
		return '';
	}

	private function image_extension_for_mime( string $mime ): string {
		$extensions = array(
			'image/jpeg' => 'jpg',
			'image/png'  => 'png',
			'image/gif'  => 'gif',
			'image/webp' => 'webp',
			'image/avif' => 'avif',
		);
		return $extensions[ $mime ] ?? 'jpg';
	}

	/**
	 * @param array<int,mixed> $assets Embedded exported images.
	 * @return array<string,array{url:string,id:int}>
	 */
	private function import_theme_images( array $assets ): array {
		require_once ABSPATH . 'wp-admin/includes/file.php';
		require_once ABSPATH . 'wp-admin/includes/media.php';
		require_once ABSPATH . 'wp-admin/includes/image.php';
		$image_map = array();
		$total_bytes = 0;
		foreach ( array_slice( $assets, 0, 250 ) as $asset ) {
			if ( ! is_array( $asset ) ) {
				continue;
			}
			$source   = esc_url_raw( (string) ( $asset['source'] ?? '' ) );
			$filename = sanitize_file_name( (string) ( $asset['filename'] ?? '' ) );
			$mime     = sanitize_mime_type( (string) ( $asset['mime'] ?? '' ) );
			$contents = base64_decode( (string) ( $asset['data'] ?? '' ), true );
			if (
				'' === $source
				|| '' === $filename
				|| ! in_array( $mime, array( 'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/avif' ), true )
				|| ! is_string( $contents )
				|| '' === $contents
				|| strlen( $contents ) > 12582912
				|| $total_bytes + strlen( $contents ) > 41943040
			) {
				continue;
			}
			$total_bytes += strlen( $contents );
			$temp_file = wp_tempnam( $filename );
			if ( ! $temp_file || false === file_put_contents( $temp_file, $contents ) ) {
				continue;
			}
			$attachment_id = media_handle_sideload(
				array(
					'name'     => $filename,
					'tmp_name' => $temp_file,
				),
				0,
				sanitize_text_field( pathinfo( $filename, PATHINFO_FILENAME ) )
			);
			if ( is_wp_error( $attachment_id ) ) {
				@unlink( $temp_file );
				continue;
			}
			$uploaded_url = wp_get_attachment_url( (int) $attachment_id );
			if ( $uploaded_url ) {
				$image_map[ $source ] = array( 'url' => (string) $uploaded_url, 'id' => (int) $attachment_id );
			}
		}
		return $image_map;
	}

	/**
	 * @param mixed                               $value Snapshot node.
	 * @param array<string,array{url:string,id:int}> $image_map Imported URL map.
	 * @return mixed
	 */
	private function replace_theme_image_urls( $value, array $image_map ) {
		if ( is_string( $value ) ) {
			return isset( $image_map[ $value ] ) ? $image_map[ $value ]['url'] : $value;
		}
		if ( ! is_array( $value ) ) {
			return $value;
		}
		foreach ( $value as $key => $item ) {
			if ( is_string( $item ) && isset( $image_map[ $item ] ) ) {
				$value[ $key ] = $image_map[ $item ]['url'];
				$id_key = preg_replace( '/_url$/', '_id', (string) $key );
				if ( is_string( $id_key ) && $id_key !== (string) $key && array_key_exists( $id_key, $value ) ) {
					$value[ $id_key ] = $image_map[ $item ]['id'];
				}
				continue;
			}
			$value[ $key ] = $this->replace_theme_image_urls( $item, $image_map );
		}
		return $value;
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
		$defaults = $this->site_identity_defaults();
		// On first run, show the connected store as it exists now instead of
		// allowing an incomplete legacy identity to cover the detected values.
		if ( ! $this->is_complete() ) {
			$saved = is_array( $saved ) ? $saved : array();
			$saved = array_merge(
				$saved,
				array_intersect_key( $defaults, array_flip( array( 'app_name', 'logo_id', 'logo_url', 'language', 'direction', 'primary_color', 'secondary_color' ) ) )
			);
		}
		$identity = wp_parse_args(
			is_array( $saved ) ? $saved : array(),
			array_merge(
				$defaults,
				array(
				'theme'         => 'fashion',
				'page_themes'   => array_fill_keys( array_keys( self::setup_pages() ), 'fashion' ),
				'enabled_pages' => array_keys( self::setup_pages() ),
				)
			)
		);

		// Older installations may have saved an incomplete identity. Keep any
		// intentional value, but hydrate missing branding from the live site.
		if ( empty( $identity['logo_url'] ) ) {
			$identity['logo_id']  = $defaults['logo_id'];
			$identity['logo_url'] = $defaults['logo_url'];
		}
		if ( ! sanitize_hex_color( (string) ( $identity['primary_color'] ?? '' ) ) ) {
			$identity['primary_color'] = $defaults['primary_color'];
		}
		if ( ! sanitize_hex_color( (string) ( $identity['secondary_color'] ?? '' ) ) ) {
			$identity['secondary_color'] = $defaults['secondary_color'];
		}
		// Migrate only the exact demo-blue pair saved by 1.46.10. Intentional
		// user palettes and previously detected site colors remain untouched.
		if ( '#0878e5' === strtolower( (string) $identity['primary_color'] ) && '#e8f3ff' === strtolower( (string) $identity['secondary_color'] ) ) {
			$identity['primary_color']   = $defaults['primary_color'];
			$identity['secondary_color'] = $defaults['secondary_color'];
		}
		return $identity;
	}

	/**
	 * Calculates first-run identity from the connected WordPress site.
	 *
	 * @return array<string,mixed>
	 */
	private function site_identity_defaults(): array {
		$logo_id = absint( get_theme_mod( 'custom_logo', 0 ) );
		if ( ! $logo_id ) {
			$logo_id = absint( get_option( 'site_logo', 0 ) );
		}
		$logo_url = $logo_id ? (string) wp_get_attachment_image_url( $logo_id, 'full' ) : '';
		if ( '' === $logo_url ) {
			$site_icon_id  = absint( get_option( 'site_icon', 0 ) );
			$site_icon_url = $site_icon_id ? (string) wp_get_attachment_image_url( $site_icon_id, 'full' ) : '';
			if ( '' === $site_icon_url && function_exists( 'get_site_icon_url' ) ) {
				$site_icon_url = (string) get_site_icon_url( 512, '', 0 );
			}
			if ( '' !== $site_icon_url ) {
				$logo_id  = $site_icon_id;
				$logo_url = $site_icon_url;
			}
		}
		if ( '' === $logo_url ) {
			$email_logo = esc_url_raw( (string) get_option( 'woocommerce_email_header_image', '' ) );
			$logo_url  = $email_logo;
		}

		$primary_candidates = array(
			get_theme_mod( 'primary_color', '' ),
			get_theme_mod( 'color_primary', '' ),
			get_theme_mod( 'theme_color', '' ),
			get_theme_mod( 'accent_color', '' ),
			get_theme_mod( 'color_accent', '' ),
			get_theme_mod( 'link_color', '' ),
			get_theme_mod( 'button_color', '' ),
			get_theme_mod( 'woocommerce_primary', '' ),
		);
		$secondary_candidates = array(
			get_theme_mod( 'secondary_color', '' ),
			get_theme_mod( 'color_secondary', '' ),
			get_theme_mod( 'woocommerce_secondary', '' ),
			get_theme_mod( 'background_color', '' ),
		);
		// Popular classic themes keep their palette in differently named theme
		// mods or a single option array. Read semantic color keys instead of
		// falling back merely because a theme does not use WordPress' generic
		// `primary_color` key.
		$theme_sources = array( function_exists( 'get_theme_mods' ) ? get_theme_mods() : array() );
		foreach ( array( 'astra-settings', 'xts-woodmart-options', 'et_divi', 'blocksy', 'kadence_global_palette' ) as $option_name ) {
			$theme_sources[] = get_option( $option_name, array() );
		}
		foreach ( $theme_sources as $source ) {
			$this->collect_site_colors( $source, $primary_candidates, $secondary_candidates );
		}
		if ( function_exists( 'wp_get_global_settings' ) ) {
			foreach ( array( 'theme', 'custom', 'default' ) as $palette_origin ) {
				$palette = wp_get_global_settings( array( 'color', 'palette', $palette_origin ) );
				if ( is_array( $palette ) ) {
					foreach ( $palette as $entry ) {
						if ( ! is_array( $entry ) || empty( $entry['color'] ) ) {
							continue;
						}
						$primary_candidates[]   = $entry['color'];
						$secondary_candidates[] = $entry['color'];
					}
				}
			}
		}

		$primary   = $this->first_site_color( $primary_candidates, '#2F806E' );
		$secondary = $this->first_site_color( $secondary_candidates, '', $primary );
		if ( '' === $secondary ) {
			$secondary = $this->tint_color( $primary, 0.88 );
		}
		$locale = function_exists( 'determine_locale' ) ? determine_locale() : get_locale();
		$language = 0 === strpos( strtolower( (string) $locale ), 'ar' ) ? 'ar' : 'en';

		return array(
			'app_name'        => get_bloginfo( 'name' ),
			'logo_id'         => $logo_id,
			'logo_url'        => $logo_url,
			'language'        => $language,
			'direction'       => is_rtl() ? 'rtl' : 'ltr',
			'primary_color'   => $primary,
			'secondary_color' => $secondary,
		);
	}

	/**
	 * Recursively collects colors whose setting names describe their role.
	 *
	 * @param mixed            $value Theme settings node.
	 * @param array<int,mixed> $primary Primary candidates.
	 * @param array<int,mixed> $secondary Secondary candidates.
	 */
	private function collect_site_colors( $value, array &$primary, array &$secondary, string $path = '' ): void {
		if ( ! is_array( $value ) ) {
			if ( ! is_string( $value ) || ! preg_match( '/#[0-9a-f]{3}(?:[0-9a-f]{3})?\b/i', $value, $match ) ) {
				return;
			}
			$key = strtolower( $path );
			if ( preg_match( '/(?:primary|accent|brand|theme|main|button|link)/', $key ) ) {
				$primary[] = $match[0];
			}
			if ( preg_match( '/(?:secondary|soft|light|background|surface)/', $key ) ) {
				$secondary[] = $match[0];
			}
			return;
		}
		foreach ( $value as $key => $child ) {
			$this->collect_site_colors( $child, $primary, $secondary, $path . '.' . sanitize_key( (string) $key ) );
		}
	}

	/** @param array<int,mixed> $candidates */
	private function first_site_color( array $candidates, string $fallback, string $exclude = '' ): string {
		foreach ( $candidates as $candidate ) {
			$value = trim( (string) $candidate );
			if ( in_array( strlen( $value ), array( 3, 6 ), true ) && '#' !== $value[0] ) {
				$value = '#' . $value;
			}
			$value = sanitize_hex_color( $value ) ?: '';
			if ( 4 === strlen( $value ) ) {
				$value = '#' . $value[1] . $value[1] . $value[2] . $value[2] . $value[3] . $value[3];
			}
			if ( '' !== $value && 0 !== strcasecmp( $value, $exclude ) ) {
				return strtoupper( $value );
			}
		}
		return $fallback;
	}

	private function tint_color( string $hex, float $amount ): string {
		$hex = ltrim( $hex, '#' );
		if ( 6 !== strlen( $hex ) ) {
			return '#EAF6F2';
		}
		$amount = max( 0, min( 1, $amount ) );
		$channels = array();
		foreach ( array( 0, 2, 4 ) as $offset ) {
			$channel    = hexdec( substr( $hex, $offset, 2 ) );
			$channels[] = (int) round( $channel + ( 255 - $channel ) * $amount );
		}
		return sprintf( '#%02X%02X%02X', $channels[0], $channels[1], $channels[2] );
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
		$profile = (string) ( $theme['layout_profile'] ?? 'fashion' );
		$signature = $this->signature_feature( $profile );
		$signature_applied = false;
		$home_design = wp_parse_args(
			is_array( $theme['home_design'] ?? null ) ? $theme['home_design'] : array(),
			array(
				'hero_ratio' => 2, 'hero_radius' => $theme['radius'], 'hero_padding' => 16, 'hero_indicators' => 'below', 'hero_show_indicators' => true,
				'category_layout' => 'grid', 'category_columns' => 3 <= (int) $theme['product_columns'] ? 4 : 3, 'category_size' => 78, 'category_gap' => 12,
				'quick_layout' => 'carousel', 'quick_columns' => 4, 'quick_size' => 76, 'quick_gap' => 12,
				'product_columns' => $theme['product_columns'], 'product_ratio' => .88, 'product_radius' => 14,
				'product_style' => 'outlined', 'product_rating' => true, 'product_badge' => false, 'product_swipe' => false, 'product_quick_add' => true, 'product_wishlist' => false,
				'banner_layout' => 'featured', 'banner_ratio' => 1.333, 'banner_gap' => 10, 'image_banner_ratio' => 1.333,
				'text_alignment' => 'center', 'text_title_size' => 24, 'text_content_size' => 15, 'text_weight' => 'medium',
			)
		);
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
			if ( ! $signature_applied && (string) $signature['type'] === (string) $type ) {
				$settings = array_merge( $settings, (array) $signature['settings'] );
				$settings['title'] = (string) $signature['title'];
				$settings['signature_feature'] = $profile;
				$signature_applied = true;
			}
			if ( 'app_header' === $type ) {
				$settings['title']    = $app_name;
				$settings['logo_url'] = $logo_url;
			}
			if ( 'hero_slider' === $type ) {
				$settings['items']            = $slides;
				$settings['aspect_ratio']     = $home_design['hero_ratio'];
				$settings['image_fit']        = 'cover';
				$settings['border_radius']    = $home_design['hero_radius'];
				$settings['horizontal_padding'] = $home_design['hero_padding'];
				$settings['overlay_strength'] = $theme['overlay'];
				$settings['text_color']       = '#FFFFFF';
				$settings['indicator_position'] = $home_design['hero_indicators'];
				$settings['show_indicators'] = ! empty( $home_design['hero_show_indicators'] );
			}
			if ( 'category_grid' === $type ) {
				$settings['title']       = $theme['sample_copy'][1] ?? __( 'Shop by category', 'kidia-mobile-cms' );
				$settings['layout']      = $home_design['category_layout'];
				$settings['columns']     = $home_design['category_columns'];
				$settings['limit']       = 6;
				$settings['image_shape'] = $theme['category_shape'];
				$settings['image_size']  = $home_design['category_size'];
				$settings['gap']         = $home_design['category_gap'];
				$settings['row_gap']     = $home_design['category_gap'];
				$settings['items_alignment'] = 'center';
			}
			if ( 'quick_links' === $type ) {
				$settings['title']       = $theme['sample_copy'][1] ?? __( 'Explore', 'kidia-mobile-cms' );
				$settings['layout']      = $home_design['quick_layout'];
				$settings['columns']     = $home_design['quick_columns'];
				$settings['image_shape'] = $theme['category_shape'];
				$settings['item_size']   = $home_design['quick_size'];
				$settings['gap']         = $home_design['quick_gap'];
				$settings['items']       = $this->build_demo_quick_links( $theme );
			}
			if ( 'image_banner' === $type ) {
				$settings['image_url']       = self::asset_url( $theme, 'banner', 6 );
				$settings['title']           = $theme['sample_copy'][0] ?? '';
				$settings['subtitle']        = $theme['description'];
				$settings['button_label']    = __( 'Shop now', 'kidia-mobile-cms' );
				$settings['aspect_ratio']    = $home_design['image_banner_ratio'];
				$settings['image_fit']       = 'cover';
				$settings['border_radius']   = $theme['radius'];
				$settings['overlay_strength']= $theme['overlay'];
			}
			if ( 'text_block' === $type ) {
				$settings['title']        = $theme['sample_copy'][0] ?? '';
				$settings['content']      = $theme['description'];
				$settings['alignment']    = $home_design['text_alignment'];
				$settings['title_size']   = $home_design['text_title_size'];
				$settings['content_size'] = $home_design['text_content_size'];
				$settings['font_weight']  = $home_design['text_weight'];
			}
			if ( 'banner_grid' === $type ) {
				$settings['title']         = $theme['sample_copy'][1] ?? '';
				$settings['layout']        = $home_design['banner_layout'];
				$settings['columns']       = 2;
				$settings['gap']           = $home_design['banner_gap'];
				$settings['aspect_ratio']  = $home_design['banner_ratio'];
				$settings['border_radius'] = $theme['radius'];
				$settings['items']         = array();
				foreach ( array_slice( $slides, 0, 3 ) as $slide_index => $slide ) {
					$settings['items'][] = array(
						'id'           => 'setup_theme_banner_' . ( $slide_index + 1 ),
						'enabled'      => true,
						'image_url'    => self::asset_url( $theme, 'banner', $slide_index + 1 ),
						'title'        => (string) ( $theme['sample_copy'][ $slide_index ] ?? $slide['title'] ?? '' ),
						'subtitle'     => '',
						'button_label' => __( 'Shop now', 'kidia-mobile-cms' ),
						'action_type'  => (string) ( $slide['action_type'] ?? '' ),
						'action_value' => (string) ( $slide['action_value'] ?? '' ),
					);
				}
			}
			if ( 'brand_carousel' === $type ) {
				$settings['title']       = __( 'Featured collections', 'kidia-mobile-cms' );
				$settings['image_shape'] = $theme['category_shape'];
				$settings['items']       = $this->build_demo_brand_items( $theme );
			}
			if ( in_array( $type, array( 'product_grid', 'product_carousel' ), true ) ) {
				$settings['title']          = $theme['sample_copy'][2] ?? __( 'Products for you', 'kidia-mobile-cms' );
				$settings['source']         = 'latest';
				$settings['columns']        = $home_design['product_columns'];
				$settings['image_ratio']    = $home_design['product_ratio'];
				$settings['card_radius']    = $home_design['product_radius'];
				$settings['card_style']     = $home_design['product_style'];
				$settings['show_price']     = true;
				$settings['show_rating']    = $home_design['product_rating'];
				$settings['show_badge']     = $home_design['product_badge'];
				$settings['show_wishlist']  = ! empty( $home_design['product_wishlist'] );
				$settings['quick_add_enabled'] = ! empty( $home_design['product_quick_add'] );
				$settings['enable_image_swipe'] = $home_design['product_swipe'];
				$settings = array_merge( $settings, $this->compact_product_card_settings( $primary, (string) $theme['ink'] ) );
			}
			if ( isset( $settings['signature_feature'] ) ) {
				$settings = array_merge( $settings, (array) $signature['settings'] );
				$settings['title'] = (string) $signature['title'];
				if ( 'promo_strip' === $type ) {
					$settings['text'] = (string) $signature['title'];
				}
			}
			$settings = $this->hydrate_theme_section_defaults( (string) $type, $settings, $theme, $slides );
			$block['settings'] = $settings;
			$block['name']     = $this->block_name( (string) $type, (array) $theme['sample_copy'] );
			$blocks[]          = $block;
		}
		return $blocks;
	}

	/**
	 * Gives every built-in theme section visible starter content.
	 *
	 * @param array<string,mixed> $settings
	 * @param array<string,mixed> $theme
	 * @param array<int,array<string,mixed>> $slides
	 * @return array<string,mixed>
	 */
	private function hydrate_theme_section_defaults( string $type, array $settings, array $theme, array $slides ): array {
		$copy  = array_values( (array) ( $theme['sample_copy'] ?? array() ) );
		$title = (string) ( $copy[2] ?? $copy[0] ?? __( 'Discover more', 'kidia-mobile-cms' ) );
		if ( array_key_exists( 'title', $settings ) && '' === trim( (string) $settings['title'] ) ) {
			$settings['title'] = $title;
		}
		if ( 'promo_strip' === $type ) {
			$settings['text'] = trim( (string) ( $settings['text'] ?? '' ) ) ?: (string) ( $copy[0] ?? __( 'Discover today’s collection', 'kidia-mobile-cms' ) );
			$settings['messages'] = ! empty( $settings['messages'] ) ? $settings['messages'] : array_values( array_filter( array_slice( $copy, 0, 3 ) ) );
		}
		if ( 'countdown' === $type ) {
			$settings['title'] = trim( (string) ( $settings['title'] ?? '' ) ) ?: __( 'Limited-time offer', 'kidia-mobile-cms' );
			$settings['ends_at'] = trim( (string) ( $settings['ends_at'] ?? '' ) ) ?: gmdate( 'c', time() + WEEK_IN_SECONDS );
			$settings['expired_text'] = trim( (string) ( $settings['expired_text'] ?? '' ) ) ?: __( 'A new offer is coming soon', 'kidia-mobile-cms' );
		}
		if ( 'quick_links' === $type && empty( $settings['items'] ) ) {
			$settings['items'] = $this->build_demo_quick_links( $theme );
		}
		if ( 'brand_carousel' === $type && empty( $settings['items'] ) ) {
			$settings['items'] = $this->build_demo_brand_items( $theme );
		}
		if ( 'banner_grid' === $type && empty( $settings['items'] ) ) {
			$settings['items'] = array_slice( $slides, 0, 3 );
		}
		if ( 'hero_slider' === $type && empty( $settings['items'] ) ) {
			$settings['items'] = $slides;
		}
		if ( in_array( $type, array( 'product_grid', 'product_carousel', 'category_grid' ), true ) ) {
			$settings['empty_title'] = (string) ( $settings['empty_title'] ?? __( 'Your collection is ready', 'kidia-mobile-cms' ) );
			$settings['empty_message'] = (string) ( $settings['empty_message'] ?? __( 'Add store items to replace the theme’s starter content.', 'kidia-mobile-cms' ) );
		}
		return $settings;
	}

	private function home_card_style( string $style ): string {
		if ( 'elevated' === $style ) {
			return 'elevated';
		}
		if ( in_array( $style, array( 'minimal', 'no_shadow' ), true ) ) {
			return 'minimal';
		}
		return 'outlined';
	}

	/** @param array<string,mixed> $theme */
	private function apply_home( array $theme, string $primary, string $secondary, string $app_name, string $logo_url ): void {
		( new Kidia_Mobile_Layout_Store() )->save_layout( $this->build_home( $theme, $primary, $secondary, $app_name, $logo_url ) );
	}

	/** @return array<int,array<string,mixed>> */
	private function catalog_slides( array $theme ): array {
		$copy = (array) ( $theme['sample_copy'] ?? array() );
		$slides = array();
		for ( $index = 1; $index <= 3; $index++ ) {
			$slides[] = array(
				'id'           => 'setup_theme_hero_' . $index,
				'enabled'      => true,
				'image_url'    => self::asset_url( $theme, 'hero', $index ),
				'title'        => $copy[ ( $index - 1 ) % max( 1, count( $copy ) ) ] ?? __( 'Discover the collection', 'kidia-mobile-cms' ),
				'subtitle'     => $theme['description'] ?? '',
				'button_label' => __( 'Shop now', 'kidia-mobile-cms' ),
				'action_type'  => '',
				'action_value' => '',
			);
		}
		return $slides;
	}

	/**
	 * Demo catalog used only by the built-in theme preview. It is intentionally
	 * bundled with the theme and never reads products, categories or media from
	 * the merchant's WooCommerce store.
	 *
	 * @param array<string,mixed> $theme
	 * @return array<string,array<int,array<string,mixed>>>
	 */
	private function build_demo_catalog( array $theme ): array {
		$labels     = $this->theme_demo_labels( $theme );
		$products   = array();
		$categories = array();
		foreach ( $labels as $index => $label ) {
			$number = $index + 1;
			$categories[] = array(
				'id'          => 9100 + $number,
				'name'        => $label,
				'slug'        => sanitize_title( $label ),
				'count'       => 8 + $number,
				'image_url'   => self::asset_url( $theme, 'category', $number ),
				'description' => sprintf( __( 'Explore the %s collection.', 'kidia-mobile-cms' ), $label ),
			);
			$price = 39 + ( $number * 18 );
			$products[] = array(
				'id'              => 9000 + $number,
				'name'            => sprintf( __( '%s favorite', 'kidia-mobile-cms' ), $label ),
				'slug'            => sanitize_title( $label . '-favorite' ),
				'type'            => 1 === $number ? 'variable' : 'simple',
				'image_url'       => self::asset_url( $theme, 'product', $number ),
				'image_urls'      => array(
					self::asset_url( $theme, 'product', $number ),
					self::asset_url( $theme, 'product', ( $number % 6 ) + 1 ),
				),
				'price'           => number_format( $price, 2, '.', '' ),
				'price_minor'     => (string) ( $price * 100 ),
				'regular_price'   => 2 === $number || 5 === $number ? number_format( $price + 20, 2, '.', '' ) : null,
				'regular_price_minor' => 2 === $number || 5 === $number ? (string) ( ( $price + 20 ) * 100 ) : '',
				'currency_code'   => 'USD',
				'currency_symbol' => '$',
				'in_stock'        => true,
				'is_on_sale'      => 2 === $number || 5 === $number,
				'badge'           => 2 === $number || 5 === $number ? __( 'Sale', 'kidia-mobile-cms' ) : null,
				'rating'          => 4.2 + ( $number / 10 ),
				'review_count'    => 12 * $number,
				'category_id'     => 9100 + $number,
				'summary'         => sprintf( __( 'A curated %s pick created for this theme preview.', 'kidia-mobile-cms' ), strtolower( $label ) ),
				'description'     => sprintf( __( 'Premium quality and thoughtful detail from the %s collection.', 'kidia-mobile-cms' ), $label ),
			);
		}
		return array( 'products' => $products, 'categories' => $categories );
	}

	/** @param array<string,mixed> $theme @return array<int,string> */
	private function theme_demo_labels( array $theme ): array {
		$labels = array(
			'fashion'        => array( 'New Edit', 'Soft Tailoring', 'Bags', 'Accessories', 'The Boutique', 'Essentials' ),
			'beauty'         => array( 'Skincare', 'Bath & Body', 'Makeup', 'Natural Care', 'Wellness', 'Daily Glow' ),
			'electronics'    => array( 'Mobile', 'Computing', 'Wearables', 'Gaming', 'Smart Home', 'Audio' ),
			'home_living'    => array( 'Living Room', 'Tableware', 'Bedroom', 'Lighting', 'Workspace', 'Natural Home' ),
			'kids_baby'      => array( 'Newborn', 'Toys', 'Nursery', 'Kids Style', 'Feeding', 'Family Picks' ),
			'sports_fitness' => array( 'Running', 'Footwear', 'Gym Gear', 'Training', 'Outdoor', 'Studio' ),
			'grocery'        => array( 'Fresh Produce', 'Pantry', 'Bakery', 'Drinks', 'Breakfast', 'Weekly Basket' ),
			'luxury'         => array( 'Evening', 'Leather', 'Timepieces', 'Fragrance', 'The Gallery', 'Signature' ),
			'coffee'         => array( 'Coffee Bar', 'Roasts', 'Bakery', 'Tea', 'Brewing', 'Cafe Edit' ),
			'multi_store'    => array( 'Top Deals', 'Electronics', 'Home', 'Personal Care', 'Office', 'Departments' ),
			'jewelry'        => array( 'Fine Jewelry', 'Rings', 'Necklaces', 'Earrings', 'The Atelier', 'Gifting' ),
			'pet_care'       => array( 'Dogs & Cats', 'Nutrition', 'Walk', 'Sleep', 'Grooming', 'Pet Store' ),
			'family_pop'     => array( 'Newborn', 'Toddler Girls', 'Toddler Boys', 'Matching Family', 'Playtime', 'Accessories' ),
			'marketplace_plus' => array( 'Today Deals', 'Electronics', 'Kitchen', 'Personal Care', 'Home Essentials', 'Travel' ),
			'studio_fashion' => array( 'Women', 'Men', 'Divided', 'Denim', 'Accessories', 'Beauty' ),
			'editorial_runway' => array( 'Women', 'Men', 'Evening', 'Tailoring', 'Accessories', 'Edition' ),
		);
		$key = sanitize_key( (string) ( $theme['asset_dir'] ?? 'fashion' ) );
		return $labels[ $key ] ?? $labels['fashion'];
	}

	/** @param array<string,mixed> $theme @return array<int,array<string,mixed>> */
	private function build_demo_quick_links( array $theme ): array {
		$items = array();
		foreach ( array_slice( $this->theme_demo_labels( $theme ), 0, 4 ) as $index => $label ) {
			$items[] = array(
				'id'           => 'theme_quick_link_' . ( $index + 1 ),
				'image_url'    => self::asset_url( $theme, 'category', $index + 1 ),
				'label'        => $label,
				'subtitle'     => '',
				'action_type'  => '',
				'action_value' => '',
			);
		}
		return $items;
	}

	/** @param array<string,mixed> $theme @return array<int,array<string,mixed>> */
	private function build_demo_brand_items( array $theme ): array {
		$items = array();
		foreach ( array_slice( $this->theme_demo_labels( $theme ), 0, 6 ) as $index => $label ) {
			$items[] = array(
				'id'           => 9201 + $index,
				'name'         => $label,
				'logo_url'     => self::asset_url( $theme, 'category', $index + 1 ),
				'action_type'  => '',
				'action_value' => '',
			);
		}
		return $items;
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
		$layout['settings']['font_family'] = (string) ( $design['chrome']['font_family'] ?? 'system' );
		$layout['settings']['content_horizontal_padding'] = (int) ( $design['chrome']['content_horizontal_padding'] ?? 20 );
		$profile = (string) ( $theme['layout_profile'] ?? 'fashion' );
		$is_family_pop = 'family_pop' === $profile;
		foreach ( array( 'header', 'footer' ) as $chrome ) {
			if ( ! isset( $layout[ $chrome ]['settings'] ) || ! is_array( $layout[ $chrome ]['settings'] ) ) {
				continue;
			}
			$layout[ $chrome ]['settings']['background_color'] = $theme['surface'];
			$layout[ $chrome ]['settings']['border_color'] = $secondary;
			$layout[ $chrome ]['settings']['corner_radius'] = 'transparent' === $theme['header_style'] ? 0 : $theme['radius'];
			if ( 'header' === $chrome ) {
				$layout[ $chrome ]['settings']['icon_color'] = $theme['ink'];
				$layout[ $chrome ]['settings']['title_color'] = $theme['ink'];
				$layout[ $chrome ]['settings']['logo_text_color'] = $theme['ink'];
				$layout[ $chrome ]['settings']['style'] = $theme['header_style'];
				$layout[ $chrome ]['settings']['height'] = (int) ( $design['chrome']['header_heights'][ $page ] ?? $design['chrome']['header_height'] );
				$layout[ $chrome ]['settings']['shadow'] = (string) $design['chrome']['header_shadow'];
				$layout[ $chrome ]['settings']['search_style'] = $theme['search_style'];
				$layout[ $chrome ]['settings']['search_background'] = $secondary;
				$layout[ $chrome ]['settings']['search_border_color'] = $secondary;
				$layout[ $chrome ]['settings']['search_radius'] = (int) $design['chrome']['search_radius'];
				$layout[ $chrome ]['settings']['logo_text'] = $app_name;
				$layout[ $chrome ]['settings']['logo_url'] = $logo_url;
				foreach ( array( 'horizontal_padding', 'vertical_padding', 'search_height', 'search_icon_size', 'search_border_width', 'show_voice_search', 'show_cart_badge', 'cart_icon_variant', 'logo_width', 'logo_height', 'icon_size', 'title_font_size' ) as $setting_key ) {
					if ( array_key_exists( $setting_key, $design['chrome'] ) ) {
						$layout[ $chrome ]['settings'][ $setting_key ] = $design['chrome'][ $setting_key ];
					}
				}
				if ( 'home' === $page ) {
					$layout[ $chrome ]['settings']['layout_json'] = wp_json_encode( $this->theme_header_layout( $profile ) );
				}
				if ( $is_family_pop ) {
					$row = static fn ( array $columns ): array => array( 'columns' => $columns );
					$column = static fn ( float $width, array $items, string $align = 'center' ): array => compact( 'width', 'align', 'items' );
					$family_headers = array(
						'home' => array( 'rows' => array( $row( array( $column( 50, array( 'logo' ), 'left' ), $column( 50, array( 'cart' ), 'right' ) ) ), $row( array( $column( 100, array( 'search_bar' ) ) ) ) ) ),
						'category' => array( 'rows' => array( $row( array( $column( 86, array( 'search_bar' ), 'left' ), $column( 14, array( 'cart' ), 'right' ) ) ) ) ),
						'catalog' => array( 'rows' => array( $row( array( $column( 14, array( 'back' ), 'left' ), $column( 58, array( 'title' ) ), $column( 28, array( 'search', 'cart' ), 'right' ) ) ) ) ),
					);
					if ( 'home' !== $page && isset( $family_headers[ $page ] ) ) {
						$layout[ $chrome ]['settings']['layout_json'] = wp_json_encode( $family_headers[ $page ] );
					}
				}
			} else {
				$layout[ $chrome ]['settings']['height'] = (int) $design['chrome']['footer_height'];
				$layout[ $chrome ]['settings']['shadow'] = (string) $design['chrome']['footer_shadow'];
				$layout[ $chrome ]['settings']['active_color'] = $primary;
				$layout[ $chrome ]['settings']['button_color'] = $primary;
				$layout[ $chrome ]['settings']['button_radius'] = (int) $design['chrome']['button_radius'];
				$layout[ $chrome ]['settings']['button_shape'] = (string) $design['chrome']['button_shape'];
				foreach ( array( 'active_color', 'inactive_color', 'icon_size', 'label_size', 'icon_label_gap', 'border_width', 'button_color', 'button_text_color', 'show_button_icon' ) as $setting_key ) {
					if ( array_key_exists( $setting_key, $design['chrome'] ) ) {
						$layout[ $chrome ]['settings'][ $setting_key ] = $design['chrome'][ $setting_key ];
					}
				}
				// Navigation accents always follow the store brand, never a hard-coded theme swatch.
				$layout[ $chrome ]['settings']['active_color'] = $primary;
				$layout[ $chrome ]['settings']['button_color'] = $primary;
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
			if ( $is_family_pop ) {
				foreach ( array( 'button_color', 'button_border_color' ) as $button_color_key ) {
					if ( array_key_exists( $button_color_key, $element['settings'] ) ) {
						$element['settings'][ $button_color_key ] = $primary;
					}
				}
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
				'button_style' => $design['catalog']['filter_button_style'] ?? 'outlined',
				'filter_color' => $design['catalog']['filter_color'] ?? false,
				'button_gap' => $design['catalog']['filter_gap'] ?? 8,
			) );
			$this->configure_element( $layout, 'product_grid', array_merge( array(
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
				'outer_horizontal_padding' => $design['catalog']['outer_horizontal_padding'] ?? 16,
				'top_spacing' => $design['catalog']['top_spacing'] ?? 20,
				'image_inset' => $design['catalog']['image_inset'] ?? 5,
				'image_radius' => $design['catalog']['image_radius'] ?? 10,
				'content_horizontal_padding' => $design['catalog']['content_horizontal_padding'] ?? 9,
				'content_top_padding' => $design['catalog']['content_top_padding'] ?? 5,
				'content_bottom_padding' => $design['catalog']['content_bottom_padding'] ?? 9,
				'price_prefix' => $design['catalog']['price_prefix'] ?? '',
				'price_color' => $design['catalog']['price_color'] ?? $theme['ink'],
				'price_size' => $design['catalog']['price_size'] ?? 14,
				'show_name' => $design['catalog']['show_name'] ?? true,
			), $this->compact_product_card_settings( $primary, (string) $theme['ink'] ) ) );
		}
		if ( 'product' === $page ) {
			$this->configure_element( $layout, 'product_tabs', array( 'sticky' => $design['product']['tabs_sticky'], 'active_color' => $primary, 'inactive_color' => $design['product']['tabs_inactive_color'] ?? '#667085', 'height' => $design['product']['tabs_height'] ?? 56 ), $design['product']['tabs_enabled'] );
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
			$this->configure_element( $layout, 'related_products', array_merge( array( 'columns' => $design['product']['related_columns'], 'gap' => $design['product']['related_gap'] ), $this->compact_product_card_settings( $primary, (string) $theme['ink'] ) ) );
			$layout['footer']['settings']['button_width_percent'] = $design['product']['button_width'];
			$layout['footer']['settings']['button_height'] = $design['product']['button_height'];
			$layout['footer']['settings']['button_color'] = $primary;
			$layout['footer']['settings']['button_text_color'] = $design['product']['button_text_color'] ?? '#FFFFFF';
			$layout['footer']['settings']['show_button_icon'] = $design['product']['show_button_icon'] ?? true;
		}
		if ( 'wishlist' === $page ) {
			$layout['settings']['wishlist_access_mode'] = $design['wishlist']['access'];
			foreach ( array( 'sign_in_state', 'empty_state' ) as $state_id ) {
				$this->configure_element( $layout, $state_id, array( 'button_style' => $design['wishlist']['button_style'], 'button_radius' => $design['wishlist']['button_radius'], 'top_spacing' => $design['wishlist']['top_spacing'] ) );
			}
			foreach ( array( 'sign_in_recommendations', 'empty_recommendations', 'products_recommendations' ) as $recommendation_id ) {
				$this->configure_element( $layout, $recommendation_id, array( 'layout_style' => $design['wishlist']['recommendation_layout'], 'columns' => $design['wishlist']['columns'], 'card_radius' => $design['wishlist']['card_radius'] ) );
			}
			$this->configure_element( $layout, 'wishlist_grid', array_merge( array(
				'columns' => $design['wishlist']['columns'],
				'gap' => $design['wishlist']['gap'],
				'card_style' => $design['wishlist']['card_style'],
				'card_radius' => $design['wishlist']['card_radius'],
				'image_ratio' => $design['wishlist']['image_ratio'],
				'show_name' => $design['wishlist']['show_name'],
				'show_wishlist' => true,
			), $this->compact_product_card_settings( $primary, (string) $theme['ink'] ) ) );
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

	/** @return array<string,mixed> */
	private function compact_product_card_settings( string $primary, string $ink ): array {
		return array(
			'card_style' => 'outlined', 'card_radius' => 14, 'image_ratio' => .88,
			'image_inset' => 5, 'image_radius' => 11,
			'content_horizontal_padding' => 9, 'content_top_padding' => 5, 'content_bottom_padding' => 8,
			'show_name' => true, 'show_price' => true, 'show_rating' => true, 'show_badge' => false,
			'price_color' => $ink, 'price_size' => 14,
			'quick_add_enabled' => true, 'quick_add_icon_variant' => 'bag',
			'quick_add_icon_style' => 'filled', 'quick_add_icon_color' => $primary,
			'quick_add_show_background' => true, 'quick_add_background_color' => '#FFFFFF',
			'quick_add_background_size' => 36, 'quick_add_radius' => 18,
			'quick_add_position' => 'bottom_end', 'show_wishlist' => false,
		);
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
			'jewelry' => array(
				'chrome' => array( 'header_height' => 86, 'header_shadow' => 'none', 'search_radius' => 18, 'footer_height' => 70, 'footer_shadow' => 'none', 'button_radius' => 22, 'button_shape' => 'pill' ),
				'catalog' => array( 'filter_sticky' => false, 'filter_radius' => 18, 'gap' => 18, 'card_style' => 'no_shadow', 'card_radius' => 12, 'image_ratio' => 1.2, 'show_rating' => false, 'show_badge' => false, 'quick_add_style' => 'outline', 'pagination' => 'numbers', 'per_page' => 10 ),
				'product' => array( 'tabs_sticky' => false, 'gallery_ratio' => 1.18, 'gallery_fit' => 'cover', 'thumbnails' => true, 'counter' => false, 'zoom' => true, 'show_rating' => false, 'price_size' => 24, 'name_size' => 22, 'chip_radius' => 18, 'accordion' => false, 'reviews_enabled' => false, 'related_gap' => 18, 'related_ratio' => 1.2, 'button_width' => 74, 'button_height' => 54 ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 22, 'top_spacing' => 68, 'recommendation_layout' => 'carousel', 'gap' => 18, 'card_style' => 'no_shadow', 'card_radius' => 12, 'image_ratio' => 1.2, 'show_name' => true ),
				'account' => array( 'avatar_size' => 68, 'summary_style' => 'minimal', 'show_support' => false ),
			),
			'pet_care' => array(
				'chrome' => array( 'header_height' => 78, 'search_radius' => 22, 'footer_height' => 68, 'button_radius' => 24, 'button_shape' => 'pill' ),
				'catalog' => array( 'show_result_count' => true, 'filter_height' => 52, 'filter_radius' => 20, 'gap' => 12, 'card_style' => 'elevated', 'card_radius' => 18, 'image_ratio' => 1, 'image_swipe' => true, 'show_rating' => true, 'quick_add_style' => 'rounded', 'pagination' => 'automatic', 'per_page' => 16 ),
				'product' => array( 'gallery_ratio' => 1, 'gallery_fit' => 'cover', 'indicators' => true, 'counter' => false, 'show_rating' => true, 'show_badge' => true, 'chip_radius' => 22, 'related_gap' => 12, 'related_ratio' => 1, 'button_width' => 70, 'button_height' => 58 ),
				'wishlist' => array( 'button_style' => 'filled', 'button_radius' => 24, 'top_spacing' => 40, 'recommendation_layout' => 'grid', 'gap' => 12, 'card_style' => 'elevated', 'card_radius' => 18, 'image_ratio' => 1, 'show_name' => true ),
				'account' => array( 'avatar_size' => 80, 'summary_style' => 'elevated' ),
			),
			'family_pop' => array(
				'chrome' => array( 'header_height' => 56, 'header_heights' => array( 'home' => 104, 'category' => 56, 'catalog' => 56, 'product' => 56, 'wishlist' => 56, 'account' => 56, 'size_chart' => 56 ), 'header_shadow' => 'none', 'search_radius' => 20, 'footer_height' => 64, 'footer_shadow' => 'none', 'button_radius' => 28, 'button_shape' => 'pill', 'horizontal_padding' => 16, 'vertical_padding' => 4, 'search_height' => 40, 'search_icon_size' => 20, 'search_border_width' => 1, 'show_voice_search' => false, 'show_cart_badge' => false, 'cart_icon_variant' => 'bag', 'icon_size' => 22, 'title_font_size' => 17, 'inactive_color' => '#66736F', 'label_size' => 11, 'icon_label_gap' => 3, 'border_width' => 1, 'button_text_color' => '#FFFFFF', 'show_button_icon' => false, 'font_family' => 'poppins', 'content_horizontal_padding' => 16 ),
				'catalog' => array( 'filter_sticky' => false, 'show_result_count' => false, 'filter_height' => 52, 'filter_radius' => 0, 'filter_button_style' => 'flat', 'filter_color' => true, 'filter_gap' => 0, 'columns' => 2, 'gap' => 6, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.1, 'image_swipe' => true, 'show_rating' => false, 'show_badge' => true, 'quick_add_style' => 'outline', 'show_wishlist' => false, 'pagination' => 'automatic', 'per_page' => 16, 'outer_horizontal_padding' => 4, 'top_spacing' => 6, 'image_inset' => 0, 'image_radius' => 0, 'content_horizontal_padding' => 4, 'content_top_padding' => 6, 'content_bottom_padding' => 7, 'price_prefix' => 'From ', 'price_size' => 14, 'show_name' => false ),
				'product' => array( 'tabs_enabled' => true, 'tabs_sticky' => false, 'tabs_height' => 52, 'tabs_inactive_color' => '#66736F', 'gallery_ratio' => .88, 'gallery_fit' => 'cover', 'thumbnails' => false, 'indicators' => false, 'counter' => true, 'zoom' => false, 'show_rating' => true, 'show_badge' => false, 'price_size' => 21, 'name_size' => 16, 'variation_style' => 'chips', 'chip_radius' => 20, 'accordion' => true, 'reviews_enabled' => true, 'related_columns' => 2, 'related_gap' => 6, 'related_ratio' => 1.1, 'button_width' => 62, 'button_height' => 52, 'button_text_color' => '#FFFFFF', 'show_button_icon' => false, 'size_chart' => 'chips' ),
				'wishlist' => array( 'access' => 'sign_in_required', 'button_style' => 'outline', 'button_radius' => 28, 'top_spacing' => 44, 'recommendation_layout' => 'grid', 'columns' => 2, 'gap' => 6, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.1, 'show_name' => false ),
				'account' => array( 'avatar_size' => 64, 'summary_style' => 'minimal', 'show_addresses' => true, 'show_support' => true, 'show_logout' => true ),
			),
			'marketplace_plus' => array(
				'chrome' => array( 'header_height' => 70, 'header_shadow' => 'subtle', 'search_radius' => 20, 'footer_height' => 58, 'footer_shadow' => 'subtle', 'button_radius' => 24, 'button_shape' => 'pill', 'horizontal_padding' => 8, 'search_height' => 48, 'search_border_width' => 0, 'show_voice_search' => true, 'show_cart_badge' => true, 'cart_icon_variant' => 'cart' ),
				'catalog' => array( 'filter_sticky' => true, 'show_result_count' => true, 'filter_height' => 46, 'filter_radius' => 18, 'columns' => 3, 'gap' => 6, 'card_style' => 'outlined', 'card_radius' => 6, 'image_ratio' => .88, 'image_swipe' => true, 'show_rating' => true, 'show_badge' => true, 'quick_add_style' => 'filled', 'show_wishlist' => true, 'pagination' => 'automatic', 'per_page' => 24 ),
				'product' => array( 'tabs_enabled' => true, 'tabs_sticky' => true, 'gallery_ratio' => .88, 'gallery_fit' => 'contain', 'thumbnails' => true, 'indicators' => false, 'counter' => true, 'zoom' => true, 'show_rating' => true, 'show_badge' => true, 'price_size' => 24, 'name_size' => 18, 'variation_style' => 'dropdown', 'chip_radius' => 8, 'accordion' => true, 'reviews_enabled' => true, 'related_columns' => 3, 'related_gap' => 6, 'related_ratio' => .88, 'button_width' => 68, 'button_height' => 56, 'size_chart' => 'list' ),
				'wishlist' => array( 'access' => 'sign_in_required', 'button_style' => 'filled', 'button_radius' => 20, 'top_spacing' => 26, 'recommendation_layout' => 'compact', 'columns' => 3, 'gap' => 6, 'card_style' => 'outlined', 'card_radius' => 6, 'image_ratio' => .88, 'show_name' => true ),
				'account' => array( 'avatar_size' => 64, 'summary_style' => 'outlined', 'show_addresses' => true, 'show_support' => true, 'show_logout' => true ),
			),
			'studio_fashion' => array(
				'chrome' => array( 'header_height' => 84, 'header_shadow' => 'none', 'search_radius' => 0, 'footer_height' => 66, 'footer_shadow' => 'none', 'button_radius' => 0, 'button_shape' => 'rectangle', 'horizontal_padding' => 18, 'search_height' => 40, 'search_border_width' => 0, 'show_voice_search' => false, 'show_cart_badge' => false, 'cart_icon_variant' => 'bag' ),
				'catalog' => array( 'filter_sticky' => false, 'show_result_count' => false, 'filter_height' => 46, 'filter_radius' => 0, 'columns' => 2, 'gap' => 2, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.35, 'image_swipe' => true, 'show_rating' => false, 'show_badge' => false, 'quick_add_style' => 'outline', 'show_wishlist' => true, 'pagination' => 'automatic', 'per_page' => 18 ),
				'product' => array( 'tabs_enabled' => false, 'tabs_sticky' => false, 'gallery_ratio' => 1.35, 'gallery_fit' => 'cover', 'thumbnails' => false, 'indicators' => true, 'counter' => false, 'zoom' => true, 'show_rating' => false, 'show_badge' => false, 'price_size' => 22, 'name_size' => 18, 'variation_style' => 'dropdown', 'chip_radius' => 0, 'accordion' => true, 'reviews_enabled' => false, 'related_columns' => 2, 'related_gap' => 2, 'related_ratio' => 1.35, 'button_width' => 100, 'button_height' => 52, 'size_chart' => 'list' ),
				'wishlist' => array( 'access' => 'guest', 'button_style' => 'outline', 'button_radius' => 0, 'top_spacing' => 42, 'recommendation_layout' => 'grid', 'columns' => 2, 'gap' => 2, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.35, 'show_name' => true ),
				'account' => array( 'avatar_size' => 58, 'summary_style' => 'minimal', 'show_addresses' => true, 'show_support' => true, 'show_logout' => true ),
			),
			'editorial_runway' => array(
				'chrome' => array( 'header_height' => 94, 'header_shadow' => 'none', 'search_radius' => 0, 'footer_height' => 74, 'footer_shadow' => 'none', 'button_radius' => 0, 'button_shape' => 'rectangle', 'horizontal_padding' => 20, 'search_height' => 40, 'search_border_width' => 0, 'show_voice_search' => false, 'show_cart_badge' => false, 'cart_icon_variant' => 'bag' ),
				'catalog' => array( 'filter_sticky' => false, 'show_result_count' => false, 'filter_height' => 44, 'filter_radius' => 0, 'columns' => 2, 'gap' => 0, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.5, 'image_swipe' => true, 'show_rating' => false, 'show_badge' => false, 'quick_add_style' => 'outline', 'show_wishlist' => true, 'pagination' => 'automatic', 'per_page' => 12 ),
				'product' => array( 'tabs_enabled' => false, 'tabs_sticky' => false, 'gallery_ratio' => 1.5, 'gallery_fit' => 'cover', 'thumbnails' => false, 'indicators' => false, 'counter' => false, 'zoom' => true, 'show_rating' => false, 'show_badge' => false, 'price_size' => 20, 'name_size' => 19, 'variation_style' => 'dropdown', 'chip_radius' => 0, 'accordion' => false, 'reviews_enabled' => false, 'related_columns' => 2, 'related_gap' => 0, 'related_ratio' => 1.5, 'button_width' => 100, 'button_height' => 54, 'size_chart' => 'table' ),
				'wishlist' => array( 'access' => 'guest', 'button_style' => 'outline', 'button_radius' => 0, 'top_spacing' => 76, 'recommendation_layout' => 'grid', 'columns' => 2, 'gap' => 0, 'card_style' => 'no_shadow', 'card_radius' => 0, 'image_ratio' => 1.5, 'show_name' => true ),
				'account' => array( 'avatar_size' => 52, 'summary_style' => 'minimal', 'show_addresses' => true, 'show_support' => false, 'show_logout' => true ),
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
			),
			is_array( $theme['category_design'] ?? null ) ? $theme['category_design'] : array()
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
		$splash_image = '' !== $logo_url ? $logo_url : self::asset_url( $home_theme, 'category', 6 );
		update_option(
			'kidia_mobile_splash_screen',
			array(
				'enabled'              => true,
				'image_url'            => $splash_image,
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
		$checkout_design = 'minimal' === $product_theme['card_style']
			? 'compact'
			: ( 'elevated' === $product_theme['card_style'] ? 'summary_first' : 'classic' );
		( new Kidia_Mobile_Checkout_Fields_Store() )->save_design( $checkout_design );
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
			'checkout_design' => get_option( Kidia_Mobile_Checkout_Fields_Store::DESIGN_OPTION, 'classic' ),
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
		if ( isset( $snapshot['checkout_design'] ) && is_scalar( $snapshot['checkout_design'] ) ) {
			( new Kidia_Mobile_Checkout_Fields_Store() )->save_design( (string) $snapshot['checkout_design'] );
		}
		foreach ( array( 'splash' => 'kidia_mobile_splash_screen', 'checkout_fields' => Kidia_Mobile_Checkout_Fields_Store::OPTION, 'identity' => self::IDENTITY_OPTION ) as $key => $option ) {
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
		$snapshot['home'] = $this->strip_product_images( $snapshot['home'] ?? array() );
		if ( isset( $snapshot['pages'] ) && is_array( $snapshot['pages'] ) ) {
			foreach ( $snapshot['pages'] as $page => $layout ) {
				$snapshot['pages'][ $page ] = $this->strip_product_images( $layout );
			}
		}
		return $snapshot;
	}

	/** @param mixed $value @return mixed */
	private function strip_product_images( $value, bool $product_context = false ) {
		if ( ! is_array( $value ) ) {
			return $value;
		}
		$type = strtolower( (string) ( $value['type'] ?? $value['source'] ?? $value['action_type'] ?? '' ) );
		$product_context = $product_context || false !== strpos( $type, 'product' );
		foreach ( $value as $key => $item ) {
			if ( $product_context && in_array( (string) $key, array( 'image_id', 'image_url', 'mobile_image_url', 'desktop_image_url', 'background_image', 'thumbnail', 'thumbnail_url', 'attachment_id' ), true ) ) {
				$value[ $key ] = is_int( $item ) ? 0 : '';
				continue;
			}
			$value[ $key ] = $this->strip_product_images( $item, $product_context || 'products' === (string) $key );
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
