<?php
/** App Header Home Builder block. @package Kidia_Mobile_CMS */
defined( 'ABSPATH' ) || exit;

final class Kidia_Mobile_App_Header_Block extends Kidia_Mobile_Block {
	public function get_type(): string { return 'app_header'; }
	public function get_label(): string { return __( 'App Header', 'mobishop' ); }
	public function get_icon(): string { return 'dashicons-align-wide'; }
	public function get_description(): string { return __( 'Configurable PatPat-style home header.', 'mobishop' ); }
	public function get_default_settings(): array {
		return array(
			'logo_url' => '', 'title' => '', 'subtitle' => '', 'layout' => 'center',
			'height' => 64, 'logo_height' => 38, 'show_search' => true,
				'show_cart' => true, 'show_account' => false,
				'title_color' => '#1F2933', 'icon_color' => '#1F2933',
				'background_color' => '#FFFFFF', 'search_style' => 'icon',
				'search_placeholder' => __( 'Search products', 'mobishop' ),
				'search_background' => '#F1F3F4', 'search_text_color' => '#5F6368',
				'sticky' => true, 'shadow' => 'subtle', 'border_radius' => 0,
				'horizontal_padding' => 12, 'icon_size' => 24, 'icon_gap' => 4,
				'icon_background' => '#FFFFFF', 'icon_radius' => 12, 'show_wishlist' => false,
				'search_height' => 40, 'search_radius' => 14, 'search_border_width' => 0,
				'search_border_color' => '#DDE3E8', 'search_icon_color' => '#5F6368',
				'show_voice_search' => false, 'account_style' => 'icon',
				'show_account_label' => false, 'account_label' => __( 'Account', 'mobishop' ),
				'account_icon_size' => 24,
		);
	}
	public function sanitize_settings( array $settings ): array {
			$layout = sanitize_key( $settings['layout'] ?? 'center' );
			$search_style = sanitize_key( $settings['search_style'] ?? 'icon' );
		return array(
			'logo_url' => $this->sanitize_http_url( $settings['logo_url'] ?? '' ),
			'title' => sanitize_text_field( $settings['title'] ?? '' ),
			'subtitle' => sanitize_text_field( $settings['subtitle'] ?? '' ),
			'layout' => in_array( $layout, array( 'center', 'start', 'end' ), true ) ? $layout : 'center',
			'height' => min( 120, max( 48, absint( $settings['height'] ?? 64 ) ) ),
			'logo_height' => min( 80, max( 20, absint( $settings['logo_height'] ?? 38 ) ) ),
			'show_search' => ! empty( $settings['show_search'] ),
			'show_cart' => ! empty( $settings['show_cart'] ),
			'show_account' => ! empty( $settings['show_account'] ),
			'title_color' => sanitize_hex_color( $settings['title_color'] ?? '' ) ?: '#1F2933',
				'icon_color' => sanitize_hex_color( $settings['icon_color'] ?? '' ) ?: '#1F2933',
				'background_color' => sanitize_hex_color( $settings['background_color'] ?? '' ) ?: '#FFFFFF',
				'search_style' => in_array( $search_style, array( 'icon', 'bar' ), true ) ? $search_style : 'icon',
				'search_placeholder' => sanitize_text_field( $settings['search_placeholder'] ?? '' ),
				'search_background' => sanitize_hex_color( $settings['search_background'] ?? '' ) ?: '#F1F3F4',
				'search_text_color' => sanitize_hex_color( $settings['search_text_color'] ?? '' ) ?: '#5F6368',
				'sticky' => ! empty( $settings['sticky'] ),
				'shadow' => in_array( sanitize_key( $settings['shadow'] ?? '' ), array( 'none', 'subtle', 'strong' ), true ) ? sanitize_key( $settings['shadow'] ) : 'subtle',
				'border_radius' => min( 40, max( 0, absint( $settings['border_radius'] ?? 0 ) ) ),
				'horizontal_padding' => min( 32, max( 0, absint( $settings['horizontal_padding'] ?? 12 ) ) ),
				'icon_size' => min( 40, max( 16, absint( $settings['icon_size'] ?? 24 ) ) ),
				'icon_gap' => min( 24, max( 0, absint( $settings['icon_gap'] ?? 4 ) ) ),
				'icon_background' => sanitize_hex_color( $settings['icon_background'] ?? '' ) ?: '#FFFFFF',
				'icon_radius' => min( 30, max( 0, absint( $settings['icon_radius'] ?? 12 ) ) ),
				'show_wishlist' => ! empty( $settings['show_wishlist'] ),
				'search_height' => min( 64, max( 32, absint( $settings['search_height'] ?? 40 ) ) ),
				'search_radius' => min( 32, max( 0, absint( $settings['search_radius'] ?? 14 ) ) ),
				'search_border_width' => min( 6, max( 0, absint( $settings['search_border_width'] ?? 0 ) ) ),
				'search_border_color' => sanitize_hex_color( $settings['search_border_color'] ?? '' ) ?: '#DDE3E8',
				'search_icon_color' => sanitize_hex_color( $settings['search_icon_color'] ?? '' ) ?: '#5F6368',
				'show_voice_search' => ! empty( $settings['show_voice_search'] ),
				'account_style' => in_array( sanitize_key( $settings['account_style'] ?? '' ), array( 'icon', 'filled', 'avatar' ), true ) ? sanitize_key( $settings['account_style'] ) : 'icon',
				'show_account_label' => ! empty( $settings['show_account_label'] ),
				'account_label' => sanitize_text_field( $settings['account_label'] ?? '' ),
				'account_icon_size' => min( 40, max( 16, absint( $settings['account_icon_size'] ?? 24 ) ) ),
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
				<label><?php esc_html_e( 'Logo', 'mobishop' ); ?></label>
				<div class="kidia-builder-media-field">
					<input class="kidia-app-header-logo-url" type="url" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][logo_url]" value="<?php echo esc_attr( $settings['logo_url'] ); ?>">
					<button type="button" class="button kidia-select-app-header-logo"><?php esc_html_e( 'Choose logo', 'mobishop' ); ?></button>
				</div>
				<img class="kidia-media-preview kidia-app-header-logo-preview" src="<?php echo esc_url( $settings['logo_url'] ); ?>" alt="" <?php echo empty( $settings['logo_url'] ) ? 'hidden' : ''; ?>>
			</div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Title', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Subtitle', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Layout', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]"><option value="center" <?php selected( 'center', $settings['layout'] ); ?>><?php esc_html_e( 'Centered', 'mobishop' ); ?></option><option value="start" <?php selected( 'start', $settings['layout'] ); ?>><?php esc_html_e( 'Start aligned', 'mobishop' ); ?></option><option value="end" <?php selected( 'end', $settings['layout'] ); ?>><?php esc_html_e( 'End aligned', 'mobishop' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Header height', 'mobishop' ); ?></label><input type="number" min="48" max="120" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][height]" value="<?php echo esc_attr( (string) $settings['height'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Logo height', 'mobishop' ); ?></label><input type="number" min="20" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][logo_height]" value="<?php echo esc_attr( (string) $settings['logo_height'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Title color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title_color]" value="<?php echo esc_attr( $settings['title_color'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Icon color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon_color]" value="<?php echo esc_attr( $settings['icon_color'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Background color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][background_color]" value="<?php echo esc_attr( $settings['background_color'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search Style', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_style]"><option value="icon" <?php selected( 'icon', $settings['search_style'] ); ?>><?php esc_html_e( 'Icon', 'mobishop' ); ?></option><option value="bar" <?php selected( 'bar', $settings['search_style'] ); ?>><?php esc_html_e( 'Search Bar', 'mobishop' ); ?></option></select></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search Placeholder', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_placeholder]" value="<?php echo esc_attr( $settings['search_placeholder'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search Background', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_background]" value="<?php echo esc_attr( $settings['search_background'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search Text Color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_text_color]" value="<?php echo esc_attr( $settings['search_text_color'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Header shadow', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][shadow]"><?php foreach ( array( 'none' => __( 'None', 'mobishop' ), 'subtle' => __( 'Subtle', 'mobishop' ), 'strong' => __( 'Strong', 'mobishop' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['shadow'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Header corner radius', 'mobishop' ); ?></label><input type="number" min="0" max="40" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][border_radius]" value="<?php echo esc_attr( (string) $settings['border_radius'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Horizontal padding', 'mobishop' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][horizontal_padding]" value="<?php echo esc_attr( (string) $settings['horizontal_padding'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Action icon size', 'mobishop' ); ?></label><input type="number" min="16" max="40" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon_size]" value="<?php echo esc_attr( (string) $settings['icon_size'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Space between icons', 'mobishop' ); ?></label><input type="number" min="0" max="24" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon_gap]" value="<?php echo esc_attr( (string) $settings['icon_gap'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Icon background', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon_background]" value="<?php echo esc_attr( $settings['icon_background'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Icon background radius', 'mobishop' ); ?></label><input type="number" min="0" max="30" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon_radius]" value="<?php echo esc_attr( (string) $settings['icon_radius'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search height', 'mobishop' ); ?></label><input type="number" min="32" max="64" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_height]" value="<?php echo esc_attr( (string) $settings['search_height'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search corner radius', 'mobishop' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_radius]" value="<?php echo esc_attr( (string) $settings['search_radius'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search border width', 'mobishop' ); ?></label><input type="number" min="0" max="6" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_border_width]" value="<?php echo esc_attr( (string) $settings['search_border_width'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search border color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_border_color]" value="<?php echo esc_attr( $settings['search_border_color'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Search icon color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][search_icon_color]" value="<?php echo esc_attr( $settings['search_icon_color'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Account icon style', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][account_style]"><?php foreach ( array( 'icon' => __( 'Outline icon', 'mobishop' ), 'filled' => __( 'Filled icon', 'mobishop' ), 'avatar' => __( 'Avatar circle', 'mobishop' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['account_style'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Account label', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][account_label]" value="<?php echo esc_attr( $settings['account_label'] ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Account icon size', 'mobishop' ); ?></label><input type="number" min="16" max="40" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][account_icon_size]" value="<?php echo esc_attr( (string) $settings['account_icon_size'] ); ?>"></div>
			<?php foreach ( array( 'sticky' => __( 'Sticky header', 'mobishop' ), 'show_search' => __( 'Show search', 'mobishop' ), 'show_voice_search' => __( 'Show voice search', 'mobishop' ), 'show_cart' => __( 'Show cart', 'mobishop' ), 'show_wishlist' => __( 'Show wishlist', 'mobishop' ), 'show_account' => __( 'Show account', 'mobishop' ), 'show_account_label' => __( 'Show account label', 'mobishop' ) ) as $key => $label ) : ?>
				<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][<?php echo esc_attr( $key ); ?>]" value="1" <?php checked( true, $settings[ $key ] ); ?>> <?php echo esc_html( $label ); ?></label></div>
			<?php endforeach; ?>
		</div>
		<?php
	}
}
