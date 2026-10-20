<?php
/**
 * Category Grid Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Category Grid',
		'mobi2app-connector'
	),

	'description' => __(
		'Display WooCommerce categories in a grid.',
		'mobi2app-connector'
	),

	'icon' => 'dashicons-grid-view',

	'defaults' => array(

		'title' => '',

		'subtitle' => '',

		'columns' => 3,

		'limit' => 5,

		'layout' => 'grid',

		'items_alignment' => 'right',
		'row_gap' => 12,

		'parent_id' => 0,

		'show_names' => true,

		'hide_empty' => true,

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
			'id' => 'display',
			'label' => __(
				'Display',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'layout', 'label' => __( 'Layout', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'display', 'default' => 'grid',
			'options' => array( 'grid' => __( 'Classic grid', 'mobi2app-connector' ), 'compact' => __( 'Compact grid', 'mobi2app-connector' ), 'cards' => __( 'Rounded cards', 'mobi2app-connector' ), 'carousel' => __( 'Horizontal row', 'mobi2app-connector' ), 'editorial_mosaic' => __( 'Editorial Mosaic', 'mobi2app-connector' ), 'full_width_banners' => __( 'Full-width Banners', 'mobi2app-connector' ) ),
		),
		array(
			'key' => 'items_alignment', 'label' => __( 'Items Alignment', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'display', 'default' => 'right',
			'options' => array( 'right' => __( 'Right', 'mobi2app-connector' ), 'center' => __( 'Center', 'mobi2app-connector' ), 'left' => __( 'Left', 'mobi2app-connector' ) ),
		),
		array(
			'key' => 'row_gap', 'label' => __( 'Row Gap', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'display', 'default' => 12, 'min' => 0, 'max' => 80,
		),

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'checkbox',
			'tab' => 'display',
			'default' => true,
		),

		array(
			'key' => 'hide_empty',
			'label' => __(
				'Hide Empty Categories',
				'mobi2app-connector'
			),
			'type' => 'checkbox',
			'tab' => 'display',
			'default' => true,
		),

	),

);
