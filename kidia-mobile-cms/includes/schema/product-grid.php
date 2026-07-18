<?php
/** Product Grid schema. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Product Grid', 'kidia-mobile-cms' ),
	'description' => __( 'Display WooCommerce products in a responsive mobile grid.', 'kidia-mobile-cms' ),
	'icon'        => 'dashicons-grid-view',
	'defaults'    => array(
		'title' => '', 'subtitle' => '', 'source' => 'latest', 'limit' => 8,
		'columns' => 2, 'category_id' => 0, 'product_ids' => '',
		'show_view_all' => true, 'view_all_label' => '', 'action_type' => '', 'action_value' => '',
		'card_style' => 'outlined', 'image_ratio' => 1, 'card_radius' => 20,
		'show_name' => true, 'show_price' => true, 'show_regular_price' => true,
		'show_badge' => true, 'show_rating' => false,
	),
	'fields'      => array(
		array( 'key' => 'title', 'label' => __( 'Section title', 'kidia-mobile-cms' ), 'type' => 'text', 'default' => '' ),
		array( 'key' => 'subtitle', 'label' => __( 'Subtitle', 'kidia-mobile-cms' ), 'type' => 'text', 'default' => '' ),
		array( 'key' => 'source', 'type' => 'select', 'default' => 'latest' ),
		array( 'key' => 'columns', 'type' => 'number', 'default' => 2, 'min' => 1, 'max' => 4 ),
		array( 'key' => 'limit', 'type' => 'number', 'default' => 8, 'min' => 1, 'max' => 50 ),
		array( 'key' => 'category_id', 'label' => __( 'Category ID', 'kidia-mobile-cms' ), 'type' => 'number', 'default' => 0, 'min' => 0 ),
		array( 'key' => 'product_ids', 'label' => __( 'Manual product IDs', 'kidia-mobile-cms' ), 'type' => 'text', 'default' => '' ),
		array( 'key' => 'card_style', 'label' => __( 'Card style', 'kidia-mobile-cms' ), 'type' => 'select', 'default' => 'outlined', 'options' => array( 'minimal' => __( 'Minimal', 'kidia-mobile-cms' ), 'outlined' => __( 'Outlined', 'kidia-mobile-cms' ), 'elevated' => __( 'Elevated', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'image_ratio', 'label' => __( 'Image ratio', 'kidia-mobile-cms' ), 'type' => 'number', 'default' => 1, 'min' => 0.6, 'max' => 1.8, 'step' => 0.05 ),
		array( 'key' => 'card_radius', 'label' => __( 'Card radius', 'kidia-mobile-cms' ), 'type' => 'number', 'default' => 20, 'min' => 0, 'max' => 40 ),
		array( 'key' => 'show_view_all', 'label' => __( 'Show view all', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'default' => true ),
		array( 'key' => 'show_name', 'label' => __( 'Show product name', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'default' => true ),
		array( 'key' => 'show_price', 'label' => __( 'Show price', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'default' => true ),
		array( 'key' => 'show_regular_price', 'label' => __( 'Show regular price', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'default' => true ),
		array( 'key' => 'show_badge', 'label' => __( 'Show sale badge', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'default' => true ),
		array( 'key' => 'show_rating', 'label' => __( 'Show rating', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'default' => false ),
	),
);
