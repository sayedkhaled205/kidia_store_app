<?php
/**
 * Countdown Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Countdown',
		'mobi2app-connector'
	),

	'description' => __(
		'Display a countdown timer.',
		'mobi2app-connector'
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
				'mobi2app-connector'
			),
		),

		array(
			'id' => 'timer',
			'label' => __(
				'Timer',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(
		array( 'key' => 'layout_style', 'label' => __( 'Layout Style', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'timer', 'default' => 'cards', 'options' => array( 'cards' => 'Cards', 'circles' => 'Circles', 'flip_clock' => 'Flip Clock', 'minimal_inline' => 'Minimal Inline', 'split_labels' => 'Split Labels' ) ),
		array( 'key' => 'visible_units', 'label' => __( 'Visible time units', 'mobi2app-connector' ), 'type' => 'select', 'tab' => 'timer', 'default' => 'days_hours_minutes_seconds', 'options' => array( 'days' => __( 'Days only', 'mobi2app-connector' ), 'days_hours' => __( 'Days + Hours', 'mobi2app-connector' ), 'days_hours_minutes' => __( 'Days + Hours + Minutes', 'mobi2app-connector' ), 'days_hours_minutes_seconds' => __( 'Days + Hours + Minutes + Seconds', 'mobi2app-connector' ) ) ),

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type' => 'text',
			'tab' => 'timer',
			'default' => 'انتهى العرض',
			'full_width' => true,
		),

	),

);
