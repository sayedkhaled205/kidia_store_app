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
			'width' => '',
			'height' => '',
			'enable_transition' => false,
			'messages' => array(),
			'transition_effect' => 'fade',
			'change_every' => 4,
			'transition_duration' => 500,
			'background_color' => '#4f9f8f',
			'text_color' => '#ffffff',
			'action_type' => '',
			'action_value' => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		$messages = is_array( $settings['messages'] ?? null ) ? $settings['messages'] : array();
		$messages = array_values( array_filter( array_map( 'sanitize_text_field', $messages ), static fn( $message ) => '' !== $message ) );
		$effect = sanitize_key( (string) ( $settings['transition_effect'] ?? 'fade' ) );

		return array(

			'text' => sanitize_text_field(
				$settings['text'] ?? ''
			),
			'width' => '' === (string) ( $settings['width'] ?? '' ) ? '' : max( 10, min( 100, absint( $settings['width'] ) ) ),
			'height' => '' === (string) ( $settings['height'] ?? '' ) ? '' : max( 20, min( 240, absint( $settings['height'] ) ) ),
			'enable_transition' => ! empty( $settings['enable_transition'] ),
			'messages' => $messages,
			'transition_effect' => in_array( $effect, array( 'fade', 'slide_up', 'slide_left', 'scale' ), true ) ? $effect : 'fade',
			'change_every' => max( 1, min( 60, absint( $settings['change_every'] ?? 4 ) ) ),
			'transition_duration' => max( 100, min( 5000, absint( $settings['transition_duration'] ?? 500 ) ) ),

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
			$settings = $this->sanitize_settings( wp_parse_args( $settings, $this->get_default_settings() ) );
			$text = $settings['text'];

			if ( '' === $text && empty( $settings['messages'] ) ) {
				return null;
			}
			$api_text = '' !== $text ? $text : (string) $settings['messages'][0];

    		return array(
				'text' => $api_text,
				'width' => $settings['width'],
				'height' => $settings['height'],
				'enable_transition' => $settings['enable_transition'],
				'messages' => $settings['messages'],
				'transition_effect' => $settings['transition_effect'],
				'change_every' => $settings['change_every'],
				'transition_duration' => $settings['transition_duration'],

    			'background_color' => sanitize_hex_color(
				$settings['background_color']
    			),

    			'text_color' => sanitize_hex_color(
				$settings['text_color']
    			),

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

		$settings = $this->sanitize_settings( wp_parse_args(
			$settings,
			$this->get_default_settings()
		) );

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
	<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--width"><label><?php esc_html_e( 'Width (%)', 'kidia-mobile-cms' ); ?></label><input type="number" min="10" max="100" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][width]" value="<?php echo esc_attr( (string) $settings['width'] ); ?>" placeholder="100"></div>
	<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--height"><label><?php esc_html_e( 'Height', 'kidia-mobile-cms' ); ?></label><input type="number" min="20" max="240" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][height]" value="<?php echo esc_attr( (string) $settings['height'] ); ?>" placeholder="Auto"></div>
	<div class="kidia-builder-field kidia-promo-action-setting kidia-promo-action-setting--enable-transition"><label><?php esc_html_e( 'Rotating Messages', 'kidia-mobile-cms' ); ?></label><label class="kidia-page-master-toggle"><input class="kidia-promo-transition-toggle" type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][enable_transition]" value="1" <?php checked( true, $settings['enable_transition'] ); ?>><span class="kidia-toggle-state"></span></label></div>
	<div class="kidia-promo-transition-fields" <?php echo $settings['enable_transition'] ? '' : 'hidden'; ?>>
		<div class="kidia-promo-messages" data-next-index="<?php echo esc_attr( (string) count( $settings['messages'] ) ); ?>">
			<?php foreach ( $settings['messages'] as $message_index => $message ) : ?><div class="kidia-promo-message-row"><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][messages][<?php echo esc_attr( (string) $message_index ); ?>]" value="<?php echo esc_attr( $message ); ?>"><button type="button" class="button kidia-remove-promo-message"><?php esc_html_e( 'Remove', 'kidia-mobile-cms' ); ?></button></div><?php endforeach; ?>
		</div>
		<button type="button" class="button kidia-add-promo-message"><?php esc_html_e( 'Add Message', 'kidia-mobile-cms' ); ?></button>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Transition Effect', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][transition_effect]"><?php foreach ( array( 'fade' => 'Fade', 'slide_up' => 'Slide Up', 'slide_left' => 'Slide Left', 'scale' => 'Scale' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['transition_effect'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Change Every (seconds)', 'kidia-mobile-cms' ); ?></label><input type="number" min="1" max="60" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][change_every]" value="<?php echo esc_attr( (string) $settings['change_every'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Transition Duration (ms)', 'kidia-mobile-cms' ); ?></label><input type="number" min="100" max="5000" step="100" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][transition_duration]" value="<?php echo esc_attr( (string) $settings['transition_duration'] ); ?>"></div>
		</div>
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
