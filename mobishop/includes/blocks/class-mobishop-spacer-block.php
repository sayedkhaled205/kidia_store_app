<?php
/**
 * Spacer Home Builder block.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'MobiShop_Spacer_Block', false ) ) {
	return;
}

final class MobiShop_Spacer_Block extends MobiShop_Block {

	public function get_type(): string {
		return 'spacer';
	}

	public function get_label(): string {
		return __( 'Spacer', 'mobishop' );
	}

	public function get_icon(): string {
		return 'dashicons-editor-expand';
	}

	public function get_description(): string {
		return __( 'Vertical spacing between blocks.', 'mobishop' );
	}

	public function get_default_settings(): array {
		return array(
			'height' => 24,
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(
			'height' => max(
				0,
				min(
					200,
					absint(
						$settings['height'] ?? 24
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

    <div class="mobishop-builder-grid">

    	<div class="mobishop-builder-field">

    		<label>Height</label>

    		<input
    			type="number"
    			min="0"
    			max="200"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][height]"
    			value="<?php echo esc_attr( $settings['height'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }
