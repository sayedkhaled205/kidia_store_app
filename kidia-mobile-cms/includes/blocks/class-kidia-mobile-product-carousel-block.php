<?php
/**
 * Product Carousel block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Product_Carousel_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Product_Carousel_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'product_carousel';
	}

	public function get_label(): string {
		return __( 'Product Carousel', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-products';
	}

	public function get_description(): string {
		return __( 'WooCommerce products in a horizontal carousel.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title'          => '',
			'source'         => 'latest',
			'limit'          => 10,
			'category_id'    => 0,
			'product_ids'    => '',
			'show_view_all'  => true,
			'cards_visible'  => 2.2,
			'gap'            => 12,
			'card_style'     => 'default',
			'image_ratio'    => 1,
			'show_rating'    => true,
			'show_category'  => false,
			'show_badge'     => true,
			'show_stock'     => true,
			'show_arrows'    => false,
			'show_dots'      => false,
		);
	}

	public function sanitize_settings( array $settings ): array {
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

		$source = sanitize_key( (string) ( $settings['source'] ?? 'latest' ) );

		if ( ! in_array( $source, $allowed_sources, true ) ) {
			$source = 'latest';
		}

		$card_style = sanitize_key( (string) ( $settings['card_style'] ?? 'default' ) );

		if ( ! in_array( $card_style, array( 'default', 'compact', 'minimal' ), true ) ) {
			$card_style = 'default';
		}

		return array(
			'title'         => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'source'        => $source,
			'limit'         => max( 1, min( 50, absint( $settings['limit'] ?? 10 ) ) ),
			'category_id'   => absint( $settings['category_id'] ?? 0 ),
			'product_ids'   => implode(
				',',
				array_filter(
					array_map(
						'absint',
						preg_split(
							'/[\s,]+/',
							(string) ( $settings['product_ids'] ?? '' )
						)
					)
				)
			),
			'show_view_all' => ! empty( $settings['show_view_all'] ),
			'cards_visible' => max( 1, min( 6, (float) ( $settings['cards_visible'] ?? 2.2 ) ) ),
			'gap'           => max( 0, min( 48, absint( $settings['gap'] ?? 12 ) ) ),
			'card_style'    => $card_style,
			'image_ratio'   => max( 0.5, min( 2, (float) ( $settings['image_ratio'] ?? 1 ) ) ),
			'show_rating'   => ! empty( $settings['show_rating'] ),
			'show_category' => ! empty( $settings['show_category'] ),
			'show_badge'    => ! empty( $settings['show_badge'] ),
			'show_stock'    => ! empty( $settings['show_stock'] ),
			'show_arrows'   => ! empty( $settings['show_arrows'] ),
			'show_dots'     => ! empty( $settings['show_dots'] ),
		);
	}

	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
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
			'title'           => $settings['title'],
			'items'           => $items,
			'show_view_all'   => $settings['show_view_all'],
			'view_all_action' => $this->build_product_view_all_action( $settings ),
			'layout'          => array(
				'cards_visible' => $settings['cards_visible'],
				'gap'           => $settings['gap'],
				'card_style'    => $settings['card_style'],
				'image_ratio'   => $settings['image_ratio'],
				'show_rating'   => $settings['show_rating'],
				'show_category' => $settings['show_category'],
				'show_badge'    => $settings['show_badge'],
				'show_stock'    => $settings['show_stock'],
				'show_arrows'   => $settings['show_arrows'],
				'show_dots'     => $settings['show_dots'],
			),
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
				<label><?php esc_html_e( 'Products Source', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][source]">
					<?php
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
					foreach ( $sources as $value => $label ) :
						?>
						<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['source'] ); ?>><?php echo esc_html( $label ); ?></option>
					<?php endforeach; ?>
				</select>
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Products Limit', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="50" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Category ID', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_id]" value="<?php echo esc_attr( (string) $settings['category_id'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Product IDs', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_ids]" value="<?php echo esc_attr( $settings['product_ids'] ); ?>" placeholder="12, 34, 56">
			</div>
		</div>
		<?php
	}
}
