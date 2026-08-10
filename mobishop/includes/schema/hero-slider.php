<?php
/**
 * Hero Slider Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title'       => __( 'Hero Slider', 'mobishop' ),

	'description' => __(
		'Manage Hero Slider settings.',
		'mobishop'
	),

	'icon' => 'dashicons-images-alt2',

	'defaults' => array(

		'aspect_ratio' => 1.8,

		'auto_play' => true,

		'interval_ms' => 4500,

		'slides' => array(),

	),

	'tabs' => array(

		array(
			'id'    => 'general',
			'label' => __( 'General', 'mobishop' ),
		),

		array(
			'id'    => 'slides',
			'label' => __( 'Slides', 'mobishop' ),
		),

	),

	'fields' => array(

		array(
			'key' => 'aspect_ratio',
			'label' => __( 'Aspect Ratio', 'mobishop' ),
			'type' => 'number',
			'tab' => 'general',
			'min' => 1,
			'max' => 4,
			'step' => 0.1,
			'default' => 1.8,
		),

		array(
			'key' => 'auto_play',
			'label' => __( 'Autoplay', 'mobishop' ),
			'type' => 'checkbox',
			'tab' => 'general',
			'default' => true,
		),

		array(
			'key' => 'interval_ms',
			'label' => __( 'Interval (ms)', 'mobishop' ),
			'type' => 'number',
			'tab' => 'general',
			'min' => 2000,
			'max' => 15000,
			'step' => 500,
			'default' => 4500,
		),

		array(
			'key' => 'slides',
			'label' => __( 'Slides', 'mobishop' ),
			'type' => 'repeater',
			'tab' => 'slides',
			'default' => array(),
		),

	),

);