<?php
/**
 * Section Header Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Section Header',
		'mobi2app-connector'
	),

	'description' => __(
		'Display a reusable section title and action.',
		'mobi2app-connector'
	),

	'icon' => 'dashicons-heading',

	'defaults' => array(

		'title' => '',

		'subtitle' => '',

		'action_label' => '',

		'action_type' => '',

		'action_value' => '',

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
			'id' => 'action',
			'label' => __(
				'Action',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 3,
			'full_width' => true,
		),

		array(
			'key' => 'action_label',
			'label' => __(
				'Action Label',
				'mobi2app-connector'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
		),

		array(
			'key' => 'action_type',
			'label' => __(
				'Action Type',
				'mobi2app-connector'
			),
			'type' => 'select',
			'tab' => 'action',
			'default' => '',
			'options' => array(
				'' => __( 'No Action', 'mobi2app-connector' ),
				'collection' => __( 'Collection', 'mobi2app-connector' ),
				'category' => __( 'Category', 'mobi2app-connector' ),
				'product' => __( 'Product', 'mobi2app-connector' ),
				'search' => __( 'Search', 'mobi2app-connector' ),
				'external' => __( 'External URL', 'mobi2app-connector' ),
			),
		),

		array(
			'key' => 'action_value',
			'label' => __(
				'Action Value',
				'mobi2app-connector'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);