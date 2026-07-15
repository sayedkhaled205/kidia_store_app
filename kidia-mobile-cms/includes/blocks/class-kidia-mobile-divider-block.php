<?php
/**
 * Divider Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Divider_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Divider_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'divider';
	}

	public function get_label(): string {
		return __( 'Divider', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-minus';
	}

	public function get_description(): string {
		return __( 'Visual divider.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'color' => '#e5e7eb',
			'thickness' => 1,
			'margin' => 16,
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(

			'color' => sanitize_hex_color(
				$settings['color'] ?? '#e5e7eb'
			),

			'thickness' => max(
				1,
				min(
					10,
					absint(
						$settings['thickness'] ?? 1
					)
				)
			),

			'margin' => max(
				0,
				min(
					100,
					absint(
						$settings['margin'] ?? 16
					)
				)
			),

		);
	}
		public function build_api_data(
    		array $settings
    	): ?array {

    		return $this->sanitize_settings(
    			wp_parse_args(
    				$settings,
    				$this->get_default_settings()
    			)
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

    	<div class="kidia-builder-field">

    		<label>Color</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][color]"
    			value="<?php echo esc_attr( $settings['color'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Thickness</label>

    		<input
    			type="number"
    			min="1"
    			max="10"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][thickness]"
    			value="<?php echo esc_attr( $settings['thickness'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Margin</label>

    		<input
    			type="number"
    			min="0"
    			max="100"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][margin]"
    			value="<?php echo esc_attr( $settings['margin'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }