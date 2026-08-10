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
		'mobishop'
	),

	'description' => __(
		'Display a reusable section title and action.',
		'mobishop'
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
				'mobishop'
			),
		),

		array(
			'id' => 'action',
			'label' => __(
				'Action',
				'mobishop'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'mobishop'
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
				'mobishop'
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
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
		),

		array(
			'key' => 'action_type',
			'label' => __(
				'Action Type',
				'mobishop'
			),
			'type' => 'select',
			'tab' => 'action',
			'default' => '',
			'options' => array(
				'' => __( 'No Action', 'mobishop' ),
				'collection' => __( 'Collection', 'mobishop' ),
				'category' => __( 'Category', 'mobishop' ),
				'product' => __( 'Product', 'mobishop' ),
				'search' => __( 'Search', 'mobishop' ),
				'external' => __( 'External URL', 'mobishop' ),
			),
		),

		array(
			'key' => 'action_value',
			'label' => __(
				'Action Value',
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);