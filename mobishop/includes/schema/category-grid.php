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
		'mobishop'
	),

	'description' => __(
		'Display WooCommerce categories in a grid.',
		'mobishop'
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
				'mobishop'
			),
		),

		array(
			'id' => 'display',
			'label' => __(
				'Display',
				'mobishop'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'layout', 'label' => __( 'Layout', 'mobishop' ), 'type' => 'select', 'tab' => 'display', 'default' => 'grid',
			'options' => array( 'grid' => __( 'Classic grid', 'mobishop' ), 'compact' => __( 'Compact grid', 'mobishop' ), 'cards' => __( 'Rounded cards', 'mobishop' ), 'carousel' => __( 'Horizontal row', 'mobishop' ), 'editorial_mosaic' => __( 'Editorial Mosaic', 'mobishop' ), 'full_width_banners' => __( 'Full-width Banners', 'mobishop' ) ),
		),
		array(
			'key' => 'items_alignment', 'label' => __( 'Items Alignment', 'mobishop' ), 'type' => 'select', 'tab' => 'display', 'default' => 'right',
			'options' => array( 'right' => __( 'Right', 'mobishop' ), 'center' => __( 'Center', 'mobishop' ), 'left' => __( 'Left', 'mobishop' ) ),
		),
		array(
			'key' => 'row_gap', 'label' => __( 'Row Gap', 'mobishop' ), 'type' => 'number', 'tab' => 'display', 'default' => 12, 'min' => 0, 'max' => 80,
		),

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'mobishop'
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
				'mobishop'
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
				'mobishop'
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
				'mobishop'
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
				'mobishop'
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
				'mobishop'
			),
			'type' => 'checkbox',
			'tab' => 'display',
			'default' => true,
		),

		array(
			'key' => 'hide_empty',
			'label' => __(
				'Hide Empty Categories',
				'mobishop'
			),
			'type' => 'checkbox',
			'tab' => 'display',
			'default' => true,
		),

	),

);
