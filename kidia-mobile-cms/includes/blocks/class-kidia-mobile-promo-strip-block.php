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
			'button_label' => '',
			'dismissible' => false,
			'border_radius' => 12,
			'padding' => 12,
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		$action_type = sanitize_key( (string) ( $settings['action_type'] ?? '' ) );

		if ( ! in_array( $action_type, array( '', 'product', 'category', 'collection', 'search', 'external' ), true ) ) {
			$action_type = '';
		}

		return array(

			'text' => sanitize_textarea_field(
				$settings['text'] ?? ''
			),

			'background_color' => sanitize_hex_color(
				$settings['background_color'] ?? '#4f9f8f'
			),

			'text_color' => sanitize_hex_color(
				$settings['text_color'] ?? '#ffffff'
			),

			'action_type' => $action_type,

			'action_value' => sanitize_text_field(
				$settings['action_value'] ?? ''
			),

			'button_label' => sanitize_text_field( (string) ( $settings['button_label'] ?? '' ) ),

			'dismissible' => ! empty( $settings['dismissible'] ),

			'border_radius' => max( 0, min( 40, absint( $settings['border_radius'] ?? 12 ) ) ),

			'padding' => max( 4, min( 32, absint( $settings['padding'] ?? 12 ) ) ),

		);
	}
		public function build_api_data(
    		array $settings
    	): ?array {

			$settings = $this->sanitize_settings(
				wp_parse_args( $settings, $this->get_default_settings() )
			);

			if ( '' === trim( $settings['text'] ) ) {
				return null;
			}

			return array(
				'text'             => $settings['text'],
				'background_color' => $settings['background_color'] ?: '#4f9f8f',
				'text_color'       => $settings['text_color'] ?: '#ffffff',
				'button_label'     => $settings['button_label'],
				'dismissible'      => $settings['dismissible'],
				'border_radius'    => $settings['border_radius'],
				'padding'          => $settings['padding'],

				'action' => $this->build_action(
					$settings['action_type'],
					$settings['action_value']
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

    	<div class="kidia-builder-field kidia-builder-field--full">

    		<label>Text</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][text]"
    			value="<?php echo esc_attr( $settings['text'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Background</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][background_color]"
    			value="<?php echo esc_attr( $settings['background_color'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Text Color</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][text_color]"
    			value="<?php echo esc_attr( $settings['text_color'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }
