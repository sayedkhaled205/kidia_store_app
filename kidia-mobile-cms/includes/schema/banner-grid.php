<?php
/** Banner Grid schema. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Banner Grid', 'kidia-mobile-cms' ),
	'description' => __( 'Equal, featured, or mosaic promotional banner groups.', 'kidia-mobile-cms' ),
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
