<?php
/**
 * Product Grid Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Product_Grid_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Product_Grid_Block extends Kidia_Mobile_Block {

	/**
	 * Returns block type.
	 *
	 * @return string
	 */
	public function get_type(): string {
		return 'product_grid';
	}

	/**
	 * Returns block label.
	 *
	 * @return string
	 */
	public function get_label(): string {
		return __( 'Product Grid', 'kidia-mobile-cms' );
	}

	/**
	 * Returns block icon.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-grid-view';
	}

	/**
	 * Returns block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return __(
			'WooCommerce products in a responsive grid.',
			'kidia-mobile-cms'
		);
	}

	/**
	 * Returns default settings.
	 *
	 * @return array<string,mixed>
	 */
	public function get_default_settings(): array {
		return array(
			'title'          => '',
			'source'         => 'latest',
			'limit'          => 8,
			'card_style'     => 'standard',
			'columns'        => 2,
			'columns_mobile' => 2,
			'gap'            => 12,
			'image_ratio'    => 1,
			'category_id'    => 0,
			'product_ids'    => '',
			'show_view_all'  => true,
			'show_rating'    => true,
			'show_badge'     => true,
			'show_stock'     => true,
		);
	}

	/**
	 * Sanitizes block settings.
	 *
	 * @param array<string,mixed> $settings Raw settings.
	 *
	 * @return array<string,mixed>
	 */
	public function sanitize_settings(
		array $settings
	): array {
		$source = sanitize_key(
			(string) ( $settings['source'] ?? 'latest' )
		);

		$allowed_sources = array(
			'latest',
			'featured',
			'on_sale',
			'best_selling',
			'top_rated',
			'random',
			'category',
			'manual',
		);

		if ( ! in_array( $source, $allowed_sources, true ) ) {
			$source = 'latest';
		}

		$card_style = sanitize_key(
			(string) ( $settings['card_style'] ?? 'standard' )
		);

		if (
			! in_array(
				$card_style,
				array( 'standard', 'compact', 'outlined' ),
				true
			)
		) {
			$card_style = 'standard';
		}

		$image_ratio = isset( $settings['image_ratio'] )
			? (float) $settings['image_ratio']
			: 1;

		$product_ids = preg_split(
			'/[\s,]+/',
			(string) ( $settings['product_ids'] ?? '' )
		);

		return array(
			'title' => sanitize_text_field(
				(string) ( $settings['title'] ?? '' )
			),
			'source' => $source,
			'limit' => max(
				1,
				min( 50, absint( $settings['limit'] ?? 8 ) )
			),
			'card_style' => $card_style,
			'columns' => max(
				1,
				min( 4, absint( $settings['columns'] ?? 2 ) )
			),
			'columns_mobile' => max(
				1,
				min( 4, absint( $settings['columns_mobile'] ?? 2 ) )
			),
			'gap' => max(
				0,
				min( 40, absint( $settings['gap'] ?? 12 ) )
			),
			'image_ratio' => max( 0.5, min( 2, $image_ratio ) ),
			'category_id' => absint(
				$settings['category_id'] ?? 0
			),
			'product_ids' => implode(
				',',
				array_values(
					array_unique(
						array_filter(
							array_map( 'absint', (array) $product_ids )
						)
					)
				)
			),
			'show_view_all' => ! empty(
				$settings['show_view_all']
			),
			'show_rating' => ! empty(
				$settings['show_rating']
			),
			'show_badge' => ! empty(
				$settings['show_badge']
			),
			'show_stock' => ! empty(
				$settings['show_stock']
			),
		);
	}

	/**
	 * Builds API data matching ProductGridBlock in Flutter.
	 *
	 * @param array<string,mixed> $settings Settings.
	 *
	 * @return array<string,mixed>|null
	 */
	public function build_api_data(
		array $settings
	): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args(
				$settings,
				$this->get_default_settings()
			)
		);

		$products = $this->query_products( $settings );

		if ( null === $products ) {
			return null;
		}

		$items = $this->build_product_items( $products, $settings );

		if ( empty( $items ) ) {
			return null;
		}

		return array(
			'title'           => '' !== $settings['title']
				? $settings['title']
				: null,
			'items'           => $items,
			'card_style'      => $settings['card_style'],
			'columns'         => $settings['columns_mobile'],
			'columns_mobile'  => $settings['columns_mobile'],
			'gap'             => $settings['gap'],
			'image_ratio'     => $settings['image_ratio'],
			'show_view_all'   => $settings['show_view_all'],
			'show_rating'     => $settings['show_rating'],
			'show_badge'      => $settings['show_badge'],
			'show_stock'      => $settings['show_stock'],
			'view_all_action' => $this->build_product_view_all_action(
				$settings
			),
		);
	}

	/**
	 * Renders block settings.
	 *
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
			wp_parse_args(
				$settings,
				$this->get_default_settings()
			)
		);

		$sources = array(
			'latest'       => __( 'Latest Products', 'kidia-mobile-cms' ),
			'featured'     => __( 'Featured Products', 'kidia-mobile-cms' ),
			'on_sale'      => __( 'On Sale', 'kidia-mobile-cms' ),
			'best_selling' => __( 'Best Selling', 'kidia-mobile-cms' ),
			'top_rated'    => __( 'Top Rated', 'kidia-mobile-cms' ),
			'random'       => __( 'Random', 'kidia-mobile-cms' ),
			'category'     => __( 'Specific Category', 'kidia-mobile-cms' ),
			'manual'       => __( 'Manual Selection', 'kidia-mobile-cms' ),
		);
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Section Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Products Source', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][source]">
					<?php foreach ( $sources as $value => $label ) : ?>
						<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['source'] ); ?>><?php echo esc_html( $label ); ?></option>
					<?php endforeach; ?>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Products Limit', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="50" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Card Style', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][card_style]">
					<option value="standard" <?php selected( 'standard', $settings['card_style'] ); ?>><?php esc_html_e( 'Standard', 'kidia-mobile-cms' ); ?></option>
					<option value="compact" <?php selected( 'compact', $settings['card_style'] ); ?>><?php esc_html_e( 'Compact', 'kidia-mobile-cms' ); ?></option>
					<option value="outlined" <?php selected( 'outlined', $settings['card_style'] ); ?>><?php esc_html_e( 'Outlined', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="4" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Mobile Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="4" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns_mobile]" value="<?php echo esc_attr( (string) $settings['columns_mobile'] ); ?>">
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
				<label><?php esc_html_e( 'Category ID', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_id]" value="<?php echo esc_attr( (string) $settings['category_id'] ); ?>">
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Product IDs', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_ids]" value="<?php echo esc_attr( $settings['product_ids'] ); ?>" placeholder="12, 34, 56">
			</div>

			<div class="kidia-builder-field">
				<label class="kidia-builder-switch">
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_view_all]" value="1" <?php checked( true, $settings['show_view_all'] ); ?>>
					<span class="kidia-builder-switch__track"></span>
				</label>
				<span><?php esc_html_e( 'Show View All', 'kidia-mobile-cms' ); ?></span>
			</div>

			<div class="kidia-builder-field">
				<label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_rating]" value="1" <?php checked( true, $settings['show_rating'] ); ?>> <?php esc_html_e( 'Show Rating', 'kidia-mobile-cms' ); ?></label>
			</div>

			<div class="kidia-builder-field">
				<label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_badge]" value="1" <?php checked( true, $settings['show_badge'] ); ?>> <?php esc_html_e( 'Show Badge', 'kidia-mobile-cms' ); ?></label>
			</div>

			<div class="kidia-builder-field">
				<label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_stock]" value="1" <?php checked( true, $settings['show_stock'] ); ?>> <?php esc_html_e( 'Show Stock Status', 'kidia-mobile-cms' ); ?></label>
			</div>
		</div>
		<?php
	}
}
