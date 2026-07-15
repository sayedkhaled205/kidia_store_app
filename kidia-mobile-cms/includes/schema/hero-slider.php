<?php
/**
 * Hero Slider Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title'       => __( 'Hero Slider', 'kidia-mobile-cms' ),

	'description' => __(
		'Manage Hero Slider settings.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-images-alt2',

	'defaults' => array(

		'aspect_ratio' => 1.8,

		'auto_play' => true,

		'interval_ms' => 4500,

		'items' => array(),

	),

	'tabs' => array(

		array(
			'id'    => 'general',
			'label' => __( 'General', 'kidia-mobile-cms' ),
		),

		array(
			'id'    => 'items',
			'label' => __( 'Images', 'kidia-mobile-cms' ),
		),

	),

	'fields' => array(

		array(
			'key' => 'aspect_ratio',
			'label' => __( 'Aspect Ratio', 'kidia-mobile-cms' ),
			'type' => 'number',
			'tab' => 'general',
			'min' => 1,
			'max' => 4,
			'step' => 0.1,
			'default' => 1.8,
		),

		array(
			'key' => 'auto_play',
			'label' => __( 'Autoplay', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'interval_ms',
			'label' => __( 'Interval (ms)', 'kidia-mobile-cms' ),
			'type' => 'number',
			'tab' => 'general',
			'min' => 2000,
			'max' => 15000,
			'step' => 500,
			'default' => 4500,
		),

		array(
			'key' => 'items',
			'label' => __( 'Slides', 'kidia-mobile-cms' ),
			'type' => 'gallery',
			'tab' => 'items',
			'default' => array(),
		),

	),

);