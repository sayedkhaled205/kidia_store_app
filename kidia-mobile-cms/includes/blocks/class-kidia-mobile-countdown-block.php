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
			'expired_text' => '',
			'background_color' => '#FFFFFF',
			'text_color' => '#1F2933',
			'box_color' => '#E9EEEC',
			'action_type' => '',
			'action_value' => '',
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
				$settings['expired_text'] ?? ''
			),

			'background_color' => sanitize_hex_color( $settings['background_color'] ?? '' ) ?: '#FFFFFF',
			'text_color' => sanitize_hex_color( $settings['text_color'] ?? '' ) ?: '#1F2933',
			'box_color' => sanitize_hex_color( $settings['box_color'] ?? '' ) ?: '#E9EEEC',
			'action_type' => in_array( sanitize_key( $settings['action_type'] ?? '' ), array( '', 'product', 'category', 'collection', 'brand', 'brands', 'search', 'external' ), true ) ? sanitize_key( $settings['action_type'] ?? '' ) : '',
			'action_value' => sanitize_text_field( $settings['action_value'] ?? '' ),

		);
	}
		public function build_api_data(
    		array $settings
    	): ?array {

		$settings = $this->sanitize_settings(
    			wp_parse_args(
    				$settings,
    				$this->get_default_settings()
    			)
			);
		$settings['action'] = $this->build_action( $settings['action_type'], $settings['action_value'] );
		unset( $settings['action_type'], $settings['action_value'] );
		return $settings;
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
		<div class="kidia-builder-field"><label>Background Color</label><input type="color" name="blocks[<?php echo esc_attr( $index ); ?>][settings][background_color]" value="<?php echo esc_attr( $settings['background_color'] ); ?>"></div>
		<div class="kidia-builder-field"><label>Text Color</label><input type="color" name="blocks[<?php echo esc_attr( $index ); ?>][settings][text_color]" value="<?php echo esc_attr( $settings['text_color'] ); ?>"></div>
		<div class="kidia-builder-field"><label>Timer Box Color</label><input type="color" name="blocks[<?php echo esc_attr( $index ); ?>][settings][box_color]" value="<?php echo esc_attr( $settings['box_color'] ); ?>"></div>
		<div class="kidia-builder-field"><label>Action Type</label><select name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_type]"><?php foreach ( array( '' => 'No Action', 'product' => 'Product', 'category' => 'Category', 'collection' => 'Collection', 'brand' => 'Brand', 'brands' => 'All Brands', 'search' => 'Search', 'external' => 'External URL' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
		<div class="kidia-builder-field"><label>Action Value</label><input type="text" name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_value]" value="<?php echo esc_attr( $settings['action_value'] ); ?>"></div>

    </div>

    <?php
    	}
    }
