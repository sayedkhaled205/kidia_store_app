<?php
/** App Header schema. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;

return array(
	'title'       => __( 'App Header', 'kidia-mobile-cms' ),
	'description' => __( 'PatPat-style home header with logo, store name and customer actions.', 'kidia-mobile-cms' ),
	'icon'        => 'dashicons-align-wide',
	'defaults'    => array(
		'logo_url'       => '',
		'title'          => '',
		'subtitle'       => '',
		'layout'         => 'center',
		'height'         => 64,
		'logo_height'    => 38,
		'show_search'    => true,
		'show_cart'      => true,
		'show_account'   => false,
		'title_color'    => '#1F2933',
		'icon_color'     => '#1F2933',
	),
	'tabs' => array(
		array( 'id' => 'content', 'label' => __( 'Content', 'kidia-mobile-cms' ) ),
		array( 'id' => 'layout', 'label' => __( 'Layout', 'kidia-mobile-cms' ) ),
	),
	'fields' => array(
		array( 'key' => 'logo_url', 'label' => __( 'Logo', 'kidia-mobile-cms' ), 'type' => 'image', 'tab' => 'content', 'default' => '', 'full_width' => true ),
		array( 'key' => 'title', 'label' => __( 'Store name', 'kidia-mobile-cms' ), 'type' => 'text', 'tab' => 'content', 'default' => '', 'full_width' => true ),
		array( 'key' => 'subtitle', 'label' => __( 'Subtitle', 'kidia-mobile-cms' ), 'type' => 'text', 'tab' => 'content', 'default' => '', 'full_width' => true ),
		array( 'key' => 'layout', 'label' => __( 'Header layout', 'kidia-mobile-cms' ), 'type' => 'select', 'tab' => 'layout', 'default' => 'center', 'options' => array( 'center' => __( 'Centered logo', 'kidia-mobile-cms' ), 'start' => __( 'Logo at start', 'kidia-mobile-cms' ) ) ),
		array( 'key' => 'height', 'label' => __( 'Header height', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'layout', 'min' => 48, 'max' => 120, 'step' => 1, 'default' => 64 ),
		array( 'key' => 'logo_height', 'label' => __( 'Logo height', 'kidia-mobile-cms' ), 'type' => 'number', 'tab' => 'layout', 'min' => 20, 'max' => 80, 'step' => 1, 'default' => 38 ),
		array( 'key' => 'show_search', 'label' => __( 'Show search', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'layout', 'default' => true ),
		array( 'key' => 'show_cart', 'label' => __( 'Show cart', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'layout', 'default' => true ),
		array( 'key' => 'show_account', 'label' => __( 'Show account', 'kidia-mobile-cms' ), 'type' => 'checkbox', 'tab' => 'layout', 'default' => false ),
		array( 'key' => 'title_color', 'label' => __( 'Title color', 'kidia-mobile-cms' ), 'type' => 'color', 'tab' => 'layout', 'default' => '#1F2933' ),
		array( 'key' => 'icon_color', 'label' => __( 'Icon color', 'kidia-mobile-cms' ), 'type' => 'color', 'tab' => 'layout', 'default' => '#1F2933' ),
	),
);
