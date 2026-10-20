<?php
/** Banner Grid schema. @package MobiShop */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Banner Grid', 'mobi2app-connector' ),
	'description' => __( 'Equal, featured, or mosaic promotional banner groups.', 'mobi2app-connector' ),
	'icon'        => 'dashicons-layout',
	'defaults'    => array(
		'title' => '', 'subtitle' => '', 'layout' => 'equal', 'columns' => 2,
		'gap' => 10, 'aspect_ratio' => 1, 'border_radius' => 16, 'image_fit' => 'cover',
		'overlay_strength' => 35, 'text_color' => '#FFFFFF', 'items' => array(),
	),
	'fields'      => array(
		array( 'key' => 'layout', 'type' => 'select', 'default' => 'equal' ),
		array( 'key' => 'items', 'type' => 'repeater', 'default' => array() ),
	),
);
