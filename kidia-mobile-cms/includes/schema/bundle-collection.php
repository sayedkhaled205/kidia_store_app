<?php
/** Bundle Collection schema. */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Bundles & Recommendations', 'kidia-mobile-cms' ),
	'description' => __( 'Show configurable and AI-recommended bundles.', 'kidia-mobile-cms' ),
	'icon'        => 'dashicons-products',
	'defaults'    => array(
		'title'            => __( 'Bundles selected for you', 'kidia-mobile-cms' ),
		'subtitle'         => '',
		'source'           => 'published',
		'bundle_ids'       => '',
		'layout'           => 'carousel',
		'limit'            => 6,
		'columns'          => 2,
		'channel'          => 'all',
		'show_image'       => true,
		'show_price'       => true,
		'show_discount'    => true,
		'hide_unavailable' => true,
		'cta_mode'         => 'auto',
		'card_radius'      => 16,
	),
	'tabs'        => array(),
	'fields'      => array(),
);
