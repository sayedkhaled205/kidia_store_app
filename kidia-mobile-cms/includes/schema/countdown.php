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

		'expired_text' => 'Offer ended',

		'end_behavior' => 'message',

		'days_label' => 'Days',

		'hours_label' => 'Hours',

		'minutes_label' => 'Minutes',

		'seconds_label' => 'Seconds',

		'background_color' => '#111827',

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
			'id' => 'timer',
			'label' => __(
				'Timer',
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'style',
			'label' => __( 'Style', 'kidia-mobile-cms' ),
		),

		array(
			'id' => 'action',
			'label' => __( 'Action', 'kidia-mobile-cms' ),
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
			'type' => 'datetime',
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
			'default' => 'Offer ended',
			'full_width' => true,
		),

		array(
			'key' => 'end_behavior',
			'label' => __( 'When Timer Ends', 'kidia-mobile-cms' ),
			'type' => 'select',
			'tab' => 'timer',
			'default' => 'message',
			'options' => array(
				'message' => __( 'Show Expired Message', 'kidia-mobile-cms' ),
				'hide' => __( 'Hide Countdown', 'kidia-mobile-cms' ),
			),
		),

		array(
			'key' => 'days_label',
			'label' => __( 'Days Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'timer',
			'default' => 'Days',
		),

		array(
			'key' => 'hours_label',
			'label' => __( 'Hours Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'timer',
			'default' => 'Hours',
		),

		array(
			'key' => 'minutes_label',
			'label' => __( 'Minutes Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'timer',
			'default' => 'Minutes',
		),

		array(
			'key' => 'seconds_label',
			'label' => __( 'Seconds Label', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'timer',
			'default' => 'Seconds',
		),

		array(
			'key' => 'background_color',
			'label' => __( 'Background Color', 'kidia-mobile-cms' ),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#111827',
		),

		array(
			'key' => 'text_color',
			'label' => __( 'Text Color', 'kidia-mobile-cms' ),
			'type' => 'color',
			'tab' => 'style',
			'default' => '#ffffff',
		),

		array(
			'key' => 'action_type',
			'label' => __( 'Action Type', 'kidia-mobile-cms' ),
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
			'label' => __( 'Action Value', 'kidia-mobile-cms' ),
			'type' => 'text',
			'tab' => 'action',
			'default' => '',
			'full_width' => true,
		),

	),

);
