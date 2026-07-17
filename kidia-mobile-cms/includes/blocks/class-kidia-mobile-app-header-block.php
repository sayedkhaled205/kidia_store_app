<?php
/** App Header Home Builder block. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_App_Header_Block extends Kidia_Mobile_Block {
	public function get_type(): string { return 'app_header'; }
	public function get_label(): string { return __( 'App Header', 'kidia-mobile-cms' ); }
	public function get_icon(): string { return 'dashicons-align-wide'; }
	public function get_description(): string { return __( 'Configurable PatPat-style home header.', 'kidia-mobile-cms' ); }
	public function get_default_settings(): array {
		return array(
			'logo_url' => '', 'title' => '', 'subtitle' => '', 'layout' => 'center',
			'height' => 64, 'logo_height' => 38, 'show_search' => true,
			'show_cart' => true, 'show_account' => false,
			'title_color' => '#1F2933', 'icon_color' => '#1F2933',
		);
	}
	public function sanitize_settings( array $settings ): array {
		$layout = sanitize_key( $settings['layout'] ?? 'center' );
		return array(
			'logo_url' => $this->sanitize_http_url( $settings['logo_url'] ?? '' ),
			'title' => sanitize_text_field( $settings['title'] ?? '' ),
			'subtitle' => sanitize_text_field( $settings['subtitle'] ?? '' ),
			'layout' => in_array( $layout, array( 'center', 'start' ), true ) ? $layout : 'center',
			'height' => min( 120, max( 48, absint( $settings['height'] ?? 64 ) ) ),
			'logo_height' => min( 80, max( 20, absint( $settings['logo_height'] ?? 38 ) ) ),
			'show_search' => ! empty( $settings['show_search'] ),
			'show_cart' => ! empty( $settings['show_cart'] ),
			'show_account' => ! empty( $settings['show_account'] ),
			'title_color' => sanitize_hex_color( $settings['title_color'] ?? '' ) ?: '#1F2933',
			'icon_color' => sanitize_hex_color( $settings['icon_color'] ?? '' ) ?: '#1F2933',
		);
	}
	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings( wp_parse_args( $settings, $this->get_default_settings() ) );
		$settings['title'] = '' !== $settings['title'] ? $settings['title'] : get_bloginfo( 'name' );
		return $settings;
	}
	public function render_settings( int $index, array $settings ): void {
		unset( $index, $settings );
		echo '<p>' . esc_html__( 'Edit this header in Library Editor for complete content, action and responsive controls.', 'kidia-mobile-cms' ) . '</p>';
	}
}
