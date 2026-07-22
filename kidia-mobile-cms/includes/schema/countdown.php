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

		'expired_text' => 'انتهى العرض',

		'show_days' => true,
		'show_hours' => true,
		'show_minutes' => true,
		'show_seconds' => true,
		'layout_style' => 'cards',

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
		array( 'key' => 'layout_style', 'label' => __( 'Layout Style', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'timer', 'default' => 'cards', 'options' => array( 'cards' => 'Cards', 'circles' => 'Circles', 'flip_clock' => 'Flip Clock', 'minimal_inline' => 'Minimal Inline', 'split_labels' => 'Split Labels' ) ),
		array( 'key' => 'show_days', 'label' => __( 'Show Days', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'timer', 'default' => true ),
		array( 'key' => 'show_hours', 'label' => __( 'Show Hours', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'timer', 'default' => true ),
		array( 'key' => 'show_minutes', 'label' => __( 'Show Minutes', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'timer', 'default' => true ),
		array( 'key' => 'show_seconds', 'label' => __( 'Show Seconds', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'timer', 'default' => true ),

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
			'default' => 'انتهى العرض',
			'full_width' => true,
		),

	),

);
