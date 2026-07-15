<?php
/**
 * Countdown Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Countdown_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Countdown_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'countdown';
	}

	public function get_label(): string {
		return __( 'Countdown', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-clock';
	}

	public function get_description(): string {
		return __( 'Offer countdown timer.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title' => '',
			'ends_at' => '',
			'expired_text' => __( 'Offer ended', 'kidia-mobile-cms' ),
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(

			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'ends_at' => sanitize_text_field(
				$settings['ends_at'] ?? ''
			),

			'expired_text' => sanitize_text_field(
				$settings['expired_text'] ?? __( 'Offer ended', 'kidia-mobile-cms' )
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

    		<label>Title</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][title]"
    			value="<?php echo esc_attr( $settings['title'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Ends At</label>

    		<input
    			type="datetime-local"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][ends_at]"
    			value="<?php echo esc_attr( $settings['ends_at'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Expired Text</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][expired_text]"
    			value="<?php echo esc_attr( $settings['expired_text'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }
