<?php
/**
 * Brand Carousel Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Brand_Carousel_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Brand_Carousel_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'brand_carousel';
	}

	public function get_label(): string {
		return __( 'Brand Carousel', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-tag';
	}

	public function get_description(): string {
		return __(
			'WooCommerce Brands Carousel.',
			'kidia-mobile-cms'
		);
	}

	public function get_default_settings(): array {
		return array(
			'title'       => '',
			'subtitle'    => '',
			'item_width'  => 92,
			'items'       => array(),
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		$items = isset( $settings['items'] )
			&& is_array( $settings['items'] )
			? $settings['items']
			: array();

		$brands = array();

		foreach ( $items as $item ) {

			if ( ! is_array( $item ) ) {
				continue;
			}

			$brands[] = array(

				'id' => absint(
					$item['id'] ?? 0
				),

				'name' => sanitize_text_field(
					$item['name'] ?? ''
				),

				'logo_url' => esc_url_raw(
					$item['logo_url'] ?? ''
				),

				'action_type' => sanitize_key(
					$item['action_type'] ?? ''
				),

				'action_value' => sanitize_text_field(
					$item['action_value'] ?? ''
				),

			);

		}

		return array(

			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'subtitle' => sanitize_textarea_field(
				$settings['subtitle'] ?? ''
			),

			'item_width' => max(
				60,
				min(
					180,
					absint(
						$settings['item_width'] ?? 92
					)
				)
			),

			'items' => $brands,

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

    		return array(
    			'title'      => $settings['title'],
    			'subtitle'   => $settings['subtitle'],
    			'item_width' => $settings['item_width'],
    			'items'      => $settings['items'],
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

    		<label>Subtitle</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][subtitle]"
    			value="<?php echo esc_attr( $settings['subtitle'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Item Width</label>

    		<input
    			type="number"
    			min="60"
    			max="180"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][item_width]"
    			value="<?php echo esc_attr( $settings['item_width'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }