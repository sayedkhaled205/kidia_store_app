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
		'mobishop'
	),

	'description' => __(
		'Display a promotional coupon banner.',
		'mobishop'
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
				'mobishop'
			),
		),

		array(
			'id' => 'media',
			'label' => __(
				'Media',
				'mobishop'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'mobishop'
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
				'mobishop'
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
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
		),

		array(
			'key' => 'image_url',
			'label' => __(
				'Banner Image',
				'mobishop'
			),
			'type' => 'image',
			'tab' => 'media',
			'default' => '',
			'full_width' => true,
		),

	),

);