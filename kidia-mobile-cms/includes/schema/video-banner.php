<?php
/**
 * Video Banner Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Video Banner',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a promotional video banner.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-video-alt3',

	'defaults' => array(

		'video_url' => '',

		'poster_url' => '',

		'aspect_ratio' => 1.8,

		'auto_play' => false,

		'muted' => true,

		'loop' => false,

		'show_controls' => true,

		'title' => '',

		'subtitle' => '',

		'button_label' => '',

		'overlay_color' => '#000000',

		'overlay_opacity' => 0,

		'action_type' => '',

		'action_value' => '',

	),

	'tabs' => array(

		array(
			'id' => 'general',
			'label' => __(
				'General',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'playback',
			'label' => __(
				'Playback',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'content',
			'label' => __( 'Content', 'kidia-mobile-cms' ),
		),

		array(
			'id' => 'action',
			'label' => __( 'Action', 'kidia-mobile-cms' ),
		),

	),

	'fields' => array(

		array(
			'key' => 'video_url',
			'label' => __(
				'Video URL',
				'kidia-mobile-cms'
			),
			'type' => 'video',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
			'required' => true,
		),

		array(
			'key' => 'poster_url',
			'label' => __(
				'Poster Image',
				'kidia-mobile-cms'
			),
			'type' => 'image',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'aspect_ratio',
			'label' => __(
				'Aspect Ratio',
				'kidia-mobile-cms'
			),
			'type' => 'number',
			'tab' => 'playback',
			'default' => 1.8,
			'min' => 1,
			'max' => 4,
			'step' => 0.1,
		),

		array(
			'key' => 'auto_play',
			'label' => __(
				'Autoplay',
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => false,
		),

		array(
			'key' => 'muted',
			'label' => __(
				'Muted',
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => true,
		),

		array(
			'key' => 'loop',
			'label' => __( 'Loop', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => false,
		),

		array(
			'key' => 'show_controls',
			'label' => __( 'Show Player Controls', 'kidia-mobile-cms' ),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => true,
		),

		array(
			'key' => 'title',
			'label' => __( 'Title', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'content',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'subtitle',
			'label' => __( 'Subtitle', 'kidia-mobile-cms' ),
			'type' => 'textarea',
			'tab' => 'content',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'button_label',
			'label' => __( 'Button Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'content',
			'default' => '',
		),

		array(
			'key' => 'overlay_color',
			'label' => __( 'Overlay Color', 'kidia-mobile-cms' ),
			'type' => 'color',
			'tab' => 'content',
			'default' => '#000000',
		),

		array(
			'key' => 'overlay_opacity',
			'label' => __( 'Overlay Opacity', 'kidia-mobile-cms' ),
			'type' => 'number',
			'tab' => 'content',
			'default' => 0,
			'min' => 0,
			'max' => 1,
			'step' => 0.05,
		),

		array(
			'key' => 'action_type',
			'label' => __( 'Action Type', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'action',
			'default' => '',
			'options' => array(
				'' => __( 'No Action', 'kidia-mobile-cms' ),
				'collection' => __( 'Collection', 'kidia-mobile-cms' ),
				'category' => __( 'Category', 'kidia-mobile-cms' ),
				'product' => __( 'Product', 'kidia-mobile-cms' ),
				'search' => __( 'Search', 'kidia-mobile-cms' ),
				'external' => __( 'External URL', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'action_value',
			'label' => __( 'Action Value', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);
