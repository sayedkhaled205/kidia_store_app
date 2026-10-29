<?php
/** Shared storage and schemas for non-home application page builders. */
defined( 'ABSPATH' ) || exit;

final class MobiShop_Page_Layout_Store {
	private const OPTION_PREFIX = 'mobishop_page_layout_';
	private const VERSION = 25;

	/** @return array<string,string> */
	public static function pages(): array {
		return array(
			'home'     => __( 'Home Page', 'mobi2app-connector' ),
			'category' => __( 'Category Page', 'mobi2app-connector' ),
			'catalog'  => __( 'Catalog Page', 'mobi2app-connector' ),
			'product'  => __( 'Product Page', 'mobi2app-connector' ),
			'size_chart' => __( 'Size Chart Page', 'mobi2app-connector' ),
			'wishlist' => __( 'Wishlist Page', 'mobi2app-connector' ),
			'account'  => __( 'Account Page', 'mobi2app-connector' ),
		);
	}

	public static function is_page( string $page ): bool {
		return isset( self::pages()[ sanitize_key( $page ) ] );
	}

	/** @return array<int,array<string,mixed>> */
	public static function header_fields(): array {
		return array(
			self::field( 'layout_json', __( 'Header element layout', 'mobi2app-connector' ), 'json', '' ),
			self::field( 'compact_layout_json', __( 'Collapsed header element layout', 'mobi2app-connector' ), 'json', '' ),
			self::field( 'align_compact_cart', __( 'Align cart across compact headers', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'collapse_on_scroll', __( 'Show collapsed header while page is scrolled', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'collapse_transition', __( 'Collapsed header transition', 'mobi2app-connector' ), 'select', 'smooth_compact', array( 'smooth_compact' => __( 'Smooth layout transition', 'mobi2app-connector' ), 'instant' => __( 'Instant (no animation)', 'mobi2app-connector' ), 'fade' => __( 'Fade in / out', 'mobi2app-connector' ), 'slide' => __( 'Slide up', 'mobi2app-connector' ), 'fade_slide' => __( 'Fade + slide', 'mobi2app-connector' ), 'scale' => __( 'Shrink / scale', 'mobi2app-connector' ) ) ),
			self::field( 'compact_search_width_percent', __( 'Transition search width (%)', 'mobi2app-connector' ), 'number', 84, array(), 30, 100 ),
			self::field( 'collapse_speed', __( 'Transition speed', 'mobi2app-connector' ), 'select', 'medium', array( 'fast' => __( 'Fast', 'mobi2app-connector' ), 'medium' => __( 'Medium', 'mobi2app-connector' ), 'slow' => __( 'Slow', 'mobi2app-connector' ) ) ),
			self::field( 'compact_height', __( 'Collapsed header height', 'mobi2app-connector' ), 'number', 60, array(), 44, 100 ),
			self::field( 'compact_style', __( 'Collapsed header shape', 'mobi2app-connector' ), 'select', 'standard', array( 'standard' => __( 'Full width', 'mobi2app-connector' ), 'floating' => __( 'Floating card', 'mobi2app-connector' ), 'pill' => __( 'Pill', 'mobi2app-connector' ), 'transparent' => __( 'Transparent', 'mobi2app-connector' ) ) ),
			self::field( 'compact_background_color', __( 'Collapsed header background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'compact_horizontal_padding', __( 'Collapsed header horizontal padding', 'mobi2app-connector' ), 'number', 16, array(), 0, 32 ),
			self::field( 'compact_side_margin', __( 'Collapsed header outside side space', 'mobi2app-connector' ), 'number', 0, array(), 0, 32 ),
			self::field( 'compact_radius', __( 'Collapsed header corner radius', 'mobi2app-connector' ), 'number', 0, array(), 0, 40 ),
			self::field( 'compact_border_width', __( 'Collapsed header border width', 'mobi2app-connector' ), 'number', 0, array(), 0, 6 ),
			self::field( 'compact_border_color', __( 'Collapsed header border color', 'mobi2app-connector' ), 'color', '#E2E6E4' ),
			self::field( 'compact_shadow', __( 'Collapsed header shadow', 'mobi2app-connector' ), 'select', 'subtle', array( 'none' => __( 'None', 'mobi2app-connector' ), 'subtle' => __( 'Subtle', 'mobi2app-connector' ), 'strong' => __( 'Strong', 'mobi2app-connector' ) ) ),
			self::field( 'title', __( 'Page title', 'mobi2app-connector' ), 'text', '' ),
			self::field( 'subtitle', __( 'Subtitle', 'mobi2app-connector' ), 'text', '' ),
			self::field( 'auth_logo_scale', __( 'Sign-in logo scale', 'mobi2app-connector' ), 'number', 1, array(), 0.5, 1.5 ),
			self::field( 'logo_url', __( 'Logo image', 'mobi2app-connector' ), 'image', '' ),
			self::field( 'logo_fit', __( 'Logo fitting', 'mobi2app-connector' ), 'select', 'contain', array( 'contain' => __( 'Show whole image', 'mobi2app-connector' ), 'cover' => __( 'Fill logo frame', 'mobi2app-connector' ) ) ),
			self::field( 'logo_text', __( 'Logo text', 'mobi2app-connector' ), 'text', __( 'Mobi2App Connector for WooCommerce', 'mobi2app-connector' ) ),
			self::field( 'logo_text_color', __( 'Logo text color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'logo_width', __( 'Logo width', 'mobi2app-connector' ), 'number', 118, array(), 32, 220 ),
			self::field( 'logo_height', __( 'Logo height', 'mobi2app-connector' ), 'number', 38, array(), 20, 80 ),
			self::field( 'logo_aspect_ratio', __( 'Logo artwork ratio (0 = original)', 'mobi2app-connector' ), 'number', 0, array(), 0, 10 ),
			self::field( 'logo_fit', __( 'Logo image fit', 'mobi2app-connector' ), 'select', 'contain', array( 'contain' => 'Contain', 'cover' => 'Fill frame' ) ),
			self::field( 'search_font_size', __( 'Search font size', 'mobi2app-connector' ), 'number', 14, array(), 10, 24 ),
			self::field( 'style', __( 'Header style', 'mobi2app-connector' ), 'select', 'standard', array( 'standard' => __( 'Standard', 'mobi2app-connector' ), 'transparent' => __( 'Transparent', 'mobi2app-connector' ) ) ),
			self::field( 'height', __( 'Height', 'mobi2app-connector' ), 'number', 64, array(), 48, 120 ),
			self::field( 'row_1_height', __( 'First row height', 'mobi2app-connector' ), 'number', 48, array(), 24, 100 ),
			self::field( 'row_1_position', __( 'First row position', 'mobi2app-connector' ), 'select', 'center', array( 'up' => __( 'Up', 'mobi2app-connector' ), 'center' => __( 'Center', 'mobi2app-connector' ), 'down' => __( 'Down', 'mobi2app-connector' ) ) ),
			self::field( 'row_2_height', __( 'Second row height', 'mobi2app-connector' ), 'number', 48, array(), 24, 100 ),
			self::field( 'row_2_position', __( 'Second row position', 'mobi2app-connector' ), 'select', 'center', array( 'up' => __( 'Up', 'mobi2app-connector' ), 'center' => __( 'Center', 'mobi2app-connector' ), 'down' => __( 'Down', 'mobi2app-connector' ) ) ),
			self::field( 'row_gap', __( 'Row spacing', 'mobi2app-connector' ), 'number', 8, array(), 0, 24 ),
			self::field( 'row_merge', __( 'Merge rows', 'mobi2app-connector' ), 'number', 0, array(), 0, 24 ),
			self::field( 'margin_top', __( 'Merge up', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Merge down', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_up', __( 'Space up', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_down', __( 'Space down', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'vertical_padding', __( 'Vertical padding', 'mobi2app-connector' ), 'number', 8, array(), 0, 24 ),
			self::field( 'background_color', __( 'Background color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'border_color', __( 'Border color', 'mobi2app-connector' ), 'color', '#E2E6E4' ),
			self::field( 'border_width', __( 'Border width', 'mobi2app-connector' ), 'number', 0, array(), 0, 6 ),
			self::field( 'corner_radius', __( 'Corner radius', 'mobi2app-connector' ), 'number', 0, array(), 0, 32 ),
			self::field( 'title_color', __( 'Title color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'title_font_size', __( 'Title font size', 'mobi2app-connector' ), 'number', 18, array(), 10, 42 ),
			self::field( 'title_font_weight', __( 'Title font weight', 'mobi2app-connector' ), 'select', '700', array( '400' => __( 'Regular', 'mobi2app-connector' ), '500' => __( 'Medium', 'mobi2app-connector' ), '600' => __( 'Semi bold', 'mobi2app-connector' ), '700' => __( 'Bold', 'mobi2app-connector' ), '800' => __( 'Extra bold', 'mobi2app-connector' ) ) ),
			self::field( 'title_alignment', __( 'Title text alignment', 'mobi2app-connector' ), 'select', 'center', array( 'start' => __( 'Start', 'mobi2app-connector' ), 'center' => __( 'Center', 'mobi2app-connector' ), 'end' => __( 'End', 'mobi2app-connector' ) ) ),
			self::field( 'title_max_width_percent', __( 'Title maximum width (%)', 'mobi2app-connector' ), 'number', 100, array(), 20, 100 ),
			self::field( 'title_letter_spacing', __( 'Title letter spacing', 'mobi2app-connector' ), 'number', 0, array(), -2, 8, 0.1 ),
			self::field( 'title_line_height', __( 'Title line height', 'mobi2app-connector' ), 'number', 1.2, array(), 0.8, 2, 0.05 ),
			self::field( 'title_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'title_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'title_transform', __( 'Title letter case', 'mobi2app-connector' ), 'select', 'none', array( 'none' => __( 'As entered', 'mobi2app-connector' ), 'uppercase' => __( 'Uppercase', 'mobi2app-connector' ), 'lowercase' => __( 'Lowercase', 'mobi2app-connector' ) ) ),
			self::field( 'logo_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'logo_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'search_icon_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'search_icon_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'search_bar_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'search_bar_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'back_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'back_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'cart_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'cart_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'wishlist_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'wishlist_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'account_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'account_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'orders_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'orders_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'support_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'support_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'menu_offset_x', __( 'Horizontal position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'menu_offset_y', __( 'Vertical position', 'mobi2app-connector' ), 'number', 0, array(), -80, 80 ),
			self::field( 'icon_gap', __( 'Icon spacing', 'mobi2app-connector' ), 'number', 6, array(), 0, 24 ),
			self::field( 'icon_size', __( 'Default icon size', 'mobi2app-connector' ), 'number', 24, array(), 14, 40 ),
			self::field( 'icon_color', __( 'Default icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'horizontal_padding', __( 'Horizontal padding', 'mobi2app-connector' ), 'number', 16, array(), 0, 32 ),
			self::field( 'shadow', __( 'Shadow', 'mobi2app-connector' ), 'select', 'subtle', array( 'none' => __( 'None', 'mobi2app-connector' ), 'subtle' => __( 'Subtle', 'mobi2app-connector' ), 'strong' => __( 'Strong', 'mobi2app-connector' ) ) ),
			self::field( 'show_back', __( 'Show back button', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_search', __( 'Show search', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_cart', __( 'Show cart', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show wishlist', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_account', __( 'Show account', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_orders', __( 'Show orders', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_support', __( 'Show customer support', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_menu', __( 'Show menu', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_count', __( 'Show page item count', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'back_style', __( 'Back icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'circle' => __( 'Circle', 'mobi2app-connector' ) ) ),
			self::field( 'back_icon_variant', __( 'Back icon design', 'mobi2app-connector' ), 'select', 'arrow', array( 'arrow' => __( 'Arrow', 'mobi2app-connector' ), 'chevron' => __( 'Chevron', 'mobi2app-connector' ), 'rounded' => __( 'Rounded arrow', 'mobi2app-connector' ) ) ),
			self::field( 'back_size', __( 'Back icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'back_color', __( 'Back icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'search_style', __( 'Search style', 'mobi2app-connector' ), 'select', 'icon', array( 'icon' => __( 'Icon', 'mobi2app-connector' ), 'bar' => __( 'Search bar', 'mobi2app-connector' ) ) ),
			self::field( 'search_icon_style', __( 'Search icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'circle' => __( 'Circle', 'mobi2app-connector' ) ) ),
			self::field( 'search_icon_variant', __( 'Search icon design', 'mobi2app-connector' ), 'select', 'rounded', array( 'rounded' => __( 'Rounded', 'mobi2app-connector' ), 'classic' => __( 'Classic', 'mobi2app-connector' ), 'minimal' => __( 'Minimal', 'mobi2app-connector' ) ) ),
			self::field( 'search_icon_size', __( 'Search icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'search_icon_color', __( 'Search icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'search_icon_background', __( 'Search icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'search_icon_radius', __( 'Search icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
			self::field( 'search_placeholder', __( 'Search placeholder', 'mobi2app-connector' ), 'text', __( 'Search products', 'mobi2app-connector' ) ),
			self::field( 'search_height', __( 'Search height', 'mobi2app-connector' ), 'number', 40, array(), 32, 64 ),
			self::field( 'search_width_percent', __( 'Search width (% of its column)', 'mobi2app-connector' ), 'number', 100, array(), 30, 100 ),
			self::field( 'search_radius', __( 'Search radius', 'mobi2app-connector' ), 'number', 14, array(), 0, 32 ),
			self::field( 'search_background', __( 'Search background', 'mobi2app-connector' ), 'color', '#F1F3F4' ),
			self::field( 'search_text_color', __( 'Search text color', 'mobi2app-connector' ), 'color', '#5F6368' ),
			self::field( 'search_border_color', __( 'Search border color', 'mobi2app-connector' ), 'color', '#DDE3E8' ),
			self::field( 'search_border_width', __( 'Search border width', 'mobi2app-connector' ), 'number', 0, array(), 0, 6 ),
			self::field( 'show_voice_search', __( 'Show voice search', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'cart_style', __( 'Cart icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'circle' => __( 'Circle', 'mobi2app-connector' ) ) ),
			self::field( 'cart_icon_variant', __( 'Cart icon design', 'mobi2app-connector' ), 'select', 'bag', array( 'bag' => __( 'Shopping bag', 'mobi2app-connector' ), 'cart' => __( 'Shopping cart', 'mobi2app-connector' ), 'basket' => __( 'Shopping basket', 'mobi2app-connector' ) ) ),
			self::field( 'show_cart_badge', __( 'Show cart item count', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'cart_badge_shape', __( 'Cart count shape', 'mobi2app-connector' ), 'select', 'circle', array( 'circle' => __( 'Circle', 'mobi2app-connector' ), 'rounded_square' => __( 'Rounded square', 'mobi2app-connector' ), 'pill' => __( 'Pill', 'mobi2app-connector' ) ) ),
			self::field( 'cart_badge_size', __( 'Cart count size', 'mobi2app-connector' ), 'number', 18, array(), 12, 30 ),
			self::field( 'cart_badge_background', __( 'Cart count background', 'mobi2app-connector' ), 'color', '#E94B5F' ),
			self::field( 'cart_badge_text_color', __( 'Cart count text color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'cart_size', __( 'Cart icon size', 'mobi2app-connector' ), 'number', 28, array(), 16, 40 ),
			self::field( 'cart_color', __( 'Cart icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'cart_background', __( 'Cart icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'cart_radius', __( 'Cart icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
			self::field( 'wishlist_style', __( 'Wishlist icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'circle' => __( 'Circle', 'mobi2app-connector' ) ) ),
			self::field( 'wishlist_icon_variant', __( 'Wishlist icon design', 'mobi2app-connector' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'mobi2app-connector' ), 'rounded' => __( 'Rounded heart', 'mobi2app-connector' ), 'bookmark' => __( 'Bookmark', 'mobi2app-connector' ) ) ),
			self::field( 'wishlist_size', __( 'Wishlist icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'wishlist_color', __( 'Wishlist icon color', 'mobi2app-connector' ), 'color', '#E53935' ),
			self::field( 'wishlist_background', __( 'Wishlist icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'wishlist_radius', __( 'Wishlist icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
			self::field( 'account_style', __( 'Account style', 'mobi2app-connector' ), 'select', 'icon', array( 'icon' => __( 'Outline icon', 'mobi2app-connector' ), 'filled' => __( 'Filled icon', 'mobi2app-connector' ), 'avatar' => __( 'Avatar', 'mobi2app-connector' ) ) ),
			self::field( 'account_icon_variant', __( 'Account icon design', 'mobi2app-connector' ), 'select', 'person', array( 'person' => __( 'Person', 'mobi2app-connector' ), 'circle' => __( 'Person circle', 'mobi2app-connector' ), 'profile' => __( 'Profile', 'mobi2app-connector' ) ) ),
			self::field( 'account_icon_size', __( 'Account icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'account_icon_color', __( 'Account icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'account_background', __( 'Account icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'account_radius', __( 'Account icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
			self::field( 'account_label', __( 'Account label', 'mobi2app-connector' ), 'text', __( 'Account', 'mobi2app-connector' ) ),
			self::field( 'show_account_label', __( 'Show account label', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'orders_icon_variant', __( 'Orders icon design', 'mobi2app-connector' ), 'select', 'receipt', array( 'receipt' => __( 'Receipt', 'mobi2app-connector' ), 'box' => __( 'Package', 'mobi2app-connector' ), 'list' => __( 'Order list', 'mobi2app-connector' ) ) ),
			self::field( 'orders_size', __( 'Orders icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'orders_color', __( 'Orders icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'orders_background', __( 'Orders icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'orders_radius', __( 'Orders icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
			self::field( 'support_icon_variant', __( 'Support icon design', 'mobi2app-connector' ), 'select', 'headset', array( 'headset' => __( 'Headset', 'mobi2app-connector' ), 'support' => __( 'Support agent', 'mobi2app-connector' ), 'chat' => __( 'Chat', 'mobi2app-connector' ) ) ),
			self::field( 'support_size', __( 'Support icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'support_color', __( 'Support icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'support_background', __( 'Support icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'support_radius', __( 'Support icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
			self::field( 'menu_icon_variant', __( 'Menu icon design', 'mobi2app-connector' ), 'select', 'menu', array( 'menu' => __( 'Menu lines', 'mobi2app-connector' ), 'dots' => __( 'Menu dots', 'mobi2app-connector' ), 'grid' => __( 'Menu grid', 'mobi2app-connector' ) ) ),
			self::field( 'menu_size', __( 'Menu icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'menu_color', __( 'Menu icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'menu_background', __( 'Menu icon background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'menu_radius', __( 'Menu icon radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 24 ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public static function footer_fields(): array {
		return array(
			self::field( 'layout_json', __( 'Footer element layout', 'mobi2app-connector' ), 'json', '' ),
			self::field( 'hide_on_scroll', __( 'Hide while scrolling down', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'style', __( 'Footer style', 'mobi2app-connector' ), 'select', 'navigation', array( 'navigation' => __( 'Bottom navigation', 'mobi2app-connector' ), 'minimal' => __( 'Minimal', 'mobi2app-connector' ), 'product_action' => __( 'Product action bar', 'mobi2app-connector' ) ) ),
			self::field( 'height', __( 'Height', 'mobi2app-connector' ), 'number', 76, array(), 48, 100 ),
			self::field( 'margin_top', __( 'Merge up', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Merge down', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_up', __( 'Space up', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_down', __( 'Space down', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'background_color', __( 'Background color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'shadow', __( 'Shadow', 'mobi2app-connector' ), 'select', 'subtle', array( 'none' => __( 'None', 'mobi2app-connector' ), 'subtle' => __( 'Subtle', 'mobi2app-connector' ), 'strong' => __( 'Strong', 'mobi2app-connector' ) ) ),
			self::field( 'top_radius', __( 'Top corner radius', 'mobi2app-connector' ), 'number', 0, array(), 0, 32 ),
			self::field( 'horizontal_padding', __( 'Horizontal padding', 'mobi2app-connector' ), 'number', 0, array(), 0, 32 ),
			self::field( 'side_spacing_percent', __( 'Outside side spacing (%)', 'mobi2app-connector' ), 'number', 0, array(), 0, 25 ),
			self::field( 'icon_size', __( 'Default icon size', 'mobi2app-connector' ), 'number', 24, array(), 14, 40 ),
			self::field( 'label_size', __( 'Label size', 'mobi2app-connector' ), 'number', 11, array(), 8, 20 ),
			self::field( 'icon_label_gap', __( 'Icon and label spacing', 'mobi2app-connector' ), 'number', 3, array(), 0, 12 ),
			self::field( 'border_color', __( 'Top border color', 'mobi2app-connector' ), 'color', '#E2E6E4' ),
			self::field( 'border_width', __( 'Top border width', 'mobi2app-connector' ), 'number', 1, array(), 0, 6 ),
			self::field( 'safe_area', __( 'Respect safe area', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'active_color', __( 'Active color', 'mobi2app-connector' ), 'color', '#1F6F61' ),
			self::field( 'inactive_color', __( 'Inactive color', 'mobi2app-connector' ), 'color', '#6B7280' ),
			self::field( 'show_labels', __( 'Show labels', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_home', __( 'Show Home', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_categories', __( 'Show Categories', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show Wishlist', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_account', __( 'Show Account', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_search', __( 'Show Search', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_cart', __( 'Show Cart', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_orders', __( 'Show Orders', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'home_icon_variant', __( 'Home icon design', 'mobi2app-connector' ), 'select', 'home', array( 'home' => __( 'Home', 'mobi2app-connector' ), 'rounded' => __( 'Rounded home', 'mobi2app-connector' ), 'filled' => __( 'Filled home', 'mobi2app-connector' ) ) ),
			self::field( 'home_label', __( 'Home label', 'mobi2app-connector' ), 'text', __( 'Home', 'mobi2app-connector' ) ),
			self::field( 'categories_icon_variant', __( 'Categories icon design', 'mobi2app-connector' ), 'select', 'grid', array( 'grid' => __( 'Grid', 'mobi2app-connector' ), 'category' => __( 'Category shapes', 'mobi2app-connector' ), 'list' => __( 'List', 'mobi2app-connector' ) ) ),
			self::field( 'categories_label', __( 'Categories label', 'mobi2app-connector' ), 'text', __( 'Categories', 'mobi2app-connector' ) ),
			self::field( 'cart_icon_variant', __( 'Cart icon design', 'mobi2app-connector' ), 'select', 'bag', array( 'bag' => __( 'Shopping bag', 'mobi2app-connector' ), 'cart' => __( 'Shopping cart', 'mobi2app-connector' ), 'basket' => __( 'Shopping basket', 'mobi2app-connector' ) ) ),
			self::field( 'cart_label', __( 'Cart label', 'mobi2app-connector' ), 'text', __( 'Cart', 'mobi2app-connector' ) ),
			self::field( 'search_icon_variant', __( 'Search icon design', 'mobi2app-connector' ), 'select', 'rounded', array( 'rounded' => __( 'Rounded', 'mobi2app-connector' ), 'classic' => __( 'Classic', 'mobi2app-connector' ), 'minimal' => __( 'Minimal', 'mobi2app-connector' ) ) ),
			self::field( 'search_label', __( 'Search label', 'mobi2app-connector' ), 'text', __( 'Search', 'mobi2app-connector' ) ),
			self::field( 'wishlist_icon_variant', __( 'Wishlist icon design', 'mobi2app-connector' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'mobi2app-connector' ), 'rounded' => __( 'Rounded heart', 'mobi2app-connector' ), 'bookmark' => __( 'Bookmark', 'mobi2app-connector' ) ) ),
			self::field( 'wishlist_label', __( 'Wishlist label', 'mobi2app-connector' ), 'text', __( 'Wishlist', 'mobi2app-connector' ) ),
			self::field( 'account_icon_variant', __( 'Account icon design', 'mobi2app-connector' ), 'select', 'person', array( 'person' => __( 'Person', 'mobi2app-connector' ), 'circle' => __( 'Person circle', 'mobi2app-connector' ), 'profile' => __( 'Profile', 'mobi2app-connector' ) ) ),
			self::field( 'account_label', __( 'Account label', 'mobi2app-connector' ), 'text', __( 'Account', 'mobi2app-connector' ) ),
			self::field( 'orders_icon_variant', __( 'Orders icon design', 'mobi2app-connector' ), 'select', 'receipt', array( 'receipt' => __( 'Receipt', 'mobi2app-connector' ), 'box' => __( 'Package', 'mobi2app-connector' ), 'list' => __( 'Order list', 'mobi2app-connector' ) ) ),
			self::field( 'orders_label', __( 'Orders label', 'mobi2app-connector' ), 'text', __( 'Orders', 'mobi2app-connector' ) ),
			self::field( 'show_share', __( 'Show share', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'share_label', __( 'Share label', 'mobi2app-connector' ), 'text', __( 'Share', 'mobi2app-connector' ) ),
			self::field( 'share_icon_style', __( 'Share icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'circle' => __( 'Circle', 'mobi2app-connector' ) ) ),
			self::field( 'share_icon_variant', __( 'Share icon design', 'mobi2app-connector' ), 'select', 'upload', array( 'upload' => __( 'Upload arrow', 'mobi2app-connector' ), 'share' => __( 'Share nodes', 'mobi2app-connector' ), 'send' => __( 'Send', 'mobi2app-connector' ) ) ),
			self::field( 'share_icon_size', __( 'Share icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'share_color', __( 'Share color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'show_like', __( 'Show like', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'like_label', __( 'Like label', 'mobi2app-connector' ), 'text', __( 'Like', 'mobi2app-connector' ) ),
			self::field( 'like_icon_style', __( 'Like icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'circle' => __( 'Circle', 'mobi2app-connector' ) ) ),
			self::field( 'like_icon_variant', __( 'Like icon design', 'mobi2app-connector' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'mobi2app-connector' ), 'rounded' => __( 'Rounded heart', 'mobi2app-connector' ), 'bookmark' => __( 'Bookmark', 'mobi2app-connector' ) ) ),
			self::field( 'like_icon_size', __( 'Like icon size', 'mobi2app-connector' ), 'number', 24, array(), 16, 40 ),
			self::field( 'like_color', __( 'Like color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'show_add_to_cart', __( 'Show add to cart', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_button_icon', __( 'Show bag icon inside button', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'add_to_cart_label', __( 'Add to cart label', 'mobi2app-connector' ), 'text', __( 'Add to bag', 'mobi2app-connector' ) ),
			self::field( 'button_color', __( 'Button color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'button_text_color', __( 'Button text color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'button_width_percent', __( 'Button width (% of footer)', 'mobi2app-connector' ), 'number', 58, array(), 20, 95 ),
			self::field( 'button_height', __( 'Button height', 'mobi2app-connector' ), 'number', 52, array(), 36, 80, 0.01 ),
			self::field( 'button_style', __( 'Button style', 'mobi2app-connector' ), 'select', 'filled', array( 'filled' => __( 'Filled', 'mobi2app-connector' ), 'outline' => __( 'Outline', 'mobi2app-connector' ), 'soft' => __( 'Soft', 'mobi2app-connector' ) ) ),
			self::field( 'quick_add_layout', __( 'Quick add footer', 'mobi2app-connector' ), 'select', 'button', array( 'button' => __( 'Add button only', 'mobi2app-connector' ), 'wishlist_button' => __( 'Wishlist beside rounded add button', 'mobi2app-connector' ) ) ),
			self::field( 'button_shape', __( 'Button shape', 'mobi2app-connector' ), 'select', 'custom', array( 'custom' => __( 'Custom radius', 'mobi2app-connector' ), 'rectangle' => __( 'Rectangle', 'mobi2app-connector' ), 'rounded' => __( 'Rounded', 'mobi2app-connector' ), 'pill' => __( 'Pill', 'mobi2app-connector' ) ) ),
			self::field( 'button_radius', __( 'Button radius', 'mobi2app-connector' ), 'number', 28, array(), 0, 40 ),
			self::field( 'button_border_color', __( 'Button border color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'button_border_width', __( 'Button border width', 'mobi2app-connector' ), 'number', 0, array(), 0, 6 ),
			self::field( 'show_price', __( 'Show price', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_quantity', __( 'Show quantity', 'mobi2app-connector' ), 'checkbox', false ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public static function element_definitions( string $page ): array {
		$page = sanitize_key( $page );
		$common_grid = array(
			self::field( 'quick_add_enabled', __( 'Quick add to cart', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'quick_add_icon_variant', __( 'Quick add icon shape', 'mobi2app-connector' ), 'select', 'bag', array( 'bag' => __( 'Shopping bag', 'mobi2app-connector' ), 'cart' => __( 'Shopping cart', 'mobi2app-connector' ), 'basket' => __( 'Shopping basket', 'mobi2app-connector' ) ) ),
			self::field( 'quick_add_icon_style', __( 'Quick add icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'rounded' => __( 'Rounded', 'mobi2app-connector' ) ) ),
			self::field( 'quick_add_icon_size', __( 'Quick add icon size', 'mobi2app-connector' ), 'number', 22, array(), 10, 36 ),
			self::field( 'quick_add_icon_color', __( 'Quick add icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'quick_add_show_background', __( 'White background behind icon', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'quick_add_background_color', __( 'Quick add background color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'quick_add_background_size', __( 'Quick add background size', 'mobi2app-connector' ), 'number', 40, array(), 10, 64 ),
			self::field( 'quick_add_radius', __( 'Quick add background radius', 'mobi2app-connector' ), 'number', 24, array(), 0, 40 ),
			self::field( 'quick_add_position', __( 'Quick add position', 'mobi2app-connector' ), 'product_position', 'bottom_end', array( 'top_start' => __( 'Top start', 'mobi2app-connector' ), 'top_end' => __( 'Top end', 'mobi2app-connector' ), 'bottom_start' => __( 'Bottom start', 'mobi2app-connector' ), 'bottom_end' => __( 'Bottom end', 'mobi2app-connector' ) ) ),
			self::field( 'show_wishlist', __( 'Product wishlist icon', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'product_wishlist_icon_variant', __( 'Product wishlist icon shape', 'mobi2app-connector' ), 'select', 'heart', array( 'heart' => __( 'Heart', 'mobi2app-connector' ), 'rounded' => __( 'Rounded heart', 'mobi2app-connector' ), 'bookmark' => __( 'Bookmark', 'mobi2app-connector' ) ) ),
			self::field( 'product_wishlist_icon_style', __( 'Product wishlist icon style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ) ) ),
			self::field( 'product_wishlist_icon_size', __( 'Product wishlist icon size', 'mobi2app-connector' ), 'number', 20, array(), 10, 36 ),
			self::field( 'product_wishlist_icon_color', __( 'Product wishlist icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'product_wishlist_show_background', __( 'Product wishlist background', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'product_wishlist_background_color', __( 'Product wishlist background color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'product_wishlist_background_size', __( 'Product wishlist background size', 'mobi2app-connector' ), 'number', 40, array(), 20, 64 ),
			self::field( 'product_wishlist_radius', __( 'Product wishlist background radius', 'mobi2app-connector' ), 'number', 24, array(), 0, 40 ),
			self::field( 'product_wishlist_position', __( 'Product wishlist position', 'mobi2app-connector' ), 'product_position', 'top_end', array( 'top_start' => __( 'Top start', 'mobi2app-connector' ), 'top_end' => __( 'Top end', 'mobi2app-connector' ), 'bottom_start' => __( 'Bottom start', 'mobi2app-connector' ), 'bottom_end' => __( 'Bottom end', 'mobi2app-connector' ) ) ),
			self::field( 'source', __( 'Source', 'mobi2app-connector' ), 'select', 'latest', array( 'latest' => __( 'Latest', 'mobi2app-connector' ), 'category' => __( 'Category', 'mobi2app-connector' ), 'featured' => __( 'Featured', 'mobi2app-connector' ), 'on_sale' => __( 'On sale', 'mobi2app-connector' ), 'manual' => __( 'Manual IDs', 'mobi2app-connector' ) ) ),
			self::field( 'category_id', __( 'Category ID', 'mobi2app-connector' ), 'number', 0, array(), 0, 999999999 ),
			self::field( 'manual_product_ids', __( 'Manual Product IDs', 'mobi2app-connector' ), 'text', '' ),
			self::field( 'columns', __( 'Columns', 'mobi2app-connector' ), 'number', 2, array(), 1, 4 ),
			self::field( 'gap', __( 'Gap', 'mobi2app-connector' ), 'number', 12, array(), 0, 32 ),
			self::field( 'card_style', __( 'Card style', 'mobi2app-connector' ), 'select', 'outlined', array( 'minimal' => __( 'Minimal', 'mobi2app-connector' ), 'no_shadow' => __( 'No shadow', 'mobi2app-connector' ), 'outlined' => __( 'Outlined', 'mobi2app-connector' ), 'elevated' => __( 'Elevated', 'mobi2app-connector' ) ) ),
			self::field( 'card_outline_color', __( 'Outline color', 'mobi2app-connector' ), 'color', sanitize_hex_color( (string) ( class_exists( 'MobiShop_Setup_Wizard' ) ? ( new MobiShop_Setup_Wizard() )->identity()['primary_color'] ?? '' : '' ) ) ?: '#2F806E' ),
			self::field( 'card_outline_width', __( 'Outline width', 'mobi2app-connector' ), 'number', 1, array(), 0, 6, 0.5 ),
			self::field( 'card_radius', __( 'Card radius', 'mobi2app-connector' ), 'number', 16, array(), 0, 40 ),
			self::field( 'image_ratio', __( 'Image ratio', 'mobi2app-connector' ), 'number', 1, array(), 0.6, 1.8, 0.1 ),
			self::field( 'outer_horizontal_padding', __( 'Grid side padding', 'mobi2app-connector' ), 'number', 16, array(), 0, 40 ),
			self::field( 'top_spacing', __( 'Grid top spacing', 'mobi2app-connector' ), 'number', 20, array(), 0, 48 ),
			self::field( 'image_inset', __( 'Image inner spacing', 'mobi2app-connector' ), 'number', 5, array(), 0, 24 ),
			self::field( 'image_radius', __( 'Image radius', 'mobi2app-connector' ), 'number', 10, array(), 0, 40 ),
			self::field( 'content_horizontal_padding', __( 'Product text side padding', 'mobi2app-connector' ), 'number', 9, array(), 0, 24 ),
			self::field( 'content_top_padding', __( 'Product text top padding', 'mobi2app-connector' ), 'number', 5, array(), 0, 24 ),
			self::field( 'content_bottom_padding', __( 'Product text bottom padding', 'mobi2app-connector' ), 'number', 9, array(), 0, 24 ),
			self::field( 'price_prefix', __( 'Price prefix', 'mobi2app-connector' ), 'text', '' ),
			self::field( 'price_color', __( 'Price color', 'mobi2app-connector' ), 'color', '#1F2933' ),
			self::field( 'price_size', __( 'Price size', 'mobi2app-connector' ), 'number', 14, array(), 10, 28 ),
			self::field( 'enable_image_swipe', __( 'Swipe product images on the card', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_name', __( 'Show product name', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_price', __( 'Show price', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_regular_price', __( 'Show regular price', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_rating', __( 'Show rating', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_badge', __( 'Show badge', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'pagination_mode', __( 'Pagination mode', 'mobi2app-connector' ), 'select', 'load_more', array( 'numbers' => __( 'Page numbers', 'mobi2app-connector' ), 'load_more' => __( 'Load more button', 'mobi2app-connector' ), 'automatic' => __( 'Automatic loading', 'mobi2app-connector' ), 'none' => __( 'No pagination', 'mobi2app-connector' ) ) ),
			self::field( 'products_per_page', __( 'Products per page', 'mobi2app-connector' ), 'number', 12, array(), 4, 48 ),
			self::field( 'pagination_label', __( 'Load more label', 'mobi2app-connector' ), 'text', __( 'Load more', 'mobi2app-connector' ) ),
			self::field( 'pagination_size', __( 'Pagination size', 'mobi2app-connector' ), 'number', 44, array(), 32, 64 ),
			self::field( 'pagination_radius', __( 'Pagination radius', 'mobi2app-connector' ), 'number', 14, array(), 0, 32 ),
			self::field( 'pagination_color', __( 'Pagination color', 'mobi2app-connector' ), 'color', '#1F6F61' ),
			self::field( 'pagination_text_color', __( 'Pagination text color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'pagination_spacing', __( 'Pagination spacing', 'mobi2app-connector' ), 'number', 16, array(), 0, 40 ),
		);
		$quick_add_keys = array( 'quick_add_enabled', 'quick_add_icon_variant', 'quick_add_icon_style', 'quick_add_icon_size', 'quick_add_icon_color', 'quick_add_show_background', 'quick_add_background_color', 'quick_add_background_size', 'quick_add_radius', 'quick_add_position', 'show_wishlist', 'product_wishlist_icon_variant', 'product_wishlist_icon_style', 'product_wishlist_icon_size', 'product_wishlist_icon_color', 'product_wishlist_show_background', 'product_wishlist_background_color', 'product_wishlist_background_size', 'product_wishlist_radius', 'product_wishlist_position' );
		$catalog_grid_keys = array_merge( $quick_add_keys, array( 'columns', 'gap', 'card_style', 'card_outline_color', 'card_outline_width', 'card_radius', 'image_ratio', 'outer_horizontal_padding', 'top_spacing', 'image_inset', 'image_radius', 'content_horizontal_padding', 'content_top_padding', 'content_bottom_padding', 'price_prefix', 'price_color', 'price_size', 'enable_image_swipe', 'show_name', 'show_price', 'show_regular_price', 'show_rating', 'show_badge', 'pagination_mode', 'products_per_page', 'pagination_label', 'pagination_size', 'pagination_radius', 'pagination_color', 'pagination_text_color', 'pagination_spacing' ) );
		$wishlist_grid_keys = array_merge( $quick_add_keys, array( 'columns', 'gap', 'card_style', 'card_outline_color', 'card_outline_width', 'card_radius', 'image_ratio', 'outer_horizontal_padding', 'top_spacing', 'image_inset', 'image_radius', 'content_horizontal_padding', 'content_top_padding', 'content_bottom_padding', 'price_prefix', 'price_color', 'price_size', 'enable_image_swipe', 'show_name', 'show_price', 'show_regular_price', 'show_rating', 'show_badge' ) );
		$catalog_grid = array_values( array_filter( $common_grid, static fn ( array $field ): bool => in_array( $field['key'], $catalog_grid_keys, true ) ) );
		$wishlist_grid = array_values( array_filter( $common_grid, static fn ( array $field ): bool => in_array( $field['key'], $wishlist_grid_keys, true ) ) );
		$wishlist_grid_defaults = array( 'gap' => 8, 'card_style' => 'minimal', 'card_radius' => 0, 'image_ratio' => 0.82, 'show_name' => false, 'show_regular_price' => false, 'show_rating' => false, 'show_badge' => false );
		foreach ( $wishlist_grid as &$wishlist_grid_field ) {
			if ( array_key_exists( $wishlist_grid_field['key'], $wishlist_grid_defaults ) ) {
				$wishlist_grid_field['default'] = $wishlist_grid_defaults[ $wishlist_grid_field['key'] ];
			}
		}
		unset( $wishlist_grid_field );
		$related_grid = $wishlist_grid;
		$related_defaults = array( 'gap' => 2, 'image_ratio' => 0.75, 'show_regular_price' => true, 'show_badge' => true );
		foreach ( $related_grid as &$related_field ) {
			if ( array_key_exists( $related_field['key'], $related_defaults ) ) {
				$related_field['default'] = $related_defaults[ $related_field['key'] ];
			}
		}
		unset( $related_field );
		$wishlist_message_fields = static function ( string $title, string $description, string $button_label, string $button_action ): array {
			return array(
				self::field( 'illustration_url', __( 'Illustration', 'mobi2app-connector' ), 'image', '' ),
				self::field( 'illustration_size', __( 'Illustration size', 'mobi2app-connector' ), 'number', 104, array(), 56, 180 ),
				self::field( 'top_spacing', __( 'Space above illustration', 'mobi2app-connector' ), 'number', 56, array(), 0, 180 ),
				self::field( 'title', __( 'Title', 'mobi2app-connector' ), 'text', $title ),
				self::field( 'title_size', __( 'Title size', 'mobi2app-connector' ), 'number', 18, array(), 12, 36 ),
				self::field( 'title_weight', __( 'Title weight', 'mobi2app-connector' ), 'select', '700', array( '400' => __( 'Regular', 'mobi2app-connector' ), '500' => __( 'Medium', 'mobi2app-connector' ), '600' => __( 'Semi bold', 'mobi2app-connector' ), '700' => __( 'Bold', 'mobi2app-connector' ), '800' => __( 'Extra bold', 'mobi2app-connector' ) ) ),
				self::field( 'description', __( 'Description', 'mobi2app-connector' ), 'text', $description ),
				self::field( 'show_description', __( 'Show description', 'mobi2app-connector' ), 'checkbox', '' !== $description ),
				self::field( 'description_size', __( 'Description size', 'mobi2app-connector' ), 'number', 14, array(), 11, 26 ),
				self::field( 'content_gap', __( 'Content spacing', 'mobi2app-connector' ), 'number', 16, array(), 0, 48 ),
				self::field( 'button_label', __( 'Button label', 'mobi2app-connector' ), 'text', $button_label ),
				self::field( 'button_action', __( 'Button action', 'mobi2app-connector' ), 'select', $button_action, array( 'shopping' => __( 'Continue shopping', 'mobi2app-connector' ), 'sign_in' => __( 'Sign in', 'mobi2app-connector' ) ) ),
				self::field( 'show_button', __( 'Show button', 'mobi2app-connector' ), 'checkbox', true ),
				self::field( 'button_width', __( 'Button width', 'mobi2app-connector' ), 'number', 220, array(), 120, 360 ),
				self::field( 'button_height', __( 'Button height', 'mobi2app-connector' ), 'number', 52, array(), 36, 84 ),
				self::field( 'button_radius', __( 'Button radius', 'mobi2app-connector' ), 'number', 26, array(), 0, 42 ),
				self::field( 'button_style', __( 'Button style', 'mobi2app-connector' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ) ) ),
				self::field( 'button_color', __( 'Button color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
				self::field( 'button_text_color', __( 'Button text color', 'mobi2app-connector' ), 'color', '#1D1D1D' ),
				self::field( 'button_border_color', __( 'Button border color', 'mobi2app-connector' ), 'color', '#1D1D1D' ),
				self::field( 'button_border_width', __( 'Button border width', 'mobi2app-connector' ), 'number', 1.5, array(), 0, 6, 0.5 ),
				self::field( 'bottom_spacing', __( 'Space below content', 'mobi2app-connector' ), 'number', 96, array(), 0, 220 ),
			);
		};
		$wishlist_recommendation_fields = array(
			self::field( 'title', __( 'Section title', 'mobi2app-connector' ), 'text', __( 'You may also like', 'mobi2app-connector' ) ),
			self::field( 'title_size', __( 'Title size', 'mobi2app-connector' ), 'number', 20, array(), 14, 36 ),
			self::field( 'title_weight', __( 'Title weight', 'mobi2app-connector' ), 'select', '700', array( '400' => __( 'Regular', 'mobi2app-connector' ), '500' => __( 'Medium', 'mobi2app-connector' ), '600' => __( 'Semi bold', 'mobi2app-connector' ), '700' => __( 'Bold', 'mobi2app-connector' ), '800' => __( 'Extra bold', 'mobi2app-connector' ) ) ),
			self::field( 'columns', __( 'Columns', 'mobi2app-connector' ), 'number', 2, array(), 1, 3 ),
			self::field( 'gap', __( 'Gap', 'mobi2app-connector' ), 'number', 8, array(), 0, 24 ),
			self::field( 'image_ratio', __( 'Image ratio', 'mobi2app-connector' ), 'number', 0.82, array(), 0.6, 1.8, 0.05 ),
			self::field( 'enable_image_swipe', __( 'Swipe product images on the card', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'limit', __( 'Products count', 'mobi2app-connector' ), 'number', 4, array(), 2, 12 ),
			self::field( 'show_name', __( 'Show product name', 'mobi2app-connector' ), 'checkbox', false ),
			self::field( 'show_price', __( 'Show price', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'show_quick_add', __( 'Show quick add', 'mobi2app-connector' ), 'checkbox', true ),
			self::field( 'layout_style', __( 'Product layout', 'mobi2app-connector' ), 'select', 'grid', array( 'grid' => __( 'Grid', 'mobi2app-connector' ), 'compact' => __( 'Compact grid', 'mobi2app-connector' ), 'carousel' => __( 'Horizontal carousel', 'mobi2app-connector' ) ) ),
			self::field( 'card_radius', __( 'Card radius', 'mobi2app-connector' ), 'number', 0, array(), 0, 32 ),
			self::field( 'card_background_color', __( 'Card background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
			self::field( 'action_type', __( 'Action type', 'mobi2app-connector' ), 'select', 'product', array( 'product' => __( 'Open product', 'mobi2app-connector' ), 'category' => __( 'Open category', 'mobi2app-connector' ), 'url' => __( 'Open URL', 'mobi2app-connector' ), 'none' => __( 'No action', 'mobi2app-connector' ) ) ),
			self::field( 'action_value', __( 'Action value', 'mobi2app-connector' ), 'text', '' ),
			self::field( 'section_padding', __( 'Side padding', 'mobi2app-connector' ), 'number', 16, array(), 0, 32 ),
			self::field( 'title_bottom_spacing', __( 'Space below title', 'mobi2app-connector' ), 'number', 18, array(), 0, 48 ),
		);

		$definitions = array(
			'home' => array(),
			'category' => array(),
			'catalog' => array(
				self::element( 'filter_bar', __( 'Filter and Sort Bar', 'mobi2app-connector' ), 'dashicons-filter', array(
					self::field( 'sticky', __( 'Sticky', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'show_filter', __( 'Show filter button', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'show_sort', __( 'Show sort', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'show_result_count', __( 'Show result count', 'mobi2app-connector' ), 'checkbox', false ),
					self::field( 'filter_price', __( 'Available filter: Price', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'filter_sale', __( 'Available filter: On sale', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'filter_brand', __( 'Available filter: Brand', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'filter_size', __( 'Available filter: Size', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'filter_color', __( 'Available filter: Color', 'mobi2app-connector' ), 'checkbox', false ),
					self::field( 'button_style', __( 'Filter button style', 'mobi2app-connector' ), 'select', 'outlined', array( 'outlined' => __( 'Outlined', 'mobi2app-connector' ), 'flat' => __( 'Flat labels', 'mobi2app-connector' ) ) ),
					self::field( 'block_width', __( 'Filter block width (%)', 'mobi2app-connector' ), 'number', 100, array(), 40, 100 ),
					self::field( 'block_height', __( 'Filter block height', 'mobi2app-connector' ), 'number', 56, array(), 48, 100 ),
					self::field( 'icon_size', __( 'Icon size', 'mobi2app-connector' ), 'number', 22, array(), 14, 36 ),
					self::field( 'filter_icon_offset_y', __( 'Filter icon vertical position', 'mobi2app-connector' ), 'number', -2, array(), -8, 8 ),
					self::field( 'button_radius', __( 'Button radius', 'mobi2app-connector' ), 'number', 12, array(), 0, 28 ),
					self::field( 'button_gap', __( 'Button spacing', 'mobi2app-connector' ), 'number', 8, array(), 0, 24 ),
					self::field( 'background_color', __( 'Background', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
					self::field( 'icon_color', __( 'Icon color', 'mobi2app-connector' ), 'color', '#1F2933' ),
					self::field( 'border_color', __( 'Border color', 'mobi2app-connector' ), 'color', '#DDE3E8' )
				) ),
				self::element( 'product_grid', __( 'Product Grid', 'mobi2app-connector' ), 'dashicons-grid-view', $catalog_grid ),
			),
			'product' => array(
				self::element( 'product_tabs', __( 'Product Tabs', 'mobi2app-connector' ), 'dashicons-index-card', array( self::field( 'sticky', __( 'Keep tabs visible while scrolling', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'after_summary', __( 'Show tabs after product summary', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'tabs_json', __( 'Visible product tabs', 'mobi2app-connector' ), 'tabs', wp_json_encode( array( array( 'label' => __( 'Overview', 'mobi2app-connector' ), 'target' => 'overview', 'enabled' => true ), array( 'label' => __( 'Reviews', 'mobi2app-connector' ), 'target' => 'reviews', 'enabled' => true ), array( 'label' => __( 'Recommend', 'mobi2app-connector' ), 'target' => 'recommend', 'enabled' => true ) ) ) ), self::field( 'active_color', __( 'Active tab color', 'mobi2app-connector' ), 'color', '#1D1D1D' ), self::field( 'inactive_color', __( 'Inactive tab color', 'mobi2app-connector' ), 'color', '#6B6B6B' ), self::field( 'indicator_width', __( 'Indicator width', 'mobi2app-connector' ), 'number', 96, array(), 24, 160 ), self::field( 'height', __( 'Tabs height', 'mobi2app-connector' ), 'number', 64, array(), 44, 88 ) ) ),
				self::element( 'image_gallery', __( 'Product Gallery', 'mobi2app-connector' ), 'dashicons-format-gallery', array( self::field( 'aspect_ratio', __( 'Image ratio', 'mobi2app-connector' ), 'number', 0.75, array(), 0.6, 1.8, 0.05 ), self::field( 'fit', __( 'Image fit', 'mobi2app-connector' ), 'select', 'contain', array( 'contain' => __( 'Contain', 'mobi2app-connector' ), 'cover' => __( 'Cover', 'mobi2app-connector' ) ) ), self::field( 'background_color', __( 'Gallery background', 'mobi2app-connector' ), 'color', '#FFFFFF' ), self::field( 'show_thumbnails', __( 'Show thumbnails', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'show_indicators', __( 'Show indicators', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'show_counter', __( 'Show image counter', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'counter_background', __( 'Counter background', 'mobi2app-connector' ), 'color', '#8A8585' ), self::field( 'counter_text_color', __( 'Counter text color', 'mobi2app-connector' ), 'color', '#FFFFFF' ), self::field( 'enable_zoom', __( 'Enable zoom', 'mobi2app-connector' ), 'checkbox', false ) ) ),
				self::element( 'product_summary', __( 'Product Information', 'mobi2app-connector' ), 'dashicons-info-outline', array( self::field( 'show_name', __( 'Show name', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_price', __( 'Show price', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_regular_price', __( 'Show regular price', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_rating', __( 'Show rating', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_review_count', __( 'Show review count', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_sku', __( 'Show SKU', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'show_stock', __( 'Show stock', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'show_badge', __( 'Show badge', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'show_selected_color', __( 'Show selected color', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'price_size', __( 'Price size', 'mobi2app-connector' ), 'number', 25, array(), 14, 36 ), self::field( 'name_size', __( 'Product name size', 'mobi2app-connector' ), 'number', 18, array(), 12, 28 ) ) ),
				self::element( 'variations', __( 'Variations', 'mobi2app-connector' ), 'dashicons-screenoptions', array( self::field( 'style', __( 'Selector style', 'mobi2app-connector' ), 'select', 'chips', array( 'chips' => __( 'Chips', 'mobi2app-connector' ), 'dropdown' => __( 'Dropdown', 'mobi2app-connector' ) ) ), self::field( 'show_size_chart', __( 'Show size chart link', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'size_chart_label', __( 'Size chart label', 'mobi2app-connector' ), 'text', __( 'Size chart', 'mobi2app-connector' ) ), self::field( 'chip_radius', __( 'Option radius', 'mobi2app-connector' ), 'number', 22, array(), 0, 32 ), self::field( 'chip_height', __( 'Option height', 'mobi2app-connector' ), 'number', 38, array(), 30, 56 ) ) ),
				self::element( 'purchase_bar', __( 'Quantity', 'mobi2app-connector' ), 'dashicons-cart', array( self::field( 'show_quantity', __( 'Show quantity', 'mobi2app-connector' ), 'checkbox', false ) ) ),
				self::element( 'description', __( 'Description and Details', 'mobi2app-connector' ), 'dashicons-text-page', array( self::field( 'accordion', __( 'Use compact accordion rows', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'details_label', __( 'Details label', 'mobi2app-connector' ), 'text', __( 'Product Details', 'mobi2app-connector' ) ), self::field( 'show_description', __( 'Show description', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_attributes', __( 'Show attributes', 'mobi2app-connector' ), 'checkbox', true ) ) ),
				self::element( 'reviews', __( 'Reviews', 'mobi2app-connector' ), 'dashicons-star-filled', array( self::field( 'title', __( 'Reviews title', 'mobi2app-connector' ), 'text', __( 'Reviews', 'mobi2app-connector' ) ), self::field( 'show_summary', __( 'Show rating summary', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_fit_summary', __( 'Show size and fit summary', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'fit_small_percent', __( 'Small (%)', 'mobi2app-connector' ), 'number', 1, array(), 0, 100 ), self::field( 'fit_true_percent', __( 'True to size (%)', 'mobi2app-connector' ), 'number', 99, array(), 0, 100 ), self::field( 'fit_large_percent', __( 'Large (%)', 'mobi2app-connector' ), 'number', 0, array(), 0, 100 ) ) ),
				self::element( 'related_products', __( 'Related Products', 'mobi2app-connector' ), 'dashicons-products', array_merge( array( self::field( 'title', __( 'Section title', 'mobi2app-connector' ), 'text', __( 'You may also like', 'mobi2app-connector' ) ) ), $related_grid, array( self::field( 'show_quick_add', __( 'Show quick add', 'mobi2app-connector' ), 'checkbox', true ) ) ) ),
			),
			'size_chart' => array(
				self::element( 'size_chart_content', __( 'Size Chart', 'mobi2app-connector' ), 'dashicons-editor-table', array(
					self::field( 'title', __( 'Page title', 'mobi2app-connector' ), 'text', __( 'Size chart', 'mobi2app-connector' ) ),
					self::field( 'description', __( 'Description', 'mobi2app-connector' ), 'text', __( 'Choose the size that fits you best.', 'mobi2app-connector' ) ),
					self::field( 'layout_style', __( 'Layout', 'mobi2app-connector' ), 'select', 'list', array( 'list' => __( 'List', 'mobi2app-connector' ), 'table' => __( 'Table', 'mobi2app-connector' ), 'chips' => __( 'Chips', 'mobi2app-connector' ) ) ),
					self::field( 'show_description', __( 'Show description', 'mobi2app-connector' ), 'checkbox', true ),
					self::field( 'row_height', __( 'Row height', 'mobi2app-connector' ), 'number', 52, array(), 36, 80 ),
					self::field( 'title_size', __( 'Title size', 'mobi2app-connector' ), 'number', 24, array(), 14, 40 ),
					self::field( 'row_color', __( 'Row background', 'mobi2app-connector' ), 'color', '#F6F8F7' ),
					self::field( 'text_color', __( 'Text color', 'mobi2app-connector' ), 'color', '#1F2933' ),
					self::field( 'accent_color', __( 'Selected color', 'mobi2app-connector' ), 'color', '#2F806E' )
				) ),
			),
			'wishlist' => array(
				self::element( 'sign_in_state', __( 'Sign-in Wishlist', 'mobi2app-connector' ), 'dashicons-lock', $wishlist_message_fields( __( 'Sign in to view your wishlist', 'mobi2app-connector' ), '', __( 'Sign In', 'mobi2app-connector' ), 'sign_in' ) ),
				self::element( 'sign_in_recommendations', __( 'Sign-in Recommendations', 'mobi2app-connector' ), 'dashicons-products', $wishlist_recommendation_fields ),
				self::element( 'empty_state', __( 'Empty Wishlist', 'mobi2app-connector' ), 'dashicons-heart', $wishlist_message_fields( __( 'Your wishlist is empty', 'mobi2app-connector' ), __( 'Add items here by clicking the little heart!', 'mobi2app-connector' ), __( 'Go Shopping', 'mobi2app-connector' ), 'shopping' ) ),
				self::element( 'empty_recommendations', __( 'Empty Wishlist Recommendations', 'mobi2app-connector' ), 'dashicons-products', $wishlist_recommendation_fields ),
				self::element( 'wishlist_grid', __( 'Wishlist Products', 'mobi2app-connector' ), 'dashicons-grid-view', $wishlist_grid ),
				self::element( 'products_recommendations', __( 'Wishlist Product Recommendations', 'mobi2app-connector' ), 'dashicons-products', $wishlist_recommendation_fields ),
			),
			'account' => array(
				self::element( 'account_summary', __( 'Account Summary', 'mobi2app-connector' ), 'dashicons-admin-users', array( self::field( 'avatar_size', __( 'Avatar size', 'mobi2app-connector' ), 'number', 66, array(), 40, 110 ), self::field( 'show_email', __( 'Show email', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'guest_title', __( 'Guest title', 'mobi2app-connector' ), 'text', __( 'Sign in / Create account', 'mobi2app-connector' ) ), self::field( 'card_style', __( 'Card style', 'mobi2app-connector' ), 'select', 'elevated', array( 'minimal' => __( 'Minimal', 'mobi2app-connector' ), 'no_shadow' => __( 'No shadow', 'mobi2app-connector' ), 'outlined' => __( 'Outlined', 'mobi2app-connector' ), 'elevated' => __( 'Elevated', 'mobi2app-connector' ) ) ) ) ),
				self::element( 'account_menu', __( 'Account Menu', 'mobi2app-connector' ), 'dashicons-menu-alt', array( self::field( 'compact_family', __( 'Compact family storefront', 'mobi2app-connector' ), 'checkbox', false ), self::field( 'show_orders', __( 'Show orders', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_addresses', __( 'Show addresses', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_profile', __( 'Show profile', 'mobi2app-connector' ), 'checkbox', true ), self::field( 'show_support', __( 'Show support', 'mobi2app-connector' ), 'checkbox', true ) ) ),
				self::element( 'logout_button', __( 'Logout Button', 'mobi2app-connector' ), 'dashicons-exit', array() ),
			),
		);

		$presentation = array(
			self::field( 'margin_top', __( 'Merge up', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'margin_bottom', __( 'Merge down', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_up', __( 'Space up', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'space_down', __( 'Space down', 'mobi2app-connector' ), 'number', 0, array(), 0, 80 ),
			self::field( 'padding_vertical', __( 'Inner vertical space', 'mobi2app-connector' ), 'number', 0, array(), 0, 40 ),
			self::field( 'padding_horizontal', __( 'Inner side space', 'mobi2app-connector' ), 'number', 0, array(), 0, 40 ),
			self::field( 'background_color', __( 'Background color', 'mobi2app-connector' ), 'color', '#FFFFFF' ),
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
		$default['enabled'] = ! isset( $saved['enabled'] ) || ! empty( $saved['enabled'] );
		$saved_page_settings = is_array( $saved['settings'] ?? null ) ? $saved['settings'] : array();
		$default['settings']['page_background_color'] = sanitize_hex_color( (string) ( $saved_page_settings['page_background_color'] ?? '' ) ) ?: '#FFFFFF';
		$default['settings']['font_family'] = in_array( (string) ( $saved_page_settings['font_family'] ?? '' ), array( 'system', 'poppins', 'roboto', 'noto_sans_arabic', 'serif', 'monospace' ), true ) ? (string) $saved_page_settings['font_family'] : 'system';
		$default['settings']['content_horizontal_padding'] = max( 0, min( 40, intval( $saved_page_settings['content_horizontal_padding'] ?? 20 ) ) );
		if ( 'wishlist' === $page ) {
			$default['settings']['wishlist_access_mode'] = in_array( (string) ( $saved_page_settings['wishlist_access_mode'] ?? '' ), array( 'guest', 'sign_in_required' ), true ) ? (string) $saved_page_settings['wishlist_access_mode'] : 'sign_in_required';
			$default['settings']['wishlist_preview_state'] = in_array( (string) ( $saved_page_settings['wishlist_preview_state'] ?? '' ), array( 'sign_in', 'empty', 'products' ), true ) ? (string) $saved_page_settings['wishlist_preview_state'] : 'products';
		}
		// Keep saved chrome settings across schema upgrades. The browser and Flutter
		// readers migrate legacy left/center/right and flat footer layouts in place.
		$default['header'] = $this->merge_component( $default['header'], $saved['header'] ?? array(), self::header_fields() );
		if ( (int) ( $saved['version'] ?? 1 ) < 21 ) {
			foreach ( array( 'cart_offset_y', 'orders_offset_y' ) as $action_offset_key ) {
				$current_offset = (float) ( $default['header']['settings'][ $action_offset_key ] ?? 0 );
				$default['header']['settings'][ $action_offset_key ] = max( -80, $current_offset - 2 );
			}
		}
		if ( 'wishlist' === $page && (int) ( $saved['version'] ?? 1 ) < 19 ) {
			$default['header']['settings']['layout_json'] = wp_json_encode( $this->default_header_layout( 'wishlist' ) );
			$default['header']['settings']['height'] = 76;
			$default['header']['settings']['show_back'] = false;
			$default['header']['settings']['show_search'] = false;
			$default['header']['settings']['show_cart'] = true;
			$default['header']['settings']['show_cart_badge'] = true;
			$default['header']['settings']['title_font_size'] = 18;
			$default['header']['settings']['title_font_weight'] = '600';
			$default['header']['settings']['title_alignment'] = 'center';
		}
		if ( (int) ( $saved['version'] ?? 1 ) < 10 && 'sticky_search_cart' === (string) ( $saved['header']['settings']['collapse_preset'] ?? '' ) ) {
			$default['header']['settings']['collapse_transition'] = 'smooth_compact';
			$default['header']['settings']['compact_search_width_percent'] = 84;
		}
		$default['footer'] = $this->merge_component( $default['footer'], $saved['footer'] ?? array(), self::footer_fields() );
		$saved_elements = array();
		foreach ( is_array( $saved['elements'] ?? null ) ? $saved['elements'] : array() as $element ) {
			if ( is_array( $element ) && ! empty( $element['id'] ) ) {
				$saved_elements[] = $element;
			}
		}
		$definitions = array();
		foreach ( self::element_definitions( $page ) as $definition ) {
			$definitions[ $definition['id'] ] = $definition;
		}
		$elements = array();
		$used_definitions = array();
		foreach ( $saved_elements as $element ) {
			$id = sanitize_key( (string) ( $element['id'] ?? '' ) );
			$type = 'wishlist' === $page ? sanitize_key( (string) ( $element['type'] ?? $id ) ) : $id;
			if ( isset( $definitions[ $type ] ) ) {
				$merged = $this->merge_element( $definitions[ $type ], $element );
				if ( 'product' === $page && 'product_tabs' === $type && (int) ( $saved['version'] ?? 1 ) < 20 ) {
					$legacy_settings = is_array( $element['settings'] ?? null ) ? $element['settings'] : array();
					if ( empty( $legacy_settings['tabs_json'] ) ) {
						$merged['settings']['tabs_json'] = wp_json_encode( array(
							array( 'label' => sanitize_text_field( (string) ( $legacy_settings['overview_label'] ?? __( 'Overview', 'mobi2app-connector' ) ) ), 'target' => 'overview', 'enabled' => true ),
							array( 'label' => sanitize_text_field( (string) ( $legacy_settings['reviews_label'] ?? __( 'Reviews', 'mobi2app-connector' ) ) ), 'target' => 'reviews', 'enabled' => true ),
							array( 'label' => sanitize_text_field( (string) ( $legacy_settings['recommend_label'] ?? __( 'Recommend', 'mobi2app-connector' ) ) ), 'target' => 'recommend', 'enabled' => true ),
						) );
					}
				}
				$merged['id'] = $id ?: $type;
				$merged['type'] = $type;
				$elements[] = $merged;
				$used_definitions[ $type ] = true;
				if ( 'wishlist' !== $page ) {
					unset( $definitions[ $type ] );
				}
			}
		}
		foreach ( $definitions as $type => $definition ) {
			if ( ! isset( $used_definitions[ $type ] ) ) {
				$elements[] = $this->default_element( $definition );
			}
		}
		if ( 'wishlist' === $page && (int) ( $saved['version'] ?? 1 ) < 19 ) {
			$order = array( 'sign_in_state', 'sign_in_recommendations', 'empty_state', 'empty_recommendations', 'wishlist_grid', 'products_recommendations' );
			usort( $elements, static function ( array $left, array $right ) use ( $order ): int {
				return array_search( $left['id'], $order, true ) <=> array_search( $right['id'], $order, true );
			} );
		}
		if ( (int) ( $saved['version'] ?? 1 ) < 17 && 16 === (int) ( $default['footer']['settings']['horizontal_padding'] ?? 16 ) ) {
			// This field existed with a value of 16 while Flutter ignored it. Keep
			// the established mobile default unchanged when it becomes functional.
			$default['footer']['settings']['horizontal_padding'] = 0;
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
			$default['footer']['settings']['add_to_cart_label'] = __( 'Add to bag', 'mobi2app-connector' );
			$default['footer']['settings']['share_label'] = __( 'Share', 'mobi2app-connector' );
			$default['footer']['settings']['like_label'] = __( 'Like', 'mobi2app-connector' );
			$default['footer']['settings']['show_price'] = false;
			$default['footer']['settings']['show_quantity'] = false;
		}
		$default['elements'] = $elements;
		$default['updated_at'] = sanitize_text_field( (string) ( $saved['updated_at'] ?? '' ) );
		return $default;
	}

	/** @param array<string,mixed> $submitted */
	public function preview_layout( string $page, array $submitted ): array {
		$page = sanitize_key( $page );
		$current = $this->get_layout( $page );
		if ( empty( $current ) ) {
			return array();
		}
		$page_settings = array(
			'page_background_color' => sanitize_hex_color( (string) ( $submitted['settings']['page_background_color'] ?? '' ) ) ?: '#FFFFFF',
			'font_family' => in_array( (string) ( $submitted['settings']['font_family'] ?? '' ), array( 'system', 'poppins', 'roboto', 'noto_sans_arabic', 'serif', 'monospace' ), true ) ? (string) $submitted['settings']['font_family'] : 'system',
			'content_horizontal_padding' => max( 0, min( 40, intval( $submitted['settings']['content_horizontal_padding'] ?? 20 ) ) ),
		);
		if ( 'wishlist' === $page ) {
			$page_settings['wishlist_access_mode'] = in_array( (string) ( $submitted['settings']['wishlist_access_mode'] ?? '' ), array( 'guest', 'sign_in_required' ), true ) ? (string) $submitted['settings']['wishlist_access_mode'] : 'sign_in_required';
			$page_settings['wishlist_preview_state'] = in_array( (string) ( $submitted['settings']['wishlist_preview_state'] ?? '' ), array( 'sign_in', 'empty', 'products' ), true ) ? (string) $submitted['settings']['wishlist_preview_state'] : 'products';
		}
		$layout = array(
			'version' => self::VERSION,
			'page' => $page,
			'enabled' => ! isset( $submitted['enabled'] ) || ! empty( $submitted['enabled'] ),
			'updated_at' => gmdate( 'c' ),
			'settings' => $page_settings,
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
			$type = 'wishlist' === $page && is_array( $element ) ? sanitize_key( (string) ( $element['type'] ?? $id ) ) : $id;
			if ( isset( $definitions[ $type ] ) ) {
				$merged = $this->merge_element( $definitions[ $type ], $element );
				$merged['id'] = $id ?: $type;
				$merged['type'] = $type;
				$layout['elements'][] = $merged;
				if ( 'wishlist' !== $page ) {
					unset( $definitions[ $type ] );
				}
			}
		}
		$submitted_types = array_column( $layout['elements'], 'type' );
		foreach ( $definitions as $type => $definition ) {
			if ( ! in_array( $type, $submitted_types, true ) ) {
				$layout['elements'][] = $this->default_element( $definition );
			}
		}
		return $layout;
	}

	/** @param array<string,mixed> $submitted */
	public function save_layout( string $page, array $submitted ): array {
		$layout = $this->preview_layout( $page, $submitted );
		if ( empty( $layout ) ) {
			return array();
		}
		update_option( self::OPTION_PREFIX . sanitize_key( $page ), $layout, false );
		if ( function_exists( 'wp_cache_delete' ) ) {
			wp_cache_delete( self::OPTION_PREFIX . sanitize_key( $page ), 'options' );
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
	public function default_layout( string $page ): array {
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
			$header_settings['search_placeholder'] = __( 'Search products', 'mobi2app-connector' );
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
			$footer_settings['icon_label_gap'] = 2;
			$footer_settings['horizontal_padding'] = 0;
			$footer_settings['button_color'] = '#1D1D1D';
			$footer_settings['button_text_color'] = '#FFFFFF';
			$footer_settings['button_width_percent'] = 62;
			$footer_settings['button_height'] = 56;
			$footer_settings['button_radius'] = 28;
			$footer_settings['add_to_cart_label'] = __( 'Add to bag', 'mobi2app-connector' );
			$footer_settings['share_label'] = __( 'Share', 'mobi2app-connector' );
			$footer_settings['like_label'] = __( 'Like', 'mobi2app-connector' );
			$footer_settings['show_price'] = false;
			$footer_settings['show_quantity'] = false;
		}
		if ( 'wishlist' === $page ) {
			$header_settings['height'] = 76;
			$header_settings['vertical_padding'] = 6;
			$header_settings['show_back'] = false;
			$header_settings['show_search'] = false;
			$header_settings['show_cart'] = true;
			$header_settings['show_cart_badge'] = true;
			$header_settings['title_font_size'] = 18;
			$header_settings['title_font_weight'] = '600';
			$header_settings['title_alignment'] = 'center';
			$footer_settings['height'] = 64;
		}
		$layout = array(
			'version' => self::VERSION,
			'page' => $page,
			'enabled' => true,
			'updated_at' => '',
			'settings' => array( 'page_background_color' => '#FFFFFF' ),
			'header' => array( 'id' => 'header', 'type' => 'app_header', 'locked' => true, 'enabled' => true, 'settings' => $header_settings ),
			'elements' => $elements,
			'footer' => array( 'id' => 'footer', 'type' => 'app_footer', 'locked' => true, 'enabled' => true, 'settings' => $footer_settings ),
		);
		$layout['settings']['font_family'] = 'system';
		$layout['settings']['content_horizontal_padding'] = 20;
		if ( 'wishlist' === $page ) {
			$layout['settings']['wishlist_access_mode'] = 'sign_in_required';
			$layout['settings']['wishlist_preview_state'] = 'products';
		}
		return $layout;
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
			'wishlist' => array( 'rows' => array( $row( array( $column( 33.33, array(), 'left' ), $column( 33.34, array( 'title' ) ), $column( 33.33, array( 'cart' ), 'right' ) ) ) ) ),
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
				case 'tabs':
					$decoded = json_decode( (string) $value, true );
					$tabs = array();
					foreach ( is_array( $decoded ) ? array_slice( $decoded, 0, 10 ) : array() as $tab ) {
						if ( ! is_array( $tab ) ) { continue; }
						$target = sanitize_key( (string) ( $tab['target'] ?? '' ) );
						if ( ! in_array( $target, array( 'overview', 'variations', 'description', 'reviews', 'recommend' ), true ) ) { continue; }
						$label = sanitize_text_field( (string) ( $tab['label'] ?? '' ) );
						if ( '' === $label ) { continue; }
						$tabs[] = array( 'label' => $label, 'target' => $target, 'enabled' => ! empty( $tab['enabled'] ) );
					}
					$clean[ $key ] = wp_json_encode( ! empty( $tabs ) ? $tabs : json_decode( (string) $field['default'], true ) );
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
