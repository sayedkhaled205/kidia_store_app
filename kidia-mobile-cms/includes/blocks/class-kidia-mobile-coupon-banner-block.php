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
			'copy_button_label' => 'Copy code',
			'expires_at' => '',
			'background_color' => '#f3f4f6',
			'text_color' => '#111827',
			'button_label' => '',
			'action_type' => '',
			'action_value' => '',
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

			'copy_button_label' => sanitize_text_field( (string) ( $settings['copy_button_label'] ?? 'Copy code' ) ),
			'expires_at' => sanitize_text_field( (string) ( $settings['expires_at'] ?? '' ) ),
			'background_color' => sanitize_hex_color( (string) ( $settings['background_color'] ?? '#f3f4f6' ) ) ?: '#f3f4f6',
			'text_color' => sanitize_hex_color( (string) ( $settings['text_color'] ?? '#111827' ) ) ?: '#111827',
			'button_label' => sanitize_text_field( (string) ( $settings['button_label'] ?? '' ) ),
			'action_type' => $action_type,
			'action_value' => sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) ),

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

			if ( '' === $settings['title'] && '' === $settings['coupon_code'] && '' === $settings['image_url'] ) {
				return null;
			}

			$expires_at = '';
			if ( '' !== trim( $settings['expires_at'] ) ) {
				try {
					$expires_at = ( new DateTimeImmutable( $settings['expires_at'], wp_timezone() ) )
						->setTimezone( new DateTimeZone( 'UTC' ) )
						->format( DATE_ATOM );
				} catch ( Exception $exception ) {
					unset( $exception );
				}
			}

			return array(
				'title'             => $settings['title'],
				'description'       => $settings['description'],
				'coupon_code'       => $settings['coupon_code'],
				'image_url'         => $settings['image_url'],
				'copy_button_label' => $settings['copy_button_label'],
				'expires_at'        => $expires_at,
				'background_color'  => $settings['background_color'],
				'text_color'        => $settings['text_color'],
				'button_label'      => $settings['button_label'],
				'action'            => $this->build_action( $settings['action_type'], $settings['action_value'] ),
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

    	<div class="kidia-builder-field">

    		<label>Image URL</label>

    		<input
    			type="url"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][image_url]"
    			value="<?php echo esc_attr( $settings['image_url'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }
