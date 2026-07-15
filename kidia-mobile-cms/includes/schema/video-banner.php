<?php
/**
 * Video Banner Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(

	'title' => __(
		'Video Banner',
		'kidia-mobile-cms'
	),

	'description' => __(
		'Display a promotional video banner.',
		'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
		),

		array(
			'id' => 'playback',
			'label' => __(
				'Playback',
				'kidia-mobile-cms'
			),
		),

	),

	'fields' => array(

		array(
			'key' => 'video_url',
			'label' => __(
				'Video URL',
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
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
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => false,
		),

		array(
			'key' => 'muted',
			'label' => __(
				'Muted',
				'kidia-mobile-cms'
			),
			'type' => 'checkbox',
			'tab' => 'playback',
			'default' => true,
		),

	),

);