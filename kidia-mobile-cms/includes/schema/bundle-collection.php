<?php
/** Bundle Collection schema. */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'Bundles & Recommendations', 'mobishop' ),
	'description' => __( 'Show configurable and AI-recommended bundles.', 'mobishop' ),
	'icon'        => 'dashicons-products',
	'defaults'    => array(
		'title'            => __( 'Bundles selected for you', 'mobishop' ),
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
