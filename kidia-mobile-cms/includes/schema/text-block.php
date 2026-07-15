<?php
/**
 * Text Block Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Text Block',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display custom formatted text.',
		'kidia-mobile-cms'
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
			'full_width' => true,
		),

		array(
			'key' => 'content',
			'label' => __(
				'Content',
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
			'type' => 'select',
			'tab' => 'style',
			'default' => 'right',
			'options' => array(
				'left' => __( 'Left', 'kidia-mobile-cms' ),
				'center' => __( 'Center', 'kidia-mobile-cms' ),
				'right' => __( 'Right', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'background',
			'label' => __(
				'Background Color',
				'kidia-mobile-cms'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '',
		),

	),

);