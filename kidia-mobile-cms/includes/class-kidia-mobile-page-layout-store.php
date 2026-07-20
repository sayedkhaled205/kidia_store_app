<?php
/** Shared storage and schemas for non-home application page builders. */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Page_Layout_Store {
	private const OPTION_PREFIX = 'kidia_mobile_page_layout_';
	private const VERSION = 13;

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
			self::field( 'margin_top', __( 'Margin top', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Margin bottom', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'row_gap', __( 'Space between rows', 'kidia-mobile-cms' ), 'number', 8, array(), 0, 24 ),
			self::field( 'vertical_padding', __( 'Vertical padding', 'kidia-mobile-cms' ), 'number', 8, array(), 0, 24 ),
			self::field( 'background_color', __( 'Background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
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
			self::field( 'hide_on_scroll', __( 'Hide while scrolling down and show while scrolling up', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'style', __( 'Footer style', 'kidia-mobile-cms' ), 'select', 'navigation', array( 'navigation' => __( 'Bottom navigation', 'kidia-mobile-cms' ), 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'product_action' => __( 'Product action bar', 'kidia-mobile-cms' ) ) ),
			self::field( 'height', __( 'Height', 'kidia-mobile-cms' ), 'number', 76, array(), 48, 100 ),
			self::field( 'margin_top', __( 'Margin top', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Margin bottom', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 80 ),
			self::field( 'background_color', __( 'Background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
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
			self::field( 'quick_add_icon_size', __( 'Quick add icon size', 'kidia-mobile-cms' ), 'number', 22, array(), 16, 36 ),
			self::field( 'quick_add_icon_color', __( 'Quick add icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'quick_add_show_background', __( 'White background behind icon', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'quick_add_background_color', __( 'Quick add background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'quick_add_background_size', __( 'Quick add background size', 'kidia-mobile-cms' ), 'number', 40, array(), 28, 64 ),
			self::field( 'quick_add_radius', __( 'Quick add background radius', 'kidia-mobile-cms' ), 'number', 24, array(), 0, 40 ),
			self::field( 'show_wishlist', __( 'Product wishlist icon', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'product_wishlist_icon_variant', __( 'Product wishlist icon shape', 'kidia-mobile-cms' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded heart', 'kidia-mobile-cms' ), 'bookmark' => __( 'Bookmark', 'kidia-mobile-cms' ) ) ),
			self::field( 'product_wishlist_icon_style', __( 'Product wishlist icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ) ) ),
			self::field( 'product_wishlist_icon_size', __( 'Product wishlist icon size', 'kidia-mobile-cms' ), 'number', 20, array(), 16, 36 ),
			self::field( 'product_wishlist_icon_color', __( 'Product wishlist icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'product_wishlist_show_background', __( 'Product wishlist background', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'product_wishlist_background_color', __( 'Product wishlist background color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'product_wishlist_background_size', __( 'Product wishlist background size', 'kidia-mobile-cms' ), 'number', 40, array(), 28, 64 ),
			self::field( 'product_wishlist_radius', __( 'Product wishlist background radius', 'kidia-mobile-cms' ), 'number', 24, array(), 0, 40 ),
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
			self::field( 'show_wishlist', __( 'Show wishlist button', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'pagination_mode', __( 'Pagination mode', 'kidia-mobile-cms' ), 'select', 'load_more', array( 'numbers' => __( 'Page numbers', 'kidia-mobile-cms' ), 'load_more' => __( 'Load more button', 'kidia-mobile-cms' ), 'automatic' => __( 'Automatic loading', 'kidia-mobile-cms' ), 'none' => __( 'No pagination', 'kidia-mobile-cms' ) ) ),
			self::field( 'products_per_page', __( 'Products per page', 'kidia-mobile-cms' ), 'number', 12, array(), 4, 48 ),
			self::field( 'pagination_label', __( 'Load more label', 'kidia-mobile-cms' ), 'text', __( 'Load more', 'kidia-mobile-cms' ) ),
			self::field( 'pagination_size', __( 'Pagination size', 'kidia-mobile-cms' ), 'number', 44, array(), 32, 64 ),
			self::field( 'pagination_radius', __( 'Pagination radius', 'kidia-mobile-cms' ), 'number', 14, array(), 0, 32 ),
			self::field( 'pagination_color', __( 'Pagination color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ),
			self::field( 'pagination_text_color', __( 'Pagination text color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'pagination_spacing', __( 'Pagination spacing', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 40 ),
		);
		$quick_add_keys = array( 'quick_add_enabled', 'quick_add_icon_variant', 'quick_add_icon_style', 'quick_add_icon_size', 'quick_add_icon_color', 'quick_add_show_background', 'quick_add_background_color', 'quick_add_background_size', 'quick_add_radius', 'show_wishlist', 'product_wishlist_icon_variant', 'product_wishlist_icon_style', 'product_wishlist_icon_size', 'product_wishlist_icon_color', 'product_wishlist_show_background', 'product_wishlist_background_color', 'product_wishlist_background_size', 'product_wishlist_radius' );
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
					self::field( 'block_height', __( 'Filter block height', 'kidia-mobile-cms' ), 'number', 68, array(), 48, 100 ),
					self::field( 'icon_size', __( 'Icon size', 'kidia-mobile-cms' ), 'number', 22, array(), 14, 36 ),
					self::field( 'filter_icon_offset_y', __( 'Filter icon vertical position', 'kidia-mobile-cms' ), 'number', -2, array(), -8, 8 ),
					self::field( 'button_radius', __( 'Button radius', 'kidia-mobiln}€è-¢Gß≤⁄Óù∆≠y—ction? action;
}

class HeroSliderBlock extends HomeBlock {
  const HeroSliderBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.items,
    required this.aspectRatio,
    required this.autoPlay,
    required this.intervalMilliseconds,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.imageFit,
    required this.overlayPosition,
    required this.overlayStrength,
    required this.textColor,
    required this.showIndicators,
    required this.indicatorStyle,
    required this.indicatorPosition,
  }) : super(type: HomeBlockType.heroSlider);

  final List<HeroSlide> items;
  final double aspectRatio;
  final bool autoPlay;
  final int intervalMilliseconds;
  final double borderRadius;
  final double horizontalPadding;
  final String imageFit;
  final String overlayPosition;
  final double overlayStrength;
  final String textColor;
  final bool showIndicators;
  final String indicatorStyle;
  final String indicatorPosition;
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.action,
  });

  final int id;
  final String name;
  final String imageUrl;
  final HomeAction? action;
}

class CategoryGridBlock extends HomeBlock {
  const CategoryGridBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.columns,
    required this.showNames,
    required this.layout,
    required this.imageShape,
    required this.imageSize,
    required this.gap,
    required this.labelSize,
    required this.labelColor,
  }) : super(type: HomeBlockType.categoryGrid);

  final String? title;
  final String? subtitle;
  final List<CategoryItem> items;
  final int columns;
  final bool showNames;
  final String layout;
  final String imageShape;
  final double imageSize;
  final double gap;
  final double labelSize;
  final String labelColor;
}

class QuickLinkItem {
  const QuickLinkItem({
    required this.id,
    required this.imageUrl,
    required this.label,
    required this.subtitle,
    required this.action,
  });

  final String id;
  final String imageUrl;
  final String label;
  final String? subtitle;
  final HomeAction? action;
}

class QuickLinksBlock extends HomeBlock {
  const QuickLinksBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.columns,
    required this.imageShape,
    required this.itemSize,
    required this.gap,
    required this.showLabels,
    required this.labelColor,
    required this.labelSize,
    required this.items,
  }) : super(type: HomeBlockType.quickLinks);

  final String? title;
  final String? subtitle;
  final String layout;
  final int columns;
  final String imageShape;
  final double itemSize;
  final double gap;
  final bool showLabels;
  final String labelColor;
  final double labelSize;
  final List<QuickLinkItem> items;
}

class BannerGridItem {
  const BannerGridItem({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.action,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final HomeAction? action;
}

class BannerGridBlock extends HomeBlock {
  const BannerGridBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.columns,
    required this.gap,
    required this.aspectRatio,
    required this.borderRadius,
    required this.imageFit,
    required this.overlayStrength,
    required this.textColor,
    required this.items,
  }) : super(type: HomeBlockType.bannerGrid);

  final String? title;
  final String? subtitle;
  final String layout;
  final int columns;
  final double gap;
  final double aspectRatio;
  final double borderRadius;
  final String imageFit;
  final double overlayStrength;
  final String textColor;
  final List<BannerGridItem> items;
}

class ImageBannerBlock extends HomeBlock {
  const ImageBannerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.imageUrl,
    required this.aspectRatio,
    required this.borderRadius,
    required this.semanticLabel,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.imageFit,
    required this.overlayStrength,
    required this.textColor,
    required this.action,
  }) : super(type: HomeBlockType.imageBanner);

  final String imageUrl;
  final double aspectRatio;
  final double borderRadius;
  final String? semanticLabel;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final String imageFit;
  final double overlayStrength;
  final String textColor;
  final HomeAction? action;
}

class HomeProductItem {
  const HomeProductItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.regularPrice,
    required this.currencyCode,
    required this.currencySymbol,
    required this.inStock,
    required this.badge,
    required this.rating,
    required this.reviewCount,
    required this.discountPercent,
    required this.action,
  });

  final int id;
  final String name;
  final String imageUrl;
  final String price;
  final String? regularPrice;
  final String currencyCode;
  final String currencySymbol;
  final bool inStock;
  final String? badge;
  final double rating;
  final int reviewCount;
  final int discountPercent;
  final HomeAction? action;
}

class ProductCarouselBlock extends HomeBlock {
  const ProductCarouselBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.showViewAll,
    required this.viewAllLabel,
    required this.viewAllAction,
    required this.cardStyle,
    required this.itemWidth,
    required this.imageRatio,
    required this.cardRadius,
    required this.showName,
    required this.showPrice,
    required this.showRegularPrice,
    required this.showBadge,
    required this.showRating,
    required this.quickAddEnabled,
    this.quickAddAppearance = const ProductQuickAddAppearance(),
	this.wishlistAppearance = const ProductWishlistAppearance(),
  }) : super(type: HomeBlockType.productCarousel);

  final String? title;
  final String? subtitle;
  final List<HomeProductItem> items;
  final bool showViewAll;
  final String? viewAllLabel;
  final HomeAction? viewAllAction;
  final String cardStyle;
  final double itemWidth;
  final double imageRatio;
  final double cardRadius;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showBadge;
  final bool showRating;
  final bool quickAddEnabled;
  final ProductQuickAddAppearance quickAddAppearance;
  final ProductWishlistAppearance wishlistAppearance;
}

class ProductGridBlock extends HomeBlock {
  const ProductGridBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.columns,
    required this.showViewAll,
    required this.viewAllLabel,
    required this.viewAllAction,
    required this.cardStyle,
    required this.imageRatio,
    required this.cardRadius,
    required this.showName,
    required this.showPrice,
    required this.showRegularPrice,
    required this.showBadge,
    required this.showRating,
    required this.quickAddEnabled,
    this.quickAddAppearance = const ProductQuickAddAppearance(),
	this.wishlistAppearance = const ProductWishlistAppearance(),
  }) : super(type: HomeBlockType.productGrid);

  final String? title;
  final String? subtitle;
  final List<HomeProductItem> items;
  final int columns;
  final bool showViewAll;
  final String? viewAllLabel;
  final HomeAction? viewAllAction;
  final String cardStyle;
  final double imageRatio;
  final double cardRadius;
  final bool showName;
  final bool showPrice;
  final bool showRegularPrice;
  final bool showBadge;
  final bool showRating;
  final bool quickAddEnabled;
  final ProductQuickAddAppearance quickAddAppearance;
  final ProductWishlistAppearance wishlistAppearance;
}

class SectionHeaderBlock extends HomeBlock {
  const SectionHeaderBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.action,
  }) : super(type: HomeBlockType.sectionHeader);

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final HomeAction? action;
}

class BrandItem {
  const BrandItem({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.action,
  });

  final int id;
  final String name;
  final String logoUrl;
  final HomeAction? action;
}

class BrandCarouselBlock extends HomeBlock {
  const BrandCarouselBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.itemWidth,
    required this.layout,
    required this.columns,
    required this.imageShape,
    required this.showNames,
    required this.gap,
  }) : super(type: HomeBlockType.brandCarousel);

  final String? title;
  final String? subtitle;
  final List<BrandItem> items;
  final double itemWidth;
  final String layout;
  final int columns;
  final String imageShape;
  final bool showNames;
  final double gap;
}

class PromoStripBlock extends HomeBlock {
  const PromoStripBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.action,
  }) : super(type: HomeBlockType.promoStrip);

  final String text;
  final String backgroundColor;
  final String textColor;
  final HomeAction? action;
}

