<?php
/**
 * Image Banner Schema.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __(
		'Image Banner',
		'mobi2app-connector'
	),
	'description' => __(
		'Create and configure a promotional image banner.',
		'mobi2app-connector'
	),
	'icon'        => 'dashicons-format-image',

	'defaults' => array(
		'image_url'      => '',
		'semantic_label' => '',
		'aspect_ratio'   => 1,
		'border_radius'  => 18,
		'button_label'   => 'SHOP NOW',
		'action_type'    => '',
		'action_value'   => '',
	),

	'tabs' => array(
		array(
			'id'    => 'general',
			'label' => __(
				'General',
				'mobi2app-connector'
			),
		),
		array(
			'id'    => 'action',
			'label' => __(
				'Action',
				'mobi2app-connector'
			),
		),
		array(
			'id'    => 'style',
			'label' => __(
				'Style',
				'mobi2app-connector'
			),
		),
	),

	'fields' => array(
		array(
			'key'         => 'image_url',
			'label'       => __(
				'Banner Image',
				'mobi2app-connector'
			),
			'description' => __(
				'Select the image displayed in the banner.',
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'description' => __(
				'Text used by screen readers.',
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
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
				'mobi2app-connector'
			),
			'type'    => 'select',
			'tab'     => 'action',
			'default' => '',
			'options' => array(
				''           => __(
					'No Action',
					'mobi2app-connector'
				),
				'product'    => __(
					'Product',
					'mobi2app-connector'
				),
				'category'   => __(
					'Category',
					'mobi2app-connector'
				),
				'collection' => __(
					'Collection',
					'mobi2app-connector'
				),
				'search'     => __(
					'Search',
					'mobi2app-connector'
				),
				'external'   => __(
					'External URL',
					'mobi2app-connector'
				),
			),
		),

		array(
			'key'         => 'action_value',
			'label'       => __(
				'Action Value',
				'mobi2app-connector'
			),
			'description' => __(
				'Enter the product ID, category ID, collection name, search text or URL.',
				'mobi2app-connector'
			),
			'type'        => 'text',
			'tab'         => 'action',
			'default'     => '',
			'full_width'  => true,
		),
	),
);
