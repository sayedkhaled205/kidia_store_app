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
		array( 'key' => 'source', 'type' => 'select', 'default' => 'latest' ),
		array( 'key' => 'columns', 'type' => 'number', 'default' => 2, 'min' => 1, 'max' => 4 ),
		array( 'key' => 'limit', 'type' => 'number', 'default' => 8, 'min' => 1, 'max' => 50 ),
	),
);
