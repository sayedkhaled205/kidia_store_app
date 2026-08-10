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
		'mobishop'
	),

	'description' => __(
		'Display a promotional announcement strip.',
		'mobishop'
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
				'mobishop'
			),
		),

		array(
			'id' => 'style',
			'label' => __(
				'Style',
				'mobishop'
			),
		),

		array(
			'id' => 'action',
			'label' => __(
				'Action',
				'mobishop'
			),
		),

	),

	'fields' => array(
		array( 'key' => 'width', 'label' => __( 'Width (%)', 'mobishop' ), 'type' => 'number', 'tab' => 'style', 'default' => '', 'min' => 10, 'max' => 100 ),
		array( 'key' => 'height', 'label' => __( 'Height', 'mobishop' ), 'type' => 'number', 'tab' => 'style', 'default' => '', 'min' => 20, 'max' => 240 ),
		array( 'key' => 'enable_transition', 'label' => __( 'Rotating Messages', 'mobishop' ), 'type' => 'checkbox', 'tab' => 'general', 'default' => false ),
		array( 'key' => 'transition_effect', 'label' => __( 'Transition Effect', 'mobishop' ), 'type' => 'select', 'tab' => 'general', 'default' => 'fade', 'options' => array( 'fade' => 'Fade', 'slide_up' => 'Slide Up', 'slide_left' => 'Slide Left', 'scale' => 'Scale' ) ),
		array( 'key' => 'change_every', 'label' => __( 'Change Every', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 4, 'min' => 1, 'max' => 60 ),
		array( 'key' => 'transition_duration', 'label' => __( 'Transition Duration', 'mobishop' ), 'type' => 'number', 'tab' => 'general', 'default' => 500, 'min' => 100, 'max' => 5000 ),

		array(
			'key' => 'text',
			'label' => __(
				'Text',
				'mobishop'
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
				'mobishop'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#4f9f8f',
		),

		array(
			'key' => 'text_color',
			'label' => __(
				'Text Color',
				'mobishop'
			),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#ffffff',
		),

		array(
			'key' => 'action_type',
			'label' => __(
				'Action Type',
				'mobishop'
			),
			'type' => 'select',
			'tab' => 'action',
			'default' => '',
			'options' => array(
				'' => __( 'No Action', 'mobishop' ),
				'collection' => __( 'Collection', 'mobishop' ),
				'category' => __( 'Category', 'mobishop' ),
				'product' => __( 'Product', 'mobishop' ),
				'search' => __( 'Search', 'mobishop' ),
				'external' => __( 'External URL', 'mobishop' ),
			),
		),

		array(
			'key' => 'action_value',
			'label' => __(
				'Action Value',
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);
