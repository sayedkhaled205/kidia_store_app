<?php
/**
 * Coupon Banner Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Coupon Banner',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a promotional coupon banner.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-tickets-alt',

	'defaults' => array(

		'title' => '',

		'description' => '',

		'coupon_code' => '',

		'image_url' => '',

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
			'id' => 'media',
			'label' => __(
				'Media',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
			'required' => true,
			'full_width' => true,
		),

		array(
			'key' => 'description',
			'label' => __(
				'Description',
				'kidia-mobile-cms'
			),
			'type' => 'textarea',
			'tab' => 'general',
			'default' => '',
			'rows' => 4,
			'full_width' => true,
		),

		array(
			'key' => 'coupon_code',
			'label' => __(
				'Coupon Code',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
		),

		array(
			'key' => 'image_url',
			'label' => __(
				'Banner Image',
				'kidia-mobile-cms'
			),
			'type' => 'image',
			'tab' => 'media',
			'default' => '',
			'full_width' => true,
		),

	),

);