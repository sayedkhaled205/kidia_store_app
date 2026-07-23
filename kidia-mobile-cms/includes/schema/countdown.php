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

		'visible_units' => 'days_hours_minutes_seconds',
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
		array( 'key' => 'visible_units', 'label' => __( 'Visible time units', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'timer', 'default' => 'days_hours_minutes_seconds', 'options' => array( 'days' => __( 'Days only', 'kidia-mobile-cms' ), 'days_hours' => __( 'Days + Hours', 'kidia-mobile-cms' ), 'days_hours_minutes' => __( 'Days + Hours + Minutes', 'kidia-mobile-cms' ), 'days_hours_minutes_seconds' => __( 'Days + Hours + Minutes + Seconds', 'kidia-mobile-cms' ) ) ),

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
