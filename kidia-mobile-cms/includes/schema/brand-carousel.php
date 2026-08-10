<?php
/**
 * Brand Carousel Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Brand Carousel',
		'mobishop'
	),

	'description' => __(
		'Display brands in a horizontal carousel.',
		'mobishop'
	),

	'icon' => 'dashicons-store',

	'defaults' => array(

		'title' => '',

		'item_width' => 90,

		'brands' => array(),

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
			'id' => 'brands',
			'label' => __(
				'Brands',
				'mobishop'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'item_width',
			'label' => __(
				'Brand Width',
				'mobishop'
			),
			'type' => 'number',
			'tab' => 'general',
			'default' => 90,
			'min' => 60,
			'max' => 200,
			'step' => 1,
		),

		array(
			'key' => 'brands',
			'label' => __(
				'Brands',
				'mobishop'
			),
			'type' => 'repeater',
			'tab' => 'brands',
			'default' => array(),
		),

	),

);