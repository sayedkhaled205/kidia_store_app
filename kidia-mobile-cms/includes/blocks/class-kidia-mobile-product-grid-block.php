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

	public function get_type(): string {
		return 'product_grid';
	}

	public function get_label(): string {
		return __( 'Product Grid', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-grid-view';
	}

	public function get_description(): string {
		return __( 'WooCommerce products in a responsive mobile grid.', 'kidia-mobile-cms' );
	}

	/**
	 * Returns default settings.
	 *
	 * @return array<string, mixed>
	 */
	public function get_default_settings(): array {
		return array(
			'title'          => '',
			'subtitle'       => '',
			'source'         => 'latest',
			'limit'          => 8,
			'columns'        => 2,
			'category_id'    => 0,
			'product_ids'    => '',
			'show_view_all'  => true,
			'view_all_label' => '',
			'action_type'    => '',
			'action_value'   => '',
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

		$allowed_actions = array(
			'',
			'product',
			'category',
			'collection',
			'brand',
			'brands',
			'search',
			'external',
		);

		$action_type = sanitize_key( (string) ( $settings['action_type'] ?? '' ) );

		if ( ! in_array( $action_type, $allowed_actions, true ) ) {
			$action_type = '';
		}

		$action_value = 'external' === $action_type
			? esc_url_raw( (string) ( $settings['action_value'] ?? '' ) )
			: sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) );

		$product_ids = array_values(
			array_unique(
				array_filter(
					array_map(
						'absint',
						preg_split(
							'/[\s,]+/',
							(string) ( $settings['product_ids'] ?? '' )
						)
					)
				)
			)
		);

		return array(
			'title'          => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'       => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'source'         => $source,
			'limit'          => max( 1, min( 50, absint( $settings['limit'] ?? 8 ) ) ),
			'columns'        => max( 1, min( 4, absint( $settings['columns'] ?? 2 ) ) ),
			'category_id'    => absint( $settings['category_id'] ?? 0 ),
			'product_ids'    => implode( ',', $product_ids ),
			'show_view_all'  => ! empty( $settings['show_view_all'] ),
			'view_all_label' => sanitize_text_field( (string) ( $settings['view_all_label'] ?? '' ) ),
			'action_type'    => $action_type,
			'action_value'   => $action_value,
		);
	}

	/**
	 * Resolves saved product settings into the Flutter API contract.
	 *
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return array<string, mixed>|null
	 */
	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		if ( ! function_exists( 'wc_get_products' ) ) {
			return null;
		}

		$products        = $this->query_products( $settings );
		$items           = array();
		$currency_code   = function_exists( 'get_woocommerce_currency' )
			? get_woocommerce_currency()
			: '';
		$currency_symbol = function_exists( 'get_woocommerce_currency_symbol' )
			? get_woocommerce_currency_symbol( $currency_code )
			: '';

		foreach ( $products as $product ) {
			if ( ! $product instanceof WC_Product ) {
				continue;
			}

			$image_url = $this->get_product_image_url( $product );
			$price     = trim( (string) $product->get_price() );
			$name      = sanitize_text_field(
				wp_specialchars_decode( (string) $product->get_name(), ENT_QUOTES )
			);

			// These fields are mandatory in the Flutter product item contract.
			if ( '' === $image_url || '' === $price || '' === $name || '' === $currency_code || '' === $currency_symbol ) {
				continue;
			}

			$regular_price = trim( (string) $product->get_regular_price() );

			$items[] = array(
				'id'              => (int) $product->get_id(),
				'name'            => $name,
				'image_url'       => $image_url,
				'price'           => $price,
				'regular_price'   => '' === $regular_price ? null : $regular_price,
				'currency_code'   => sanitize_text_field( (string) $currency_code ),
				'currency_symbol' => sanitize_text_field( (string) $currency_symbol ),
				'in_stock'        => $product->is_in_stock(),
				'badge'           => $product->is_on_sale()
					? __( 'Sale', 'kidia-mobile-cms' )
					: null,
				'action'          => $this->build_action( 'product', (string) $product->get_id() ),
			);
		}

		return array(
			'title'           => $settings['title'],
			'subtitle'        => $settings['subtitle'],
			'items'           => $items,
			'columns'         => $settings['columns'],
			'show_view_all'   => $settings['show_view_all'],
			'view_all_label'  => $settings['view_all_label'],
			'view_all_action' => $this->get_view_all_action( $settings ),
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

		$action_types = array(
			''           => __( 'Automatic', 'kidia-mobile-cms' ),
			'collection' => __( 'Collection', 'kidia-mobile-cms' ),
			'category'   => __( 'Category', 'kidia-mobile-cms' ),
			'product'    => __( 'Product', 'kidia-mobile-cms' ),
			'brand'      => __( 'Brand', 'kidia-mobile-cms' ),
			'brands'     => __( 'All Brands', 'kidia-mobile-cms' ),
			'search'     => __( 'Search', 'kidia-mobile-cms' ),
			'external'   => __( 'External URL', 'kidia-mobile-cms' ),
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
				<label><?php esc_html_e( 'Columns', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="4" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>">
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
				<label>
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_view_all]" value="1" <?php checked( true, $settings['show_view_all'] ); ?>>
					<?php esc_html_e( 'Show View All', 'kidia-mobile-cms' ); ?>
				</label>
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'View All Label', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][view_all_label]" value="<?php echo esc_attr( $settings['view_all_label'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'View All Action', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
					<?php foreach ( $action_types as $value => $label ) : ?>
						<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option>
					<?php endforeach; ?>
				</select>
			</div>
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Action Value', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]" value="<?php echo esc_attr( $settings['action_value'] ); ?>">
			</div>
		</div>
		<?php
	}

	/**
	 * Queries WooCommerce products for the selected source.
	 *
	 * @param array<string, mixed> $settings Sanitized settings.
	 *
	 * @return array<int, WC_Product>
	 */
	private function query_products( array $settings ): array {
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
				$product_ids = function_exists( 'wc_get_product_ids_on_sale' )
					? array_values( array_unique( array_filter( array_map( 'absint', wc_get_product_ids_on_sale() ) ) ) )
					: array();

				if ( empty( $product_ids ) ) {
					return array();
				}

				$args['include'] = $product_ids;
				break;

			case 'best_selling':
				$args['meta_key'] = 'total_sales';
				$args['orderby']  = 'meta_value_num';
				$args['order']    = 'DESC';
				break;

			case 'top_rated':
				$args['meta_key'] = '_wc_average_rating';
				$args['orderby']  = 'meta_value_num';
				$args['order']    = 'DESC';
				break;

			case 'random':
				$args['orderby'] = 'rand';
				break;

			case 'category':
				$term = get_term( $settings['category_id'], 'product_cat' );

				if ( is_wp_error( $term ) || ! $term instanceof WP_Term ) {
					return array();
				}

				$args['category'] = array( $term->slug );
				break;

			case 'manual':
				$product_ids = array_values(
					array_filter(
						array_map( 'absint', explode( ',', $settings['product_ids'] ) )
					)
				);

				if ( empty( $product_ids ) ) {
					return array();
				}

				$args['include'] = $product_ids;
				$args['orderby'] = 'include';
				break;

			case 'latest':
			default:
				$args['orderby'] = 'date';
				$args['order']   = 'DESC';
				break;
		}

		$products = wc_get_products( $args );

		if ( ! is_array( $products ) ) {
			return array();
		}

		return array_values(
			array_filter(
				$products,
				static fn ( $product ): bool => $product instanceof WC_Product
			)
		);
	}

	/**
	 * Returns a product thumbnail or the WooCommerce placeholder.
	 *
	 * @param WC_Product $product Product object.
	 *
	 * @return string
	 */
	private function get_product_image_url( WC_Product $product ): string {
		$image_id  = $product->get_image_id();
		$image_url = $image_id
			? wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' )
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

	/**
	 * Builds the explicit or automatic View All action.
	 *
	 * @param array<string, mixed> $settings Sanitized settings.
	 *
	 * @return array<string, string>|null
	 */
	private function get_view_all_action( array $settings ): ?array {
		$action = $this->build_action(
			$settings['action_type'],
			$settings['action_value']
		);

		if ( null !== $action ) {
			return $action;
		}

		if ( 'category' === $settings['source'] && 0 < $settings['category_id'] ) {
			return $this->build_action( 'category', (string) $settings['category_id'] );
		}

		return $this->build_action( 'collection', $settings['source'] );
	}
}
