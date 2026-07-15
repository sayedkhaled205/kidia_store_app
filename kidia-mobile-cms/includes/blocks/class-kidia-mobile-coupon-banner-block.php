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

			'image_url' => $this->sanitize_http_url(
				$settings['image_url'] ?? ''
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

	/**
	 * Sanitizes an HTTP(S) URL for the mobile API contract.
	 *
	 * @param mixed $value Raw URL.
	 *
	 * @return string
	 */
	private function sanitize_http_url( $value ): string {
		$url = esc_url_raw(
			(string) $value,
			array( 'http', 'https' )
		);

		$scheme = strtolower(
			(string) wp_parse_url( $url, PHP_URL_SCHEME )
		);
		$host = (string) wp_parse_url( $url, PHP_URL_HOST );

		return '' !== $host
			&& in_array( $scheme, array( 'http', 'https' ), true )
			? $url
			: '';
	}
    }
