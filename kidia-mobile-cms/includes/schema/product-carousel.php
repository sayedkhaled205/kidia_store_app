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

		'source' => 'latest',

		'limit' => 10,

		'show_view_all' => true,

		'category_id' => 0,

		'product_ids' => '',

		'cards_visible' => 2.2,

		'gap' => 12,

		'card_style' => 'default',

		'image_ratio' => 1,

		'show_rating' => true,

		'show_category' => false,

		'show_badge' => true,

		'show_stock' => true,

		'show_arrows' => false,

		'show_dots' => false,

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

		array(
			'id' => 'style',
			'label' => __( 'Layout', 'kidia-mobile-cms' ),
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

				'best_selling' => __( 'Best Selling', 'kidia-mobile-cms' ),

				'top_rated' => __( 'Top Rated', 'kidia-mobile-cms' ),

				'random' => __( 'Random', 'kidia-mobile-cms' ),

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
				'Product Category',
				'kidia-mobile-cms'
			),
			'type' => 'entity_select',
			'entity' => 'term',
			'taxonomy' => 'product_cat',
			'tab' => 'source',
			'default' => 0,
			'description' => __( 'Used when Products Source is Specific Category.', 'kidia-mobile-cms' ),
			'show_if' => array( 'source' => 'category' ),
		),

		array(
			'key' => 'product_ids',
			'label' => __( 'Products', 'kidia-mobile-cms' ),
			'type' => 'entity_select',
			'entity' => 'product',
			'multiple' => true,
			'tab' => 'source',
			'default' => '',
			'description' => __( 'For Manual Selection, add products one by one in the order you want.', 'kidia-mobile-cms' ),
			'full_width' => true,
			'show_if' => array( 'source' => 'manual' ),
		),

		array(
			'key' => 'cards_visible',
			'label' => __( 'Visible Cards', 'kidia-mobile-cms' ),
			'type' => 'number',
			'tab' => 'style',
			'default' => 2.2,
			'min' => 1,
			'max' => 6,
			'step' => 0.1,
		),

		array(
			'key' => 'gap',
			'label' => __( 'Card Gap', 'kidia-mobile-cms' ),
			'type' => 'number',
			'tab' => 'style',
			'default' => 12,
			'min' => 0,
			'max' => 48,
			'step' => 1,
		),

		array(
			'key' => 'card_style',
			'label' => __( 'Card Style', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'style',
			'default' => 'default',
			'options' => array(
				'default' => __( 'Default', 'kidia-mobile-cms' ),
				'compact' => __( 'Compact', 'kidia-mobile-cms' ),
				'minimal' => __( 'Minimal', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'image_ratio',
			'label' => __( 'Image Aspect Ratio', 'kidia-mobile-cms' ),
			'type' => 'number',
			'tab' => 'style',
			'default' => 1,
			'min' => 0.5,
			'max' => 2,
			'step' => 0.1,
		),

		array(
			'key' => 'show_rating',
			'label' => __( 'Show Rating', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'style',
			'default' => true,
		),

		array(
			'key' => 'show_category',
			'label' => __( 'Show Category', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'style',
			'default' => false,
		),

		array(
			'key' => 'show_badge',
			'label' => __( 'Show Sale Badge', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'style',
			'default' => true,
		),

		array(
			'key' => 'show_stock',
			'label' => __( 'Show Stock State', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'style',
			'default' => true,
		),

		array(
			'key' => 'show_arrows',
			'label' => __( 'Show Navigation Arrows', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'style',
			'default' => false,
		),

		array(
			'key' => 'show_dots',
			'label' => __( 'Show Navigation Dots', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'style',
			'default' => false,
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

	),

);
