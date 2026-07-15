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
		);
	}

	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		if ( ! function_exists( 'wc_get_products' ) ) {
			return null;
		}

		$args = array(
			'status' => 'publish',
			'limit'  => $settings['limit'],
			'return' => 'objects',
		);

		switch ( $settings['source'] ) {
			case 'featured':
				$args['featured'] = true;
				break;

			case 'on_sale':
				$args['include'] = function_exists( 'wc_get_product_ids_on_sale' )
					? wc_get_product_ids_on_sale()
					: array();
				break;

			case 'best_selling':
				$args['orderby'] = 'meta_value_num';
				$args['meta_key'] = 'total_sales';
				$args['order'] = 'DESC';
				break;

			case 'top_rated':
				$args['orderby'] = 'rating';
				$args['order'] = 'DESC';
				break;

			case 'random':
				$args['orderby'] = 'rand';
				break;

			case 'category':
				$term = get_term( $settings['category_id'], 'product_cat' );
				if ( $term instanceof WP_Term ) {
					$args['category'] = array( $term->slug );
				}
				break;

			case 'manual':
				$args['include'] = array_values(
					array_filter(
						array_map(
							'absint',
							explode( ',', $settings['product_ids'] )
						)
					)
				);
				$args['orderby'] = 'include';
				break;

			case 'latest':
			default:
				$args['orderby'] = 'date';
				$args['order'] = 'DESC';
				break;
		}

		$products = wc_get_products( $args );
		$items    = array();

		foreach ( $products as $product ) {
			if ( ! $product instanceof WC_Product ) {
				continue;
			}

			$image_id  = $product->get_image_id();
			$image_url = $image_id ? wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' ) : '';

			if ( ! $image_url && function_exists( 'wc_placeholder_img_src' ) ) {
				$image_url = wc_placeholder_img_src();
			}

			$items[] = array(
				'id'              => $product->get_id(),
				'name'            => $product->get_name(),
				'image_url'       => esc_url_raw( (string) $image_url ),
				'price'           => (string) $product->get_price(),
				'regular_price'   => (string) $product->get_regular_price(),
				'currency_code'   => get_woocommerce_currency(),
				'currency_symbol' => get_woocommerce_currency_symbol(),
				'in_stock'        => $product->is_in_stock(),
				'badge'           => $product->is_on_sale() ? __( 'Sale', 'kidia-mobile-cms' ) : null,
				'action'          => $this->build_action( 'product', (string) $product->get_id() ),
			);
		}

		return array(
			'title'           => $settings['title'],
			'items'           => $items,
			'show_view_all'   => $settings['show_view_all'],
			'view_all_action' => $this->build_action( 'collection', $settings['source'] ),
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
