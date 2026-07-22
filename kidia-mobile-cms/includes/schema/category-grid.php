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

		'limit' => 5,

		'layout' => 'grid',

		'items_alignment' => 'right',

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
			'key' => 'layout', 'label' => __( 'Layout', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'display', 'default' => 'grid',
			'options' => array( 'grid' => __( 'Classic grid', 'kidia-mobile-cms' ), 'compact' => __( 'Compact grid', 'kidia-mobile-cms' ), 'cards' => __( 'Rounded cards', 'kidia-mobile-cms' ), 'carousel' => __( 'Horizontal row', 'kidia-mobile-cms' ), 'editorial_mosaic' => __( 'Editorial Mosaic', 'kidia-mobile-cms' ), 'full_width_banners' => __( 'Full-width Banners', 'kidia-mobile-cms' ) ),
		),
		array(
			'key' => 'items_alignment', 'label' => __( 'Items Alignment', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'display', 'default' => 'right',
			'options' => array( 'right' => __( 'Right', 'kidia-mobile-cms' ), 'center' => __( 'Center', 'kidia-mobile-cms' ), 'left' => __( 'Left', 'kidia-mobile-cms' ) ),
		),

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
