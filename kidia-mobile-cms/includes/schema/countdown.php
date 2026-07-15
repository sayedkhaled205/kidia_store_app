<?php
/**
 * Countdown Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Countdown',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a countdown timer.',
		'kidia-mobile-cms'
	),

	'icon' => 'dashicons-clock',

	'defaults' => array(

		'title' => '',

		'ends_at' => '',

		'expired_text' => __( 'Offer ended', 'kidia-mobile-cms' ),

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
			'id' => 'timer',
			'label' => __(
				'Timer',
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
			'full_width' => true,
		),

		array(
			'key' => 'ends_at',
			'label' => __(
				'End Date',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'timer',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'expired_text',
			'label' => __(
				'Expired Text',
				'kidia-mobile-cms'
			),
			'type' => 'text',
			'tab' => 'timer',
			'default' => __( 'Offer ended', 'kidia-mobile-cms' ),
			'full_width' => true,
		),

	),

);
