
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
				__( 'Fashion Editorial', 'mobishop' ),
				__( 'A premium fashion storefront with editorial banners, spacious collections and modern product cards.', 'mobishop' ),
				array(
					'primary' => '#2C2926', 'soft' => '#F2E9DF', 'ink' => '#211F1D', 'surface' => '#FCFAF7',
					'card_style' => 'no_shadow', 'asset_dir' => 'fashion', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'fashion',
					'product_columns' => 2, 'radius' => 8, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 42,
					'blocks' => array( 'hero_slider', 'category_grid', 'text_block', 'product_carousel', 'banner_grid', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'The new edit', 'mobishop' ), __( 'Shop the collections', 'mobishop' ), __( 'Trending now', 'mobishop' ) ),
				)
			),
			'beauty' => self::theme(
				__( 'Beauty & Wellness', 'mobishop' ),
				__( 'A soft beauty store with calming color, rounded product cards and ingredient-led discovery.', 'mobishop' ),
				array(
					'primary' => '#A45E70', 'soft' => '#FBE9ED', 'ink' => '#3F2930', 'surface' => '#FFF9FA',
					'card_style' => 'elevated', 'asset_dir' => 'beauty', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'beauty',
					'product_columns' => 2, 'radius' => 20, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 32,
					'blocks' => array( 'hero_slider', 'quick_links', 'category_grid', 'product_carousel', 'image_banner', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Glow every day', 'mobishop' ), __( 'Shop by concern', 'mobishop' ), __( 'Self-care favorites', 'mobishop' ) ),
				)
			),
			'electronics' => self::theme(
				__( 'Electronics Pro', 'mobishop' ),
				__( 'A sharp technology store with dark hero media, compact navigation and deal-focused sections.', 'mobishop' ),
				array(
					'primary' => '#0878E5', 'soft' => '#E8F3FF', 'ink' => '#101A2A', 'surface' => '#F6F9FD',
					'card_style' => 'outlined', 'asset_dir' => 'electronics', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'electronics',
					'product_columns' => 2, 'radius' => 12, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 28,
					'blocks' => array( 'promo_strip', 'hero_slider', 'quick_links', 'category_grid', 'product_grid', 'countdown', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Upgrade your everyday', 'mobishop' ), __( 'Top tech categories', 'mobishop' ), __( 'Smart deals', 'mobishop' ) ),
				)
			),
			'home_living' => self::theme(
				__( 'Home & Living', 'mobishop' ),
				__( 'A warm interior store with natural tones, editorial storytelling and curated room collections.', 'mobishop' ),
				array(
					'primary' => '#786248', 'soft' => '#F3ECE2', 'ink' => '#342C23', 'surface' => '#FBF8F3',
					'card_style' => 'no_shadow', 'asset_dir' => 'home_living', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'home_living',
					'product_columns' => 2, 'radius' => 6, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 24,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'banner_grid', 'product_carousel', 'image_banner', 'product_grid' ),
					'sample_copy' => array( __( 'Make space feel yours', 'mobishop' ), __( 'Shop by room', 'mobishop' ), __( 'Curated for home', 'mobishop' ) ),
				)
			),
			'kids_baby' => self::theme(
				__( 'Kids & Baby', 'mobishop' ),
				__( 'A bright family store with playful color, friendly shapes and easy age-based browsing.', 'mobishop' ),
				array(
					'primary' => '#2E8EC7', 'soft' => '#E8F7FC', 'ink' => '#253A46', 'surface' => '#FAFDFE',
					'card_style' => 'elevated', 'asset_dir' => 'kids_baby', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'kids_baby',
					'product_columns' => 2, 'radius' => 22, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 18,
					'blocks' => array( 'hero_slider', 'quick_links', 'category_grid', 'promo_strip', 'product_carousel', 'banner_grid', 'product_grid' ),
					'sample_copy' => array( __( 'Big joy for little ones', 'mobishop' ), __( 'Shop by age', 'mobishop' ), __( 'Loved by families', 'mobishop' ) ),
				)
			),
			'sports_fitness' => self::theme(
				__( 'Sports & Fitness', 'mobishop' ),
				__( 'A high-energy performance store with bold contrast, quick departments and promotional drops.', 'mobishop' ),
				array(
					'primary' => '#F15A24', 'soft' => '#FFF0E8', 'ink' => '#17191B', 'surface' => '#F7F7F7',
					'card_style' => 'outlined', 'asset_dir' => 'sports_fitness', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'sports_fitness',
					'product_columns' => 2, 'radius' => 10, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 38,
					'blocks' => array( 'promo_strip', 'hero_slider', 'quick_links', 'category_grid', 'countdown', 'product_grid', 'product_carousel' ),
					'sample_copy' => array( __( 'Built to move', 'mobishop' ), __( 'Train by category', 'mobishop' ), __( 'Performance picks', 'mobishop' ) ),
				)
			),
			'grocery' => self::theme(
				__( 'Grocery Fresh', 'mobishop' ),
				__( 'A practical grocery store with fast categories, offer strips and dense everyday product discovery.', 'mobishop' ),
				array(
					'primary' => '#238447', 'soft' => '#E9F7ED', 'ink' => '#21362A', 'surface' => '#FBFDFB',
					'card_style' => 'elevated', 'asset_dir' => 'grocery', 'category_layout' => 'compact_grid', 'category_shape' => 'circle',
					'layout_profile' => 'grocery',
					'product_columns' => 3, 'radius' => 14, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 16,
					'blocks' => array( 'promo_strip', 'hero_slider', 'quick_links', 'category_grid', 'countdown', 'product_carousel', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Fresh for today', 'mobishop' ), __( 'Shop essentials', 'mobishop' ), __( 'Weekly value', 'mobishop' ) ),
				)
			),
			'luxury' => self::theme(
				__( 'Luxury Boutique', 'mobishop' ),
				__( 'A refined dark boutique with dramatic imagery, minimal chrome and gallery-style products.', 'mobishop' ),
				array(
					'primary' => '#B58A45', 'soft' => '#F3E9D6', 'ink' => '#17130E', 'surface' => '#FCFAF6',
					'card_style' => 'no_shadow', 'asset_dir' => 'luxury', 'category_layout' => 'visual_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'luxury',
					'product_columns' => 2, 'radius' => 2, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 50,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'image_banner', 'product_carousel', 'banner_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Objects of distinction', 'mobishop' ), __( 'The collections', 'mobishop' ), __( 'Signature pieces', 'mobishop' ) ),
				)
			),
			'coffee' => self::theme(
				__( 'Coffee & Gourmet', 'mobishop' ),
				__( 'A crafted food store with rich imagery, story sections and specialty product collections.', 'mobishop' ),
				array(
					'primary' => '#8A4B2A', 'soft' => '#F5E9DE', 'ink' => '#33231A', 'surface' => '#FCF8F3',
					'card_style' => 'elevated', 'asset_dir' => 'coffee', 'category_layout' => 'visual_grid', 'category_shape' => 'circle',
					'layout_profile' => 'coffee',
					'product_columns' => 2, 'radius' => 16, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 36,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'promo_strip', 'product_carousel', 'image_banner', 'product_grid' ),
					'sample_copy' => array( __( 'Crafted for slow mornings', 'mobishop' ), __( 'Explore the roast', 'mobishop' ), __( 'Gourmet favorites', 'mobishop' ) ),
				)
			),
			'multi_store' => self::theme(
				__( 'Multi Store', 'mobishop' ),
				__( 'A flexible marketplace for large mixed catalogs with fast navigation, offers and compact grids.', 'mobishop' ),
				array(
					'primary' => '#195BC7', 'soft' => '#EAF1FF', 'ink' => '#16243A', 'surface' => '#F7F9FC',
					'card_style' => 'outlined', 'asset_dir' => 'multi_store', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'multi_store',
					'product_columns' => 3, 'radius' => 12, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 12,
					'blocks' => array( 'quick_links', 'hero_slider', 'promo_strip', 'category_grid', 'countdown', 'product_grid', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Everything in one place', 'mobishop' ), __( 'Browse departments', 'mobishop' ), __( 'Best value today', 'mobishop' ) ),
				)
			),
			'jewelry' => self::theme(
				__( 'Jewelry Atelier', 'mobishop' ),
				__( 'A luminous jewelry boutique with editorial collections, fine-detail product cards and elegant gifting.', 'mobishop' ),
				array(
					'primary' => '#9A6A38', 'soft' => '#F5EBDD', 'ink' => '#2B2118', 'surface' => '#FFFDFC',
					'card_style' => 'no_shadow', 'asset_dir' => 'jewelry', 'category_layout' => 'visual_grid', 'category_shape' => 'circle',
					'layout_profile' => 'jewelry',
					'product_columns' => 2, 'radius' => 12, 'header_style' => 'transparent', 'search_style' => 'icon', 'overlay' => 28,
					'blocks' => array( 'hero_slider', 'quick_links', 'text_block', 'category_grid', 'product_carousel', 'banner_grid', 'product_grid' ),
					'sample_copy' => array( __( 'Made to be remembered', 'mobishop' ), __( 'Shop fine collections', 'mobishop' ), __( 'New signatures', 'mobishop' ) ),
				)
			),
			'pet_care' => self::theme(
				__( 'Pet Care', 'mobishop' ),
				__( 'A friendly pet store with playful navigation, practical product discovery and warm lifestyle imagery.', 'mobishop' ),
				array(
					'primary' => '#168578', 'soft' => '#E6F6F2', 'ink' => '#203A36', 'surface' => '#FBFEFD',
					'card_style' => 'elevated', 'asset_dir' => 'pet_care', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'pet_care',
					'product_columns' => 2, 'radius' => 18, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 20,
					'blocks' => array( 'hero_slider', 'quick_links', 'category_grid', 'promo_strip', 'product_carousel', 'image_banner', 'product_grid' ),
					'sample_copy' => array( __( 'Better days for every pet', 'mobishop' ), __( 'Shop by companion', 'mobishop' ), __( 'Pet parent favorites', 'mobishop' ) ),
				)
			),
			'family_pop' => self::theme(
				__( 'Family Pop', 'mobishop' ),
				__( 'A bright family-fashion storefront with quick circular discovery, friendly promotions and clean product-first shopping.', 'mobishop' ),
				array(
					'primary' => '#F04F5F', 'soft' => '#E5F6F2', 'ink' => '#151515', 'surface' => '#FFFFFF',
					'card_style' => 'no_shadow', 'asset_dir' => 'family_pop', 'category_layout' => 'circular_grid', 'category_shape' => 'circle',
					'layout_profile' => 'family_pop',
					'product_columns' => 2, 'radius' => 18, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 18,
					'blocks' => array( 'category_grid', 'image_banner', 'quick_links', 'banner_grid', 'product_carousel', 'product_grid' ),
					'sample_copy' => array( __( 'Made for every family moment', 'mobishop' ), __( 'Shop by age', 'mobishop' ), __( 'Family favorites', 'mobishop' ) ),
					'home_design' => array(
						'hero_ratio' => 1.0, 'hero_radius' => 12, 'hero_padding' => 16, 'hero_indicators' => 'image_bottom',
						'category_layout' => 'grid', 'category_columns' => 3, 'category_size' => 64, 'category_gap' => 12,
						'quick_layout' => 'carousel', 'quick_columns' => 4, 'quick_size' => 64, 'quick_gap' => 12,
						'product_columns' => 2, 'product_ratio' => 1.22, 'product_radius' => 12, 'product_style' => 'outlined',
						'product_rating' => false, 'product_badge' => true, 'product_swipe' => true, 'product_quick_add' => true, 'product_wishlist' => true,
						'banner_layout' => 'featured', 'banner_ratio' => 1.33, 'banner_gap' => 10, 'image_banner_ratio' => 1.33,
					),
					'category_design' => array(
						'category_layout' => 'default', 'navigation_mode' => 'separate_page', 'card_gap' => 12, 'card_height' => 84, 'card_style' => 'outlined',
						'card_radius' => 16, 'image_size' => 68, 'image_shape' => 'rounded', 'image_radius' => 14,
						'image_text_gap' => 14, 'font_size' => 16, 'font_weight' => 600, 'line_height' => 125,
						'text_align' => 'start', 'image_position' => 'right', 'show_arrow' => true, 'arrow_size' => 20, 'horizontal_padding' => 14,
					),
				)
			),
			'marketplace_plus' => self::theme(
				__( 'Marketplace Plus', 'mobishop' ),
				__( 'A dense all-departments marketplace with persistent search, deal-led grids, compact navigation and information-rich products.', 'mobishop' ),
				array(
					'primary' => '#F59B23', 'soft' => '#E7F3F5', 'ink' => '#132536', 'surface' => '#F5F6F6',
					'card_style' => 'outlined', 'asset_dir' => 'marketplace_plus', 'category_layout' => 'compact_grid', 'category_shape' => 'rounded',
					'layout_profile' => 'marketplace_plus',
					'product_columns' => 3, 'radius' => 8, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 8,
					'blocks' => array( 'quick_links', 'promo_strip', 'hero_slider', 'category_grid', 'countdown', 'product_grid', 'banner_grid', 'product_carousel', 'brand_carousel' ),
					'sample_copy' => array( __( 'Everything you need, one place', 'mobishop' ), __( 'Browse departments', 'mobishop' ), __( 'Deals for you', 'mobishop' ) ),
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
			'amazon_marketplace' => self::theme(
				__( 'Amazon Marketplace', 'mobishop' ),
				__( 'An Amazon-inspired shopping application with persistent search, delivery context, dense deals, department discovery and information-rich commerce pages.', 'mobishop' ),
				array(
					// These swatches are preview fallbacks only. Applying the preset keeps
					// the connected store logo and brand palette selected in Setup.
					'primary' => '#2F806E', 'soft' => '#EAF6F2', 'ink' => '#172B34', 'surface' => '#FFFFFF',
					'card_style' => 'outlined', 'asset_dir' => 'marketplace_plus', 'category_layout' => 'compact_grid', 'category_shape' => 'circle',
					'layout_profile' => 'amazon_marketplace',
					'product_columns' => 2, 'radius' => 8, 'header_style' => 'standard', 'search_style' => 'bar', 'overlay' => 8,
					'blocks' => array( 'promo_strip', 'quick_links', 'hero_slider', 'category_grid', 'countdown', 'product_carousel', 'banner_grid', 'product_grid', 'brand_carousel' ),
					'sample_copy' => array( __( 'Shop everything you need', 'mobishop' ), __( 'Shop by department', 'mobishop' ), __( 'Deals for you', 'mobishop' ) ),
					'home_design' => array(
						'hero_ratio' => 2.15, 'hero_radius' => 0, 'hero_padding' => 0, 'hero_indicators' => 'image_bottom',
						'category_layout' => 'carousel', 'category_columns' => 4, 'category_size' => 72, 'category_gap' => 8,
						'quick_layout' => 'grid', 'quick_columns' => 4, 'quick_size' => 68, 'quick_gap' => 8,
						'product_columns' => 2, 'product_ratio' => .92, 'product_radius' => 8, 'product_style' => 'outlined',
						'product_rating' => true, 'product_badge' => true, 'product_swipe' => true, 'product_quick_add' => true, 'product_wishlist' => true,
						'banner_layout' => 'equal', 'banner_ratio' => 1.15, 'banner_gap' => 8, 'image_banner_ratio' => 1.15,
					),
					'category_design' => array(
						'navigation_mode' => 'separate_page', 'grid_columns' => 3, 'card_gap' => 8, 'card_style' => 'outlined',
						'card_radius' => 8, 'image_size' => 72, 'image_shape' => 'circle', 'image_text_gap' => 8,
						'font_size' => 14, 'font_weight' => 600, 'text_align' => 'center', 'show_arrow' => false,
					),
				)
			),
			'studio_fashion' => self::theme(
				__( 'Studio Fashion', 'mobishop' ),
				__( 'A minimal editorial fashion shop with quiet navigation, full-width campaigns and clean garment-led product grids.', 'mobishop' ),
				array(
					'primary' => '#C4142B', 'soft' => '#F1F0EE', 'ink' => '#111111', 'surface' => '#FAF9F7',
					'card_style' => 'no_shadow', 'asset_dir' => 'studio_fashion', 'category_layout' => 'default', 'category_shape' => 'rounded',
					'layout_profile' => 'studio_fashion',
					'product_columns' => 2, 'radius' => 0, 'header_style' => 'standard', 'search_style' => 'icon', 'overlay' => 10,
					'blocks' => array( 'hero_slider', 'text_block', 'category_grid', 'banner_grid', 'product_grid', 'image_banner', 'product_carousel' ),
					'sample_copy' => array( __( 'The new edit', 'mobishop' ), __( 'Shop by collection', 'mobishop' ), __( 'New arrivals', 'mobishop' ) ),
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
				__( 'Editorial Runway', 'mobishop' ),
				__( 'An immersive high-fashion gallery with full-bleed campaigns, near-invisible chrome and spacious monochrome commerce pages.', 'mobishop' ),
				array(
					'primary' => '#111111', 'soft' => '#EDEAE4', 'ink' => '#080808', 'surface' => '#FFFFFF',
					'card_style' => 'no_shadow', 'asset_dir' => 'editorial_runway', 'category_layout' => 'visual_grid', 'category_shape' => 'square',
					'layout_profile' => 'editorial_runway',
					'product_columns' => 2, 'radius' => 0, 'header_style' => 'transparent', 'searc…23064 tokens truncated…_cart_badge' => false, 'cart_icon_variant' => 'bag', 'icon_size' => 24, 'title_font_size' => 18, 'inactive_color' => '#66736F', 'label_size' => 11, 'icon_label_gap' => 3, 'border_width' => 1, 'button_text_color' => '#FFFFFF', 'show_button_icon' => false, 'font_family' => 'poppins', 'content_horizontal_padding' => 16 ),
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
			'amazon_marketplace' => array(
				'chrome' => array( 'header_height' => 116, 'header_heights' => array( 'home' => 116, 'category' => 70, 'catalog' => 70, 'product' => 64, 'wishlist' => 64, 'account' => 64, 'size_chart' => 64 ), 'header_shadow' => 'none', 'search_radius' => 22, 'footer_height' => 62, 'footer_shadow' => 'subtle', 'button_radius' => 22, 'button_shape' => 'pill', 'horizontal_padding' => 8, 'vertical_padding' => 6, 'search_height' => 46, 'search_icon_size' => 21, 'search_border_width' => 1, 'show_voice_search' => true, 'show_cart_badge' => true, 'cart_icon_variant' => 'cart', 'icon_size' => 24, 'label_size' => 11, 'icon_label_gap' => 3, 'content_horizontal_padding' => 8 ),
				'catalog' => array( 'filter_sticky' => true, 'show_result_count' => true, 'filter_height' => 46, 'filter_radius' => 18, 'columns' => 2, 'gap' => 8, 'card_style' => 'outlined', 'card_radius' => 8, 'image_ratio' => .92, 'image_swipe' => true, 'show_rating' => true, 'show_badge' => true, 'quick_add_style' => 'filled', 'show_wishlist' => true, 'pagination' => 'automatic', 'per_page' => 20, 'outer_horizontal_padding' => 8, 'top_spacing' => 8, 'image_inset' => 4, 'image_radius' => 6, 'content_horizontal_padding' => 8, 'content_top_padding' => 5, 'content_bottom_padding' => 8, 'price_size' => 16, 'show_name' => true ),
				'product' => array( 'tabs_enabled' => true, 'tabs_sticky' => true, 'gallery_ratio' => .95, 'gallery_fit' => 'contain', 'thumbnails' => false, 'indicators' => false, 'counter' => true, 'zoom' => true, 'show_rating' => true, 'show_badge' => true, 'price_size' => 26, 'name_size' => 17, 'variation_style' => 'chips', 'chip_radius' => 8, 'accordion' => true, 'reviews_enabled' => true, 'related_columns' => 2, 'related_gap' => 8, 'related_ratio' => .92, 'button_width' => 74, 'button_height' => 52, 'button_text_color' => '#FFFFFF', 'show_button_icon' => false, 'size_chart' => 'list' ),
				'wishlist' => array( 'access' => 'sign_in_required', 'button_style' => 'filled', 'button_radius' => 22, 'top_spacing' => 24, 'recommendation_layout' => 'grid', 'columns' => 2, 'gap' => 8, 'card_style' => 'outlined', 'card_radius' => 8, 'image_ratio' => .92, 'show_name' => true ),
				'account' => array( 'avatar_size' => 58, 'summary_style' => 'minimal', 'show_addresses' => true, 'show_support' => true, 'show_logout' => true ),
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
	private function apply_extras( array $home_theme, array $product_theme, string $primary, string $secondary, string $app_name, string $logo_url ): void {
		update_option(
			'kidia_mobile_splash_screen',
			$this->build_splash_settings( $home_theme, $primary, $secondary, $app_name, $logo_url ),
			false
		);
		$checkout_design = 'minimal' === $product_theme['card_style']
			? 'compact'
			: ( 'elevated' === $product_theme['card_style'] ? 'summary_first' : 'classic' );
		( new Kidia_Mobile_Checkout_Fields_Store() )->save_design( $checkout_design );
	}

	/**
	 * Builds the branded startup screen shared by every built-in theme preview
	 * and the installed application.
	 *
	 * @param array<string,mixed> $theme
	 * @return array<string,mixed>
	 */
	private function build_splash_settings( array $theme, string $primary, string $secondary, string $app_name, string $logo_url ): array {
		$splash_image = $logo_url;
		$foreground   = $this->readable_foreground( $primary, $secondary );
		return array(
			'enabled'              => true,
			'image_url'            => $splash_image,
			'background_color'     => $primary,
			'background_color_end' => $secondary,
			'duration_ms'          => 1800,
			'image_width'          => 140,
			'image_height'         => 140,
			'image_fit'            => 'contain',
			'image_shape'          => 'none',
			'show_store_name'      => true,
			'store_name'           => $app_name,
			'text_color'           => $foreground,
			'show_loader'          => true,
			'loader_color'         => $foreground,
		);
	}

	private function readable_foreground( string $primary, string $secondary ): string {
		$luminance = static function ( string $hex ): float {
			$hex = ltrim( $hex, '#' );
			if ( 6 !== strlen( $hex ) ) {
				return 0.0;
			}
			$channels = array_map(
				static function ( int $offset ) use ( $hex ): float {
					$value = hexdec( substr( $hex, $offset, 2 ) ) / 255;
					return $value <= 0.03928 ? $value / 12.92 : pow( ( $value + 0.055 ) / 1.055, 2.4 );
				},
				array( 0, 2, 4 )
			);
			return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2];
		};
		return ( $luminance( $primary ) + $luminance( $secondary ) ) / 2 > 0.42 ? '#111111' : '#FFFFFF';
	}

	private function block_name( string $type, array $copy ): string {
		$names = array(
			'hero_slider'     => $copy[0] ?? __( 'Featured collection', 'mobishop' ),
			'category_grid'   => $copy[1] ?? __( 'Shop by category', 'mobishop' ),
			'product_grid'    => $copy[2] ?? __( 'Products for you', 'mobishop' ),
			'product_carousel'=> $copy[2] ?? __( 'Popular products', 'mobishop' ),
			'promo_strip'     => __( 'Store benefits', 'mobishop' ),
			'quick_links'     => __( 'Quick links', 'mobishop' ),
			'brand_carousel'  => __( 'Featured brands', 'mobishop' ),
			'countdown'       => __( 'Flash sale', 'mobishop' ),
			'image_banner'    => __( 'Collection story', 'mobishop' ),
			'banner_grid'     => __( 'Seasonal collections', 'mobishop' ),
			'text_block'      => __( 'Brand story', 'mobishop' ),
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
