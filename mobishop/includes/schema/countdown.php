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
		'mobishop'
	),

	'description' => __(
		'Display a countdown timer.',
		'mobishop'
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
				'mobishop'
			),
		),

		array(
			'id' => 'timer',
			'label' => __(
				'Timer',
				'mobishop'
			),
		),

	),

	'fields' => array(
		array( 'key' => 'layout_style', 'label' => __( 'Layout Style', 'mobishop' ), 'type' => 'select', 'tab' => 'timer', 'default' => 'cards', 'options' => array( 'cards' => 'Cards', 'circles' => 'Circles', 'flip_clock' => 'Flip Clock', 'minimal_inline' => 'Minimal Inline', 'split_labels' => 'Split Labels' ) ),
		array( 'key' => 'visible_units', 'label' => __( 'Visible time units', 'mobishop' ), 'type' => 'select', 'tab' => 'timer', 'default' => 'days_hours_minutes_seconds', 'options' => array( 'days' => __( 'Days only', 'mobishop' ), 'days_hours' => __( 'Days + Hours', 'mobishop' ), 'days_hours_minutes' => __( 'Days + Hours + Minutes', 'mobishop' ), 'days_hours_minutes_seconds' => __( 'Days + Hours + Minutes + Seconds', 'mobishop' ) ) ),

		array(
			'key' => 'title',
			'label' => __(
				'Title',
				'mobishop'
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
				'mobishop'
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
				'mobishop'
			),
			'type' => 'text',
			'tab' => 'timer',
			'default' => 'انتهى العرض',
			'full_width' => true,
		),

	),

);
