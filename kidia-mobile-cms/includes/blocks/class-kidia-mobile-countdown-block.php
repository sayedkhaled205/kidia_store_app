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
			// An empty default lets existing saved layouts migrate from the four
			// legacy show_* flags the first time they are normalized.
			'visible_units' => '',
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
		$visible_units = sanitize_key( (string) ( $settings['visible_units'] ?? '' ) );
		$allowed_visible_units = array( 'days', 'days_hours', 'days_hours_minutes', 'days_hours_minutes_seconds' );
		if ( ! in_array( $visible_units, $allowed_visible_units, true ) ) {
			if ( ! empty( $settings['show_seconds'] ) ) {
				$visible_units = 'days_hours_minutes_seconds';
			} elseif ( ! empty( $settings['show_minutes'] ) ) {
				$visible_units = 'days_hours_minutes';
			} elseif ( ! empty( $settings['show_hours'] ) ) {
				$visible_units = 'days_hours';
			} else {
				$visible_units = 'days';
			}
		}
		$visible_unit_flags = array(
			'show_days' => true,
			'show_hours' => in_array( $visible_units, array( 'days_hours', 'days_hours_minutes', 'days_hours_minutes_seconds' ), true ),
			'show_minutes' => in_array( $visible_units, array( 'days_hours_minutes', 'days_hours_minutes_seconds' ), true ),
			'show_seconds' => 'days_hours_minutes_seconds' === $visible_units,
		);
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
			'visible_units' => $visible_units,
			// Keep the established API flags so older installed app versions
			// continue to render the new cumulative selection correctly.
			'show_days' => $visible_unit_flags['show_days'],
			'show_hours' => $visible_unit_flags['show_hours'],
			'show_minutes' => $visible_unit_flags['show_minutes'],
			'show_seconds' => $visible_unit_flags['show_seconds'],
			'layout_style' => in_array( $layout_style, array( 'cards', 'circles', 'flip_clock', 'minimal_inline', 'split_labels' ), true ) ? $layout_style : 'cards',
			'action_type' => in_array( sanitize_key( $settings['action_type'] ?? '' ), array( '', 'product', 'category', 'collection', 'brand', 'brands', 'search', 'external' ), true ) ? sanitize_key( $settings['action_type'] ?? '' ) : '',
			'action_value' => sanitize_text_field( $settings['action_value'] ?? '' ),

		);
	}
		public function build_api_data(
    		array $settings
    	): ?array {

		$settings = $this->sanitize_settings( $settings );
		$settings['action'] = $this->build_action( $settings['action_type'], $settings['action_value'] );
		unset( $settings['action_type'], $settings['action_value'] );
		return $settings;
    	}

    	public function render_settings(
    		int $index,
    		array $settings
    	): void {

		$settings = $this->sanitize_settings( $settings );

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
		<div class="kidia-builder-field kidia-countdown-setting kidia-countdown-setting--layout"><label><?php esc_html_e( 'Layout Style', 'kidia-mobile-cms' ); ?></label><select class="kidia-countdown-layout" name="blocks[<?php echo esc_attr( $index ); ?>][settings][layout_style]"><?php foreach ( array( 'cards' => 'Cards', 'circles' => 'Circles', 'flip_clock' => 'Flip Clock', 'minimal_inline' => 'Minimal Inline', 'split_labels' => 'Split Labels' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['layout_style'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select><span class="kidia-countdown-layout-preview is-<?php echo esc_attr( $settings['layout_style'] ); ?>" aria-hidden="true"><i data-countdown-unit="days">08<small>D</small></i><i data-countdown-unit="hours" <?php echo $settings['show_hours'] ? '' : 'hidden'; ?>>12<small>H</small></i><i data-countdown-unit="minutes" <?php echo $settings['show_minutes'] ? '' : 'hidden'; ?>>24<small>M</small></i><i data-countdown-unit="seconds" <?php echo $settings['show_seconds'] ? '' : 'hidden'; ?>>36<small>S</small></i></span></div>
		<div class="kidia-builder-field kidia-countdown-setting kidia-countdown-setting--visible-units">
			<label><?php esc_html_e( 'Visible time units', 'kidia-mobile-cms' ); ?></label>
			<select class="kidia-countdown-visible-units" name="blocks[<?php echo esc_attr( $index ); ?>][settings][visible_units]">
				<?php foreach ( array(
					'days' => __( 'Days only', 'kidia-mobile-cms' ),
					'days_hours' => __( 'Days + Hours', 'kidia-mobile-cms' ),
					'days_hours_minutes' => __( 'Days + Hours + Minutes', 'kidia-mobile-cms' ),
					'days_hours_minutes_seconds' => __( 'Days + Hours + Minutes + Seconds', 'kidia-mobile-cms' ),
				) as $value => $label ) : ?>
					<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['visible_units'] ); ?>><?php echo esc_html( $label ); ?></option>
				<?php endforeach; ?>
			</select>
		</div>
		<div class="kidia-countdown-actions">
			<div class="kidia-builder-field"><label>Action Type</label><select name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_type]"><?php foreach ( array( '' => 'No Action', 'product' => 'Product', 'category' => 'Category', 'collection' => 'Collection', 'brand' => 'Brand', 'brands' => 'All Brands', 'search' => 'Search', 'external' => 'External URL' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="kidia-builder-field"><label>Action Value</label><input type="text" name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_value]" value="<?php echo esc_attr( $settings['action_value'] ); ?>"></div>
		</div>

    </div>

    <?php
    	}
    }
