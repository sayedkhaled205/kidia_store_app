<?php
/**
 * Brand Carousel block.
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
		return __( 'WooCommerce brands in a horizontal carousel.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title'      => '',
			'source'     => 'all',
			'brand_ids'  => '',
			'limit'      => 20,
			'item_width' => 92,
		);
	}

	public function sanitize_settings( array $settings ): array {
		$source = sanitize_key( (string) ( $settings['source'] ?? 'all' ) );

		if ( ! in_array( $source, array( 'all', 'manual' ), true ) ) {
			$source = 'all';
		}

		return array(
			'title'      => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'source'     => $source,
			'brand_ids'  => implode(
				',',
				array_filter(
					array_map(
						'absint',
						preg_split( '/[\s,]+/', (string) ( $settings['brand_ids'] ?? '' ) )
					)
				)
			),
			'limit'      => max( 1, min( 100, absint( $settings['limit'] ?? 20 ) ) ),
			'item_width' => max( 60, min( 180, absint( $settings['item_width'] ?? 92 ) ) ),
		);
	}

	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		$taxonomy = $this->get_brand_taxonomy();

		if ( '' === $taxonomy ) {
			return null;
		}

		$args = array(
			'taxonomy'   => $taxonomy,
			'hide_empty' => true,
			'number'     => $settings['limit'],
			'orderby'    => 'name',
			'order'      => 'ASC',
		);

		if ( 'manual' === $settings['source'] ) {
			$args['include'] = array_values(
				array_filter(
					array_map( 'absint', explode( ',', $settings['brand_ids'] ) )
				)
			);
			$args['orderby'] = 'include';
		}

		$terms = get_terms( $args );

		if ( is_wp_error( $terms ) ) {
			return null;
		}

		$items = array();

		foreach ( $terms as $term ) {
			if ( ! $term instanceof WP_Term ) {
				continue;
			}

			$image_id = absint( get_term_meta( $term->term_id, 'thumbnail_id', true ) );

			if ( ! $image_id ) {
				$image_id = absint( get_term_meta( $term->term_id, 'brand_image_id', true ) );
			}

			$logo_url = $image_id
				? wp_get_attachment_image_url( $image_id, 'medium' )
				: '';

			if ( ! $logo_url ) {
				continue;
			}

			$items[] = array(
				'id'       => $term->term_id,
				'name'     => $term->name,
				'logo_url' => esc_url_raw( (string) $logo_url ),
				'action'   => $this->build_action( 'brand', (string) $term->term_id ),
			);
		}

		return array(
			'title'      => $settings['title'],
			'item_width' => $settings['item_width'],
			'items'      => $items,
		);
	}

	public function render_settings( int $index, array $settings ): void {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Section Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Brands Source', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][source]">
					<option value="all" <?php selected( 'all', $settings['source'] ); ?>><?php esc_html_e( 'All Brands', 'kidia-mobile-cms' ); ?></option>
					<option value="manual" <?php selected( 'manual', $settings['source'] ); ?>><?php esc_html_e( 'Manual Selection', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Brands Limit', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="100" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Brand Width', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="60" max="180" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][item_width]" value="<?php echo esc_attr( (string) $settings['item_width'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Brand IDs', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][brand_ids]" value="<?php echo esc_attr( $settings['brand_ids'] ); ?>" placeholder="4, 8, 15">
			</div>
		</div>
		<?php
	}

	private function get_brand_taxonomy(): string {
		$candidates = array(
			'product_brand',
			'pwb-brand',
			'yith_product_brand',
		);

		foreach ( $candidates as $taxonomy ) {
			if ( taxonomy_exists( $taxonomy ) ) {
				return $taxonomy;
			}
		}

		return '';
	}
}
