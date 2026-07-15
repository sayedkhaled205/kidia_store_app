<?php
/**
 * Divider Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Divider',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a horizontal divider.',
		'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'color',
			'label' => __(
				'Divider Color',
				'kidia-mobile-cms'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#e5e7eb',
		),

		array(
			'key' => 'thickness',
			'label' => __(
				'Thickness',
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
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