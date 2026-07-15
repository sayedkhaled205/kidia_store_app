<?php
/**
 * Coupon Banner Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Coupon Banner',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a promotional coupon banner.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-tickets-alt',

	'defaults' => array(

		'title' => '',

		'description' => '',

		'coupon_code' => '',

		'image_url' => '',

		'copy_button_label' => 'Copy code',

		'expires_at' => '',

		'background_color' => '#f3f4f6',

		'text_color' => '#111827',

		'button_label' => '',

		'action_type' => '',

		'action_value' => '',

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
			'id' => 'media',
			'label' => __(
				'Media',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'style',
			'label' => __( 'Style', 'kidia-mobile-cms' ),
		),

		array(
			'id' => 'action',
			'label' => __( 'Action', 'kidia-mobile-cms' ),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
			'required' => true,
			'full_width' => true,
		),

		array(
			'key' => 'description',
			'label' => __(
				'Description',
				'kidia-mobile-cms'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 4,
			'full_width' => true,
		),

		array(
			'key' => 'coupon_code',
			'label' => __(
				'Coupon Code',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
		),

		array(
			'key' => 'copy_button_label',
			'label' => __( 'Copy Button Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'general',
			'default' => 'Copy code',
		),

		array(
			'key' => 'expires_at',
			'label' => __( 'Expiry Date', 'kidia-mobile-cms' ),
			'type' => 'datetime',
			'tab' => 'general',
			'default' => '',
		),

		array(
			'key' => 'image_url',
			'label' => __(
				'Banner Image',
				'kidia-mobile-cms'
			),
			'type' => 'image',
			'tab' => 'media',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'background_color',
			'label' => __( 'Background Color', 'kidia-mobile-cms' ),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#f3f4f6',
		),

		array(
			'key' => 'text_color',
			'label' => __( 'Text Color', 'kidia-mobile-cms' ),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#111827',
		),

		array(
			'key' => 'button_label',
			'label' => __( 'Action Button Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
		),

		array(
			'key' => 'action_type',
			'label' => __( 'Action Type', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'action',
			'default' => '',
			'options' => array(
				'' => __( 'No Action', 'kidia-mobile-cms' ),
				'collection' => __( 'Collection', 'kidia-mobile-cms' ),
				'category' => __( 'Category', 'kidia-mobile-cms' ),
				'product' => __( 'Product', 'kidia-mobile-cms' ),
				'search' => __( 'Search', 'kidia-mobile-cms' ),
				'external' => __( 'External URL', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'action_value',
			'label' => __( 'Action Value', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);
