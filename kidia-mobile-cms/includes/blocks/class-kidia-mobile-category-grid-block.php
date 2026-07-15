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
		return __( 'WooCommerce categories with configurable mobile layout.', 'kidia-mobile-cms' );
	}

	/**
	 * @return array<string,mixed>
	 */
	public function get_default_settings(): array {
		return array(
			'title'          => '',
			'subtitle'       => '',
			'layout'         => 'grid',
			'style'          => 'circle',
			'columns'        => 4,
			'columns_mobile' => 4,
			'gap'            => 10,
			'image_ratio'    => 1,
			'limit'          => 8,
			'source'         => 'top_level',
			'parent_id'      => 0,
			'category_ids'   => '',
			'hide_empty'     => true,
			'show_names'     => true,
			'show_count'     => false,
		);
	}

	/**
	 * @param array<string,mixed> $settings Raw settings.
	 *
	 * @return array<string,mixed>
	 */
	public function sanitize_settings(
		array $settings
	): array {
		$layout = sanitize_key( (string) ( $settings['layout'] ?? 'grid' ) );
		$style  = sanitize_key( (string) ( $settings['style'] ?? 'circle' ) );

		if ( ! in_array( $layout, array( 'grid', 'compact', 'carousel' ), true ) ) {
			$layout = 'grid';
		}

		if ( ! in_array( $style, array( 'circle', 'square', 'card', 'simple', 'badge', 'overlay' ), true ) ) {
			$style = 'circle';
		}

		$image_ratio = isset( $settings['image_ratio'] )
			? (float) $settings['image_ratio']
			: 1;

		$source = sanitize_key( (string) ( $settings['source'] ?? 'top_level' ) );
		if ( ! in_array( $source, array( 'top_level', 'children', 'all', 'manual' ), true ) ) {
			$source = 'top_level';
		}

		$category_ids = preg_split( '/[\s,]+/', (string) ( $settings['category_ids'] ?? '' ) );

		return array(
			'title' => sanitize_text_field(
				(string) ( $settings['title'] ?? '' )
			),
			'subtitle' => sanitize_textarea_field(
				(string) ( $settings['subtitle'] ?? '' )
			),
			'layout' => $layout,
			'style' => $style,
			'columns' => max(
				2,
				min( 6, absint( $settings['columns'] ?? 4 ) )
			),
			'columns_mobile' => max(
				2,
				min( 6, absint( $settings['columns_mobile'] ?? 4 ) )
			),
			'gap' => max(
				0,
				min( 40, absint( $settings['gap'] ?? 10 ) )
			),
			'image_ratio' => max( 0.5, min( 2, $image_ratio ) ),
			'limit' => max(
				1,
				min( 50, absint( $settings['limit'] ?? 8 ) )
			),
			'source' => $source,
			'parent_id' => absint(
				$settings['parent_id'] ?? 0
			),
			'category_ids' => implode( ',', array_values( array_unique( array_filter( array_map( 'absint', (array) $category_ids ) ) ) ) ),
			'hide_empty' => ! empty(
				$settings['hide_empty']
			),
			'show_names' => ! empty(
				$settings['show_names']
			),
			'show_count' => ! empty(
				$settings['show_count']
			),
		);
	}

	/**
	 * Builds API data matching CategoryGridBlock in Flutter.
	 *
	 * @param array<string,mixed> $settings Settings.
	 *
	 * @return array<string,mixed>|null
	 */
	public function build_api_data(
		array $settings
	): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		if (
			! function_exists( 'taxonomy_exists' )
			|| ! taxonomy_exists( 'product_cat' )
			|| ! function_exists( 'get_terms' )
		) {
			return null;
		}

		if ( 'children' === $settings['source'] ) {
			if ( 0 === $settings['parent_id'] || ! function_exists( 'get_term' ) ) {
				return null;
			}

			$parent = get_term( $settings['parent_id'], 'product_cat' );

			if (
				! $parent instanceof WP_Term
				|| ( function_exists( 'is_wp_error' ) && is_wp_error( $parent ) )
			) {
				return null;
			}
		}

		$term_args = array(
				'taxonomy'   => 'product_cat',
				'hide_empty' => $settings['hide_empty'],
				'number'     => $settings['limit'],
				'orderby'    => 'name',
				'order'      => 'ASC',
			);

		if ( 'top_level' === $settings['source'] ) {
			$term_args['parent'] = 0;
		} elseif ( 'children' === $settings['source'] ) {
			$term_args['parent'] = $settings['parent_id'];
		} elseif ( 'manual' === $settings['source'] ) {
			$manual_ids = array_values( array_filter( array_map( 'absint', explode( ',', $settings['category_ids'] ) ) ) );
			if ( empty( $manual_ids ) ) {
				return null;
			}
			$term_args['include']    = $manual_ids;
			$term_args['orderby']    = 'include';
			$term_args['hide_empty'] = false;
		}

		$terms = get_terms( $term_args );

		if (
			( function_exists( 'is_wp_error' ) && is_wp_error( $terms ) )
			|| ! is_array( $terms )
		) {
			return null;
		}

		$items = array();

		foreach ( $terms as $term ) {
			if ( ! $term instanceof WP_Term ) {
				continue;
			}

			$image_id  = absint(
				get_term_meta( $term->term_id, 'thumbnail_id', true )
			);
			$image_url = $image_id
				? wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' )
				: '';

			if ( ! $image_url && function_exists( 'wc_placeholder_img_src' ) ) {
				$image_url = wc_placeholder_img_src();
			}

			$image_url = esc_url_raw( (string) $image_url );

			if ( '' === $image_url ) {
				continue;
			}

			$items[] = array(
				'id'        => absint( $term->term_id ),
				'name'      => sanitize_text_field( (string) $term->name ),
				'image_url' => $image_url,
				'count'     => absint( $term->count ),
				'action'    => $this->build_action(
					'category',
					(string) absint( $term->term_id )
				),
			);
		}

		if ( empty( $items ) ) {
			return null;
		}

		return array(
			'title'          => $settings['title'],
			'subtitle'       => $settings['subtitle'],
			'items'          => $items,
			'columns'        => $settings['columns_mobile'],
			'columns_mobile' => $settings['columns_mobile'],
			'layout'         => $settings['layout'],
			'style'          => $settings['style'],
			'gap'            => $settings['gap'],
			'image_ratio'    => $settings['image_ratio'],
			'show_names'     => $settings['show_names'],
			'show_count'     => $settings['show_count'],
		);
	}

	/**
	 * @param int                 $index    Block index.
	 * @param array<string,mixed> $settings Settings.
	 *
	 * @return void
	 */
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
				<label><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>">
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]">
					<option value="grid" <?php selected( 'grid', $settings['layout'] ); ?>><?php esc_html_e( 'Grid', 'kidia-mobile-cms' ); ?></option>
					<option value="compact" <?php selected( 'compact', $settings['layout'] ); ?>><?php esc_html_e( 'Compact Grid', 'kidia-mobile-cms' ); ?></option>
					<option value="carousel" <?php selected( 'carousel', $settings['layout'] ); ?>><?php esc_html_e( 'Carousel', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Style', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][style]">
					<option value="circle" <?php selected( 'circle', $settings['style'] ); ?>><?php esc_html_e( 'Circle', 'kidia-mobile-cms' ); ?></option>
					<option value="square" <?php selected( 'square', $settings['style'] ); ?>><?php esc_html_e( 'Square', 'kidia-mobile-cms' ); ?></option>
					<option value="card" <?php selected( 'card', $settings['style'] ); ?>><?php esc_html_e( 'Card', 'kidia-mobile-cms' ); ?></option>
					<option value="simple" <?php selected( 'simple', $settings['style'] ); ?>><?php esc_html_e( 'Simple', 'kidia-mobile-cms' ); ?></option>
					<option value="badge" <?php selected( 'badge', $settings['style'] ); ?>><?php esc_html_e( 'Badge', 'kidia-mobile-cms' ); ?></option>
					<option value="overlay" <?php selected( 'overlay', $settings['style'] ); ?>><?php esc_html_e( 'Overlay', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Mobile Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="2" max="6" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns_mobile]" value="<?php echo esc_attr( (string) $settings['columns_mobile'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Gap (px)', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0" max="40" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][gap]" value="<?php echo esc_attr( (string) $settings['gap'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Image Ratio', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0.5" max="2" step="0.1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_ratio]" value="<?php echo esc_attr( (string) $settings['image_ratio'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Categories Limit', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="50" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Categories Source', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][source]">
					<option value="top_level" <?php selected( 'top_level', $settings['source'] ); ?>><?php esc_html_e( 'Top-level Categories', 'kidia-mobile-cms' ); ?></option>
					<option value="children" <?php selected( 'children', $settings['source'] ); ?>><?php esc_html_e( 'Children of a Category', 'kidia-mobile-cms' ); ?></option>
					<option value="all" <?php selected( 'all', $settings['source'] ); ?>><?php esc_html_e( 'All Categories', 'kidia-mobile-cms' ); ?></option>
					<option value="manual" <?php selected( 'manual', $settings['source'] ); ?>><?php esc_html_e( 'Manual Selection', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Parent Category ID (Children source)', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][parent_id]" value="<?php echo esc_attr( (string) $settings['parent_id'] ); ?>">
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Category IDs (Manual source)', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_ids]" value="<?php echo esc_attr( $settings['category_ids'] ); ?>" placeholder="12, 34, 56">
			</div>

			<div class="kidia-builder-field">
				<label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_names]" value="1" <?php checked( true, $settings['show_names'] ); ?>> <?php esc_html_e( 'Show Category Names', 'kidia-mobile-cms' ); ?></label>
			</div>

			<div class="kidia-builder-field">
				<label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_count]" value="1" <?php checked( true, $settings['show_count'] ); ?>> <?php esc_html_e( 'Show Product Count', 'kidia-mobile-cms' ); ?></label>
			</div>

			<div class="kidia-builder-field">
				<label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][hide_empty]" value="1" <?php checked( true, $settings['hide_empty'] ); ?>> <?php esc_html_e( 'Hide Empty Categories', 'kidia-mobile-cms' ); ?></label>
			</div>
		</div>
		<?php
	}
}
