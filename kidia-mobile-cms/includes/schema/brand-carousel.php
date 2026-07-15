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
			'label'       => __( 'Brand IDs', 'kidia-mobile-cms' ),
			'description' => __( 'Enter IDs separated by commas in the display order.', 'kidia-mobile-cms' ),
			'type'        => 'text',
			'tab'         => 'brands',
			'default'     => '',
			'placeholder' => '12, 8, 24',
			'full_width'  => true,
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
