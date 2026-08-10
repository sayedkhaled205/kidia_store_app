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
		'mobishop'
	),
	'description' => __(
		'Create and configure a promotional image banner.',
		'mobishop'
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
				'mobishop'
			),
		),
		array(
			'id'    => 'action',
			'label' => __(
				'Action',
				'mobishop'
			),
		),
		array(
			'id'    => 'style',
			'label' => __(
				'Style',
				'mobishop'
			),
		),
	),

	'fields' => array(
		array(
			'key'         => 'image_url',
			'label'       => __(
				'Banner Image',
				'mobishop'
			),
			'description' => __(
				'Select the image displayed in the banner.',
				'mobishop'
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
				'mobishop'
			),
			'description' => __(
				'Text used by screen readers.',
				'mobishop'
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
				'mobishop'
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
				'mobishop'
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
				'mobishop'
			),
			'type'    => 'select',
			'tab'     => 'action',
			'default' => '',
			'options' => array(
				''           => __(
					'No Action',
					'mobishop'
				),
				'product'    => __(
					'Product',
					'mobishop'
				),
				'category'   => __(
					'Category',
					'mobishop'
				),
				'collection' => __(
					'Collection',
					'mobishop'
				),
				'search'     => __(
					'Search',
					'mobishop'
				),
				'external'   => __(
					'External URL',
					'mobishop'
				),
			),
		),

		array(
			'key'         => 'action_value',
			'label'       => __(
				'Action Value',
				'mobishop'
			),
			'description' => __(
				'Enter the product ID, category ID, collection name, search text or URL.',
				'mobishop'
			),
			'type'        => 'text',
			'tab'         => 'action',
			'default'     => '',
			'full_width'  => true,
		),
	),
);
