<?php
/**
 * Spacer Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Spacer',
		'mobishop'
	),

	'description' => __(
		'Add vertical spacing between elements.',
		'mobishop'
	),

	'icon' => 'dashicons-editor-expand',

	'defaults' => array(

		'height' => 24,

	),

	'tabs' => array(

		array(
			'id' => 'general',
			'label' => __(
				'General',
				'mobishop'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'height',
			'label' => __(
				'Height',
				'mobishop'
			),
			'type' => 'number',
			'tab' => 'general',
			'default' => 24,
			'min' => 0,
			'max' => 300,
			'step' => 1,
		),

	),

);