<?php
/**
 * Category Grid Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Category Grid',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display WooCommerce categories in a grid.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-grid-view',

	'defaults' => array(

		'title' => '',

		'subtitle' => '',

		'columns' => 3,

		'limit' => 3,

		'parent_id' => 0,

		'show_names' => true,

		'hide_empty' => true,

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
			'id' => 'display',
			'label' => __(
				'Display',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'subtitle',
			'label' => __(
				'Subtitle',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'columns',
			'label' => __(
				'Columns',
				'kidia-mobile-cms'
			),
			'type' => 'number',
			'tab' => 'display',
			'default' => 4,
			'min' => 2,
			'max' => 6,
			'step' => 1,
		),

		array(
			'key' => 'limit',
			'label' => __(
				'Categories Limit',
				'kidia-mobile-cms'
			),
			'type' => 'number',
			'tab' => 'display',
			'default' => 8,
			'min' => 1,
			'max' => 50,
			'step' => 1,
		),

		array(
			'key' => 'parent_id',
			'label' => __(
				'Parent Category ID',
				'kidia-mobile-cms'
			),
			'type' => 'number',
			'tab' => 'display',
			'default' => 0,
			'min' => 0,
			'step' => 1,
		),

		array(
			'key' => 'show_names',
			'label' => __(
				'Show Category Names',
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'display',
			'default' => true,
		),

		array(
			'key' => 'hide_empty',
			'label' => __(
				'Hide Empty Categories',
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'display',
			'default' => true,
		),

	),

);
