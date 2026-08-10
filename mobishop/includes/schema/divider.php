<?php
/**
 * Divider Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Divider',
		'mobishop'
	),

	'description' => __(
		'Display a horizontal divider.',
		'mobishop'
	),

	'icon' => 'dashicons-minus',

	'defaults' => array(

		'color' => '#e5e7eb',

		'thickness' => 1,

		'margin' => 16,

	),

	'tabs' => array(

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
			'key' => 'color',
			'label' => __(
				'Divider Color',
				'mobishop'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#e5e7eb',
		),

		array(
			'key' => 'thickness',
			'label' => __(
				'Thickness',
				'mobishop'
			),
			'type' => 'number',
			'tab' => 'style',
			'default' => 1,
			'min' => 1,
			'max' => 20,
			'step' => 1,
		),

		array(
			'key' => 'margin',
			'label' => __(
				'Vertical Margin',
				'mobishop'
			),
			'type' => 'number',
			'tab' => 'style',
			'default' => 16,
			'min' => 0,
			'max' => 100,
			'step' => 1,
		),

	),

);