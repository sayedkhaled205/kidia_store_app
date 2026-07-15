<?php
/**
 * Promo Strip Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Promo Strip',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a promotional announcement strip.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-megaphone',

	'defaults' => array(

		'text' => '',

		'background_color' => '#4f9f8f',

		'text_color' => '#ffffff',

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
			'id' => 'style',
			'label' => __(
				'Style',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'action',
			'label' => __(
				'Action',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'text',
			'label' => __(
				'Text',
				'kidia-mobile-cms'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 3,
			'full_width' => true,
			'required' => true,
		),

		array(
			'key' => 'background_color',
			'label' => __(
				'Background Color',
				'kidia-mobile-cms'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#4f9f8f',
		),

		array(
			'key' => 'text_color',
			'label' => __(
				'Text Color',
				'kidia-mobile-cms'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#ffffff',
		),

		array(
			'key' => 'action_type',
			'label' => __(
				'Action Type',
				'kidia-mobile-cms'
			),
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
			'label' => __(
				'Action Value',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);