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

	),

);
