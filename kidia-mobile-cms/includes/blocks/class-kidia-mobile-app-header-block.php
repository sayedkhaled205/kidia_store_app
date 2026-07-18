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
		$settings = $this->sanitize_settings( wp_parse_args( $settings, $this->get_default_settings() ) );
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-builder-field--full kidia-builder-field--media">
				<label><?php esc_html_e( 'Logo', 'kidia-mobile-cms' ); ?></label>
				<div class="kidia-builder-media-field">
					<input class="kidia-app-header-logo-url" type="url" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][logo_url]" value="<?php echo esc_attr( $settings['logo_url'] ); ?>">
					<button type="button" class="button kidia-select-app-header-logo"><?php esc_html_e( 'Choose logo', 'kidia-mobile-cms' ); ?></button>
				</div>
			</div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]"><option value="center" <?php selected( 'center', $settings['layout'] ); ?>><?php esc_html_e( 'Centered', 'kidia-mobile-cms' ); ?></option><option value="start" <?php selected( 'start', $settings['layout'] ); ?>><?php esc_html_e( 'Start aligned', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Header height', 'kidia-mobile-cms' ); ?></label><input type="number" min="48" max="120" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][height]" value="<?php echo esc_attr( (string) $settings['height'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Logo height', 'kidia-mobile-cms' ); ?></label><input type="number" min="20" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][logo_height]" value="<?php echo esc_attr( (string) $settings['logo_height'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Title color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title_color]" value="<?php echo esc_attr( $settings['title_color'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Icon color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon_color]" value="<?php echo esc_attr( $settings['icon_color'] ); ?>"></div>
			<?php foreach ( array( 'show_search' => __( 'Show search', 'kidia-mobile-cms' ), 'show_cart' => __( 'Show cart', 'kidia-mobile-cms' ), 'show_account' => __( 'Show account', 'kidia-mobile-cms' ) ) as $key => $label ) : ?>
				<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][<?php echo esc_attr( $key ); ?>]" value="1" <?php checked( true, $settings[ $key ] ); ?>> <?php echo esc_html( $label ); ?></label></div>
			<?php endforeach; ?>
		</div>
		<?php
	}
}
