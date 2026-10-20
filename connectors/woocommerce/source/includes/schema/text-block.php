<?php
/**
 * Text Block Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Text Block',
		'mobi2app-connector'
	),

	'description' => __(
		'Display custom formatted text.',
		'mobi2app-connector'
	),

	'icon' => 'dashicons-text',

	'defaults' => array(

		'title' => '',

		'content' => '',

		'alignment' => 'right',

		'background' => '',

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
			'id' => 'style',
			'label' => __(
				'Style',
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
			'full_width' => true,
		),

		array(
			'key' => 'content',
			'label' => __(
				'Content',
				'mobi2app-connector'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 8,
			'full_width' => true,
			'required' => true,
		),

		array(
			'key' => 'alignment',
			'label' => __(
				'Text Alignment',
				'mobi2app-connector'
			),
			'type' => 'select',
			'tab' => 'style',
			'default' => 'right',
			'options' => array(
				'left' => __( 'Left', 'mobi2app-connector' ),
				'center' => __( 'Center', 'mobi2app-connector' ),
				'right' => __( 'Right', 'mobi2app-connector' ),
			),
		),

		array(
			'key' => 'background',
			'label' => __(
				'Background Color',
				'mobi2app-connector'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '',
		),

	),

);