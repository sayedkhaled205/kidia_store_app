<?php
/**
 * Category Grid Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Category_Grid_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Category_Grid_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'category_grid';
	}

	public function get_label(): string {
		return __( 'Category Grid', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-grid-view';
	}

	public function get_description(): string {
		return __( 'WooCommerce categories in a mobile grid.', 'kidia-mobile-cms' );
	}

	/**
	 * Returns default settings.
	 *
	 * @return array<string, mixed>
	 */
	public function get_default_settings(): array {
		return array(
			'title'      => '',
			'subtitle'   => '',
			'columns'    => 3,
			'limit'      => 5,
			'parent_id'  => 0,
			'hide_empty' => false,
			'show_names' => true,
			'layout'      => 'grid',
			'items_alignment' => 'right',
			'image_shape' => 'circle',
			'image_size'  => 86,
			'gap'         => 16,
			'label_size'  => 14,
			'label_color' => '#1F2933',
			'category_ids'=> '',
		);
	}

	/**
	 * Sanitizes block settings.
	 *
	 * @param array<string, mixed> $settings Raw settings.
	 *
	 * @return array<string, mixed>
	 */
	public function sanitize_settings( array $settings ): array {
		$layout = sanitize_key( (string) ( $settings['layout'] ?? 'grid' ) );
		// PatPat was removed from the editor. Treat old saved values as the
		// equivalent classic grid so existing elements continue to render.
		if ( 'patpat' === $layout ) {
			$layout = 'grid';
		}
		$items_alignment = sanitize_key( (string) ( $settings['items_alignment'] ?? 'right' ) );
		$shape  = sanitize_key( (string) ( $settings['image_shape'] ?? 'rounded' ) );
		$category_ids = array_values( array_unique( array_filter( array_map( 'absint', preg_split( '/[\s,]+/', (string) ( $settings['category_ids'] ?? '' ) ) ) ) ) );
		return array(
			'title'      => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'   => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'columns'    => max( 2, min( 6, absint( $settings['columns'] ?? 4 ) ) ),
			'limit'      => max( 1, min( 50, absint( $settings['limit'] ?? 8 ) ) ),
			'parent_id'  => absint( $settings['parent_id'] ?? 0 ),
			'hide_empty' => ! empty( $settings['hide_empty'] ),
			'show_names' => ! empty( $settings['show_names'] ),
			'layout'      => in_array( $layout, array( 'grid', 'compact', 'cards', 'carousel', 'editorial_mosaic', 'full_width_banners' ), true ) ? $layout : 'grid',
			'items_alignment' => in_array( $items_alignment, array( 'right', 'center', 'left' ), true ) ? $items_alignment : 'right',
			'image_shape' => in_array( $shape, array( 'circle', 'rounded', 'square' ), true ) ? $shape : 'rounded',
			'image_size'  => max( 48, min( 140, absint( $settings['image_size'] ?? 78 ) ) ),
			'gap'         => max( 0, min( 32, absint( $settings['gap'] ?? 12 ) ) ),
			'label_size'  => max( 10, min( 22, absint( $settings['label_size'] ?? 13 ) ) ),
			'label_color' => sanitize_hex_color( $settings['label_color'] ?? '' ) ?: '#1F2933',
			'category_ids'=> implode( ',', $category_ids ),
		);
	}

	/**
	 * Resolves saved category settings into the Flutter API contract.
	 *
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return array<string, mixed>|null
	 */
	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		if ( ! taxonomy_exists( 'product_cat' ) ) {
			return null;
		}

		$query_args = array(
				'taxonomy'   => 'product_cat',
				'hide_empty' => $settings['hide_empty'],
				'parent'     => $settings['parent_id'],
				'number'     => $settings['limit'],
				'orderby'    => 'name',
				'order'      => 'ASC',
			);

		$manual_ids = array_values( array_filter( array_map( 'absint', explode( ',', $settings['category_ids'] ) ) ) );
		if ( ! empty( $manual_ids ) ) {
			$query_args['include'] = $manual_ids;
			$query_args['orderby'] = 'include';
			$query_args['number'] = count( $manual_ids );
			unset( $query_args['parent'] );
		}

		$terms = get_terms( $query_args );

		// Existing elements created by older plugin versions defaulted to hiding
		// empty categories. Do not render an empty mobile block when the store has
		// valid categories that simply have no directly assigned product yet.
		if (
			$settings['hide_empty']
			&& is_array( $terms )
			&& empty( $terms )
		) {
			$query_args['hide_empty'] = false;
			$terms = get_terms( $query_args );
		}

		if ( is_wp_error( $terms ) || ! is_array( $terms ) ) {
			return null;
		}

		$items = array();

		foreach ( $terms as $term ) {
			if ( ! $term instanceof WP_Term ) {
				continue;
			}

			$image_url = $this->get_category_image_url( $term->term_id );

			// Flutter requires every category item to contain a valid image URL.
			if ( '' === $image_url ) {
				continue;
			}

			$items[] = array(
				'id'        => (int) $term->term_id,
				'name'      => sanitize_text_field(
					wp_specialchars_decode( (string) $term->name, ENT_QUOTES )
				),
				'image_url' => $image_url,
				'action'    => $this->build_action( 'category', (string) $term->term_id ),
			);
		}

		return array(
			'title'      => $settings['title'],
			'subtitle'   => $settings['subtitle'],
			'items'      => $items,
			'columns'    => $settings['columns'],
			'show_names' => $settings['show_names'],
			'layout'      => $settings['layout'],
			'items_alignment' => $settings['items_alignment'],
			'image_shape' => $settings['image_shape'],
			'image_size'  => $settings['image_size'],
			'gap'         => $settings['gap'],
			'label_size'  => $settings['label_size'],
			'label_color' => $settings['label_color'],
		);
	}

	/**
	 * Renders settings for the legacy Home Builder form.
	 *
	 * @param int                  $index    Block index.
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return void
	 */
	public function render_settings( int $index, array $settings ): void {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--title">
				<label><?php esc_html_e( 'Section Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--subtitle">
				<label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--category-ids"><label><?php esc_html_e( 'Manual Category IDs (optional)', 'kidia-mobile-cms' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_ids]" value="<?php echo esc_attr( (string) $settings['category_ids'] ); ?>" placeholder="12, 34, 56"></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--layout"><label><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]"><option value="grid" <?php selected( 'grid', $settings['layout'] ); ?>><?php esc_html_e( 'Classic grid', 'kidia-mobile-cms' ); ?></option><option value="compact" <?php selected( 'compact', $settings['layout'] ); ?>><?php esc_html_e( 'Compact grid', 'kidia-mobile-cms' ); ?></option><option value="cards" <?php selected( 'cards', $settings['layout'] ); ?>><?php esc_html_e( 'Rounded cards', 'kidia-mobile-cms' ); ?></option><option value="carousel" <?php selected( 'carousel', $settings['layout'] ); ?>><?php esc_html_e( 'Horizontal row', 'kidia-mobile-cms' ); ?></option><option value="editorial_mosaic" <?php selected( 'editorial_mosaic', $settings['layout'] ); ?>><?php esc_html_e( 'Editorial Mosaic', 'kidia-mobile-cms' ); ?></option><option value="full_width_banners" <?php selected( 'full_width_banners', $settings['layout'] ); ?>><?php esc_html_e( 'Full-width Banners', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--items-alignment"><label><?php esc_html_e( 'Items Alignment', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][items_alignment]"><option value="right" <?php selected( 'right', $settings['items_alignment'] ); ?>><?php esc_html_e( 'Right', 'kidia-mobile-cms' ); ?></option><option value="center" <?php selected( 'center', $settings['items_alignment'] ); ?>><?php esc_html_e( 'Center', 'kidia-mobile-cms' ); ?></option><option value="left" <?php selected( 'left', $settings['items_alignment'] ); ?>><?php esc_html_e( 'Left', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--limit">
				<label><?php esc_html_e( 'Categories Limit', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="50" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--columns">
				<label><?php esc_html_e( 'Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="2" max="6" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--gap"><label><?php esc_html_e( 'Gap', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][gap]" value="<?php echo esc_attr( (string) $settings['gap'] ); ?>"></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--image-size"><label><?php esc_html_e( 'Image Size', 'kidia-mobile-cms' ); ?></label><input type="number" min="48" max="140" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_size]" value="<?php echo esc_attr( (string) $settings['image_size'] ); ?>"></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--image-shape"><label><?php esc_html_e( 'Image Shape', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_shape]"><option value="circle" <?php selected( 'circle', $settings['image_shape'] ); ?>><?php esc_html_e( 'Circle', 'kidia-mobile-cms' ); ?></option><option value="rounded" <?php selected( 'rounded', $settings['image_shape'] ); ?>><?php esc_html_e( 'Rounded', 'kidia-mobile-cms' ); ?></option><option value="square" <?php selected( 'square', $settings['image_shape'] ); ?>><?php esc_html_e( 'Square', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--label-color"><label><?php esc_html_e( 'Label Color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][label_color]" value="<?php echo esc_attr( (string) $settings['label_color'] ); ?>"></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--label-size"><label><?php esc_html_e( 'Label Size', 'kidia-mobile-cms' ); ?></label><input type="number" min="10" max="22" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][label_size]" value="<?php echo esc_attr( (string) $settings['label_size'] ); ?>"></div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--hide-empty">
				<label><?php esc_html_e( 'Hide Empty Categories', 'kidia-mobile-cms' ); ?></label>
				<label class="kidia-page-master-toggle"><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][hide_empty]" value="1" <?php checked( true, $settings['hide_empty'] ); ?>><span class="kidia-toggle-state"></span></label>
			</div>
			<div class="kidia-builder-field kidia-category-grid-image-setting kidia-category-grid-image-setting--show-names">
				<label><?php esc_html_e( 'Show Category Names', 'kidia-mobile-cms' ); ?></label>
				<label class="kidia-page-master-toggle"><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_names]" value="1" <?php checked( true, $settings['show_names'] ); ?>><span class="kidia-toggle-state"></span></label>
			</div>
		</div>
		<?php
	}

	/**
	 * Returns a category thumbnail or the WooCommerce placeholder.
	 *
	 * @param int $term_id Product category term ID.
	 *
	 * @return string
	 */
	private function get_category_image_url( int $term_id ): string {
		$thumbnail_id = absint( get_term_meta( $term_id, 'thumbnail_id', true ) );
		$image_url    = $thumbnail_id
			? wp_get_attachment_image_url( $thumbnail_id, 'woocommerce_thumbnail' )
			: '';

		if ( ! $image_url && function_exists( 'wc_placeholder_img_src' ) ) {
			$image_url = wc_placeholder_img_src( 'woocommerce_thumbnail' );
		}

		$image_url = esc_url_raw(
			(string) $image_url,
			array( 'http', 'https' )
		);

		return '' !== (string) wp_parse_url( $image_url, PHP_URL_HOST )
			? $image_url
			: '';
	}
}
