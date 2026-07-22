<?php
/**
 * Promo Strip Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Promo Strip',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a promotional announcement strip.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-megaphone',

	'defaults' => array(

		'text' => '',
		'width' => '',
		'height' => '',
		'enable_transition' => false,
		'messages' => array(),
		'transition_effect' => 'fade',
		'change_every' => 4,
		'transition_duration' => 500,

		'background_color' => '#4f9f8f',

		'text_color' => '#ffffff',

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
			'id' => 'style',
			'label' => __(
				'Style',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'action',
			'label' => __(
				'Action',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(
		array( 'key' => 'width', 'label' => __( 'Width (%)', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'style', 'default' => '', 'min' => 10, 'max' => 100 ),
		array( 'key' => 'height', 'label' => __( 'Height', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'style', 'default' => '', 'min' => 20, 'max' => 240 ),
		array( 'key' => 'enable_transition', 'label' => __( 'Rotating Messages', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'transition_effect', 'label' => __( 'Transition Effect', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'general', 'default' => 'fade', 'options' => array( 'fade' => 'Fade', 'slide_up' => 'Slide Up', 'slide_left' => 'Slide Left', 'scale' => 'Scale' ) ),
		array( 'key' => 'change_every', 'label' => __( 'Change Every', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 4, 'min' => 1, 'max' => 60 ),
		array( 'key' => 'transition_duration', 'label' => __( 'Transition Duration', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'general', 'default' => 500, 'min' => 100, 'max' => 5000 ),

		array(
			'key' => 'text',
			'label' => __(
				'Text',
				'kidia-mobile-cms'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 3,
			'full_width' => true,
			'required' => true,
		),

		array(
			'key' => 'background_color',
			'label' => __(
				'Background Color',
				'kidia-mobile-cms'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#4f9f8f',
		),

		array(
			'key' => 'text_color',
			'label' => __(
				'Text Color',
				'kidia-mobile-cms'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#ffffff',
		),

		array(
			'key' => 'action_type',
			'label' => __(
				'Action Type',
				'kidia-mobile-cms'
			),
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
			'label' => __(
				'Action Value',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);
