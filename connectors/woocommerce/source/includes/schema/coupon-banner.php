<?php
/**
 * Coupon Banner Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Coupon Banner',
		'mobi2app-connector'
	),

	'description' => __(
		'Display a promotional coupon banner.',
		'mobi2app-connector'
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
				'mobi2app-connector'
			),
		),

		array(
			'id' => 'media',
			'label' => __(
				'Media',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'text',
			'tab' => 'general',
			'default' => '',
		),

		array(
			'key' => 'image_url',
			'label' => __(
				'Banner Image',
				'mobi2app-connector'
			),
			'type' => 'image',
			'tab' => 'media',
			'default' => '',
			'full_width' => true,
		),

	),

);