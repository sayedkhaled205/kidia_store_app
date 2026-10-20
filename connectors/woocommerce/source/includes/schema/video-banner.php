<?php
/**
 * Video Banner Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Video Banner',
		'mobi2app-connector'
	),

	'description' => __(
		'Display a promotional video banner.',
		'mobi2app-connector'
	),

	'icon' => 'dashicons-video-alt3',

	'defaults' => array(

		'video_url' => '',

		'poster_url' => '',

		'aspect_ratio' => 1.8,

		'auto_play' => false,

		'muted' => true,

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
			'id' => 'playback',
			'label' => __(
				'Playback',
				'mobi2app-connector'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'video_url',
			'label' => __(
				'Video URL',
				'mobi2app-connector'
			),
			'type' => 'url',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
			'required' => true,
		),

		array(
			'key' => 'poster_url',
			'label' => __(
				'Poster Image',
				'mobi2app-connector'
			),
			'type' => 'image',
			'tab' => 'general',
			'default' => '',
			'full_width' => true,
		),

		array(
			'key' => 'aspect_ratio',
			'label' => __(
				'Aspect Ratio',
				'mobi2app-connector'
			),
			'type' => 'number',
			'tab' => 'playback',
			'default' => 1.8,
			'min' => 1,
			'max' => 4,
			'step' => 0.1,
		),

		array(
			'key' => 'auto_play',
			'label' => __(
				'Autoplay',
				'mobi2app-connector'
			),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => false,
		),

		array(
			'key' => 'muted',
			'label' => __(
				'Muted',
				'mobi2app-connector'
			),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => true,
		),

	),

);