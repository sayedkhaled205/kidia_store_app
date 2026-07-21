<?php
/** Shared storage and schemas for non-home application page builders. */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Page_Layout_Store {
	private const OPTION_PREFIX = 'kidia_mobile_page_layout_';
	private const VERSION = 16;

	/** @return array<string,string> */
	public static function pages(): array {
		return array(
			'home'     => __( 'Home Page', 'kidia-mobile-cms' ),
			'category' => __( 'Category Page', 'kidia-mobile-cms' ),
			'catalog'  => __( 'Catalog Page', 'kidia-mobile-cms' ),
			'product'  => __( 'Product Page', 'kidia-mobile-cms' ),
			'wishlist' => __( 'Wishlist Page', 'kidia-mobile-cms' ),
			'account'  => __( 'Account Page', 'kidia-mobile-cms' ),
		);
	}

	public static function is_page( string $page ): bool {
		return isset( self::pages()[ sanitize_key( $page ) ] );
	}

	/** @return array<int,array<string,mixed>> */
	public static function header_fields(): array {
		return array(
			self::field( 'layout_json', __( 'Header element layout', 'kidia-mobile-cms' ), 'json', '' ),
			self::field( 'compact_layout_json', __( 'Collapsed header element layout', 'kidia-mobile-cms' ), 'json', '' ),
			self::field( 'collapse_on_scroll', __( 'Show collapsed header while page is scrolled', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'collapse_transition', __( 'Collapsed header transition', 'kidia-mobile-cms' ), 'select', 'smooth_compact', array( 'smooth_compact' => __( 'Smooth compact Search + Cart', 'kidia-mobile-cms' ), 'instant' => __( 'Instant (no animation)', 'kidia-mobile-cms' ), 'fade' => __( 'Fade in / out', 'kidia-mobile-cms' ), 'slide' => __( 'Slide up', 'kidia-mobile-cms' ), 'fade_slide' => __( 'Fade + slide', 'kidia-mobile-cms' ), 'scale' => __( 'Shrink / scale', 'kidia-mobile-cms' ) ) ),
			self::field( 'collapse_speed', __( 'Transition speed', 'kidia-mobile-cms' ), 'select', 'medium', array( 'fast' => __( 'Fast', 'kidia-mobile-cms' ), 'medium' => __( 'Medium', 'kidia-mobile-cms' ), 'slow' => __( 'Slow', 'kidia-mobile-cms' ) ) ),
			self::field( 'compact_height', __( 'Collapsed header height', 'kidia-mobile-cms' ), 'number', 60, array(), 44, 100 ),
			self::field( 'compact_style', __( 'Collapsed header shape', 'kidia-mobile-cms' ), 'select', 'standard', array( 'standard' => __( 'Full width', 'kidia-mobile-cms' ), 'floating' => __( 'Floating card', 'kidia-mobile-cms' ), 'pill' => __( 'Pill', 'kidia-mobile-cms' ), 'transparent' => __( 'Transparent', 'kidia-mobile-cms' ) ) ),
			self::field( 'compact_background_color', __( 'Collapsed header background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'compact_horizontal_padding', __( 'Collapsed header horizontal padding', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 32 ),
			self::field( 'compact_side_margin', __( 'Collapsed header outside side space', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 32 ),
			self::field( 'compact_radius', __( 'Collapsed header corner radius', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 40 ),
			self::field( 'compact_border_width', __( 'Collapsed header border width', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 6 ),
			self::field( 'compact_border_color', __( 'Collapsed header border color', 'kidia-mobile-cms' ), 'color', '#E2E6E4' ),
			self::field( 'compact_shadow', __( 'Collapsed header shadow', 'kidia-mobile-cms' ), 'select', 'subtle', array( 'none' => __( 'None', 'kidia-mobile-cms' ), 'subtle' => __( 'Subtle', 'kidia-mobile-cms' ), 'strong' => __( 'Strong', 'kidia-mobile-cms' ) ) ),
			self::field( 'title', __( 'Page title', 'kidia-mobile-cms' ), 'text', '' ),
			self::field( 'subtitle', __( 'Subtitle', 'kidia-mobile-cms' ), 'text', '' ),
			self::field( 'logo_url', __( 'Logo image', 'kidia-mobile-cms' ), 'image', '' ),
			self::field( 'logo_text', __( 'Logo text (used when no image is selected)', 'kidia-mobile-cms' ), 'text', __( 'Kidia', 'kidia-mobile-cms' ) ),
			self::field( 'logo_text_color', __( 'Logo text color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'logo_width', __( 'Logo width', 'kidia-mobile-cms' ), 'number', 118, array(), 32, 220 ),
			self::field( 'logo_height', __( 'Logo height', 'kidia-mobile-cms' ), 'number', 38, array(), 20, 80 ),
			self::field( 'style', __( 'Header style', 'kidia-mobile-cms' ), 'select', 'standard', array( 'standard' => __( 'Standard', 'kidia-mobile-cms' ), 'transparent' => __( 'Transparent', 'kidia-mobile-cms' ) ) ),
			self::field( 'height', __( 'Height', 'kidia-mobile-cms' ), 'number', 64, array(), 48, 120 ),
			self::field( 'margin_top', __( 'Merge up', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Merge down', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_up', __( 'Space up', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_down', __( 'Space down', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'row_gap', __( 'Space between rows', 'kidia-mobile-cms' ), 'number', 8, array(), 0, 24 ),
			self::field( 'vertical_padding', __( 'Vertical padding', 'kidia-mobile-cms' ), 'number', 8, array(), 0, 24 ),
			self::field( 'background_color', __( 'Background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'border_color', __( 'Border color', 'kidia-mobile-cms' ), 'color', '#E2E6E4' ),
			self::field( 'border_width', __( 'Border width', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 6 ),
			self::field( 'corner_radius', __( 'Corner radius', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 32 ),
			self::field( 'title_color', __( 'Title color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'icon_gap', __( 'Icon spacing', 'kidia-mobile-cms' ), 'number', 6, array(), 0, 24 ),
			self::field( 'icon_size', __( 'Default icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 14, 40 ),
			self::field( 'icon_color', __( 'Default icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'horizontal_padding', __( 'Horizontal padding', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 32 ),
			self::field( 'shadow', __( 'Shadow', 'kidia-mobile-cms' ), 'select', 'subtle', array( 'none' => __( 'None', 'kidia-mobile-cms' ), 'subtle' => __( 'Subtle', 'kidia-mobile-cms' ), 'strong' => __( 'Strong', 'kidia-mobile-cms' ) ) ),
			self::field( 'show_back', __( 'Show back button', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_search', __( 'Show search', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_cart', __( 'Show cart', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show wishlist', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_account', __( 'Show account', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_orders', __( 'Show orders', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_support', __( 'Show customer support', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_menu', __( 'Show menu', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_count', __( 'Show page item count', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'back_style', __( 'Back icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'back_icon_variant', __( 'Back icon design', 'kidia-mobile-cms' ), 'select', 'arrow', array( 'arrow' => __( 'Arrow', 'kidia-mobile-cms' ), 'chevron' => __( 'Chevron', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded arrow', 'kidia-mobile-cms' ) ) ),
			self::field( 'back_size', __( 'Back icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'back_color', __( 'Back icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'search_style', __( 'Search style', 'kidia-mobile-cms' ), 'select', 'icon', array( 'icon' => __( 'Icon', 'kidia-mobile-cms' ), 'bar' => __( 'Search bar', 'kidia-mobile-cms' ) ) ),
			self::field( 'search_icon_style', __( 'Search icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'search_icon_variant', __( 'Search icon design', 'kidia-mobile-cms' ), 'select', 'rounded', array( 'rounded' => __( 'Rounded', 'kidia-mobile-cms' ), 'classic' => __( 'Classic', 'kidia-mobile-cms' ), 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ) ) ),
			self::field( 'search_icon_size', __( 'Search icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'search_icon_color', __( 'Search icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'search_icon_background', __( 'Search icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'search_icon_radius', __( 'Search icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'search_placeholder', __( 'Search placeholder', 'kidia-mobile-cms' ), 'text', __( 'Search products', 'kidia-mobile-cms' ) ),
			self::field( 'search_height', __( 'Search height', 'kidia-mobile-cms' ), 'number', 40, array(), 32, 64 ),
			self::field( 'search_width_percent', __( 'Search width (% of its column)', 'kidia-mobile-cms' ), 'number', 100, array(), 30, 100 ),
			self::field( 'search_radius', __( 'Search radius', 'kidia-mobile-cms' ), 'number', 14, array(), 0, 32 ),
			self::field( 'search_background', __( 'Search background', 'kidia-mobile-cms' ), 'color', '#F1F3F4' ),
			self::field( 'search_text_color', __( 'Search text color', 'kidia-mobile-cms' ), 'color', '#5F6368' ),
			self::field( 'search_border_color', __( 'Search border color', 'kidia-mobile-cms' ), 'color', '#DDE3E8' ),
			self::field( 'search_border_width', __( 'Search border width', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 6 ),
			self::field( 'show_voice_search', __( 'Show voice search', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'cart_style', __( 'Cart icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'cart_icon_variant', __( 'Cart icon design', 'kidia-mobile-cms' ), 'select', 'bag', array( 'bag' => __( 'Shopping bag', 'kidia-mobile-cms' ), 'cart' => __( 'Shopping cart', 'kidia-mobile-cms' ), 'basket' => __( 'Shopping basket', 'kidia-mobile-cms' ) ) ),
			self::field( 'show_cart_badge', __( 'Show cart item count', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'cart_badge_shape', __( 'Cart count shape', 'kidia-mobile-cms' ), 'select', 'circle', array( 'circle' => __( 'Circle', 'kidia-mobile-cms' ), 'rounded_square' => __( 'Rounded square', 'kidia-mobile-cms' ), 'pill' => __( 'Pill', 'kidia-mobile-cms' ) ) ),
			self::field( 'cart_badge_size', __( 'Cart count size', 'kidia-mobile-cms' ), 'number', 18, array(), 12, 30 ),
			self::field( 'cart_badge_background', __( 'Cart count background', 'kidia-mobile-cms' ), 'color', '#E94B5F' ),
			self::field( 'cart_badge_text_color', __( 'Cart count text color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'cart_size', __( 'Cart icon size', 'kidia-mobile-cms' ), 'number', 28, array(), 16, 40 ),
			self::field( 'cart_color', __( 'Cart icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'cart_background', __( 'Cart icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'cart_radius', __( 'Cart icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'wishlist_style', __( 'Wishlist icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'wishlist_icon_variant', __( 'Wishlist icon design', 'kidia-mobile-cms' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded heart', 'kidia-mobile-cms' ), 'bookmark' => __( 'Bookmark', 'kidia-mobile-cms' ) ) ),
			self::field( 'wishlist_size', __( 'Wishlist icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'wishlist_color', __( 'Wishlist icon color', 'kidia-mobile-cms' ), 'color', '#E53935' ),
			self::field( 'wishlist_background', __( 'Wishlist icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'wishlist_radius', __( 'Wishlist icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'account_style', __( 'Account style', 'kidia-mobile-cms' ), 'select', 'icon', array( 'icon' => __( 'Outline icon', 'kidia-mobile-cms' ), 'filled' => __( 'Filled icon', 'kidia-mobile-cms' ), 'avatar' => __( 'Avatar', 'kidia-mobile-cms' ) ) ),
			self::field( 'account_icon_variant', __( 'Account icon design', 'kidia-mobile-cms' ), 'select', 'person', array( 'person' => __( 'Person', 'kidia-mobile-cms' ), 'circle' => __( 'Person circle', 'kidia-mobile-cms' ), 'profile' => __( 'Profile', 'kidia-mobile-cms' ) ) ),
			self::field( 'account_icon_size', __( 'Account icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'account_icon_color', __( 'Account icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'account_background', __( 'Account icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'account_radius', __( 'Account icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'account_label', __( 'Account label', 'kidia-mobile-cms' ), 'text', __( 'Account', 'kidia-mobile-cms' ) ),
			self::field( 'show_account_label', __( 'Show account label', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'orders_icon_variant', __( 'Orders icon design', 'kidia-mobile-cms' ), 'select', 'receipt', array( 'receipt' => __( 'Receipt', 'kidia-mobile-cms' ), 'box' => __( 'Package', 'kidia-mobile-cms' ), 'list' => __( 'Order list', 'kidia-mobile-cms' ) ) ),
			self::field( 'orders_size', __( 'Orders icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'orders_color', __( 'Orders icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'orders_background', __( 'Orders icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'orders_radius', __( 'Orders icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'support_icon_variant', __( 'Support icon design', 'kidia-mobile-cms' ), 'select', 'headset', array( 'headset' => __( 'Headset', 'kidia-mobile-cms' ), 'support' => __( 'Support agent', 'kidia-mobile-cms' ), 'chat' => __( 'Chat', 'kidia-mobile-cms' ) ) ),
			self::field( 'support_size', __( 'Support icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'support_color', __( 'Support icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'support_background', __( 'Support icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'support_radius', __( 'Support icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'menu_icon_variant', __( 'Menu icon design', 'kidia-mobile-cms' ), 'select', 'menu', array( 'menu' => __( 'Menu lines', 'kidia-mobile-cms' ), 'dots' => __( 'Menu dots', 'kidia-mobile-cms' ), 'grid' => __( 'Menu grid', 'kidia-mobile-cms' ) ) ),
			self::field( 'menu_size', __( 'Menu icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'menu_color', __( 'Menu icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'menu_background', __( 'Menu icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'menu_radius', __( 'Menu icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public static function footer_fields(): array {
		return array(
			self::field( 'layout_json', __( 'Footer element layout', 'kidia-mobile-cms' ), 'json', '' ),
			self::field( 'hide_on_scroll', __( 'Hide while scrolling down', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'style', __( 'Footer style', 'kidia-mobile-cms' ), 'select', 'navigation', array( 'navigation' => __( 'Bottom navigation', 'kidia-mobile-cms' ), 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'product_action' => __( 'Product action bar', 'kidia-mobile-cms' ) ) ),
			self::field( 'height', __( 'Height', 'kidia-mobile-cms' ), 'number', 76, array(), 48, 100 ),
			self::field( 'margin_top', __( 'Merge up', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Merge down', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_up', __( 'Space up', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_down', __( 'Space down', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'background_color', __( 'Background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'shadow', __( 'Shadow', 'kidia-mobile-cms' ), 'select', 'subtle', array( 'none' => __( 'None', 'kidia-mobile-cms' ), 'subtle' => __( 'Subtle', 'kidia-mobile-cms' ), 'strong' => __( 'Strong', 'kidia-mobile-cms' ) ) ),
			self::field( 'top_radius', __( 'Top corner radius', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 32 ),
			self::field( 'horizontal_padding', __( 'Horizontal padding', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 32 ),
			self::field( 'side_spacing_percent', __( 'Outside side spacing (%)', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 25 ),
			self::field( 'icon_size', __( 'Default icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 14, 40 ),
			self::field( 'label_size', __( 'Label size', 'kidia-mobile-cms' ), 'number', 11, array(), 8, 20 ),
			self::field( 'icon_label_gap', __( 'Icon and label spacing', 'kidia-mobile-cms' ), 'number', 3, array(), 0, 12 ),
			self::field( 'border_color', __( 'Top border color', 'kidia-mobile-cms' ), 'color', '#E2E6E4' ),
			self::field( 'border_width', __( 'Top border width', 'kidia-mobile-cms' ), 'number', 1, array(), 0, 6 ),
			self::field( 'safe_area', __( 'Respect safe area', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'active_color', __( 'Active color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ),
			self::field( 'inactive_color', __( 'Inactive color', 'kidia-mobile-cms' ), 'color', '#6B7280' ),
			self::field( 'show_labels', __( 'Show labels', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_home', __( 'Show Home', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_categories', __( 'Show Categories', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show Wishlist', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_account', __( 'Show Account', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_search', __( 'Show Search', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_cart', __( 'Show Cart', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_orders', __( 'Show Orders', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'home_icon_variant', __( 'Home icon design', 'kidia-mobile-cms' ), 'select', 'home', array( 'home' => __( 'Home', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded home', 'kidia-mobile-cms' ), 'filled' => __( 'Filled home', 'kidia-mobile-cms' ) ) ),
			self::field( 'home_label', __( 'Home label', 'kidia-mobile-cms' ), 'text', __( 'Home', 'kidia-mobile-cms' ) ),
			self::field( 'categories_icon_variant', __( 'Categories icon design', 'kidia-mobile-cms' ), 'select', 'grid', array( 'grid' => __( 'Grid', 'kidia-mobile-cms' ), 'category' => __( 'Category shapes', 'kidia-mobile-cms' ), 'list' => __( 'List', 'kidia-mobile-cms' ) ) ),
			self::field( 'categories_label', __( 'Categories label', 'kidia-mobile-cms' ), 'text', __( 'Categories', 'kidia-mobile-cms' ) ),
			self::field( 'cart_icon_variant', __( 'Cart icon design', 'kidia-mobile-cms' ), 'select', 'bag', array( 'bag' => __( 'Shopping bag', 'kidia-mobile-cms' ), 'cart' => __( 'Shopping cart', 'kidia-mobile-cms' ), 'basket' => __( 'Shopping basket', 'kidia-mobile-cms' ) ) ),
			self::field( 'cart_label', __( 'Cart label', 'kidia-mobile-cms' ), 'text', __( 'Cart', 'kidia-mobile-cms' ) ),
			self::field( 'search_icon_variant', __( 'Search icon design', 'kidia-mobile-cms' ), 'select', 'rounded', array( 'rounded' => __( 'Rounded', 'kidia-mobile-cms' ), 'classic' => __( 'Classic', 'kidia-mobile-cms' ), 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ) ) ),
			self::field( 'search_label', __( 'Search label', 'kidia-mobile-cms' ), 'text', __( 'Search', 'kidia-mobile-cms' ) ),
			self::field( 'wishlist_icon_variant', __( 'Wishlist icon design', 'kidia-mobile-cms' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded heart', 'kidia-mobile-cms' ), 'bookmark' => __( 'Bookmark', 'kidia-mobile-cms' ) ) ),
			self::field( 'wishlist_label', __( 'Wishlist label', 'kidia-mobile-cms' ), 'text', __( 'Wishlist', 'kidia-mobile-cms' ) ),
			self::field( 'account_icon_variant', __( 'Account icon design', 'kidia-mobile-cms' ), 'select', 'person', array( 'person' => __( 'Person', 'kidia-mobile-cms' ), 'circle' => __( 'Person circle', 'kidia-mobile-cms' ), 'profile' => __( 'Profile', 'kidia-mobile-cms' ) ) ),
			self::field( 'account_label', __( 'Account label', 'kidia-mobile-cms' ), 'text', __( 'Account', 'kidia-mobile-cms' ) ),
			self::field( 'orders_icon_variant', __( 'Orders icon design', 'kidia-mobile-cms' ), 'select', 'receipt', array( 'receipt' => __( 'Receipt', 'kidia-mobile-cms' ), 'box' => __( 'Package', 'kidia-mobile-cms' ), 'list' => __( 'Order list', 'kidia-mobile-cms' ) ) ),
			self::field( 'orders_label', __( 'Orders label', 'kidia-mobile-cms' ), 'text', __( 'Orders', 'kidia-mobile-cms' ) ),
			self::field( 'show_share', __( 'Show share', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'share_label', __( 'Share label', 'kidia-mobile-cms' ), 'text', __( 'Share', 'kidia-mobile-cms' ) ),
			self::field( 'share_icon_style', __( 'Share icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'share_icon_variant', __( 'Share icon design', 'kidia-mobile-cms' ), 'select', 'upload', array( 'upload' => __( 'Upload arrow', 'kidia-mobile-cms' ), 'share' => __( 'Share nodes', 'kidia-mobile-cms' ), 'send' => __( 'Send', 'kidia-mobile-cms' ) ) ),
			self::field( 'share_icon_size', __( 'Share icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'share_color', __( 'Share color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'show_like', __( 'Show like', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'like_label', __( 'Like label', 'kidia-mobile-cms' ), 'text', __( 'Like', 'kidia-mobile-cms' ) ),
			self::field( 'like_icon_style', __( 'Like icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'like_icon_variant', __( 'Like icon design', 'kidia-mobile-cms' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded heart', 'kidia-mobile-cms' ), 'bookmark' => __( 'Bookmark', 'kidia-mobile-cms' ) ) ),
			self::field( 'like_icon_size', __( 'Like icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'like_color', __( 'Like color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'show_add_to_cart', __( 'Show add to cart', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'add_to_cart_label', __( 'Add to cart label', 'kidia-mobile-cms' ), 'text', __( 'Add to bag', 'kidia-mobile-cms' ) ),
			self::field( 'button_color', __( 'Button color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'button_text_color', __( 'Button text color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'button_width_percent', __( 'Button width (% of footer)', 'kidia-mobile-cms' ), 'number', 58, array(), 20, 95 ),
			self::field( 'button_height', __( 'Button height', 'kidia-mobile-cms' ), 'number', 52, array(), 36, 80 ),
			self::field( 'button_style', __( 'Button style', 'kidia-mobile-cms' ), 'select', 'filled', array( 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'soft' => __( 'Soft', 'kidia-mobile-cms' ) ) ),
			self::field( 'button_shape', __( 'Button shape', 'kidia-mobile-cms' ), 'select', 'custom', array( 'custom' => __( 'Custom radius', 'kidia-mobile-cms' ), 'rectangle' => __( 'Rectangle', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded', 'kidia-mobile-cms' ), 'pill' => __( 'Pill', 'kidia-mobile-cms' ) ) ),
			self::field( 'button_radius', __( 'Button radius', 'kidia-mobile-cms' ), 'number', 28, array(), 0, 40 ),
			self::field( 'button_border_color', __( 'Button border color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'button_border_width', __( 'Button border width', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 6 ),
			self::field( 'show_price', __( 'Show price', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_quantity', __( 'Show quantity', 'kidia-mobile-cms' ), 'checkbox', false ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public static function element_definitions( string $page ): array {
		$page = sanitize_key( $page );
		$common_grid = array(
			self::field( 'quick_add_enabled', __( 'Quick add to cart', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'quick_add_icon_variant', __( 'Quick add icon shape', 'kidia-mobile-cms' ), 'select', 'bag', array( 'bag' => __( 'Shopping bag', 'kidia-mobile-cms' ), 'cart' => __( 'Shopping cart', 'kidia-mobile-cms' ), 'basket' => __( 'Shopping basket', 'kidia-mobile-cms' ) ) ),
			self::field( 'quick_add_icon_style', __( 'Quick add icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded', 'kidia-mobile-cms' ) ) ),
			self::field( 'quick_add_icon_size', __( 'Quick add icon size', 'kidia-mobile-cms' ), 'number', 22, array(), 10, 36 ),
			self::field( 'quick_add_icon_color', __( 'Quick add icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'quick_add_show_background', __( 'White background behind icon', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'quick_add_background_color', __( 'Quick add background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'quick_add_background_size', __( 'Quick add background size', 'kidia-mobile-cms' ), 'number', 40, array(), 10, 64 ),
			self::field( 'quick_add_radius', __( 'Quick add background radius', 'kidia-mobile-cms' ), 'number', 24, array(), 0, 40 ),
			self::field( 'quick_add_position', __( 'Quick add position', 'kidia-mobile-cms' ), 'product_position', 'bottom_end', array( 'top_start' => __( 'Top start', 'kidia-mobile-cms' ), 'top_end' => __( 'Top end', 'kidia-mobile-cms' ), 'bottom_start' => __( 'Bottom start', 'kidia-mobile-cms' ), 'bottom_end' => __( 'Bottom end', 'kidia-mobile-cms' ) ) ),
			self::field( 'show_wishlist', __( 'Product wishlist icon', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'product_wishlist_icon_variant', __( 'Product wishlist icon shape', 'kidia-mobile-cms' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded heart', 'kidia-mobile-cms' ), 'bookmark' => __( 'Bookmark', 'kidia-mobile-cms' ) ) ),
			self::field( 'product_wishlist_icon_style', __( 'Product wishlist icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ) ) ),
			self::field( 'product_wishlist_icon_size', __( 'Product wishlist icon size', 'kidia-mobile-cms' ), 'number', 20, array(), 10, 36 ),
			self::field( 'product_wishlist_icon_color', __( 'Product wishlist icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'product_wishlist_show_background', __( 'Product wishlist background', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'product_wishlist_background_color', __( 'Product wishlist background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'product_wishlist_background_size', __( 'Product wishlist background size', 'kidia-mobile-cms' ), 'number', 40, array(), 20, 64 ),
			self::field( 'product_wishlist_radius', __( 'Product wishlist background radius', 'kidia-mobile-cms' ), 'number', 24, array(), 0, 40 ),
			self::field( 'product_wishlist_position', __( 'Product wishlist position', 'kidia-mobile-cms' ), 'product_position', 'top_end', array( 'top_start' => __( 'Top start', 'kidia-mobile-cms' ), 'top_end' => __( 'Top end', 'kidia-mobile-cms' ), 'bottom_start' => __( 'Bottom start', 'kidia-mobile-cms' ), 'bottom_end' => __( 'Bottom end', 'kidia-mobile-cms' ) ) ),
			self::field( 'source', __( 'Source', 'kidia-mobile-cms' ), 'select', 'latest', array( 'latest' => __( 'Latest', 'kidia-mobile-cms' ), 'category' => __( 'Category', 'kidia-mobile-cms' ), 'featured' => __( 'Featured', 'kidia-mobile-cms' ), 'on_sale' => __( 'On sale', 'kidia-mobile-cms' ), 'manual' => __( 'Manual IDs', 'kidia-mobile-cms' ) ) ),
			self::field( 'category_id', __( 'Category ID', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 999999999 ),
			self::field( 'manual_product_ids', __( 'Manual Product IDs', 'kidia-mobile-cms' ), 'text', '' ),
			self::field( 'columns', __( 'Columns', 'kidia-mobile-cms' ), 'number', 2, array(), 1, 4 ),
			self::field( 'gap', __( 'Gap', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 32 ),
			self::field( 'card_style', __( 'Card style', 'kidia-mobile-cms' ), 'select', 'outlined', array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'no_shadow' => __( 'No shadow', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobile-cms' ) ) ),
			self::field( 'card_radius', __( 'Card radius', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 40 ),
			self::field( 'image_ratio', __( 'Image ratio', 'kidia-mobile-cms' ), 'number', 1, array(), 0.6, 1.8, 0.1 ),
			self::field( 'show_price', __( 'Show price', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_regular_price', __( 'Show regular price', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_rating', __( 'Show rating', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_badge', __( 'Show badge', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'pagination_mode', __( 'Pagination mode', 'kidia-mobile-cms' ), 'select', 'load_more', array( 'numbers' => __( 'Page numbers', 'kidia-mobile-cms' ), 'load_more' => __( 'Load more button', 'kidia-mobile-cms' ), 'automatic' => __( 'Automatic loading', 'kidia-mobile-cms' ), 'none' => __( 'No pagination', 'kidia-mobile-cms' ) ) ),
			self::field( 'products_per_page', __( 'Products per page', 'kidia-mobile-cms' ), 'number', 12, array(), 4, 48 ),
			self::field( 'pagination_label', __( 'Load more label', 'kidia-mobile-cms' ), 'text', __( 'Load more', 'kidia-mobile-cms' ) ),
			self::field( 'pagination_size', __( 'Pagination size', 'kidia-mobile-cms' ), 'number', 44, array(), 32, 64 ),
			self::field( 'pagination_radius', __( 'Pagination radius', 'kidia-mobile-cms' ), 'number', 14, array(), 0, 32 ),
			self::field( 'pagination_color', __( 'Pagination color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ),
			self::field( 'pagination_text_color', __( 'Pagination text color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'pagination_spacing', __( 'Pagination spacing', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 40 ),
		);
		$quick_add_keys = array( 'quick_add_enabled', 'quick_add_icon_variant', 'quick_add_icon_style', 'quick_add_icon_size', 'quick_add_icon_color', 'quick_add_show_background', 'quick_add_background_color', 'quick_add_background_size', 'quick_add_radius', 'quick_add_position', 'show_wishlist', 'product_wishlist_icon_variant', 'product_wishlist_icon_style', 'product_wishlist_icon_size', 'product_wishlist_icon_color', 'product_wishlist_show_background', 'product_wishlist_background_color', 'product_wishlist_background_size', 'product_wishlist_radius', 'product_wishlist_position' );
		$catalog_grid_keys = array_merge( $quick_add_keys, array( 'columns', 'gap', 'card_style', 'card_radius', 'image_ratio', 'show_price', 'show_regular_price', 'show_rating', 'show_badge', 'pagination_mode', 'products_per_page', 'pagination_label', 'pagination_size', 'pagination_radius', 'pagination_color', 'pagination_text_color', 'pagination_spacing' ) );
		$wishlist_grid_keys = array_merge( $quick_add_keys, array( 'columns', 'gap', 'card_style', 'card_radius', 'image_ratio', 'show_price', 'show_regular_price', 'show_rating', 'show_badge' ) );
		$catalog_grid = array_values( array_filter( $common_grid, static fn ( array $field ): bool => in_array( $field['key'], $catalog_grid_keys, true ) ) );
		$wishlist_grid = array_values( array_filter( $common_grid, static fn ( array $field ): bool => in_array( $field['key'], $wishlist_grid_keys, true ) ) );

		$definitions = array(
			'home' => array(),
			'category' => array(),
			'catalog' => array(
				self::element( 'filter_bar', __( 'Filter and Sort Bar', 'kidia-mobile-cms' ), 'dashicons-filter', array(
					self::field( 'sticky', __( 'Sticky', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'show_filter', __( 'Show filter button', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'show_sort', __( 'Show sort', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'show_result_count', __( 'Show result count', 'kidia-mobile-cms' ), 'checkbox', false ),
					self::field( 'filter_price', __( 'Available filter: Price', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'filter_sale', __( 'Available filter: On sale', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'filter_brand', __( 'Available filter: Brand', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'filter_size', __( 'Available filter: Size', 'kidia-mobile-cms' ), 'checkbox', true ),
					self::field( 'block_width', __( 'Filter block width (%)', 'kidia-mobile-cms' ), 'number', 100, array(), 40, 100 ),
					self::field( 'block_height', __( 'Filter block height', 'kidia-mobile-cms' ), 'number', 56, array(), 48, 100 ),
					self::field( 'icon_size', __( 'Icon size', 'kidia-mobile-cms' ), 'number', 22, array(), 14, 36 ),
					self::field( 'filter_icon_offset_y', __( 'Filter icon vertical position', 'kidia-mobile-cms' ), 'number', -2, array(), -8, 8 ),
					self::field( 'button_radius', __( 'Button radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 28 ),
					self::field( 'button_gap', __( 'Button spacing', 'kidia-mobile-cms' ), 'number', 8, array(), 0, 24 ),
					self::field( 'background_color', __( 'Background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
					self::field( 'icon_color', __( 'Icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
					self::field( 'border_color', __( 'Border color', 'kidia-mobile-cms' ), 'color', '#DDE3E8' )
				) ),
				self::element( 'product_grid', __( 'Product Grid', 'kidia-mobile-cms' ), 'dashicons-grid-view', $catalog_grid ),
			),
			'product' => array(
				self::element( 'product_tabs', __( 'Product Tabs', 'kidia-mobile-cms' ), 'dashicons-index-card', array( self::field( 'sticky', __( 'Keep tabs visible while scrolling', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'overview_label', __( 'Overview label', 'kidia-mobile-cms' ), 'text', __( 'Overview', 'kidia-mobile-cms' ) ), self::field( 'reviews_label', __( 'Reviews label', 'kidia-mobile-cms' ), 'text', __( 'Reviews', 'kidia-mobile-cms' ) ), self::field( 'recommend_label', __( 'Recommend label', 'kidia-mobile-cms' ), 'text', __( 'Recommend', 'kidia-mobile-cms' ) ), self::field( 'active_color', __( 'Active tab color', 'kidia-mobile-cms' ), 'color', '#1D1D1D' ), self::field( 'inactive_color', __( 'Inactive tab color', 'kidia-mobile-cms' ), 'color', '#6B6B6B' ), self::field( 'indicator_width', __( 'Indicator width', 'kidia-mobile-cms' ), 'number', 96, array(), 24, 160 ), self::field( 'height', __( 'Tabs height', 'kidia-mobile-cms' ), 'number', 64, array(), 44, 88 ) ) ),
				self::element( 'image_gallery', __( 'Product Gallery', 'kidia-mobile-cms' ), 'dashicons-format-gallery', array( self::field( 'aspect_ratio', __( 'Image ratio', 'kidia-mobile-cms' ), 'number', 0.75, array(), 0.6, 1.8, 0.05 ), self::field( 'fit', __( 'Image fit', 'kidia-mobile-cms' ), 'select', 'contain', array( 'contain' => __( 'Contain', 'kidia-mobile-cms' ), 'cover' => __( 'Cover', 'kidia-mobile-cms' ) ) ), self::field( 'background_color', __( 'Gallery background', 'kidia-mobile-cms' ), 'color', '#F4F2F3' ), self::field( 'show_thumbnails', __( 'Show thumbnails', 'kidia-mobile-cms' ), 'checkbox', false ), self::field( 'show_indicators', __( 'Show indicators', 'kidia-mobile-cms' ), 'checkbox', false ), self::field( 'show_counter', __( 'Show image counter', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'counter_background', __( 'Counter background', 'kidia-mobile-cms' ), 'color', '#8A8585' ), self::field( 'counter_text_color', __( 'Counter text color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ), self::field( 'enable_zoom', __( 'Enable zoom', 'kidia-mobile-cms' ), 'checkbox', false ) ) ),
				self::element( 'product_summary', __( 'Product Information', 'kidia-mobile-cms' ), 'dashicons-info-outline', array( self::field( 'show_name', __( 'Show name', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_price', __( 'Show price', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_regular_price', __( 'Show regular price', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_rating', __( 'Show rating', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_review_count', __( 'Show review count', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_sku', __( 'Show SKU', 'kidia-mobile-cms' ), 'checkbox', false ), self::field( 'show_stock', __( 'Show stock', 'kidia-mobile-cms' ), 'checkbox', false ), self::field( 'show_badge', __( 'Show badge', 'kidia-mobile-cms' ), 'checkbox', false ), self::field( 'show_selected_color', __( 'Show selected color', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'price_size', __( 'Price size', 'kidia-mobile-cms' ), 'number', 25, array(), 14, 36 ), self::field( 'name_size', __( 'Product name size', 'kidia-mobile-cms' ), 'number', 18, array(), 12, 28 ) ) ),
				self::element( 'variations', __( 'Variations', 'kidia-mobile-cms' ), 'dashicons-screenoptions', array( self::field( 'style', __( 'Selector style', 'kidia-mobile-cms' ), 'select', 'chips', array( 'chips' => __( 'Chips', 'kidia-mobile-cms' ), 'dropdown' => __( 'Dropdown', 'kidia-mobile-cms' ) ) ), self::field( 'show_size_chart', __( 'Show size chart link', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'size_chart_label', __( 'Size chart label', 'kidia-mobile-cms' ), 'text', __( 'Size chart', 'kidia-mobile-cms' ) ), self::field( 'chip_radius', __( 'Option radius', 'kidia-mobile-cms' ), 'number', 22, array(), 0, 32 ), self::field( 'chip_height', __( 'Option height', 'kidia-mobile-cms' ), 'number', 44, array(), 32, 60 ) ) ),
				self::element( 'purchase_bar', __( 'Quantity', 'kidia-mobile-cms' ), 'dashicons-cart', array( self::field( 'show_quantity', __( 'Show quantity', 'kidia-mobile-cms' ), 'checkbox', false ) ) ),
				self::element( 'description', __( 'Description and Details', 'kidia-mobile-cms' ), 'dashicons-text-page', array( self::field( 'accordion', __( 'Use compact accordion rows', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'details_label', __( 'Details label', 'kidia-mobile-cms' ), 'text', __( 'Product Details', 'kidia-mobile-cms' ) ), self::field( 'show_description', __( 'Show description', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_attributes', __( 'Show attributes', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
				self::element( 'reviews', __( 'Reviews', 'kidia-mobile-cms' ), 'dashicons-star-filled', array( self::field( 'title', __( 'Reviews title', 'kidia-mobile-cms' ), 'text', __( 'Reviews', 'kidia-mobile-cms' ) ), self::field( 'show_summary', __( 'Show rating summary', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_fit_summary', __( 'Show size and fit summary', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'fit_small_percent', __( 'Small (%)', 'kidia-mobile-cms' ), 'number', 1, array(), 0, 100 ), self::field( 'fit_true_percent', __( 'True to size (%)', 'kidia-mobile-cms' ), 'number', 99, array(), 0, 100 ), self::field( 'fit_large_percent', __( 'Large (%)', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 100 ) ) ),
				self::element( 'related_products', __( 'Related Products', 'kidia-mobile-cms' ), 'dashicons-products', array( self::field( 'title', __( 'Section title', 'kidia-mobile-cms' ), 'text', __( 'You may also like', 'kidia-mobile-cms' ) ), self::field( 'columns', __( 'Columns', 'kidia-mobile-cms' ), 'number', 2, array(), 1, 3 ), self::field( 'gap', __( 'Gap', 'kidia-mobile-cms' ), 'number', 2, array(), 0, 24 ), self::field( 'image_ratio', __( 'Image ratio', 'kidia-mobile-cms' ), 'number', 0.75, array(), 0.6, 1.8, 0.05 ), self::field( 'show_price', __( 'Show price', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_quick_add', __( 'Show quick add', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
			),
			'wishlist' => array(
				self::element( 'wishlist_grid', __( 'Wishlist Products', 'kidia-mobile-cms' ), 'dashicons-heart', $wishlist_grid ),
				self::element( 'empty_state', __( 'Empty Wishlist', 'kidia-mobile-cms' ), 'dashicons-heart', array( self::field( 'title', __( 'Title', 'kidia-mobile-cms' ), 'text', __( 'Your wishlist is empty', 'kidia-mobile-cms' ) ), self::field( 'description', __( 'Description', 'kidia-mobile-cms' ), 'text', __( 'Save products you love and find them here.', 'kidia-mobile-cms' ) ), self::field( 'button_label', __( 'Button label', 'kidia-mobile-cms' ), 'text', __( 'Continue shopping', 'kidia-mobile-cms' ) ), self::field( 'button_action', __( 'Button action', 'kidia-mobile-cms' ), 'select', 'shopping', array( 'shopping' => __( 'Continue shopping', 'kidia-mobile-cms' ), 'sign_in' => __( 'Sign in', 'kidia-mobile-cms' ) ) ), self::field( 'show_button', __( 'Show button', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
			),
			'account' => array(
				self::element( 'account_summary', __( 'Account Summary', 'kidia-mobile-cms' ), 'dashicons-admin-users', array( self::field( 'avatar_size', __( 'Avatar size', 'kidia-mobile-cms' ), 'number', 66, array(), 40, 110 ), self::field( 'show_email', __( 'Show email', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'guest_title', __( 'Guest title', 'kidia-mobile-cms' ), 'text', __( 'Sign in / Create account', 'kidia-mobile-cms' ) ), self::field( 'card_style', __( 'Card style', 'kidia-mobile-cms' ), 'select', 'elevated', array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'no_shadow' => __( 'No shadow', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobile-cms' ) ) ) ) ),
				self::element( 'account_menu', __( 'Account Menu', 'kidia-mobile-cms' ), 'dashicons-menu-alt', array( self::field( 'show_orders', __( 'Show orders', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_addresses', __( 'Show addresses', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_profile', __( 'Show profile', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_support', __( 'Show support', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
				self::element( 'logout_button', __( 'Logout Button', 'kidia-mobile-cms' ), 'dashicons-exit', array() ),
			),
		);

		$presentation = array(
			self::field( 'margin_top', __( 'Merge up', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Merge down', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_up', __( 'Space up', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_down', __( 'Space down', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'padding_vertical', __( 'Inner vertical space', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 40 ),
			self::field( 'padding_horizontal', __( 'Inner side space', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 40 ),
			self::field( 'background_color', __( 'Background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
		);
		$result = $definitions[ $page ] ?? array();
		foreach ( $result as &$definition ) {
			$keys = array_column( $definition['fields'], 'key' );
			foreach ( $presentation as $field ) {
				if ( ! in_array( $field['key'], $keys, true ) ) { $definition['fields'][] = $field; }
			}
		}
		unset( $definition );
		return $result;
	}

	/** @return array<string,mixed> */
	public function get_layout( string $page ): array {
		$page = sanitize_key( $page );
		if ( ! self::is_page( $page ) ) {
			return array();
		}
		$default = $this->default_layout( $page );
		$saved = get_option( self::OPTION_PREFIX . $page, array() );
		if ( ! is_array( $saved ) || empty( $saved ) ) {
			return $default;
		}
		// Keep saved chrome settings across schema upgrades. The browser and Flutter
		// readers migrate legacy left/center/right and flat footer layouts in place.
		$default['header'] = $this->merge_component( $default['header'], $saved['header'] ?? array(), self::header_fields() );
		if ( (int) ( $saved['version'] ?? 1 ) < 10 && 'sticky_search_cart' === (string) ( $saved['header']['settings']['collapse_preset'] ?? '' ) ) {
			$default['header']['settings']['collapse_transition'] = 'smooth_compact';
		}
		$default['footer'] = $this->merge_component( $default['footer'], $saved['footer'] ?? array(), self::footer_fields() );
		$saved_elements = array();
		foreach ( is_array( $saved['elements'] ?? null ) ? $saved['elements'] : array() as $element ) {
			if ( is_array( $element ) && ! empty( $element['id'] ) ) {
				$saved_elements[ sanitize_key( $element['id'] ) ] = $element;
			}
		}
		$definitions = array();
		foreach ( self::element_definitions( $page ) as $definition ) {
			$definitions[ $definition['id'] ] = $definition;
		}
		$elements = array();
		foreach ( $saved_elements as $id => $element ) {
			if ( isset( $definitions[ $id ] ) ) {
				$elements[] = $this->merge_element( $definitions[ $id ], $element );
				unset( $definitions[ $id ] );
			}
		}
		foreach ( $definitions as $definition ) {
			$elements[] = $this->default_element( $definition );
		}
		if ( 'catalog' === $page && (int) ( $saved['version'] ?? 1 ) < 2 ) {
			foreach ( $elements as &$migrated_element ) { if ( 'filter_bar' === $migrated_element['id'] ) { $migrated_element['settings']['show_result_count'] = false; $migrated_element['settings']['filter_icon_offset_y'] = -2; } }
			unset( $migrated_element );
		}
		if ( 'product' === $page && (int) ( $saved['version'] ?? 1 ) < 16 ) {
			$fresh_product_elements = array();
			foreach ( self::element_definitions( 'product' ) as $definition ) {
				$fresh_product_elements[ $definition['id'] ] = $this->default_element( $definition );
			}
			foreach ( $elements as &$migrated_element ) {
				if ( isset( $fresh_product_elements[ $migrated_element['id'] ] ) ) {
					$migrated_element['settings'] = $fresh_product_elements[ $migrated_element['id'] ]['settings'];
				}
			}
			unset( $migrated_element );
			usort( $elements, static function ( array $left, array $right ): int {
				$order = array( 'product_tabs', 'image_gallery', 'product_summary', 'variations', 'purchase_bar', 'description', 'reviews', 'related_products' );
				return array_search( $left['id'], $order, true ) <=> array_search( $right['id'], $order, true );
			} );
			$default['footer']['settings']['button_color'] = '#1D1D1D';
			$default['footer']['settings']['button_text_color'] = '#FFFFFF';
			$default['footer']['settings']['button_width_percent'] = 62;
			$default['footer']['settings']['button_height'] = 56;
			$default['footer']['settings']['button_radius'] = 28;
			$default['footer']['settings']['add_to_cart_label'] = __( 'Add to bag', 'kidia-mobile-cms' );
			$default['footer']['settings']['share_label'] = __( 'Share', 'kidia-mobile-cms' );
			$default['footer']['settings']['like_label'] = __( 'Like', 'kidia-mobile-cms' );
			$default['footer']['settings']['show_price'] = false;
			$default['footer']['settings']['show_quantity'] = false;
		}
		$default['elements'] = $elements;
		$default['updated_at'] = sanitize_text_field( (string) ( $saved['updated_at'] ?? '' ) );
		return $default;
	}

	/** @param array<string,mixed> $submitted */
	public function save_layout( string $page, array $submitted ): array {
		$page = sanitize_key( $page );
		$current = $this->get_layout( $page );
		if ( empty( $current ) ) {
			return array();
		}
		$layout = array(
			'version' => self::VERSION,
			'page' => $page,
			'updated_at' => gmdate( 'c' ),
			'header' => $this->merge_component( $current['header'], $submitted['header'] ?? array(), self::header_fields() ),
			'elements' => array(),
			'footer' => $this->merge_component( $current['footer'], $submitted['footer'] ?? array(), self::footer_fields() ),
		);
		$definitions = array();
		foreach ( self::element_definitions( $page ) as $definition ) {
			$definitions[ $definition['id'] ] = $definition;
		}
		foreach ( is_array( $submitted['elements'] ?? null ) ? $submitted['elements'] : array() as $element ) {
			$id = is_array( $element ) ? sanitize_key( (string) ( $element['id'] ?? '' ) ) : '';
			if ( isset( $definitions[ $id ] ) ) {
				$layout['elements'][] = $this->merge_element( $definitions[ $id ], $element );
				unset( $definitions[ $id ] );
			}
		}
		foreach ( $definitions as $definition ) {
			$layout['elements'][] = $this->default_element( $definition );
		}
		update_option( self::OPTION_PREFIX . $page, $layout, false );
		if ( function_exists( 'wp_cache_delete' ) ) {
			wp_cache_delete( self::OPTION_PREFIX . $page, 'options' );
		}
		return $layout;
	}

	/** Removes only one page's saved layout so its canonical defaults are used again. */
	public function reset_layout( string $page ): bool {
		$page = sanitize_key( $page );
		if ( ! self::is_page( $page ) ) {
			return false;
		}
		$deleted = delete_option( self::OPTION_PREFIX . $page );
		if ( function_exists( 'wp_cache_delete' ) ) {
			wp_cache_delete( self::OPTION_PREFIX . $page, 'options' );
		}
		return $deleted;
	}

	/** @return array<string,mixed> */
	private function default_layout( string $page ): array {
		$elements = array_map( array( $this, 'default_element' ), self::element_definitions( $page ) );
		$header_settings = $this->defaults( self::header_fields() );
		$footer_settings = $this->defaults( self::footer_fields() );
		$header_settings['layout_json'] = wp_json_encode( $this->default_header_layout( $page ) );
		$header_settings['compact_layout_json'] = wp_json_encode( $this->default_compact_header_layout() );
		$footer_settings['layout_json'] = wp_json_encode( $this->default_footer_layout( $page ) );
		if ( 'home' === $page ) {
			$header_settings['collapse_on_scroll'] = true;
			$header_settings['collapse_transition'] = 'smooth_compact';
			$header_settings['height'] = 120;
			$header_settings['row_gap'] = 8;
			$header_settings['vertical_padding'] = 8;
			$header_settings['horizontal_padding'] = 16;
			$header_settings['show_back'] = false;
			$header_settings['show_search'] = true;
			$header_settings['search_style'] = 'bar';
			$header_settings['search_width_percent'] = 100;
			$header_settings['search_height'] = 44;
			$header_settings['search_radius'] = 22;
			$header_settings['search_background'] = '#F4F5F5';
			$header_settings['search_text_color'] = '#5F6368';
			$header_settings['search_placeholder'] = __( 'Search products', 'kidia-mobile-cms' );
			$header_settings['background_color'] = '#FFFFFF';
			$header_settings['icon_color'] = '#1F2933';
			$header_settings['logo_width'] = 132;
			$header_settings['logo_height'] = 42;
			$header_settings['cart_size'] = 28;
			$header_settings['show_cart_badge'] = false;
			$header_settings['logo_url'] = $this->site_logo_url();
		}
		if ( 'product' === $page ) {
			$header_settings['height'] = 72;
			$header_settings['background_color'] = '#FFFFFF';
			$header_settings['icon_color'] = '#1D1D1D';
			$header_settings['show_search'] = false;
			$header_settings['show_support'] = true;
			$header_settings['show_cart_badge'] = false;
			$footer_settings['style'] = 'product_action';
			$footer_settings['height'] = 84;
			$footer_settings['horizontal_padding'] = 16;
			$footer_settings['button_color'] = '#1D1D1D';
			$footer_settings['button_text_color'] = '#FFFFFF';
			$footer_settings['button_width_percent'] = 62;
			$footer_settings['button_height'] = 56;
			$footer_settings['button_radius'] = 28;
			$footer_settings['add_to_cart_label'] = __( 'Add to bag', 'kidia-mobile-cms' );
			$footer_settings['share_label'] = __( 'Share', 'kidia-mobile-cms' );
			$footer_settings['like_label'] = __( 'Like', 'kidia-mobile-cms' );
			$footer_settings['show_price'] = false;
			$footer_settings['show_quantity'] = false;
		}
		return array(
			'version' => self::VERSION,
			'page' => $page,
			'updated_at' => '',
			'header' => array( 'id' => 'header', 'type' => 'app_header', 'locked' => true, 'enabled' => true, 'settings' => $header_settings ),
			'elements' => $elements,
			'footer' => array( 'id' => 'footer', 'type' => 'app_footer', 'locked' => true, 'enabled' => true, 'settings' => $footer_settings ),
		);
	}

	private function site_logo_url(): string {
		if ( ! function_exists( 'get_theme_mod' ) || ! function_exists( 'wp_get_attachment_image_url' ) ) {
			return '';
		}
		$logo_id = (int) get_theme_mod( 'custom_logo', 0 );
		$url = $logo_id > 0 ? wp_get_attachment_image_url( $logo_id, 'full' ) : '';
		return is_string( $url ) ? esc_url_raw( $url ) : '';
	}

	/** @param array<string,mixed> $definition @return array<string,mixed> */
	private function default_element( array $definition ): array {
		return array( 'id' => $definition['id'], 'type' => $definition['id'], 'label' => $definition['label'], 'icon' => $definition['icon'], 'locked' => false, 'enabled' => true, 'settings' => $this->defaults( $definition['fields'] ) );
	}

	/** @param array<string,mixed> $definition @param array<string,mixed> $saved @return array<string,mixed> */
	private function merge_element( array $definition, array $saved ): array {
		$element = $this->default_element( $definition );
		$element['enabled'] = ! empty( $saved['enabled'] );
		$saved_settings = is_array( $saved['settings'] ?? null ) ? $saved['settings'] : array();
		// Preserve the old single vertical-padding value when upgrading to the two
		// independent outside spacing controls. Explicit new values always win.
		if ( array_key_exists( 'padding_vertical', $saved_settings ) ) {
			if ( ! array_key_exists( 'space_up', $saved_settings ) ) { $saved_settings['space_up'] = $saved_settings['padding_vertical']; }
			if ( ! array_key_exists( 'space_down', $saved_settings ) ) { $saved_settings['space_down'] = $saved_settings['padding_vertical']; }
		}
		$element['settings'] = $this->sanitize_settings( $saved_settings, $definition['fields'] );
		return $element;
	}

	/** @param array<string,mixed> $default @param mixed $saved @param array<int,array<string,mixed>> $fields @return array<string,mixed> */
	private function merge_component( array $default, $saved, array $fields ): array {
		$saved = is_array( $saved ) ? $saved : array();
		$default['enabled'] = ! empty( $saved['enabled'] );
		$submitted_settings = is_array( $saved['settings'] ?? null ) ? $saved['settings'] : array();
		$default['settings'] = $this->sanitize_settings( array_merge( $default['settings'], $submitted_settings ), $fields );
		return $default;
	}

	/** @return array<string,mixed> */
	private function default_header_layout( string $page ): array {
		$row = static function ( array $columns ): array {
			return array( 'columns' => $columns );
		};
		$column = static function ( float $width, array $items, string $align = 'center' ): array {
			return compact( 'width', 'align', 'items' );
		};
		$layouts = array(
			'home' => array( 'rows' => array( $row( array( $column( 33.33, array( 'logo' ), 'left' ), $column( 33.34, array() ), $column( 33.33, array( 'cart' ), 'right' ) ) ), $row( array( $column( 100, array( 'search_bar' ) ) ) ) ) ),
			'catalog' => array( 'rows' => array( $row( array( $column( 33.33, array( 'cart', 'search' ), 'left' ), $column( 33.34, array( 'title' ) ), $column( 33.33, array( 'back' ), 'right' ) ) ) ) ),
			'product' => array( 'rows' => array( $row( array( $column( 33.33, array( 'back' ), 'left' ), $column( 33.34, array() ), $column( 33.33, array( 'support', 'cart' ), 'right' ) ) ) ) ),
			'category' => array( 'rows' => array( $row( array( $column( 33.33, array( 'search', 'cart' ), 'left' ), $column( 33.34, array( 'title' ) ), $column( 33.33, array(), 'right' ) ) ) ) ),
			'wishlist' => array( 'rows' => array( $row( array( $column( 33.33, array( 'back' ), 'left' ), $column( 33.34, array( 'title' ) ), $column( 33.33, array( 'cart' ), 'right' ) ) ) ) ),
			'account' => array( 'rows' => array( $row( array( $column( 33.33, array(), 'left' ), $column( 33.34, array( 'title' ) ), $column( 33.33, array( 'orders' ), 'right' ) ) ) ) ),
		);
		return $layouts[ $page ] ?? $layouts['catalog'];
	}

	/** @return array<string,mixed> */
	private function default_compact_header_layout(): array {
		return array( 'rows' => array( array( 'columns' => array(
			array( 'width' => 84, 'align' => 'left', 'items' => array( 'search_bar' ) ),
			array( 'width' => 16, 'align' => 'right', 'items' => array( 'cart' ) ),
		) ) ) );
	}

	/** @return array<string,mixed> */
	private function default_footer_layout( string $page ): array {
		$items = 'product' === $page ? array( 'share', 'like', 'add_to_cart' ) : array( 'home', 'categories', 'wishlist', 'account' );
		$count = count( $items );
		$base = floor( 10000 / $count ) / 100;
		$columns = array();
		foreach ( $items as $index => $item ) {
			$width = $index === $count - 1 ? round( 100 - ( $base * ( $count - 1 ) ), 2 ) : $base;
			$columns[] = array( 'width' => $width, 'align' => 'center', 'items' => array( $item ) );
		}
		return array( 'rows' => array( array( 'columns' => $columns ) ) );
	}

	/** @param array<int,array<string,mixed>> $fields @return array<string,mixed> */
	private function defaults( array $fields ): array {
		$values = array();
		foreach ( $fields as $field ) {
			$values[ $field['key'] ] = $field['default'];
		}
		return $values;
	}

	/** @param array<string,mixed> $settings @param array<int,array<string,mixed>> $fields @return array<string,mixed> */
	private function sanitize_settings( array $settings, array $fields ): array {
		$clean = array();
		foreach ( $fields as $field ) {
			$key = $field['key'];
			$value = $settings[ $key ] ?? $field['default'];
			switch ( $field['type'] ) {
				case 'checkbox': $clean[ $key ] = ! empty( $value ); break;
				case 'number':
					$number = is_numeric( $value ) ? (float) $value : (float) $field['default'];
					$clean[ $key ] = min( (float) $field['max'], max( (float) $field['min'], $number ) );
					break;
			case 'color': $clean[ $key ] = sanitize_hex_color( (string) $value ) ?: $field['default']; break;
				case 'json':
					$decoded = json_decode( (string) $value, true );
					$clean[ $key ] = is_array( $decoded ) ? wp_json_encode( $decoded ) : (string) $field['default'];
					break;
				case 'image': $clean[ $key ] = esc_url_raw( (string) $value ); break;
				case 'select': $clean[ $key ] = isset( $field['options'][ sanitize_key( (string) $value ) ] ) ? sanitize_key( (string) $value ) : $field['default']; break;
				case 'product_position': $clean[ $key ] = isset( $field['options'][ sanitize_key( (string) $value ) ] ) ? sanitize_key( (string) $value ) : $field['default']; break;
				default: $clean[ $key ] = sanitize_text_field( (string) $value );
			}
		}
		return $clean;
	}

	/** @return array<string,mixed> */
	private static function field( string $key, string $label, string $type, $default, array $options = array(), float $min = 0, float $max = 100, float $step = 1 ): array {
		return compact( 'key', 'label', 'type', 'default', 'options', 'min', 'max', 'step' );
	}

	/** @param array<int,array<string,mixed>> $fields @return array<string,mixed> */
	private static function element( string $id, string $label, string $icon, array $fields ): array {
		return compact( 'id', 'label', 'icon', 'fields' );
	}
}
