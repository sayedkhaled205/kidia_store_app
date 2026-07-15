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
			'limit'      => 12,
			'item_width' => 90,
			'layout'     => 'carousel',
			'columns'    => 4,
			'columns_mobile' => 3,
			'gap'        => 12,
			'show_names' => true,
		);
	}

	public function sanitize_settings( array $settings ): array {
		$source = sanitize_key( (string) ( $settings['source'] ?? 'all' ) );

		if ( ! in_array( $source, array( 'all', 'manual' ), true ) ) {
			$source = 'all';
		}

		$layout = sanitize_key( (string) ( $settings['layout'] ?? 'carousel' ) );

		if ( ! in_array( $layout, array( 'carousel', 'grid' ), true ) ) {
			$layout = 'carousel';
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
			'limit'      => max( 1, min( 100, absint( $settings['limit'] ?? 12 ) ) ),
			'item_width' => max( 60, min( 180, absint( $settings['item_width'] ?? 90 ) ) ),
			'layout'     => $layout,
			'columns'    => max( 1, min( 8, absint( $settings['columns'] ?? 4 ) ) ),
			'columns_mobile' => max( 1, min( 4, absint( $settings['columns_mobile'] ?? 3 ) ) ),
			'gap'        => max( 0, min( 48, absint( $settings['gap'] ?? 12 ) ) ),
			'show_names' => ! empty( $settings['show_names'] ),
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
			$args['hide_empty'] = false;
			$args['include'] = array_values(
				array_filter(
					array_map( 'absint', explode( ',', $settings['brand_ids'] ) )
				)
			);
			$args['orderby'] = 'include';

			if ( empty( $args['include'] ) ) {
				return array(
					'title'      => $settings['title'],
					'item_width' => $settings['item_width'],
					'layout'     => $settings['layout'],
					'columns'    => $settings['columns'],
					'columns_mobile' => $settings['columns_mobile'],
					'gap'        => $settings['gap'],
					'show_names' => $settings['show_names'],
					'items'      => array(),
				);
			}
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

			$image_id = 0;
			foreach ( array( 'thumbnail_id', 'brand_image_id', 'brand_logo_id', 'pwb_brand_image', 'yith_wcbr_logo' ) as $image_meta_key ) {
				$image_id = absint( get_term_meta( $term->term_id, $image_meta_key, true ) );
				if ( $image_id ) {
					break;
				}
			}

			$logo_url = $image_id
				? wp_get_attachment_image_url( $image_id, 'medium' )
				: '';

			if ( ! $logo_url ) {
				foreach ( array( 'brand_image', 'logo', 'image_url' ) as $url_meta_key ) {
					$logo_url = esc_url_raw( (string) get_term_meta( $term->term_id, $url_meta_key, true ) );
					if ( $logo_url ) {
						break;
					}
				}
			}

			if ( ! $logo_url && function_exists( 'wc_placeholder_img_src' ) ) {
				$logo_url = wc_placeholder_img_src();
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
			'layout'     => $settings['layout'],
			'columns'    => $settings['columns'],
			'columns_mobile' => $settings['columns_mobile'],
			'gap'        => $settings['gap'],
			'show_names' => $settings['show_names'],
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
				<label><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]">
					<option value="carousel" <?php selected( 'carousel', $settings['layout'] ); ?>><?php esc_html_e( 'Carousel', 'kidia-mobile-cms' ); ?></option>
					<option value="grid" <?php selected( 'grid', $settings['layout'] ); ?>><?php esc_html_e( 'Grid', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Visible Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="8" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Mobile Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="4" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns_mobile]" value="<?php echo esc_attr( (string) $settings['columns_mobile'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Item Gap', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0" max="48" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][gap]" value="<?php echo esc_attr( (string) $settings['gap'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label>
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_names]" value="1" <?php checked( true, $settings['show_names'] ); ?>>
					<?php esc_html_e( 'Show Brand Names', 'kidia-mobile-cms' ); ?>
				</label>
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
			'pa_brand',
		);

		$fallback = '';

		foreach ( $candidates as $taxonomy ) {
			if ( ! taxonomy_exists( $taxonomy ) ) {
				continue;
			}

			if ( '' === $fallback ) {
				$fallback = $taxonomy;
			}

			$count = wp_count_terms(
				array(
					'taxonomy'   => $taxonomy,
					'hide_empty' => false,
				)
			);

			if ( ! is_wp_error( $count ) && 0 < (int) $count ) {
				return $taxonomy;
			}
		}

		return $fallback;
	}
}
