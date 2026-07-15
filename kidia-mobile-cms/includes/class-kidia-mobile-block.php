<?php
/**
 * Base Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Block', false ) ) {
	return;
}

/**
 * Base class for every Home Builder block.
 */
abstract class Kidia_Mobile_Block {

	/**
	 * Unique block type.
	 *
	 * Example: image_banner, product_carousel.
	 *
	 * @return string
	 */
	abstract public function get_type(): string;

	/**
	 * Block display name inside the Builder.
	 *
	 * @return string
	 */
	abstract public function get_label(): string;

	/**
	 * WordPress Dashicon class.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-screenoptions';
	}

	/**
	 * Short block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return '';
	}

	/**
	 * Returns default block settings.
	 *
	 * @return array<string, mixed>
	 */
	public function get_default_settings(): array {
		return array();
	}

	/**
	 * Sanitizes submitted settings.
	 *
	 * Child blocks may override this method.
	 *
	 * @param array<string, mixed> $settings Submitted settings.
	 *
	 * @return array<string, mixed>
	 */
	public function sanitize_settings(
		array $settings
	): array {
		return $this->sanitize_value_array(
			$settings
		);
	}

	/**
	 * Builds the block data returned by the REST API.
	 *
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return array<string, mixed>|null
	 */
	abstract public function build_api_data(
		array $settings
	): ?array;

	/**
	 * Renders the block settings inside Home Builder.
	 *
	 * @param int                  $index    Block index.
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return void
	 */
	abstract public function render_settings(
		int $index,
		array $settings
	): void;

	/**
	 * Creates a new block instance.
	 *
	 * @param int $order Block order.
	 *
	 * @return array<string, mixed>
	 */
	public function create_instance(
		int $order = 1
	): array {
		return array(
			'id'       => $this->generate_instance_id(),
			'type'     => $this->get_type(),
			'enabled'  => true,
			'order'    => max( 1, $order ),
			'settings' => $this->get_default_settings(),
		);
	}

	/**
	 * Normalizes a saved block instance.
	 *
	 * @param array<string, mixed> $block Raw saved block.
	 * @param int                  $order Block order.
	 *
	 * @return array<string, mixed>
	 */
	public function normalize_instance(
		array $block,
		int $order
	): array {
		$id = isset( $block['id'] )
			? sanitize_key(
				(string) $block['id']
			)
			: '';

		if ( empty( $id ) ) {
			$id = $this->generate_instance_id();
		}

		$settings = isset( $block['settings'] )
			&& is_array( $block['settings'] )
				? $block['settings']
				: array();

		$settings = wp_parse_args(
			$this->sanitize_settings( $settings ),
			$this->get_default_settings()
		);

		return array(
			'id'       => $id,
			'type'     => $this->get_type(),
			'enabled'  => ! empty( $block['enabled'] ),
			'order'    => max( 1, $order ),
			'settings' => $settings,
		);
	}

	/**
	 * Builds the complete REST API block structure.
	 *
	 * @param array<string, mixed> $instance Saved block instance.
	 *
	 * @return array<string, mixed>|null
	 */
	public function build_api_block(
		array $instance
	): ?array {
		if ( empty( $instance['enabled'] ) ) {
			return null;
		}

		$settings = isset( $instance['settings'] )
			&& is_array( $instance['settings'] )
				? $instance['settings']
				: array();

		$data = $this->build_api_data(
			wp_parse_args(
				$settings,
				$this->get_default_settings()
			)
		);

		if ( null === $data ) {
			return null;
		}

		$id = isset( $instance['id'] )
			? sanitize_key(
				(string) $instance['id']
			)
			: $this->generate_instance_id();

		return array(
			'id'      => $id,
			'type'    => $this->get_type(),
			'enabled' => true,
			'data'    => $data,
		);
	}

	/**
	 * Returns block metadata for the Add Element popup.
	 *
	 * @return array<string, mixed>
	 */
	public function get_definition(): array {
		return array(
			'type'        => $this->get_type(),
			'label'       => $this->get_label(),
			'description' => $this->get_description(),
			'icon'        => $this->get_icon(),
			'duplicable'  => true,
		);
	}

	/**
	 * Generates a unique instance ID.
	 *
	 * @return string
	 */
	protected function generate_instance_id(): string {
		$uuid = function_exists( 'wp_generate_uuid4' )
			? wp_generate_uuid4()
			: uniqid( '', true );

		return sanitize_key(
			$this->get_type()
			. '_'
			. str_replace( '-', '', $uuid )
		);
	}

