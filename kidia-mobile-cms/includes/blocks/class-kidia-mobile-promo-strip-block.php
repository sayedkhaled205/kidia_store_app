<?php
/**
 * Promo Strip Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Promo_Strip_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Promo_Strip_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'promo_strip';
	}

	public function get_label(): string {
		return __( 'Promo Strip', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-megaphone';
	}

	public function get_description(): string {
		return __( 'Small promotional strip.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'text' => '',
			'background_color' => '#4f9f8f',
			'text_color' => '#ffffff',
			'action_type' => '',
			'action_value' => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(

			'text' => sanitize_text_field(
				$settings['text'] ?? ''
			),

			'background_color' => sanitize_hex_color(
				$settings['background_color'] ?? '#4f9f8f'
			),

			'text_color' => sanitize_hex_color(
				$settings['text_color'] ?? '#ffffff'
			),

			'action_type' => sanitize_key(
				$settings['action_type'] ?? ''
			),

			'action_value' => sanitize_text_field(
				$settings['action_value'] ?? ''
			),

		);
	}
		public function build_api_data(
    		array $settings
    	): ?array {
			$text = sanitize_text_field(
				$settings['text'] ?? ''
			);

			if ( '' === $text ) {
				return null;
			}

    		return array(
				'text' => $text,

    			'background_color' => sanitize_hex_color(
    				$settings['background_color'] ?? '#4f9f8f'
    			),

    			'text_color' => sanitize_hex_color(
    				$settings['text_color'] ?? '#ffffff'
    			),

    			'action' => $this->build_action(
    				$settings['action_type'] ?? '',
    				$settings['action_value'] ?? ''
    			),
    		);
    	}

    	public function render_settings(
    		int $index,
    		array $settings
    	): void {

    		$settings = wp_parse_args(
    			$settings,
    			$this->get_default_settings()
    		);

    ?>

    <div class="kidia-builder-grid">

	<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--text">

    		<label>Text</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][text]"
    			value="<?php echo esc_attr( $settings['text'] ); ?>"
    		>

    	</div>

	<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--background">

    		<label>Background</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][background_color]"
    			value="<?php echo esc_attr( $settings['background_color'] ); ?>"
    		>

    	</div>

	<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--text-color">

    		<label>Text Color</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][text_color]"
    			value="<?php echo esc_attr( $settings['text_color'] ); ?>"
    		>

    	</div>

		<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--action-type">
			<label><?php esc_html_e( 'Action Type', 'kidia-mobile-cms' ); ?></label>
			<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
				<option value="" <?php selected( '', $settings['action_type'] ); ?>><?php esc_html_e( 'No Action', 'kidia-mobile-cms' ); ?></option>
				<option value="product" <?php selected( 'product', $settings['action_type'] ); ?>><?php esc_html_e( 'Product', 'kidia-mobile-cms' ); ?></option>
				<option value="category" <?php selected( 'category', $settings['action_type'] ); ?>><?php esc_html_e( 'Category', 'kidia-mobile-cms' ); ?></option>
				<option value="collection" <?php selected( 'collection', $settings['action_type'] ); ?>><?php esc_html_e( 'Collection', 'kidia-mobile-cms' ); ?></option>
				<option value="search" <?php selected( 'search', $settings['action_type'] ); ?>><?php esc_html_e( 'Search', 'kidia-mobile-cms' ); ?></option>
				<option value="external" <?php selected( 'external', $settings['action_type'] ); ?>><?php esc_html_e( 'External URL', 'kidia-mobile-cms' ); ?></option>
			</select>
		</div>

		<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--action-value">
			<label><?php esc_html_e( 'Action Value', 'kidia-mobile-cms' ); ?></label>
			<input
				type="text"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]"
				value="<?php echo esc_attr( $settings['action_value'] ); ?>"
			>
		</div>

    </div>

    <?php
    	}
    }
