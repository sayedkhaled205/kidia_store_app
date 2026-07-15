<?php
/**
 * Section Header Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Section Header',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a reusable section title and action.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-heading',

	'defaults' => array(

		'title' => '',

		'subtitle' => '',

		'show_view_all' => true,

		'view_all_label' => '',

		'alignment' => 'start',

		'icon' => '',

		'divider_style' => 'none',

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
			'id' => 'action',
			'label' => __(
				'Action',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'style',
			'label' => __( 'Style', 'kidia-mobile-cms' ),
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
			'key' => 'subtitle',
			'label' => __(
				'Subtitle',
				'kidia-mobile-cms'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 3,
			'full_width' => true,
		),

		array(
			'key' => 'alignment',
			'label' => __( 'Alignment', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'style',
			'default' => 'start',
			'options' => array(
				'start'  => __( 'Start', 'kidia-mobile-cms' ),
				'center' => __( 'Center', 'kidia-mobile-cms' ),
				'end'    => __( 'End', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'icon',
			'label' => __( 'Icon', 'kidia-mobile-cms' ),
			'description' => __( 'Optional app icon name, for example: star or tag.', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'style',
			'default' => '',
		),

		array(
			'key' => 'divider_style',
			'label' => __( 'Divider', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'style',
			'default' => 'none',
			'options' => array(
				'none'      => __( 'None', 'kidia-mobile-cms' ),
				'line'      => __( 'Line', 'kidia-mobile-cms' ),
				'underline' => __( 'Underline', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'show_view_all',
			'label' => __( 'Show View All', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'action',
			'default' => true,
		),

		array(
			'key' => 'view_all_label',
			'label' => __(
				'View All Label',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
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
