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
			'columns'    => 4,
			'limit'      => 8,
			'parent_id'  => 0,
			'hide_empty' => true,
			'show_names' => true,
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
		return array(
			'title'      => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'   => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'columns'    => max( 2, min( 6, absint( $settings['columns'] ?? 4 ) ) ),
			'limit'      => max( 1, min( 50, absint( $settings['limit'] ?? 8 ) ) ),
			'parent_id'  => absint( $settings['parent_id'] ?? 0 ),
			'hide_empty' => ! empty( $settings['hide_empty'] ),
			'show_names' => ! empty( $settings['show_names'] ),
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

		$terms = get_terms(
			array(
				'taxonomy'   => 'product_cat',
				'hide_empty' => $settings['hide_empty'],
				'parent'     => $settings['parent_id'],
				'number'     => $settings['limit'],
				'orderby'    => 'name',
				'order'      => 'ASC',
			)
		);

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
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Section Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="2" max="6" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Categories Limit', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="50" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Parent Category ID', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][parent_id]" value="<?php echo esc_attr( (string) $settings['parent_id'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label>
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_names]" value="1" <?php checked( true, $settings['show_names'] ); ?>>
					<?php esc_html_e( 'Show Category Names', 'kidia-mobile-cms' ); ?>
				</label>
			</div>
			<div class="kidia-builder-field">
				<label>
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][hide_empty]" value="1" <?php checked( true, $settings['hide_empty'] ); ?>>
					<?php esc_html_e( 'Hide Empty Categories', 'kidia-mobile-cms' ); ?>
				</label>
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
