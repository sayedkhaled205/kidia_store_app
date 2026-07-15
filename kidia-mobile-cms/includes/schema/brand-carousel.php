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
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display brands in a horizontal carousel.',
		'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'brands',
			'label' => __(
				'Brands',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
			'type' => 'repeater',
			'tab' => 'brands',
			'default' => array(),
		),

	),

);