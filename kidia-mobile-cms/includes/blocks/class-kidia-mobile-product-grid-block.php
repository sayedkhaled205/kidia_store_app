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
			'card_style'     => 'outlined',
			'image_ratio'    => 1,
			'card_radius'    => 20,
			'show_name'      => true,
			'show_price'     => true,
			'show_regular_price' => true,
			'show_badge'     => true,
			'show_rating'    => false,
			'quick_add_enabled' => true,
			'quick_add_icon_variant' => 'bag',
			'quick_add_icon_style' => 'outline',
			'quick_add_icon_size' => 22,
			'quick_add_icon_color' => '#1F2933',
			'quick_add_show_background' => true,
			'quick_add_background_color' => '#FFFFFF',
			'quick_add_background_size' => 40,
			'quick_add_radius' => 24,
			'quick_add_position' => 'bottom_end',
			'show_wishlist' => false,
			'product_wishlist_icon_variant' => 'heart',
			'product_wishlist_icon_style' => 'outline',
			'product_wishlist_icon_size' => 20,
			'product_wishlist_icon_color' => '#1F2933',
			'product_wishlist_show_background' => true,
			'product_wishlist_background_color' => '#FFFFFF',
			'product_wishlist_background_size' => 40,
			'product_wishlist_radius' => 24,
			'product_wishlist_position' => 'top_end',
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
		$card_style = sanitize_key( (string) ( $settings['card_style'] ?? 'outlined' ) );

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
			'card_style'     => in_array( $card_style, array( 'outlined', 'elevated', 'minimal', 'no_shadow' ), true ) ? $card_style : 'outlined',
			'image_ratio'    => max( 0.6, min( 1.8, (float) ( $settings['image_ratio'] ?? 1 ) ) ),
			'card_radius'    => max( 0, min( 40, absint( $settings['card_radius'] ?? 20 ) ) ),
			'show_name'      => ! empty( $settings['show_name'] ),
			'show_price'     => ! empty( $settings['show_price'] ),
			'show_regular_price' => ! empty( $settings['show_regular_price'] ),
			'show_badge'     => ! empty( $settings['show_badge'] ),
			'show_rating'    => ! empty( $settings['show_rating'] ),
			'quick_add_enabled' => ! empty( $settings['quick_add_enabled'] ),
			'quick_add_icon_variant' => in_array( sanitize_key( (string) ( $settings['quick_add_icon_variant'] ?? 'bag' ) ), array( 'bag', 'cart', 'basket' ), true ) ? sanitize_key( (string) $settings['quick_add_icon_variant'] ) : 'bag',
			'quick_add_icon_style' => in_array( sanitize_key( (string) ( $settings['quick_add_icon_style'] ?? 'outline' ) ), array( 'outline', 'filled', 'rounded' ), true ) ? sanitize_key( (string) $settings['quick_add_icon_style'] ) : 'outline',
			'quick_add_icon_size' => max( 10, min( 36, absint( $settings['quick_add_icon_size'] ?? 22 ) ) ),
			'quick_add_icon_color' => sanitize_hex_color( (string) ( $settings['quick_add_icon_color'] ?? '#1F2933' ) ) ?: '#1F2933',
			'quick_add_show_background' => ! empty( $settings['quick_add_show_background'] ),
			'quick_add_background_color' => sanitize_hex_color( (string) ( $settings['quick_add_background_color'] ?? '#FFFFFF' ) ) ?: '#FFFFFF',
			'quick_add_background_size' => max( 20, min( 64, absint( $settings['quick_add_background_size'] ?? 40 ) ) ),
			'quick_add_radius' => max( 0, min( 40, absint( $settings['quick_add_radius'] ?? 24 ) ) ),
			'quick_add_position' => in_array( sanitize_key( (string) ( $settings['quick_add_position'] ?? 'bottom_end' ) ), array( 'top_start', 'top_end', 'bottom_start', 'bottom_end' ), true ) ? sanitize_key( (string) $settings['quick_add_position'] ) : 'bottom_end',
			'show_wishlist' => ! empty( $settings['show_wishlist'] ),
			'product_wishlist_icon_variant' => in_array( sanitize_key( (string) ( $settings['product_wishlist_icon_variant'] ?? 'heart' ) ), array( 'heart', 'rounded', 'bookmark' ), true ) ? sanitize_key( (string) $settings['product_wishlist_icon_variant'] ) : 'heart',
			'product_wishlist_icon_style' => in_array( sanitize_key( (string) ( $settings['product_wishlist_icon_style'] ?? 'outline' ) ), array( 'outline', 'filled' ), true ) ? sanitize_key( (string) $settings['product_wishlist_icon_style'] ) : 'outline',
			'product_wishlist_icon_size' => max( 10, min( 36, absint( $settings['product_wishlist_icon_size'] ?? 20 ) ) ),
			'product_wishlist_icon_color' => sanitize_hex_color( (string) ( $settings['product_wishlist_icon_color'] ?? '#1F2933' ) ) ?: '#1F2933',
			'product_wishlist_show_background' => ! empty( $settings['product_wishlist_show_background'] ),
			'product_wishlist_background_color' => sanitize_hex_color( (string) ( $settings['product_wishlist_background_color'] ?? '#FFFFFF' ) ) ?: '#FFFFFF',
			'product_wishlist_background_size' => max( 20, min( 64, absint( $settings['product_wishlist_background_size'] ?? 40 ) ) ),
			'product_wishlist_radius' => max( 0, min( 40, absint( $settings['product_wishlist_radius'] ?? 24 ) ) ),
			'product_wishlist_position' => in_array( sanitize_key( (string) ( $settings['product_wishlist_position'] ?? 'top_end' ) ), array( 'top_start', 'top_end', 'bottom_start', 'bottom_end' ), true ) ? sanitize_key( (string) $settings['product_wishlist_position'] ) : 'top_end',
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
			$rating = is_callable( array( $product, 'get_average_rating' ) ) ? (float) $product->get_average_rating() : 0.0;
			$review_count = is_callable( array( $product, 'get_review_count' ) ) ? absint( $product->get_review_count() ) : 0;
			$discount = is_numeric( $regular_price ) && is_numeric( $price ) && (float) $regular_price > (float) $price && 0 < (float) $regular_price
				? (int) round( ( ( (float) $regular_price - (float) $price ) / (float) $regular_price ) * 100 )
				: 0;

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
				'rating'           => $rating,
				'review_count'     => $review_count,
				'discount_percent' => $discount,
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
			'card_style'      => $settings['card_style'],
			'image_ratio'     => $settings['image_ratio'],
			'card_radius'     => $settings['card_radius'],
			'show_name'       => $settings['show_name'],
			'show_price'      => $settings['show_price'],
			'show_regular_price' => $settings['show_regular_price'],
			'show_badge'      => $settings['show_badge'],
			'show_rating'     => $settings['show_rating'],
			'quick_add_enabled' => $settings['quick_add_enabled'],
			'quick_add_icon_variant' => $settings['quick_add_icon_variant'],
			'quick_add_icon_style' => $settings['quick_add_icon_style'],
			'quick_add_icon_size' => $settings['quick_add_icon_size'],
			'quick_add_icon_color' => $settings['quick_add_icon_color'],
			'quick_add_show_background' => $settings['quick_add_show_background'],
			'quick_add_background_color' => $settings['quick_add_background_color'],
			'quick_add_background_size' => $settings['quick_add_background_size'],
			'quick_add_radius' => $settings['quick_add_radius'],
			'quick_add_position' => $settings['quick_add_position'],
			'show_wishlist' => $settings['show_wishlist'],
			'product_wishlist_icon_variant' => $settings['product_wishlist_icon_variant'],
			'product_wishlist_icon_style' => $settings['product_wishlist_icon_style'],
			'product_wishlist_icon_size' => $settings['product_wishlist_icon_size'],
			'product_wishlist_icon_color' => $settings['product_wishlist_icon_color'],
			'product_wishlist_show_background' => $settings['product_wishlist_show_background'],
			'product_wishlist_background_color' => $settings['product_wishlist_background_color'],
			'product_wishlist_background_size' => $settings['product_wishlist_background_size'],
			'product_wishlist_radius' => $settings['product_wishlist_radius'],
			'product_wishlist_position' => $settings['product_wishlist_position'],
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
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Card Style', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][card_style]"><option value="outlined" <?php selected( 'outlined', $settings['card_style'] ); ?>><?php esc_html_e( 'Outlined', 'kidia-mobile-cms' ); ?></option><option value="elevated" <?php selected( 'elevated', $settings['card_style'] ); ?>><?php esc_html_e( 'Elevated', 'kidia-mobile-cms' ); ?></option><option value="minimal" <?php selected( 'minimal', $settings['card_style'] ); ?>><?php esc_html_e( 'Minimal', 'kidia-mobile-cms' ); ?></option><option value="no_shadow" <?php selected( 'no_shadow', $settings['card_style'] ); ?>><?php esc_html_e( 'No shadow', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Image Ratio', 'kidia-mobile-cms' ); ?></label><input type="number" min="0.6" max="1.8" step="0.1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_ratio]" value="<?php echo esc_attr( (string) $settings['image_ratio'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Card Radius', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="40" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][card_radius]" value="<?php echo esc_attr( (string) $settings['card_radius'] ); ?>"></div>
			<?php foreach ( array( 'show_name' => __( 'Show Name', 'kidia-mobile-cms' ), 'show_price' => __( 'Show Price', 'kidia-mobile-cms' ), 'show_regular_price' => __( 'Show Regular Price', 'kidia-mobile-cms' ), 'show_badge' => __( 'Show Badge', 'kidia-mobile-cms' ), 'show_rating' => __( 'Show Rating', 'kidia-mobile-cms' ), 'quick_add_enabled' => __( 'Quick add to cart', 'kidia-mobile-cms' ) ) as $key => $label ) : ?>
				<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][<?php echo esc_attr( $key ); ?>]" value="1" <?php checked( true, $settings[ $key ] ); ?>> <?php echo esc_html( $label ); ?></label></div>
			<?php endforeach; ?>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add icon shape', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_icon_variant]"><option value="bag" <?php selected( 'bag', $settings['quick_add_icon_variant'] ); ?>><?php esc_html_e( 'Shopping bag', 'kidia-mobile-cms' ); ?></option><option value="cart" <?php selected( 'cart', $settings['quick_add_icon_variant'] ); ?>><?php esc_html_e( 'Shopping cart', 'kidia-mobile-cms' ); ?></option><option value="basket" <?php selected( 'basket', $settings['quick_add_icon_variant'] ); ?>><?php esc_html_e( 'Shopping basket', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add icon style', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_icon_style]"><option value="outline" <?php selected( 'outline', $settings['quick_add_icon_style'] ); ?>><?php esc_html_e( 'Outline', 'kidia-mobile-cms' ); ?></option><option value="filled" <?php selected( 'filled', $settings['quick_add_icon_style'] ); ?>><?php esc_html_e( 'Filled', 'kidia-mobile-cms' ); ?></option><option value="rounded" <?php selected( 'rounded', $settings['quick_add_icon_style'] ); ?>><?php esc_html_e( 'Rounded', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add icon size', 'kidia-mobile-cms' ); ?></label><input type="number" min="10" max="36" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_icon_size]" value="<?php echo esc_attr( (string) $settings['quick_add_icon_size'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add icon color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_icon_color]" value="<?php echo esc_attr( $settings['quick_add_icon_color'] ); ?>"></div>
			<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_show_background]" value="1" <?php checked( true, $settings['quick_add_show_background'] ); ?>> <?php esc_html_e( 'White background behind icon', 'kidia-mobile-cms' ); ?></label></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add background color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_background_color]" value="<?php echo esc_attr( $settings['quick_add_background_color'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add background size', 'kidia-mobile-cms' ); ?></label><input type="number" min="20" max="64" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_background_size]" value="<?php echo esc_attr( (string) $settings['quick_add_background_size'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add background radius', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="40" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_radius]" value="<?php echo esc_attr( (string) $settings['quick_add_radius'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Quick add position', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][quick_add_position]"><?php foreach ( array( 'top_start' => 'Top start', 'top_end' => 'Top end', 'bottom_start' => 'Bottom start', 'bottom_end' => 'Bottom end' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['quick_add_position'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_wishlist]" value="1" <?php checked( true, $settings['show_wishlist'] ); ?>> <?php esc_html_e( 'Product wishlist icon', 'kidia-mobile-cms' ); ?></label></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist icon shape', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_icon_variant]"><option value="heart" <?php selected( 'heart', $settings['product_wishlist_icon_variant'] ); ?>>Heart</option><option value="rounded" <?php selected( 'rounded', $settings['product_wishlist_icon_variant'] ); ?>>Rounded heart</option><option value="bookmark" <?php selected( 'bookmark', $settings['product_wishlist_icon_variant'] ); ?>>Bookmark</option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist icon style', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_icon_style]"><option value="outline" <?php selected( 'outline', $settings['product_wishlist_icon_style'] ); ?>>Outline</option><option value="filled" <?php selected( 'filled', $settings['product_wishlist_icon_style'] ); ?>>Filled</option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist icon size', 'kidia-mobile-cms' ); ?></label><input type="number" min="10" max="36" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_icon_size]" value="<?php echo esc_attr( (string) $settings['product_wishlist_icon_size'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist icon color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_icon_color]" value="<?php echo esc_attr( $settings['product_wishlist_icon_color'] ); ?>"></div>
			<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_show_background]" value="1" <?php checked( true, $settings['product_wishlist_show_background'] ); ?>> <?php esc_html_e( 'Product wishlist background', 'kidia-mobile-cms' ); ?></label></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist background color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_background_color]" value="<?php echo esc_attr( $settings['product_wishlist_background_color'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist background size', 'kidia-mobile-cms' ); ?></label><input type="number" min="20" max="64" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_background_size]" value="<?php echo esc_attr( (string) $settings['product_wishlist_background_size'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist background radius', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="40" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_radius]" value="<?php echo esc_attr( (string) $settings['product_wishlist_radius'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Product wishlist position', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][product_wishlist_position]"><?php foreach ( array( 'top_start' => 'Top start', 'top_end' => 'Top end', 'bottom_start' => 'Bottom start', 'bottom_end' => 'Bottom end' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['product_wishlist_position'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( $settings['subtitle'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-builder-field--product-source">
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
			<div class="kidia-builder-field kidia-builder-field--product-source">
				<label><?php esc_html_e( 'Category ID', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="0" step="1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_id]" value="<?php echo esc_attr( (string) $settings['category_id'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-builder-field--product-source">
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
