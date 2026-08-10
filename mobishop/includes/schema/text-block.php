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
		'mobishop'
	),

	'description' => __(
		'Display custom formatted text.',
		'mobishop'
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
				'mobishop'
			),
		),

		array(
			'id' => 'style',
			'label' => __(
				'Style',
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
			'full_width' => true,
		),

		array(
			'key' => 'content',
			'label' => __(
				'Content',
				'mobishop'
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
				'mobishop'
			),
			'type' => 'select',
			'tab' => 'style',
			'default' => 'right',
			'options' => array(
				'left' => __( 'Left', 'mobishop' ),
				'center' => __( 'Center', 'mobishop' ),
				'right' => __( 'Right', 'mobishop' ),
			),
		),

		array(
			'key' => 'background',
			'label' => __(
				'Background Color',
				'mobishop'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '',
		),

	),

);