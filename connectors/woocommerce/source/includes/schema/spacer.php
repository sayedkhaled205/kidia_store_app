<?php
/**
 * Spacer Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Spacer',
		'mobi2app-connector'
	),

	'description' => __(
		'Add vertical spacing between elements.',
		'mobi2app-connector'
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
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'height',
			'label' => __(
				'Height',
				'mobi2app-connector'
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