	/**
	 * Sanitizes nested settings arrays.
	 *
	 * @param array<string|int, mixed> $values Raw values.
	 *
	 * @return array<string|int, mixed>
	 */
	protected function sanitize_value_array(
		array $values
	): array {
		$sanitized = array();

		foreach ( $values as $key => $value ) {
			$clean_key = is_string( $key )
				? sanitize_key( $key )
				: absint( $key );

			if ( is_array( $value ) ) {
				$sanitized[ $clean_key ] =
					$this->sanitize_value_array( $value );

				continue;
			}

			if ( is_bool( $value ) ) {
				$sanitized[ $clean_key ] = $value;
				continue;
			}

			if ( is_int( $value ) || is_float( $value ) ) {
				$sanitized[ $clean_key ] = $value;
				continue;
			}

			if ( null === $value ) {
				$sanitized[ $clean_key ] = null;
				continue;
			}

			$string_value = (string) $value;

			if (
				is_string( $clean_key )
				&& (
					str_ends_with( $clean_key, '_url' )
					|| 'url' === $clean_key
				)
			) {
				$sanitized[ $clean_key ] = esc_url_raw(
					$string_value
				);

				continue;
			}

			if (
				is_string( $clean_key )
				&& in_array(
					$clean_key,
					array(
						'content',
						'description',
						'subtitle',
					),
					true
				)
			) {
				$sanitized[ $clean_key ] =
					sanitize_textarea_field(
						$string_value
					);

				continue;
			}

			$sanitized[ $clean_key ] =
				sanitize_text_field(
					$string_value
				);
		}

		return $sanitized;
	}

	/**
	 * Queries WooCommerce products for a CMS product block.
	 *
	 * A null result means that WooCommerce is unavailable or that the chosen
	 * source is incomplete/invalid. An empty array means that the source is
	 * valid but currently contains no published products.
	 *
	 * @param array<string,mixed> $settings Sanitized block settings.
	 *
	 * @return array<int,object>|null
	 */
	protected function query_products(
		array $settings
	): ?array {
		if ( ! function_exists( 'wc_get_products' ) ) {
			return null;
		}

		$source = sanitize_key(
			(string) ( $settings['source'] ?? 'latest' )
		);

		$limit = max(
			1,
			min( 50, absint( $settings['limit'] ?? 10 ) )
		);

		$args = array(
			'status' => 'publish',
			'limit'  => $limit,
			'return' => 'objects',
		);

		switch ( $source ) {
			case 'featured':
				$args['featured'] = true;
				break;

			case 'on_sale':
				if ( ! function_exists( 'wc_get_product_ids_on_sale' ) ) {
					return null;
				}

				$product_ids = array_values(
					array_unique(
						array_filter(
							array_map(
								'absint',
								wc_get_product_ids_on_sale()
							)
						)
					)
				);

				if ( empty( $product_ids ) ) {
					return array();
				}

				$args['include'] = $product_ids;
				break;

			case 'best_selling':
			case 'top_rated':
				if ( ! function_exists( 'get_posts' ) ) {
					return null;
				}

				$ranked_ids = get_posts(
					array(
						'post_type'              => 'product',
						'post_status'            => 'publish',
						'fields'                 => 'ids',
						'posts_per_page'         => $limit,
						'no_found_rows'          => true,
						'ignore_sticky_posts'    => true,
						'update_post_meta_cache' => false,
						'update_post_term_cache' => false,
						'meta_key'               => 'best_selling' === $source
							? 'total_sales'
							: '_wc_average_rating',
						'orderby'                => array(
							'meta_value_num' => 'DESC',
							'date'           => 'DESC',
						),
					)
				);

				$ranked_ids = array_values(
					array_filter(
						array_map( 'absint', (array) $ranked_ids )
					)
				);

				if ( empty( $ranked_ids ) ) {
					return array();
				}

				$args['include'] = $ranked_ids;
				$args['orderby'] = 'include';
				break;

			case 'random':
				$args['orderby'] = 'rand';
				break;

			case 'category':
				$category_id = absint( $settings['category_id'] ?? 0 );

				if ( 0 === $category_id || ! function_exists( 'get_term' ) ) {
					return null;
				}

				$term = get_term( $category_id, 'product_cat' );

				if (
					! $term instanceof WP_Term
					|| ( function_exists( 'is_wp_error' ) && is_wp_error( $term ) )
				) {
					return null;
				}

				$args['category'] = array( $term->slug );
				break;

			case 'manual':
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

				if ( empty( $product_ids ) ) {
					return array();
				}

				$args['include'] = array_slice( $product_ids, 0, $limit );
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
				static function ( $product ): bool {
					return is_object( $product )
						&& is_a( $product, 'WC_Product' );
				}
			)
		);
	}

	/**
	 * Converts WooCommerce products to the Flutter product-item contract.
	 *
	 * @param array<int,object>     $products WooCommerce product objects.
	 * @param array<string,mixed>   $display  Optional display settings.
	 *
	 * @return array<int,array<string,mixed>>
	 */
	protected function build_product_items(
		array $products,
		array $display = array()
	): array {
		$items = array();
		$show_badge = ! array_key_exists( 'show_badge', $display )
			|| ! empty( $display['show_badge'] );

		foreach ( $products as $product ) {
			if ( ! is_object( $product ) || ! is_a( $product, 'WC_Product' ) ) {
				continue;
			}

			$product_id = absint( $product->get_id() );
			$price      = (string) $product->get_price();

			if ( 0 === $product_id || '' === trim( $price ) ) {
				continue;
			}

			$image_id  = absint( $product->get_image_id() );
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

			$regular_price = trim( (string) $product->get_regular_price() );
			$category_name = '';
			$category_ids  = method_exists( $product, 'get_category_ids' )
				? array_filter( array_map( 'absint', (array) $product->get_category_ids() ) )
				: array();

			if ( ! empty( $category_ids ) && function_exists( 'get_term' ) ) {
				$category_term = get_term( (int) reset( $category_ids ), 'product_cat' );
				if (
					$category_term instanceof WP_Term
					&& ( ! function_exists( 'is_wp_error' ) || ! is_wp_error( $category_term ) )
				) {
					$category_name = sanitize_text_field( (string) $category_term->name );
				}
			}

			$rating       = method_exists( $product, 'get_average_rating' )
				? (float) $product->get_average_rating()
				: 0.0;
			$review_count = method_exists( $product, 'get_review_count' )
				? absint( $product->get_review_count() )
				: 0;
			$rating_count = method_exists( $product, 'get_rating_count' )
				? absint( $product->get_rating_count() )
				: $review_count;
			$stock_status = method_exists( $product, 'get_stock_status' )
				? sanitize_key( (string) $product->get_stock_status() )
				: ( $product->is_in_stock() ? 'instock' : 'outofstock' );
			$currency_code = function_exists( 'get_woocommerce_currency' )
				? (string) get_woocommerce_currency()
				: '';
			$currency_symbol = function_exists( 'get_woocommerce_currency_symbol' )
				? html_entity_decode(
					(string) get_woocommerce_currency_symbol(),
					ENT_QUOTES | ENT_HTML5,
					'UTF-8'
				)
				: '';

			if ( '' === $currency_code || '' === $currency_symbol ) {
				continue;
			}

			$items[] = array(
				'id'              => $product_id,
				'name'            => sanitize_text_field( (string) $product->get_name() ),
				'image_url'       => $image_url,
				'price'           => $price,
				'regular_price'   => '' !== $regular_price ? $regular_price : null,
				'currency_code'   => sanitize_text_field( $currency_code ),
				'currency_symbol' => sanitize_text_field( $currency_symbol ),
				'in_stock'        => (bool) $product->is_in_stock(),
				'stock_status'    => $stock_status,
				'rating'          => $rating,
				'review_count'    => $review_count,
				'rating_count'    => $rating_count,
				'category'        => $category_name ?: null,
				'badge'           => $show_badge && $product->is_on_sale()
					? __( 'Sale', 'kidia-mobile-cms' )
					: null,
				'action'          => $this->build_action(
					'product',
					(string) $product_id
				),
			);
		}

		return $items;
	}

	/**
	 * Builds a useful View All action for a product source.
	 *
	 * @param array<string,mixed> $settings Sanitized block settings.
	 *
	 * @return array<string,string>|null
	 */
	protected function build_product_view_all_action(
		array $settings
	): ?array {
		$source = sanitize_key(
			(string) ( $settings['source'] ?? '' )
		);

		if ( 'category' === $source ) {
			return $this->build_action(
				'category',
				(string) absint( $settings['category_id'] ?? 0 )
			);
		}

		if ( 'manual' === $source ) {
			return null;
		}

		return $this->build_action( 'collection', $source );
	}

	/**
	 * Builds a Flutter navigation action.
	 *
	 * @param mixed $type  Action type.
	 * @param mixed $value Action value.
	 *
	 * @return array<string, string>|null
	 */
	protected function build_action(
		$type,
		$value
	): ?array {
		$type = sanitize_key(
			(string) $type
		);

		$value = trim(
			(string) $value
		);

		$allowed_types = array(
			'product',
			'category',
			'collection',
			'brand',
			'brands',
			'search',
			'external',
		);

		if (
			empty( $type )
			|| empty( $value )
			|| ! in_array(
				$type,
				$allowed_types,
				true
			)
		) {
			return null;
		}

		if ( 'external' === $type ) {
			$value = esc_url_raw( $value );

			if ( empty( $value ) ) {
				return null;
			}
		} else {
			$value = sanitize_text_field(
				$value
			);
		}

		return array(
			'type'  => $type,
			'value' => $value,
		);
	}
}
