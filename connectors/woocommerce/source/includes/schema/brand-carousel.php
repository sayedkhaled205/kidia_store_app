<?php
/**
 * Brand Carousel Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Brand Carousel',
		'mobi2app-connector'
	),

	'description' => __(
		'Display brands in a horizontal carousel.',
		'mobi2app-connector'
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
				'mobi2app-connector'
			),
		),

		array(
			'id' => 'brands',
			'label' => __(
				'Brands',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Section Title',
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'repeater',
			'tab' => 'brands',
			'default' => array(),
		),

	),

);