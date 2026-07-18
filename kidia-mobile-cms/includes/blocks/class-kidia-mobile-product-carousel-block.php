<?php
/**
 * Product Carousel Home Builder block.
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
		return __(
			'Horizontally scrollable WooCommerce products.',
			'kidia-mobile-cms'
		);
	}

	public function get_default_settings(): array {
		return array(
			'title'           => '',
			'subtitle'        => '',
			'source'          => 'latest',
			'limit'           => 10,
			'category_id'     => 0,
			'product_ids'     => '',
			'show_view_all'   => true,
			'view_all_label'  => '',
			'action_type'     => '',
			'action_value'    => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {
		$source = sanitize_key(
			(string) ( $settings['source'] ?? 'latest' )
		);

		if ( 'sale' === $source ) {
			$source = 'on_sale';
		}

		if (
			! in_array(
				$source,
				array(
					'latest',
					'featured',
					'on_sale',
					'best_selling',
					'top_rated',
					'random',
					'category',
					'manual',
				),
				true
			)
		) {
			$source = 'latest';
		}

		$action_type = sanitize_key(
			(string) ( $settings['action_type'] ?? '' )
		);

		if (
			! in_array(
				$action_type,
				array(
					'',
					'product',
					'category',
					'collection',
					'brand',
					'brands',
					'search',
					'external',
				),
				true
			)
		) {
			$action_type = '';
		}

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
			'title' => isset( $settings['title'] )
				? sanitize_text_field(
					$settings['title']
				)
				: '',

			'subtitle' => isset( $settings['subtitle'] )
				? sanitize_textarea_field(
					$settings['subtitle']
				)
				: '',

			'source' => $source,

			'limit' => isset( $settings['limit'] )
				? max(
					1,
					min(
						50,
						absint(
							$settings['limit']
						)
					)
				)
				: 10,

			'category_id' => isset(
				$settings['category_id']
			)
				? absint(
					$settings['category_id']
				)
				: 0,

			'product_ids' => implode( ',', $product_ids ),

			'show_view_all' => ! empty(
				$settings['show_view_all']
			),

			'view_all_label' => isset(
				$settings['view_all_label']
			)
				? sanitize_text_field(
					$settings['view_all_label']
				)
				: '',

			'action_type' => $action_type,

			'action_value' => isset(
				$settings['action_value']
			)
				? (
					'external' === $action_type
						? $this->sanitize_http_url( $settings['action_value'] )
						: sanitize_text_field( $settings['action_value'] )
				)
				: '',
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

		if ( ! function_exists( 'wc_get_products' ) ) {
			return null;
		}

		$items           = array();
		$currency_code   = function_exists( 'get_woocommerce_currency' )
			? get_woocommerce_currency()
			: '';
		$currency_symbol = function_exists( 'get_woocommerce_currency_symbol' )
			? get_woocommerce_currency_symbol( $currency_code )
			: '';

		foreach ( $this->query_products( $settings ) as $product ) {
			if ( ! $product instanceof WC_Product ) {
				continue;
			}

			$image_url = $this->get_product_image_url( $product );
			$name      = sanitize_text_field(
				wp_specialchars_decode( (string) $product->get_name(), ENT_QUOTES )
			);
			$price     = trim( (string) $product->get_price() );

			if (
				'' === $image_url
				|| '' === $name
				|| '' === $price
				|| '' === $currency_code
				|| '' === $currency_symbol
			) {
				continue;
			}

			$regular_price = trim( (string) $product->get_regular_price() );
			$items[]       = array(
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
				'action'          => $this->build_action(
					'product',
					(string) $product->get_id()
				),
			);
		}

		return array(
			'title'           => $settings['title'],
			'items'           => $items,
			'show_view_all'   => $settings['show_view_all'],
			'view_all_action' => $this->get_view_all_action( $settings ),
		);
	}

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

    ?>
    <div class="kidia-builder-grid">

    	<div class="kidia-builder-field">

    		<label>Title</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]"
    			value="<?php echo esc_attr( $settings['title'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Subtitle</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]"
    			value="<?php echo esc_attr( $settings['subtitle'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Source</label>

    		<select
    			name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][source]"
    		>

    			<option value="featured" <?php selected( 'featured', $settings['source'] ); ?>>Featured</option>

    			<option value="latest" <?php selected( 'latest', $settings['source'] ); ?>>Latest</option>

			<option value="on_sale" <?php selected( 'on_sale', $settings['source'] ); ?>>Sale</option>

			<option value="best_selling" <?php selected( 'best_selling', $settings['source'] ); ?>>Best Selling</option>

			<option value="top_rated" <?php selected( 'top_rated', $settings['source'] ); ?>>Top Rated</option>

			<option value="random" <?php selected( 'random', $settings['source'] ); ?>>Random</option>

    			<option value="category" <?php selected( 'category', $settings['source'] ); ?>>Category</option>

    			<option value="manual" <?php selected( 'manual', $settings['source'] ); ?>>Manual</option>

    		</select>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Limit</label>

    		<input
    			type="number"
    			min="1"
    			max="50"
    			name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]"
    			value="<?php echo esc_attr( (string) $settings['limit'] ); ?>"
    		>

		</div>

		<div class="kidia-builder-field">

			<label>Category ID</label>

			<input
				type="number"
				min="0"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_id]"
				value="<?php echo esc_attr( (string) $settings['category_id'] ); ?>"
			>

		</div>

		<div class="kidia-builder-field kidia-builder-field--full">

			<label>Manual Product IDs</label>

			<input
				type="text"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_ids]"
				value="<?php echo esc_attr( $settings['product_ids'] ); ?>"
				placeholder="12, 34, 56"
			>

		</div>

		<div class="kidia-builder-field">

			<label>
				<input
					type="checkbox"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_view_all]"
					value="1"
					<?php checked( true, $settings['show_view_all'] ); ?>
				>
				Show View All
			</label>

		</div>

		<div class="kidia-builder-field">

			<label>View All Action</label>

			<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
				<option value="" <?php selected( '', $settings['action_type'] ); ?>>Automatic</option>
				<option value="collection" <?php selected( 'collection', $settings['action_type'] ); ?>>Collection</option>
				<option value="category" <?php selected( 'category', $settings['action_type'] ); ?>>Category</option>
				<option value="product" <?php selected( 'product', $settings['action_type'] ); ?>>Product</option>
				<option value="brand" <?php selected( 'brand', $settings['action_type'] ); ?>>Brand</option>
				<option value="brands" <?php selected( 'brands', $settings['action_type'] ); ?>>All Brands</option>
				<option value="search" <?php selected( 'search', $settings['action_type'] ); ?>>Search</option>
				<option value="external" <?php selected( 'external', $settings['action_type'] ); ?>>External URL</option>
			</select>

		</div>

		<div class="kidia-builder-field kidia-builder-field--full">

			<label>View All Action Value</label>

			<input
				type="text"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]"
				value="<?php echo esc_attr( $settings['action_value'] ); ?>"
			>

		</div>

	</div>

	<?php
	}

	/** Queries products using the same source choices exposed by the Builder. */
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
				$ids = function_exists( 'wc_get_product_ids_on_sale' )
					? array_values( array_unique( array_filter( array_map( 'absint', wc_get_product_ids_on_sale() ) ) ) )
					: array();
				if ( empty( $ids ) ) {
					return array();
				}
				$args['include'] = $ids;
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
				$ids = array_values(
					array_filter(
						array_map( 'absint', explode( ',', $settings['product_ids'] ) )
					)
				);
				if ( empty( $ids ) ) {
					return array();
				}
				$args['include'] = $ids;
				$args['orderby'] = 'include';
				break;

			case 'latest':
			default:
				$args['orderby'] = 'date';
				$args['order']   = 'DESC';
				break;
		}

		$products = wc_get_products( $args );

		return is_array( $products ) ? array_values( $products ) : array();
	}

	/** Returns a product thumbnail or WooCommerce's HTTPS placeholder. */
	private function get_product_image_url( WC_Product $product ): string {
		$image_id  = $product->get_image_id();
		$image_url = $image_id
			? wp_get_attachment_image_url( $image_id, 'woocommerce_thumbnail' )
			: '';

		if ( ! $image_url && function_exists( 'wc_placeholder_img_src' ) ) {
			$image_url = wc_placeholder_img_src( 'woocommerce_thumbnail' );
		}

		return $this->sanitize_http_url( $image_url );
	}

	/** Builds an explicit or source-derived View All action. */
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

		if ( 'manual' === $settings['source'] ) {
			return null;
		}

		return $this->build_action( 'collection', $settings['source'] );
	}
}