class CouponBannerBlock extends HomeBlock {
  const CouponBannerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.description,
    required this.couponCode,
    required this.imageUrl,
    this.backgroundColor = '#DCEEE8',
    this.textColor = '#1F2933',
    this.accentColor = '#2F806E',
    this.borderRadius = 20,
    this.action,
  }) : super(type: HomeBlockType.couponBanner);

  final String? title;
  final String? description;
  final String? couponCode;
  final String? imageUrl;
  final String backgroundColor;
  final String textColor;
  final String accentColor;
  final double borderRadius;
  final HomeAction? action;
}

class CountdownBlock extends HomeBlock {
  const CountdownBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.endsAt,
    required this.expiredText,
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#1F2933',
    this.boxColor = '#E9EEEC',
    this.action,
  }) : super(type: HomeBlockType.countdown);

  final String? title;
  final DateTime? endsAt;
  final String expiredText;
  final String backgroundColor;
  final String textColor;
  final String boxColor;
  final HomeAction? action;
}

class VideoBannerBlock extends HomeBlock {
  const VideoBannerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.videoUrl,
    required this.posterUrl,
    required this.aspectRatio,
    required this.autoPlay,
    required this.muted,
    required this.loop,
    required this.action,
  }) : super(type: HomeBlockType.videoBanner);

  final String videoUrl;
  final String? posterUrl;
  final double aspectRatio;
  final bool autoPlay;
  final bool muted;
  final bool loop;
  final HomeAction? action;
}

enum HomeTextAlignment {
  left,
  center,
  right;

  static HomeTextAlignment? tryParse(String value) {
    for (final HomeTextAlignment alignment in values) {
      if (alignment.name == value) {
        return alignment;
      }
    }

    return null;
  }
}

class TextBlock extends HomeBlock {
  const TextBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.title,
    required this.content,
    required this.alignment,
    required this.backgroundColor,
    required this.textColor,
    this.titleSize = 22,
    this.contentSize = 15,
    this.fontWeight = 'normal',
  }) : super(type: HomeBlockType.textBlock);

  final String? title;
  final String? content;
  final HomeTextAlignment alignment;
  final String? backgroundColor;
  final String textColor;
  final double titleSize;
  final double contentSize;
  final String fontWeight;
}

class DividerBlock extends HomeBlock {
  const DividerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.color,
    required this.thickness,
    required this.margin,
  }) : super(type: HomeBlockType.divider);

  final String color;
  final double thickness;
  final double margin;
}

class SpacerBlock extends HomeBlock {
  const SpacerBlock({
    required super.id,
    required super.enabled,
    super.presentation,
    required this.height,
  }) : super(type: HomeBlockType.spacer);

  final double height;
}
