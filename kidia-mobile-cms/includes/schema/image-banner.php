<?php
/**
 * Image Banner Schema.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __(
		'Image Banner',
		'kidia-mobile-cms'
	),
	'description' => __(
		'Create and configure a promotional image banner.',
		'kidia-mobile-cms'
	),
	'icon'        => 'dashicons-format-image',

	'defaults' => array(
		'image_url'      => '',
		'semantic_label' => '',
		'aspect_ratio'   => 2.4,
		'border_radius'  => 20,
		'action_type'    => '',
		'action_value'   => '',
	),

	'tabs' => array(
		array(
			'id'    => 'general',
			'label' => __(
				'General',
				'kidia-mobile-cms'
			),
		),
		array(
			'id'    => 'action',
			'label' => __(
				'Action',
				'kidia-mobile-cms'
			),
		),
		array(
			'id'    => 'style',
			'label' => __(
				'Style',
				'kidia-mobile-cms'
			),
		),
	),

	'fields' => array(
		array(
			'key'         => 'image_url',
			'label'       => __(
				'Banner Image',
				'kidia-mobile-cms'
			),
			'description' => __(
				'Select the image displayed in the banner.',
				'kidia-mobile-cms'
			),
			'type'        => 'image',
			'tab'         => 'general',
			'default'     => '',
			'required'    => true,
			'full_width'  => true,
		),

		array(
			'key'         => 'semantic_label',
			'label'       => __(
				'Accessibility Label',
				'kidia-mobile-cms'
			),
			'description' => __(
				'Text used by screen readers.',
				'kidia-mobile-cms'
			),
			'type'        => 'text',
			'tab'         => 'general',
			'default'     => '',
			'full_width'  => true,
		),

		array(
			'key'     => 'aspect_ratio',
			'label'   => __(
				'Aspect Ratio',
				'kidia-mobile-cms'
			),
			'type'    => 'number',
			'tab'     => 'style',
			'default' => 2.4,
			'min'     => 1,
			'max'     => 5,
			'step'    => 0.1,
		),

		array(
			'key'     => 'border_radius',
			'label'   => __(
				'Border Radius',
				'kidia-mobile-cms'
			),
			'type'    => 'number',
			'tab'     => 'style',
			'default' => 20,
			'min'     => 0,
			'max'     => 48,
			'step'    => 1,
		),

		array(
			'key'     => 'action_type',
			'label'   => __(
				'Action Type',
				'kidia-mobile-cms'
			),
			'type'    => 'select',
			'tab'     => 'action',
			'default' => '',
			'options' => array(
				''           => __(
					'No Action',
					'kidia-mobile-cms'
				),
				'product'    => __(
					'Product',
					'kidia-mobile-cms'
				),
				'category'   => __(
					'Category',
					'kidia-mobile-cms'
				),
				'collection' => __(
					'Collection',
					'kidia-mobile-cms'
				),
				'search'     => __(
					'Search',
					'kidia-mobile-cms'
				),
				'external'   => __(
					'External URL',
					'kidia-mobile-cms'
				),
			),
		),

		array(
			'key'         => 'action_value',
			'label'       => __(
				'Action Value',
				'kidia-mobile-cms'
			),
			'description' => __(
				'Enter the product ID, category ID, collection name, search text or URL.',
				'kidia-mobile-cms'
			),
			'type'        => 'text',
			'tab'         => 'action',
			'default'     => '',
			'full_width'  => true,
		),
	),
);