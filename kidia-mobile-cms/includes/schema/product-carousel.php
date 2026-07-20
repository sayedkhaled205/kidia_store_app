<?php
/**
 * Product Carousel Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Product Carousel',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display WooCommerce products in a horizontal carousel.',
		'kidia-mobile-cms'
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
		'show_wishlist' => false,
		'product_wishlist_icon_variant' => 'heart',
		'product_wishlist_icon_style' => 'outline',
		'product_wishlist_icon_size' => 20,
		'product_wishlist_icon_color' => '#1F2933',
		'product_wishlist_show_background' => true,
		'product_wishlist_background_color' => '#FFFFFF',
		'product_wishlist_background_size' => 40,
		'product_wishlist_radius' => 24,

	),

	'tabs' => array(

		array(
			'id' => 'general',
			'label' => __(
				'General',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'source',
			'label' => __(
				'Source',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'source',
			'label' => __(
				'Products Source',
				'kidia-mobile-cms'
			),
			'type' => 'select',
			'tab' => 'source',
			'default' => 'latest',

			'options' => array(

				'latest' => __(
					'Latest Products',
					'kidia-mobile-cms'
				),

				'featured' => __(
					'Featured Products',
					'kidia-mobile-cms'
				),

				'on_sale' => __(
					'On Sale',
					'kidia-mobile-cms'
				),

				'category' => __(
					'Specific Category',
					'kidia-mobile-cms'
				),

				'manual' => __(
					'Manual Selection',
					'kidia-mobile-cms'
				),

			),

		),

		array(
			'key' => 'category_id',
			'label' => __(
				'Category ID',
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
			'type' => 'number',
			'tab' => 'source',
			'default' => 10,
			'min' => 1,
			'max' => 50,
			'step' => 1,
		),

		array( 'key' => 'card_style', 'label' => __( 'Card style', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outlined', 'options' => array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'no_shadow' => __( 'No shadow', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'item_width', 'label' => __( 'Card width', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 168, 'min' => 120, 'max' => 260, 'step' => 4 ),
		array( 'key' => 'image_ratio', 'label' => __( 'Image ratio', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 1, 'min' => 0.6, 'max' => 1.8, 'step' => 0.05 ),
		array( 'key' => 'card_radius', 'label' => __( 'Card radius', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 20, 'min' => 0, 'max' => 40, 'step' => 1 ),
		array( 'key' => 'show_name', 'label' => __( 'Show product name', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_price', 'label' => __( 'Show price', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_regular_price', 'label' => __( 'Show regular price', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_badge', 'label' => __( 'Show sale badge', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_rating', 'label' => __( 'Show rating', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'quick_add_enabled', 'label' => __( 'Quick add to cart', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'quick_add_icon_variant', 'label' => __( 'Quick add icon shape', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'general', 'default' => 'bag', 'options' => array( 'bag' => __( 'Shopping bag', 'kidia-mobile-cms' ), 'cart' => __( 'Shopping cart', 'kidia-mobile-cms' ), 'basket' => __( 'Shopping basket', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'quick_add_icon_style', 'label' => __( 'Quick add icon style', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outline', 'options' => array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'quick_add_icon_size', 'label' => __( 'Quick add icon size', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 22, 'min' => 16, 'max' => 36 ),
		array( 'key' => 'quick_add_icon_color', 'label' => __( 'Quick add icon color', 'kidia-mobile-cms' ), 'type' => 'color', 'tab' => 'general', 'default' => '#1F2933' ),
		array( 'key' => 'quick_add_show_background', 'label' => __( 'White background behind icon', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'quick_add_background_color', 'label' => __( 'Quick add background color', 'kidia-mobile-cms' ), 'type' => 'color', 'tab' => 'general', 'default' => '#FFFFFF' ),
		array( 'key' => 'quick_add_background_size', 'label' => __( 'Quick add background size', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 40, 'min' => 28, 'max' => 64 ),
		array( 'key' => 'quick_add_radius', 'label' => __( 'Quick add background radius', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 24, 'min' => 0, 'max' => 40 ),
		array( 'key' => 'show_wishlist', 'label' => __( 'Product wishlist icon', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'product_wishlist_icon_variant', 'label' => __( 'Product wishlist icon shape', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'general', 'default' => 'heart', 'options' => array( 'heart' => __( 'Heart', 'kidia-mobile-cms' ), 'rounded' => __( 'Rounded heart', 'kidia-mobile-cms' ), 'bookmark' => __( 'Bookmark', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'product_wishlist_icon_style', 'label' => __( 'Product wishlist icon style', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outline', 'options' => array( 'outline' => __( 'Outline', 'kidia-mobile-cms' ), 'filled' => __( 'Filled', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'product_wishlist_icon_size', 'label' => __( 'Product wishlist icon size', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 20, 'min' => 16, 'max' => 36 ),
		array( 'key' => 'product_wishlist_icon_color', 'label' => __( 'Product wishlist icon color', 'kidia-mobile-cms' ), 'type' => 'color', 'tab' => 'general', 'default' => '#1F2933' ),
		array( 'key' => 'product_wishlist_show_background', 'label' => __( 'Product wishlist background', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'product_wishlist_background_color', 'label' => __( 'Product wishlist background color', 'kidia-mobile-cms' ), 'type' => 'color', 'tab' => 'general', 'default' => '#FFFFFF' ),
		array( 'key' => 'product_wishlist_background_size', 'label' => __( 'Product wishlist background size', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 40, 'min' => 28, 'max' => 64 ),
		array( 'key' => 'product_wishlist_radius', 'label' => __( 'Product wishlist background radius', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 24, 'min' => 0, 'max' => 40 ),

	),

);
