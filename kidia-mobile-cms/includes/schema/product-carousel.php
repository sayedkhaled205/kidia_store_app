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

	),

);
