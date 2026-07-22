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
			'show_days' => true,
			'show_hours' => true,
			'show_minutes' => true,
			'show_seconds' => true,
			'layout_style' => 'cards',
			'action_type' => '',
			'action_value' => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		$layout_style = sanitize_key( (string) ( $settings['layout_style'] ?? 'cards' ) );
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
			'show_days' => ! empty( $settings['show_days'] ),
			'show_hours' => ! empty( $settings['show_hours'] ),
			'show_minutes' => ! empty( $settings['show_minutes'] ),
			'show_seconds' => ! empty( $settings['show_seconds'] ),
			'layout_style' => in_array( $layout_style, array( 'cards', 'circles', 'flip_clock', 'minimal_inline', 'split_labels' ), true ) ? $layout_style : 'cards',
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

		$settings = $this->sanitize_settings( wp_parse_args(
			$settings,
			$this->get_default_settings()
		) );

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
		<div class="kidia-builder-field kidia-countdown-setting kidia-countdown-setting--layout"><label><?php esc_html_e( 'Layout Style', 'kidia-mobile-cms' ); ?></label><select class="kidia-countdown-layout" name="blocks[<?php echo esc_attr( $index ); ?>][settings][layout_style]"><?php foreach ( array( 'cards' => 'Cards', 'circles' => 'Circles', 'flip_clock' => 'Flip Clock', 'minimal_inline' => 'Minimal Inline', 'split_labels' => 'Split Labels' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['layout_style'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select><span class="kidia-countdown-layout-preview is-<?php echo esc_attr( $settings['layout_style'] ); ?>" aria-hidden="true"><i>08<small>D</small></i><i>12<small>H</small></i><i>24<small>M</small></i><i>36<small>S</small></i></span></div>
		<?php foreach ( array( 'days' => 'Show Days', 'hours' => 'Show Hours', 'minutes' => 'Show Minutes', 'seconds' => 'Show Seconds' ) as $unit => $label ) : ?><div class="kidia-builder-field kidia-countdown-setting kidia-countdown-setting--show-<?php echo esc_attr( $unit ); ?>"><label><?php echo esc_html( $label ); ?></label><label class="kidia-page-master-toggle"><input type="checkbox" name="blocks[<?php echo esc_attr( $index ); ?>][settings][show_<?php echo esc_attr( $unit ); ?>]" value="1" <?php checked( true, $settings[ 'show_' . $unit ] ); ?>><span class="kidia-toggle-state"></span></label></div><?php endforeach; ?>
		<div class="kidia-builder-field"><label>Action Type</label><select name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_type]"><?php foreach ( array( '' => 'No Action', 'product' => 'Product', 'category' => 'Category', 'collection' => 'Collection', 'brand' => 'Brand', 'brands' => 'All Brands', 'search' => 'Search', 'external' => 'External URL' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
		<div class="kidia-builder-field"><label>Action Value</label><input type="text" name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_value]" value="<?php echo esc_attr( $settings['action_value'] ); ?>"></div>

    </div>

    <?php
    	}
    }
