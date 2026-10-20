<?php
/**
 * Promo Strip Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Promo Strip',
		'mobi2app-connector'
	),

	'description' => __(
		'Display a promotional announcement strip.',
		'mobi2app-connector'
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
				'mobi2app-connector'
			),
		),

		array(
			'id' => 'style',
			'label' => __(
				'Style',
				'mobi2app-connector'
			),
		),

		array(
			'id' => 'action',
			'label' => __(
				'Action',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(
		array( 'key' => 'width', 'label' => __( 'Width (%)', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'style', 'default' => '', 'min' => 10, 'max' => 100 ),
		array( 'key' => 'height', 'label' => __( 'Height', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'style', 'default' => '', 'min' => 20, 'max' => 240 ),
		array( 'key' => 'enable_transition', 'label' => __( 'Rotating Messages', 'mobi2app-connector' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'transition_effect', 'label' => __( 'Transition Effect', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'general', 'default' => 'fade', 'options' => array( 'fade' => 'Fade', 'slide_up' => 'Slide Up', 'slide_left' => 'Slide Left', 'scale' => 'Scale' ) ),
		array( 'key' => 'change_every', 'label' => __( 'Change Every', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 4, 'min' => 1, 'max' => 60 ),
		array( 'key' => 'transition_duration', 'label' => __( 'Transition Duration', 'mobi2app-connector' ), 'type' => 'number', 'tab' => 'general', 'default' => 500, 'min' => 100, 'max' => 5000 ),

		array(
			'key' => 'text',
			'label' => __(
				'Text',
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#4f9f8f',
		),

		array(
			'key' => 'text_color',
			'label' => __(
				'Text Color',
				'mobi2app-connector'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#ffffff',
		),

		array(
			'key' => 'action_type',
			'label' => __(
				'Action Type',
				'mobi2app-connector'
			),
			'type' => 'select',
			'tab' => 'action',
			'default' => '',
			'options' => array(
				'' => __( 'No Action', 'mobi2app-connector' ),
				'collection' => __( 'Collection', 'mobi2app-connector' ),
				'category' => __( 'Category', 'mobi2app-connector' ),
				'product' => __( 'Product', 'mobi2app-connector' ),
				'search' => __( 'Search', 'mobi2app-connector' ),
				'external' => __( 'External URL', 'mobi2app-connector' ),
			),
		),

		array(
			'key' => 'action_value',
			'label' => __(
				'Action Value',
				'mobi2app-connector'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);
