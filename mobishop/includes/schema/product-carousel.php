<?php
/**
 * Product Carousel Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Product Carousel',
		'mobishop'
	),

	'description' => __(
		'Display WooCommerce products in a horizontal carousel.',
		'mobishop'
	),

	'icon' => 'dashicons-products',

	'defaults' => array(

		'title' => '',

		'subtitle' => '',

		'source' => 'latest',

		'limit' => 10,

		'show_view_all' => true,

		'category_id' => 0,

		'product_ids' => '',

		'view_all_label' => '',

		'card_style' => 'outlined',

		'item_width' => 168,

		'image_ratio' => 1,

		'enable_image_swipe' => false,

		'card_radius' => 20,

		'show_name' => true,

		'show_price' => true,

		'show_regular_price' => true,

		'show_badge' => true,

		'show_rating' => false,

		'quick_add_enabled' => true,
		'quick_add_icon_variant' => 'bag',
		'quick_add_icon_style' => 'outline',
		'quick_add_icon_size' => 22,
		'quick_add_icon_color' => '#1F2933',
		'quick_add_show_background' => true,
		'quick_add_background_color' => '#FFFFFF',
		'quick_add_background_size' => 40,
		'quick_add_radius' => 24,
		'quick_add_position' => 'bottom_end',
		'show_wishlist' => false,
		'product_wishlist_icon_variant' => 'heart',
		'product_wishlist_icon_style' => 'outline',
		'product_wishlist_icon_size' => 20,
		'product_wishlist_icon_color' => '#1F2933',
		'product_wishlist_show_background' => true,
		'product_wishlist_background_color' => '#FFFFFF',
		'product_wishlist_background_size' => 40,
		'product_wishlist_radius' => 24,
		'product_wishlist_position' => 'top_end',

	),

	'tabs' => array(

		array(
			'id' => 'general',
			'label' => __(
				'General',
				'mobishop'
			),
		),

		array(
			'id' => 'source',
			'label' => __(
				'Source',
				'mobishop'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'show_view_all',
			'label' => __(
				'Show View All',
				'mobishop'
			),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'source',
			'label' => __(
				'Products Source',
				'mobishop'
			),
			'type' => 'select',
			'tab' => 'source',
			'default' => 'latest',

			'options' => array(

				'latest' => __(
					'Latest Products',
					'mobishop'
				),

				'featured' => __(
					'Featured Products',
					'mobishop'
				),

				'on_sale' => __(
					'On Sale',
					'mobishop'
				),

				'category' => __(
					'Specific Category',
					'mobishop'
				),

				'manual' => __(
					'Manual Selection',
					'mobishop'
				),

			),

		),

		array(
			'key' => 'category_id',
			'label' => __(
				'Category ID',
				'mobishop'
			),
			'type' => 'number',
			'tab' => 'source',
			'default' => 0,
			'min' => 0,
			'step' => 1,
		),

		array(
			'key' => 'limit',
			'label' => __(
				'Products Limit',
				'mobishop'
			),
			'type' => 'number',
			'tab' => 'source',
			'default' => 10,
			'min' => 1,
			'max' => 50,
			'step' => 1,
		),

		array( 'key' => 'card_style', 'label' => __( 'Card style', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outlined', 'options' => array( 'minimal' => __( 'Minimal', 'mobishop' ), 'no_shadow' => __( 'No shadow', 'mobishop' ), 'outlined' => __( 'Outlined', 'mobishop' ), 'elevated' => __( 'Elevated', 'mobishop' ) ) ),
		array( 'key' => 'item_width', 'label' => __( 'Card width', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 168, 'min' => 120, 'max' => 260, 'step' => 4 ),
		array( 'key' => 'image_ratio', 'label' => __( 'Image ratio', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 1, 'min' => 0.6, 'max' => 1.8, 'step' => 0.05 ),
		array( 'key' => 'enable_image_swipe', 'label' => __( 'Swipe product images on the card', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'card_radius', 'label' => __( 'Card radius', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 20, 'min' => 0, 'max' => 40, 'step' => 1 ),
		array( 'key' => 'show_name', 'label' => __( 'Show product name', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_price', 'label' => __( 'Show price', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_regular_price', 'label' => __( 'Show regular price', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_badge', 'label' => __( 'Show sale badge', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_rating', 'label' => __( 'Show rating', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'quick_add_enabled', 'label' => __( 'Quick add to cart', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'quick_add_icon_variant', 'label' => __( 'Quick add icon shape', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'bag', 'options' => array( 'bag' => __( 'Shopping bag', 'mobishop' ), 'cart' => __( 'Shopping cart', 'mobishop' ), 'basket' => __( 'Shopping basket', 'mobishop' ) ) ),
		array( 'key' => 'quick_add_icon_style', 'label' => __( 'Quick add icon style', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outline', 'options' => array( 'outline' => __( 'Outline', 'mobishop' ), 'filled' => __( 'Filled', 'mobishop' ), 'rounded' => __( 'Rounded', 'mobishop' ) ) ),
		array( 'key' => 'quick_add_icon_size', 'label' => __( 'Quick add icon size', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 22, 'min' => 10, 'max' => 36 ),
		array( 'key' => 'quick_add_icon_color', 'label' => __( 'Quick add icon color', 'mobishop' ), 'type' => 'color', 'tab' => 'general', 'default' => '#1F2933' ),
		array( 'key' => 'quick_add_show_background', 'label' => __( 'White background behind icon', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'quick_add_background_color', 'label' => __( 'Quick add background color', 'mobishop' ), 'type' => 'color', 'tab' => 'general', 'default' => '#FFFFFF' ),
		array( 'key' => 'quick_add_background_size', 'label' => __( 'Quick add background size', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 40, 'min' => 10, 'max' => 64 ),
		array( 'key' => 'quick_add_radius', 'label' => __( 'Quick add background radius', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 24, 'min' => 0, 'max' => 40 ),
		array( 'key' => 'quick_add_position', 'label' => __( 'Quick add position', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'bottom_end', 'options' => array( 'top_start' => 'Top start', 'top_end' => 'Top end', 'bottom_start' => 'Bottom start', 'bottom_end' => 'Bottom end' ) ),
		array( 'key' => 'show_wishlist', 'label' => __( 'Product wishlist icon', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'product_wishlist_icon_variant', 'label' => __( 'Product wishlist icon shape', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'heart', 'options' => array( 'heart' => __( 'Heart', 'mobishop' ), 'rounded' => __( 'Rounded heart', 'mobishop' ), 'bookmark' => __( 'Bookmark', 'mobishop' ) ) ),
		array( 'key' => 'product_wishlist_icon_style', 'label' => __( 'Product wishlist icon style', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outline', 'options' => array( 'outline' => __( 'Outline', 'mobishop' ), 'filled' => __( 'Filled', 'mobishop' ) ) ),
		array( 'key' => 'product_wishlist_icon_size', 'label' => __( 'Product wishlist icon size', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 20, 'min' => 10, 'max' => 36 ),
		array( 'key' => 'product_wishlist_icon_color', 'label' => __( 'Product wishlist icon color', 'mobishop' ), 'type' => 'color', 'tab' => 'general', 'default' => '#1F2933' ),
		array( 'key' => 'product_wishlist_show_background', 'label' => __( 'Product wishlist background', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'product_wishlist_background_color', 'label' => __( 'Product wishlist background color', 'mobishop' ), 'type' => 'color', 'tab' => 'general', 'default' => '#FFFFFF' ),
		array( 'key' => 'product_wishlist_background_size', 'label' => __( 'Product wishlist background size', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 40, 'min' => 20, 'max' => 64 ),
		array( 'key' => 'product_wishlist_radius', 'label' => __( 'Product wishlist background radius', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 24, 'min' => 0, 'max' => 40 ),
		array( 'key' => 'product_wishlist_position', 'label' => __( 'Product wishlist position', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'top_end', 'options' => array( 'top_start' => 'Top start', 'top_end' => 'Top end', 'bottom_start' => 'Bottom start', 'bottom_end' => 'Bottom end' ) ),

	),

);
