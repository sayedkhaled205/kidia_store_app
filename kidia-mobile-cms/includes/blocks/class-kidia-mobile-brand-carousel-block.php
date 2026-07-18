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
			'limit'       => 12,
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

			$id       = absint( $item['id'] ?? 0 );
			$name     = sanitize_text_field( $item['name'] ?? '' );
			$logo_url = $this->sanitize_http_url( $item['logo_url'] ?? '' );

			if ( 0 === $id || '' === $name || '' === $logo_url ) {
				continue;
			}

			$brands[] = array(

				'id' => $id,

				'name' => $name,

				'logo_url' => $logo_url,

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

			'limit' => max(
				1,
				min(
					50,
					absint( $settings['limit'] ?? 12 )
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

			$items = $settings['items'];

			if ( empty( $items ) ) {
				$items = $this->query_brand_items( $settings['limit'] );
			}

			$api_items = array();

			foreach ( $items as $item ) {
				$action = $this->build_action(
					$item['action_type'] ?? 'brand',
					$item['action_value'] ?? (string) $item['id']
				);

				$api_items[] = array(
					'id'       => (int) $item['id'],
					'name'     => (string) $item['name'],
					'logo_url' => (string) $item['logo_url'],
					'action'   => $action ?? $this->build_action( 'brand', (string) $item['id'] ),
				);
			}

			return array(
				'title'      => $settings['title'],
				'subtitle'   => $settings['subtitle'],
				'item_width' => $settings['item_width'],
				'items'      => $api_items,
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

			<label>Brands Limit</label>

			<input
				type="number"
				min="1"
				max="50"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]"
				value="<?php echo esc_attr( (string) ( $settings['limit'] ?? 12 ) ); ?>"
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

	/** Uses whichever supported WooCommerce brand taxonomy is active. */
	private function query_brand_items( int $limit ): array {
		$taxonomy = '';

		foreach ( array( 'product_brand', 'pwb-brand', 'yith_product_brand' ) as $candidate ) {
			if ( taxonomy_exists( $candidate ) ) {
				$taxonomy = $candidate;
				break;
			}
		}

		if ( '' === $taxonomy ) {
			return array();
		}

		$terms = get_terms(
			array(
				'taxonomy'   => $taxonomy,
				'hide_empty' => false,
				'number'     => max( 1, min( 50, $limit ) ),
				'orderby'    => 'name',
				'order'      => 'ASC',
			)
		);

		if ( is_wp_error( $terms ) || ! is_array( $terms ) ) {
			return array();
		}

		$items = array();

		foreach ( $terms as $term ) {
			if ( ! $term instanceof WP_Term ) {
				continue;
			}

			$logo_url = $this->get_brand_logo_url( (int) $term->term_id );

			if ( '' === $logo_url ) {
				continue;
			}

			$items[] = array(
				'id'           => (int) $term->term_id,
				'name'         => sanitize_text_field( (string) $term->name ),
				'logo_url'     => $logo_url,
				'action_type'  => 'brand',
				'action_value' => (string) $term->term_id,
			);
		}

		return $items;
	}

	/** Resolves common brand-logo metadata used by supported brand plugins. */
	private function get_brand_logo_url( int $term_id ): string {
		foreach ( array( 'thumbnail_id', 'pwb_brand_image', 'brand_image_id' ) as $key ) {
			$attachment_id = absint( get_term_meta( $term_id, $key, true ) );

			if ( 0 === $attachment_id ) {
				continue;
			}

			$url = wp_get_attachment_image_url(
				$attachment_id,
				'woocommerce_thumbnail'
			);
			$url = $this->sanitize_http_url( $url );

			if ( '' !== $url ) {
				return $url;
			}
		}

		return '';
	}
}
