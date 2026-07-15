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
			'background_color' => '#4f9f8f',
			'text_color' => '#ffffff',
			'action_type' => '',
			'action_value' => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {
		$allowed_actions = array(
			'',
			'product',
			'category',
			'collection',
			'brand',
			'brands',
			'search',
			'external',
		);

		$action_type = sanitize_key(
			(string) ( $settings['action_type'] ?? '' )
		);

		if ( ! in_array( $action_type, $allowed_actions, true ) ) {
			$action_type = '';
		}

		$action_value = 'external' === $action_type
			? $this->sanitize_http_url( $settings['action_value'] ?? '' )
			: sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) );

		return array(
			'text'             => sanitize_text_field( (string) ( $settings['text'] ?? '' ) ),
			'background_color' => sanitize_hex_color( (string) ( $settings['background_color'] ?? '' ) )
				?: '#4f9f8f',
			'text_color'       => sanitize_hex_color( (string) ( $settings['text_color'] ?? '' ) )
				?: '#ffffff',
			'action_type'      => $action_type,
			'action_value'     => $action_value,
		);
	}

	public function build_api_data(
		array $settings
	): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		if ( '' === $settings['text'] ) {
			return null;
		}

		return array(
			'text'             => $settings['text'],
			'background_color' => $settings['background_color'],
			'text_color'       => $settings['text_color'],
			'action'           => $this->build_action(
				$settings['action_type'],
				$settings['action_value']
			),
		);
	}

    	public function render_settings(
    		int $index,
    		array $settings
    	): void {

	    	$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

    ?>

    <div class="kidia-builder-grid">

    	<div class="kidia-builder-field kidia-builder-field--full">

    		<label>Text</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][text]"
    			value="<?php echo esc_attr( $settings['text'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Background</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][background_color]"
    			value="<?php echo esc_attr( $settings['background_color'] ); ?>"
    		>

    	</div>

		<div class="kidia-builder-field">

			<label><?php esc_html_e( 'Action Type', 'kidia-mobile-cms' ); ?></label>

			<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
				<?php
				$action_types = array(
					''           => __( 'No Action', 'kidia-mobile-cms' ),
					'product'    => __( 'Product', 'kidia-mobile-cms' ),
					'category'   => __( 'Category', 'kidia-mobile-cms' ),
					'collection' => __( 'Collection', 'kidia-mobile-cms' ),
					'brand'      => __( 'Brand', 'kidia-mobile-cms' ),
					'brands'     => __( 'All Brands', 'kidia-mobile-cms' ),
					'search'     => __( 'Search', 'kidia-mobile-cms' ),
					'external'   => __( 'External URL', 'kidia-mobile-cms' ),
				);
				?>
				<?php foreach ( $action_types as $value => $label ) : ?>
					<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option>
				<?php endforeach; ?>
			</select>

		</div>

		<div class="kidia-builder-field kidia-builder-field--full">

			<label><?php esc_html_e( 'Action Value', 'kidia-mobile-cms' ); ?></label>

			<input
				type="text"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]"
				value="<?php echo esc_attr( $settings['action_value'] ); ?>"
			>

		</div>

    	<div class="kidia-builder-field">

    		<label>Text Color</label>

    		<input
    			type="color"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][text_color]"
    			value="<?php echo esc_attr( $settings['text_color'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}

	/**
	 * Sanitizes a URL that must be consumable by the mobile client.
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
