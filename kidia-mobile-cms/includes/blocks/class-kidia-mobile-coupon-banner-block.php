<?php
/**
 * Coupon Banner Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Coupon_Banner_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Coupon_Banner_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'coupon_banner';
	}

	public function get_label(): string {
		return __( 'Coupon Banner', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-tickets-alt';
	}

	public function get_description(): string {
		return __( 'Coupon promotion banner.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title' => '',
			'description' => '',
			'coupon_code' => '',
			'image_url' => '',
			'background_color' => '#DCEEE8',
			'text_color' => '#1F2933',
			'accent_color' => '#2F806E',
			'border_radius' => 20,
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

			'description' => sanitize_textarea_field(
				$settings['description'] ?? ''
			),

			'coupon_code' => sanitize_text_field(
				$settings['coupon_code'] ?? ''
			),

			'image_url' => esc_url_raw(
				$settings['image_url'] ?? ''
			),

			'background_color' => sanitize_hex_color( $settings['background_color'] ?? '' ) ?: '#DCEEE8',
			'text_color' => sanitize_hex_color( $settings['text_color'] ?? '' ) ?: '#1F2933',
			'accent_color' => sanitize_hex_color( $settings['accent_color'] ?? '' ) ?: '#2F806E',
			'border_radius' => max( 0, min( 48, absint( $settings['border_radius'] ?? 20 ) ) ),
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

    	<div class="kidia-builder-field kidia-builder-field--full">

    		<label>Description</label>

    		<textarea
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][description]"
    		><?php echo esc_textarea( $settings['description'] ); ?></textarea>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Coupon Code</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][coupon_code]"
    			value="<?php echo esc_attr( $settings['coupon_code'] ); ?>"
    		>

    	</div>

	<div class="kidia-builder-field kidia-builder-field--full kidia-builder-field--media">

		<label>Image URL</label>

		<div class="kidia-builder-media-field">

			<input
				type="url"
				class="kidia-media-url"
				name="blocks[<?php echo esc_attr( $index ); ?>][settings][image_url]"
				value="<?php echo esc_attr( $settings['image_url'] ); ?>"
			>

			<button type="button" class="button kidia-select-media">
				<?php esc_html_e( 'Select Image', 'kidia-mobile-cms' ); ?>
			</button>

		</div>

		<img
			class="kidia-media-preview"
			src="<?php echo esc_url( $settings['image_url'] ); ?>"
			alt=""
			<?php echo empty( $settings['image_url'] ) ? 'hidden' : ''; ?>
		>

	</div>

	<div class="kidia-builder-field"><label>Background Color</label><input type="color" name="blocks[<?php echo esc_attr( $index ); ?>][settings][background_color]" value="<?php echo esc_attr( $settings['background_color'] ); ?>"></div>
	<div class="kidia-builder-field"><label>Text Color</label><input type="color" name="blocks[<?php echo esc_attr( $index ); ?>][settings][text_color]" value="<?php echo esc_attr( $settings['text_color'] ); ?>"></div>
	<div class="kidia-builder-field"><label>Accent Color</label><input type="color" name="blocks[<?php echo esc_attr( $index ); ?>][settings][accent_color]" value="<?php echo esc_attr( $settings['accent_color'] ); ?>"></div>
	<div class="kidia-builder-field"><label>Border Radius</label><input type="number" min="0" max="48" name="blocks[<?php echo esc_attr( $index ); ?>][settings][border_radius]" value="<?php echo esc_attr( (string) $settings['border_radius'] ); ?>"></div>
	<div class="kidia-builder-field"><label>Action Type</label><select name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_type]"><?php foreach ( array( '' => 'No Action', 'product' => 'Product', 'category' => 'Category', 'collection' => 'Collection', 'brand' => 'Brand', 'brands' => 'All Brands', 'search' => 'Search', 'external' => 'External URL' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
	<div class="kidia-builder-field"><label>Action Value</label><input type="text" name="blocks[<?php echo esc_attr( $index ); ?>][settings][action_value]" value="<?php echo esc_attr( $settings['action_value'] ); ?>"></div>

    </div>

    <?php
    	}
    }
