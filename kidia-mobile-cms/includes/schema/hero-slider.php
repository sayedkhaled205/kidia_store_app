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

		'loop' => true,

		'show_arrows' => true,

		'show_dots' => true,

		'transition' => 'slide',

		'slide_direction' => 'horizontal',

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
			'key' => 'transition',
			'label' => __( 'Transition', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'general',
			'default' => 'slide',
			'options' => array(
				'slide' => __( 'Slide', 'kidia-mobile-cms' ),
				'fade'  => __( 'Fade', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'slide_direction',
			'label' => __( 'Slide Direction', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'general',
			'default' => 'horizontal',
			'options' => array(
				'horizontal' => __( 'Horizontal', 'kidia-mobile-cms' ),
				'vertical'   => __( 'Vertical', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'loop',
			'label' => __( 'Loop Slides', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'show_arrows',
			'label' => __( 'Show Navigation Arrows', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'show_dots',
			'label' => __( 'Show Pagination Dots', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
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
