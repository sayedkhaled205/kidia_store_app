<?php
/** Shared storage and schemas for non-home application page builders. */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_Page_Layout_Store {
	private const OPTION_PREFIX = 'kidia_mobile_page_layout_';
	private const VERSION = 1;

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
			self::field( 'title', __( 'Page title', 'kidia-mobile-cms' ), 'text', '' ),
			self::field( 'logo_url', __( 'Logo', 'kidia-mobile-cms' ), 'image', '' ),
			self::field( 'style', __( 'Header style', 'kidia-mobile-cms' ), 'select', 'standard', array( 'standard' => __( 'Standard', 'kidia-mobile-cms' ), 'compact' => __( 'Compact', 'kidia-mobile-cms' ), 'transparent' => __( 'Transparent', 'kidia-mobile-cms' ) ) ),
			self::field( 'height', __( 'Height', 'kidia-mobile-cms' ), 'number', 64, array(), 48, 120 ),
			self::field( 'background_color', __( 'Background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'title_color', __( 'Title color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'icon_gap', __( 'Icon spacing', 'kidia-mobile-cms' ), 'number', 6, array(), 0, 24 ),
			self::field( 'horizontal_padding', __( 'Horizontal padding', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 32 ),
			self::field( 'shadow', __( 'Shadow', 'kidia-mobile-cms' ), 'select', 'subtle', array( 'none' => __( 'None', 'kidia-mobile-cms' ), 'subtle' => __( 'Subtle', 'kidia-mobile-cms' ), 'strong' => __( 'Strong', 'kidia-mobile-cms' ) ) ),
			self::field( 'sticky', __( 'Sticky header', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_back', __( 'Show back button', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_search', __( 'Show search', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_cart', __( 'Show cart', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show wishlist', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'show_account', __( 'Show account', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'back_style', __( 'Back icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'back_size', __( 'Back icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'back_color', __( 'Back icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'search_style', __( 'Search style', 'kidia-mobile-cms' ), 'select', 'icon', array( 'icon' => __( 'Icon', 'kidia-mobile-cms' ), 'bar' => __( 'Search bar', 'kidia-mobile-cms' ) ) ),
			self::field( 'search_icon_style', __( 'Search icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'search_icon_size', __( 'Search icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'search_icon_color', __( 'Search icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'search_icon_background', __( 'Search icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'search_icon_radius', __( 'Search icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'search_placeholder', __( 'Search placeholder', 'kidia-mobile-cms' ), 'text', __( 'Search products', 'kidia-mobile-cms' ) ),
			self::field( 'search_height', __( 'Search height', 'kidia-mobile-cms' ), 'number', 40, array(), 32, 64 ),
			self::field( 'search_radius', __( 'Search radius', 'kidia-mobile-cms' ), 'number', 14, array(), 0, 32 ),
			self::field( 'search_background', __( 'Search background', 'kidia-mobile-cms' ), 'color', '#F1F3F4' ),
			self::field( 'search_text_color', __( 'Search text color', 'kidia-mobile-cms' ), 'color', '#5F6368' ),
			self::field( 'search_border_color', __( 'Search border color', 'kidia-mobile-cms' ), 'color', '#DDE3E8' ),
			self::field( 'search_border_width', __( 'Search border width', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 6 ),
			self::field( 'show_voice_search', __( 'Show voice search', 'kidia-mobile-cms' ), 'checkbox', false ),
			self::field( 'cart_style', __( 'Cart icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'cart_size', __( 'Cart icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'cart_color', __( 'Cart icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'cart_background', __( 'Cart icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'cart_radius', __( 'Cart icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'wishlist_style', __( 'Wishlist icon style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'circle' => __( 'Circle', 'kidia-mobile-cms' ) ) ),
			self::field( 'wishlist_size', __( 'Wishlist icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'wishlist_color', __( 'Wishlist icon color', 'kidia-mobile-cms' ), 'color', '#E53935' ),
			self::field( 'wishlist_background', __( 'Wishlist icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'wishlist_radius', __( 'Wishlist icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'account_style', __( 'Account style', 'kidia-mobile-cms' ), 'select', 'icon', array( 'icon' => __( 'Outline icon', 'kidia-mobile-cms' ), 'filled' => __( 'Filled icon', 'kidia-mobile-cms' ), 'avatar' => __( 'Avatar', 'kidia-mobile-cms' ) ) ),
			self::field( 'account_icon_size', __( 'Account icon size', 'kidia-mobile-cms' ), 'number', 24, array(), 16, 40 ),
			self::field( 'account_icon_color', __( 'Account icon color', 'kidia-mobile-cms' ), 'color', '#1F2933' ),
			self::field( 'account_background', __( 'Account icon background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'account_radius', __( 'Account icon radius', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 24 ),
			self::field( 'account_label', __( 'Account label', 'kidia-mobile-cms' ), 'text', __( 'Account', 'kidia-mobile-cms' ) ),
			self::field( 'show_account_label', __( 'Show account label', 'kidia-mobile-cms' ), 'checkbox', false ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public static function footer_fields(): array {
		return array(
			self::field( 'style', __( 'Footer style', 'kidia-mobile-cms' ), 'select', 'navigation', array( 'navigation' => __( 'Bottom navigation', 'kidia-mobile-cms' ), 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ) ) ),
			self::field( 'height', __( 'Height', 'kidia-mobile-cms' ), 'number', 72, array(), 48, 100 ),
			self::field( 'background_color', __( 'Background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ),
			self::field( 'active_color', __( 'Active color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ),
			self::field( 'inactive_color', __( 'Inactive color', 'kidia-mobile-cms' ), 'color', '#6B7280' ),
			self::field( 'show_labels', __( 'Show labels', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_home', __( 'Show Home', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_categories', __( 'Show Categories', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show Wishlist', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_account', __( 'Show Account', 'kidia-mobile-cms' ), 'checkbox', true ),
		);
	}

	/** @return array<int,array<string,mixed>> */
	public static function element_definitions( string $page ): array {
		$page = sanitize_key( $page );
		$common_grid = array(
			self::field( 'source', __( 'Source', 'kidia-mobile-cms' ), 'select', 'latest', array( 'latest' => __( 'Latest', 'kidia-mobile-cms' ), 'category' => __( 'Category', 'kidia-mobile-cms' ), 'featured' => __( 'Featured', 'kidia-mobile-cms' ), 'on_sale' => __( 'On sale', 'kidia-mobile-cms' ), 'manual' => __( 'Manual IDs', 'kidia-mobile-cms' ) ) ),
			self::field( 'category_id', __( 'Category ID', 'kidia-mobile-cms' ), 'number', 0, array(), 0, 999999999 ),
			self::field( 'manual_product_ids', __( 'Manual Product IDs', 'kidia-mobile-cms' ), 'text', '' ),
			self::field( 'columns', __( 'Columns', 'kidia-mobile-cms' ), 'number', 2, array(), 1, 4 ),
			self::field( 'gap', __( 'Gap', 'kidia-mobile-cms' ), 'number', 12, array(), 0, 32 ),
			self::field( 'card_style', __( 'Card style', 'kidia-mobile-cms' ), 'select', 'outlined', array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobile-cms' ) ) ),
			self::field( 'card_radius', __( 'Card radius', 'kidia-mobile-cms' ), 'number', 16, array(), 0, 40 ),
			self::field( 'image_ratio', __( 'Image ratio', 'kidia-mobile-cms' ), 'number', 1, array(), 0.6, 1.8, 0.1 ),
			self::field( 'show_price', __( 'Show price', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_regular_price', __( 'Show regular price', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_rating', __( 'Show rating', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_badge', __( 'Show badge', 'kidia-mobile-cms' ), 'checkbox', true ),
			self::field( 'show_wishlist', __( 'Show wishlist button', 'kidia-mobile-cms' ), 'checkbox', true ),
		);

		$definitions = array(
			'home' => array(),
			'category' => array(),
			'catalog' => array(
				self::element( 'filter_bar', __( 'Filter and Sort Bar', 'kidia-mobile-cms' ), 'dashicons-filter', array( self::field( 'sticky', __( 'Sticky', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_filter', __( 'Show filter', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_sort', __( 'Show sort', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_result_count', __( 'Show result count', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'background_color', __( 'Background', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ) ) ),
				self::element( 'product_grid', __( 'Product Grid', 'kidia-mobile-cms' ), 'dashicons-grid-view', $common_grid ),
				self::element( 'pagination', __( 'Pagination', 'kidia-mobile-cms' ), 'dashicons-update', array( self::field( 'automatic', __( 'Load automatically', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'button_label', __( 'Button label', 'kidia-mobile-cms' ), 'text', __( 'Load more', 'kidia-mobile-cms' ) ), self::field( 'loader_color', __( 'Loader color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ) ) ),
			),
			'product' => array(
				self::element( 'image_gallery', __( 'Product Gallery', 'kidia-mobile-cms' ), 'dashicons-format-gallery', array( self::field( 'aspect_ratio', __( 'Image ratio', 'kidia-mobile-cms' ), 'number', 1, array(), 0.6, 1.8, 0.1 ), self::field( 'fit', __( 'Image fit', 'kidia-mobile-cms' ), 'select', 'contain', array( 'contain' => __( 'Contain', 'kidia-mobile-cms' ), 'cover' => __( 'Cover', 'kidia-mobile-cms' ) ) ), self::field( 'show_thumbnails', __( 'Show thumbnails', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_indicators', __( 'Show indicators', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'enable_zoom', __( 'Enable zoom', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
				self::element( 'product_summary', __( 'Product Information', 'kidia-mobile-cms' ), 'dashicons-info-outline', array( self::field( 'show_name', __( 'Show name', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_price', __( 'Show price', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_regular_price', __( 'Show regular price', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_rating', __( 'Show rating', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_sku', __( 'Show SKU', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_stock', __( 'Show stock', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_badge', __( 'Show badge', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
				self::element( 'variations', __( 'Variations', 'kidia-mobile-cms' ), 'dashicons-screenoptions', array( self::field( 'style', __( 'Selector style', 'kidia-mobile-cms' ), 'select', 'chips', array( 'chips' => __( 'Chips', 'kidia-mobile-cms' ), 'dropdown' => __( 'Dropdown', 'kidia-mobile-cms' ) ) ), self::field( 'show_size_guide', __( 'Show size guide', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'disabled_style', __( 'Unavailable style', 'kidia-mobile-cms' ), 'select', 'crossed', array( 'crossed' => __( 'Crossed', 'kidia-mobile-cms' ), 'faded' => __( 'Faded', 'kidia-mobile-cms' ) ) ) ) ),
				self::element( 'purchase_bar', __( 'Quantity and Add to Cart', 'kidia-mobile-cms' ), 'dashicons-cart', array( self::field( 'sticky', __( 'Sticky purchase bar', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_quantity', __( 'Show quantity', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_buy_now', __( 'Show Buy now', 'kidia-mobile-cms' ), 'checkbox', false ), self::field( 'button_color', __( 'Button color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ), self::field( 'button_text_color', __( 'Button text color', 'kidia-mobile-cms' ), 'color', '#FFFFFF' ), self::field( 'button_radius', __( 'Button radius', 'kidia-mobile-cms' ), 'number', 14, array(), 0, 32 ) ) ),
				self::element( 'description', __( 'Description and Details', 'kidia-mobile-cms' ), 'dashicons-text-page', array( self::field( 'style', __( 'Display style', 'kidia-mobile-cms' ), 'select', 'sections', array( 'sections' => __( 'Sections', 'kidia-mobile-cms' ), 'tabs' => __( 'Tabs', 'kidia-mobile-cms' ), 'accordion' => __( 'Accordion', 'kidia-mobile-cms' ) ) ), self::field( 'show_description', __( 'Show description', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_attributes', __( 'Show attributes', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_shipping', __( 'Show shipping information', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
				self::element( 'reviews', __( 'Reviews', 'kidia-mobile-cms' ), 'dashicons-star-filled', array( self::field( 'show_summary', __( 'Show rating summary', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'initial_count', __( 'Initial reviews', 'kidia-mobile-cms' ), 'number', 3, array(), 1, 20 ) ) ),
				self::element( 'related_products', __( 'Related Products', 'kidia-mobile-cms' ), 'dashicons-products', array_merge( array( self::field( 'title', __( 'Title', 'kidia-mobile-cms' ), 'text', __( 'You may also like', 'kidia-mobile-cms' ) ), self::field( 'limit', __( 'Product limit', 'kidia-mobile-cms' ), 'number', 8, array(), 1, 20 ) ), $common_grid ) ),
			),
			'wishlist' => array(
				self::element( 'wishlist_grid', __( 'Wishlist Products', 'kidia-mobile-cms' ), 'dashicons-heart', $common_grid ),
				self::element( 'empty_state', __( 'Empty Wishlist', 'kidia-mobile-cms' ), 'dashicons-heart', array( self::field( 'title', __( 'Title', 'kidia-mobile-cms' ), 'text', __( 'Your wishlist is empty', 'kidia-mobile-cms' ) ), self::field( 'description', __( 'Description', 'kidia-mobile-cms' ), 'text', __( 'Save products you love and find them here.', 'kidia-mobile-cms' ) ), self::field( 'button_label', __( 'Button label', 'kidia-mobile-cms' ), 'text', __( 'Continue shopping', 'kidia-mobile-cms' ) ), self::field( 'show_button', __( 'Show button', 'kidia-mobile-cms' ), 'checkbox', true ) ) ),
			),
			'account' => array(
				self::element( 'account_summary', __( 'Account Summary', 'kidia-mobile-cms' ), 'dashicons-admin-users', array( self::field( 'avatar_size', __( 'Avatar size', 'kidia-mobile-cms' ), 'number', 66, array(), 40, 110 ), self::field( 'show_email', __( 'Show email', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'guest_title', __( 'Guest title', 'kidia-mobile-cms' ), 'text', __( 'Sign in / Create account', 'kidia-mobile-cms' ) ), self::field( 'card_style', __( 'Card style', 'kidia-mobile-cms' ), 'select', 'elevated', array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobile-cms' ) ) ) ) ),
				self::element( 'account_menu', __( 'Account Menu', 'kidia-mobile-cms' ), 'dashicons-menu-alt', array( self::field( 'style', __( 'Menu style', 'kidia-mobile-cms' ), 'select', 'list', array( 'list' => __( 'List', 'kidia-mobile-cms' ), 'grid' => __( 'Grid', 'kidia-mobile-cms' ) ) ), self::field( 'show_orders', __( 'Show orders', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_addresses', __( 'Show addresses', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_profile', __( 'Show profile', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'show_support', __( 'Show support', 'kidia-mobile-cms' ), 'checkbox', true ), self::field( 'icon_color', __( 'Icon color', 'kidia-mobile-cms' ), 'color', '#1F6F61' ) ) ),
				self::element( 'logout_button', __( 'Logout Button', 'kidia-mobile-cms' ), 'dashicons-exit', array( self::field( 'label', __( 'Label', 'kidia-mobile-cms' ), 'text', __( 'Sign out', 'kidia-mobile-cms' ) ), self::field( 'style', __( 'Button style', 'kidia-mobile-cms' ), 'select', 'outline', array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'text' => __( 'Text', 'kidia-mobile-cms' ) ) ), self::field( 'color', __( 'Color', 'kidia-mobile-cms' ), 'color', '#B42318' ) ) ),
			),
		);

		return $definitions[ $page ] ?? array();
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
		$default['header'] = $this->merge_component( $default['header'], $saved['header'] ?? array(), self::header_fields() );
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
		return $layout;
	}

	/** @return array<string,mixed> */
	private function default_layout( string $page ): array {
		$elements = array_map( array( $this, 'default_element' ), self::element_definitions( $page ) );
		return array(
			'version' => self::VERSION,
			'page' => $page,
			'updated_at' => '',
			'header' => array( 'id' => 'header', 'type' => 'app_header', 'locked' => true, 'enabled' => true, 'settings' => $this->defaults( self::header_fields() ) ),
			'elements' => $elements,
			'footer' => array( 'id' => 'footer', 'type' => 'app_footer', 'locked' => true, 'enabled' => true, 'settings' => $this->defaults( self::footer_fields() ) ),
		);
	}

	/** @param array<string,mixed> $definition @return array<string,mixed> */
	private function default_element( array $definition ): array {
		return array( 'id' => $definition['id'], 'type' => $definition['id'], 'label' => $definition['label'], 'icon' => $definition['icon'], 'locked' => false, 'enabled' => true, 'settings' => $this->defaults( $definition['fields'] ) );
	}

	/** @param array<string,mixed> $definition @param array<string,mixed> $saved @return array<string,mixed> */
	private function merge_element( array $definition, array $saved ): array {
		$element = $this->default_element( $definition );
		$element['enabled'] = ! empty( $saved['enabled'] );
		$element['settings'] = $this->sanitize_settings( is_array( $saved['settings'] ?? null ) ? $saved['settings'] : array(), $definition['fields'] );
		return $element;
	}

	/** @param array<string,mixed> $default @param mixed $saved @param array<int,array<string,mixed>> $fields @return array<string,mixed> */
	private function merge_component( array $default, $saved, array $fields ): array {
		$saved = is_array( $saved ) ? $saved : array();
		$default['enabled'] = ! empty( $saved['enabled'] );
		$default['settings'] = $this->sanitize_settings( is_array( $saved['settings'] ?? null ) ? $saved['settings'] : array(), $fields );
		return $default;
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
				case 'image': $clean[ $key ] = esc_url_raw( (string) $value ); break;
				case 'select': $clean[ $key ] = isset( $field['options'][ sanitize_key( (string) $value ) ] ) ? sanitize_key( (string) $value ) : $field['default']; break;
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
