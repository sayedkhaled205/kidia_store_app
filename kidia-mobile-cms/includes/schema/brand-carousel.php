<?php
/**
 * Brand Carousel Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Brand Carousel', 'kidia-mobile-cms' ),
	'description' => __( 'Display WooCommerce brands in a horizontal carousel.', 'kidia-mobile-cms' ),
	'icon'        => 'dashicons-store',
	'defaults'    => array(
		'title'      => '',
		'source'     => 'all',
		'brand_ids'  => '',
		'limit'      => 12,
		'item_width' => 90,
		'layout'     => 'carousel',
		'columns'    => 4,
		'columns_mobile' => 3,
		'gap'        => 12,
		'show_names' => true,
	),
	'tabs'        => array(
		array(
			'id'    => 'general',
			'label' => __( 'General', 'kidia-mobile-cms' ),
		),
		array(
			'id'    => 'brands',
			'label' => __( 'Brands', 'kidia-mobile-cms' ),
		),
	),
	'fields'      => array(
		array(
			'key'        => 'title',
			'label'      => __( 'Section Title', 'kidia-mobile-cms' ),
			'type'       => 'text',
			'tab'        => 'general',
			'default'    => '',
			'full_width' => true,
		),
		array(
			'key'     => 'item_width',
			'label'   => __( 'Brand Width', 'kidia-mobile-cms' ),
			'type'    => 'number',
			'tab'     => 'general',
			'default' => 90,
			'min'     => 60,
			'max'     => 200,
			'step'    => 1,
		),
		array(
			'key'     => 'layout',
			'label'   => __( 'Layout', 'kidia-mobile-cms' ),
			'type'    => 'select',
			'tab'     => 'general',
			'default' => 'carousel',
			'options' => array(
				'carousel' => __( 'Carousel', 'kidia-mobile-cms' ),
				'grid'     => __( 'Grid', 'kidia-mobile-cms' ),
			),
		),
		array(
			'key'     => 'columns',
			'label'   => __( 'Visible Columns', 'kidia-mobile-cms' ),
			'type'    => 'number',
			'tab'     => 'general',
			'default' => 4,
			'min'     => 1,
			'max'     => 8,
			'step'    => 1,
		),
		array(
			'key'     => 'columns_mobile',
			'label'   => __( 'Mobile Columns', 'kidia-mobile-cms' ),
			'type'    => 'number',
			'tab'     => 'general',
			'default' => 3,
			'min'     => 1,
			'max'     => 4,
			'step'    => 1,
		),
		array(
			'key'     => 'gap',
			'label'   => __( 'Item Gap', 'kidia-mobile-cms' ),
			'type'    => 'number',
			'tab'     => 'general',
			'default' => 12,
			'min'     => 0,
			'max'     => 48,
			'step'    => 1,
		),
		array(
			'key'     => 'show_names',
			'label'   => __( 'Show Brand Names', 'kidia-mobile-cms' ),
			'type'    => 'checkbox',
			'tab'     => 'general',
			'default' => true,
		),
		array(
			'key'     => 'source',
			'label'   => __( 'Brands Source', 'kidia-mobile-cms' ),
			'type'    => 'select',
			'tab'     => 'brands',
			'default' => 'all',
			'options' => array(
				'all'    => __( 'All Brands', 'kidia-mobile-cms' ),
				'manual' => __( 'Manual Selection', 'kidia-mobile-cms' ),
			),
		),
		array(
			'key'         => 'brand_ids',
			'label'       => __( 'Brands', 'kidia-mobile-cms' ),
			'description' => __( 'For Manual Selection, add brands one by one in the display order.', 'kidia-mobile-cms' ),
			'type'        => 'entity_select',
			'entity'      => 'brand',
			'multiple'    => true,
			'tab'         => 'brands',
			'default'     => '',
			'full_width'  => true,
			'show_if'     => array( 'source' => 'manual' ),
		),
		array(
			'key'     => 'limit',
			'label'   => __( 'Brands Count', 'kidia-mobile-cms' ),
			'type'    => 'number',
			'tab'     => 'brands',
			'default' => 12,
			'min'     => 1,
			'max'     => 50,
			'step'    => 1,
		),
	),
);
