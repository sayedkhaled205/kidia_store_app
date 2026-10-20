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
		'mobi2app-connector'
	),

	'description' => __(
		'Display WooCommerce products in a horizontal carousel.',
		'mobi2app-connector'
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
				'mobi2app-connector'
			),
		),

		array(
			'id' => 'source',
			'label' => __(
				'Source',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'source',
			'label' => __(
				'Products Source',
				'mobi2app-connector'
			),
			'type' => 'select',
			'tab' => 'source',
			'default' => 'latest',

			'options' => array(

				'latest' => __(
					'Latest Products',
					'mobi2app-connector'
				),

				'featured' => __(
					'Featured Products',
					'mobi2app-connector'
				),

				'on_sale' => __(
					'On Sale',
					'mobi2app-connector'
				),

				'category' => __(
					'Specific Category',
					'mobi2app-connector'
				),

				'manual' => __(
					'Manual Selection',
					'mobi2app-connector'
				),

			),

		),

		array(
			'key' => 'category_id',
			'label' => __(
				'Category ID',
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'number',
			'tab' => 'source',
			'default' => 10,
			'min' => 1,
			'max' => 50,
			'step' => 1,
		),

		array( 'key' => 'card_style', 'label' => __( 'Card style', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outlined', 'options' => array( 'minimal' => __( 'Minimal', 'mobi2app-connector' ), 'no_shadow' => __( 'No shadow', 'mobi2app-connector' ), 'outlined' => __( 'Outlined', 'mobi2app-connector' ), 'elevated' => __( 'Elevated', 'mobi2app-connector' ) ) ),
		array( 'key' => 'item_width', 'label' => __( 'Card width', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 168, 'min' => 120, 'max' => 260, 'step' => 4 ),
		array( 'key' => 'image_ratio', 'label' => __( 'Image ratio', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 1, 'min' => 0.6, 'max' => 1.8, 'step' => 0.05 ),
		array( 'key' => 'enable_image_swipe', 'label' => __( 'Swipe product images on the card', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'card_radius', 'label' => __( 'Card radius', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 20, 'min' => 0, 'max' => 40, 'step' => 1 ),
		array( 'key' => 'show_name', 'label' => __( 'Show product name', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_price', 'label' => __( 'Show price', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_regular_price', 'label' => __( 'Show regular price', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_badge', 'label' => __( 'Show sale badge', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'show_rating', 'label' => __( 'Show rating', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'quick_add_enabled', 'label' => __( 'Quick add to cart', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'quick_add_icon_variant', 'label' => __( 'Quick add icon shape', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'bag', 'options' => array( 'bag' => __( 'Shopping bag', 'mobi2app-connector' ), 'cart' => __( 'Shopping cart', 'mobi2app-connector' ), 'basket' => __( 'Shopping basket', 'mobi2app-connector' ) ) ),
		array( 'key' => 'quick_add_icon_style', 'label' => __( 'Quick add icon style', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outline', 'options' => array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ), 'rounded' => __( 'Rounded', 'mobi2app-connector' ) ) ),
		array( 'key' => 'quick_add_icon_size', 'label' => __( 'Quick add icon size', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 22, 'min' => 10, 'max' => 36 ),
		array( 'key' => 'quick_add_icon_color', 'label' => __( 'Quick add icon color', 'mobi2app-connector' ), 'type' => 'color', 'tab' => 'general', 'default' => '#1F2933' ),
		array( 'key' => 'quick_add_show_background', 'label' => __( 'White background behind icon', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'quick_add_background_color', 'label' => __( 'Quick add background color', 'mobi2app-connector' ), 'type' => 'color', 'tab' => 'general', 'default' => '#FFFFFF' ),
		array( 'key' => 'quick_add_background_size', 'label' => __( 'Quick add background size', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 40, 'min' => 10, 'max' => 64 ),
		array( 'key' => 'quick_add_radius', 'label' => __( 'Quick add background radius', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 24, 'min' => 0, 'max' => 40 ),
		array( 'key' => 'quick_add_position', 'label' => __( 'Quick add position', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'bottom_end', 'options' => array( 'top_start' => 'Top start', 'top_end' => 'Top end', 'bottom_start' => 'Bottom start', 'bottom_end' => 'Bottom end' ) ),
		array( 'key' => 'show_wishlist', 'label' => __( 'Product wishlist icon', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'product_wishlist_icon_variant', 'label' => __( 'Product wishlist icon shape', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'heart', 'options' => array( 'heart' => __( 'Heart', 'mobi2app-connector' ), 'rounded' => __( 'Rounded heart', 'mobi2app-connector' ), 'bookmark' => __( 'Bookmark', 'mobi2app-connector' ) ) ),
		array( 'key' => 'product_wishlist_icon_style', 'label' => __( 'Product wishlist icon style', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'outline', 'options' => array( 'outline' => __( 'Outline', 'mobi2app-connector' ), 'filled' => __( 'Filled', 'mobi2app-connector' ) ) ),
		array( 'key' => 'product_wishlist_icon_size', 'label' => __( 'Product wishlist icon size', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 20, 'min' => 10, 'max' => 36 ),
		array( 'key' => 'product_wishlist_icon_color', 'label' => __( 'Product wishlist icon color', 'mobi2app-connector' ), 'type' => 'color', 'tab' => 'general', 'default' => '#1F2933' ),
		array( 'key' => 'product_wishlist_show_background', 'label' => __( 'Product wishlist background', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => true ),
		array( 'key' => 'product_wishlist_background_color', 'label' => __( 'Product wishlist background color', 'mobi2app-connector' ), 'type' => 'color', 'tab' => 'general', 'default' => '#FFFFFF' ),
		array( 'key' => 'product_wishlist_background_size', 'label' => __( 'Product wishlist background size', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 40, 'min' => 20, 'max' => 64 ),
		array( 'key' => 'product_wishlist_radius', 'label' => __( 'Product wishlist background radius', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 24, 'min' => 0, 'max' => 40 ),
		array( 'key' => 'product_wishlist_position', 'label' => __( 'Product wishlist position', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'top_end', 'options' => array( 'top_start' => 'Top start', 'top_end' => 'Top end', 'bottom_start' => 'Bottom start', 'bottom_end' => 'Bottom end' ) ),

	),

);
