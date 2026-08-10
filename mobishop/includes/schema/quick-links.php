<?php
/** Quick Links schema. @package MobiShop */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Quick Links', 'mobishop' ),
	'description' => __( 'Flexible image shortcuts in a row or grid.', 'mobishop' ),
	'icon'        => 'dashicons-admin-links',
	'defaults'    => array(
		'title' => '', 'subtitle' => '', 'layout' => 'carousel', 'columns' => 4,
		'image_shape' => 'circle', 'item_size' => 76, 'gap' => 12, 'show_labels' => true,
		'label_color' => '#1F2933', 'label_size' => 13, 'items' => array(),
	),
	'fields'      => array(
		array( 'key' => 'layout', 'type' => 'select', 'default' => 'carousel' ),
		array( 'key' => 'items', 'type' => 'repeater', 'default' => array() ),
	),
);
