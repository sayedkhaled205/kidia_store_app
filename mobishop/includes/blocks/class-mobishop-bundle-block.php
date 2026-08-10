<?php
/**
 * Bundle collection Home Builder block.
 *
 * Kept in its own files so existing element internals remain untouched.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

final class MobiShop_Bundle_Block extends MobiShop_Block {

	public function get_type(): string {
		return 'bundle_collection';
	}

	public function get_label(): string {
		return __( 'Bundles & Recommendations', 'mobishop' );
	}

	public function get_icon(): string {
		return 'dashicons-products';
	}

	public function get_description(): string {
		return __( 'Show manual, automatic or AI-selected bundles on the Home Page.', 'mobishop' );
	}

	public function get_default_settings(): array {
		return array(
			'title'            => __( 'Bundles selected for you', 'mobishop' ),
			'subtitle'         => '',
			'source'           => 'published',
			'bundle_ids'       => '',
			'layout'           => 'carousel',
			'limit'            => 6,
			'columns'          => 2,
			'channel'          => 'all',
			'show_image'       => true,
			'show_price'       => true,
			'show_discount'    => true,
			'hide_unavailable' => true,
			'cta_mode'         => 'auto',
			'card_radius'      => 16,
		);
	}

	public function sanitize_settings( array $settings ): array {
		$source = sanitize_key( (string) ( $settings['source'] ?? 'published' ) );
		$source = in_array( $source, array( 'published', 'manual', 'ai', 'frequently_bought', 'trending' ), true ) ? $source : 'published';
		$channel = sanitize_key( (string) ( $settings['channel'] ?? 'all' ) );
		$channel = in_array( $channel, array( 'all', 'website', 'mobile' ), true ) ? $channel : 'all';
		$ids = array_values( array_unique( array_filter( array_map( 'sanitize_key', preg_split( '/[\s,]+/', (string) ( $settings['bundle_ids'] ?? '' ) ) ) ) ) );
		return array(
			'title'            => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'         => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'source'           => $source,
			'bundle_ids'       => implode( ',', $ids ),
			'layout'           => in_array( sanitize_key( (string) ( $settings['layout'] ?? 'carousel' ) ), array( 'carousel', 'grid', 'banner' ), true ) ? sanitize_key( (string) $settings['layout'] ) : 'carousel',
			'limit'            => min( 20, max( 1, absint( $settings['limit'] ?? 6 ) ) ),
			'columns'          => min( 3, max( 1, absint( $settings['columns'] ?? 2 ) ) ),
			'channel'          => $channel,
			'show_image'       => ! empty( $settings['show_image'] ),
			'show_price'       => ! empty( $settings['show_price'] ),
			'show_discount'    => ! empty( $settings['show_discount'] ),
			'hide_unavailable' => ! empty( $settings['hide_unavailable'] ),
			'cta_mode'         => in_array( sanitize_key( (string) ( $settings['cta_mode'] ?? 'auto' ) ), array( 'auto', 'add', 'customize' ), true ) ? sanitize_key( (string) $settings['cta_mode'] ) : 'auto',
			'card_radius'      => min( 40, max( 0, absint( $settings['card_radius'] ?? 16 ) ) ),
		);
	}

	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings( wp_parse_args( $settings, $this->get_default_settings() ) );
		$recipes  = MobiShop_Bundle_Recipes::all();
		$manual   = array_filter( explode( ',', $settings['bundle_ids'] ) );
		if ( 'manual' === $settings['source'] ) {
			$recipes = array_intersect_key( $recipes, array_flip( $manual ) );
		}
		$items = array();
		foreach ( $recipes as $recipe ) {
			if (
				'published' !== ( $recipe['status'] ?? 'draft' )
				|| ! in_array( (string) ( $recipe['channel'] ?? 'all' ), array( 'all', $settings['channel'] ), true )
			) {
				continue;
			}
			$items[] = array(
				'id'              => (string) $recipe['id'],
				'product_id'      => absint( $recipe['product_id'] ?? 0 ),
				'name'            => (string) $recipe['name'],
				'description'     => (string) $recipe['description'],
				'type'            => (string) $recipe['type'],
				'image_url'       => (string) $recipe['image_url'],
				'pricing'         => (string) $recipe['pricing'],
				'discount_value'  => (float) $recipe['discount_value'],
				'minimum_items'   => absint( $recipe['minimum_items'] ),
				'maximum_items'   => absint( $recipe['maximum_items'] ),
				'product_ids'     => array_map( 'absint', (array) $recipe['product_ids'] ),
				'groups'          => (array) $recipe['groups'],
				'cta_label'       => (string) $recipe['cta_label'],
				'action'          => array( 'type' => 'bundle', 'value' => (string) $recipe['id'] ),
			);
			if ( count( $items ) >= $settings['limit'] ) {
				break;
			}
		}
		return array(
			'title'         => $settings['title'],
			'subtitle'      => $settings['subtitle'],
			'source'        => $settings['source'],
			'layout'        => $settings['layout'],
			'columns'       => $settings['columns'],
			'show_image'    => $settings['show_image'],
			'show_price'    => $settings['show_price'],
			'show_discount' => $settings['show_discount'],
			'cta_mode'      => $settings['cta_mode'],
			'card_radius'   => $settings['card_radius'],
			'items'         => $items,
		);
	}

	public function render_settings( int $index, array $settings ): void {
		$settings = wp_parse_args( $settings, $this->get_default_settings() );
		$name = static fn( string $key ): string => 'blocks[' . $index . '][settings][' . $key . ']';
		?>
		<div class="mobishop-builder-fields">
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Section title', 'mobishop' ); ?></label><input type="text" name="<?php echo esc_attr( $name( 'title' ) ); ?>" value="<?php echo esc_attr( $settings['title'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Subtitle', 'mobishop' ); ?></label><input type="text" name="<?php echo esc_attr( $name( 'subtitle' ) ); ?>" value="<?php echo esc_attr( $settings['subtitle'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Bundle source', 'mobishop' ); ?></label><select name="<?php echo esc_attr( $name( 'source' ) ); ?>"><?php foreach ( array( 'published' => 'Published bundles', 'manual' => 'Manual selection', 'ai' => 'AI recommendations', 'frequently_bought' => 'Frequently bought together', 'trending' => 'Trending bundles' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['source'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Bundle IDs', 'mobishop' ); ?></label><input type="text" name="<?php echo esc_attr( $name( 'bundle_ids' ) ); ?>" value="<?php echo esc_attr( $settings['bundle_ids'] ); ?>" placeholder="bundle-one, bundle-two"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Layout', 'mobishop' ); ?></label><select name="<?php echo esc_attr( $name( 'layout' ) ); ?>"><?php foreach ( array( 'carousel' => 'Carousel', 'grid' => 'Grid', 'banner' => 'Banner' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['layout'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Sales channel', 'mobishop' ); ?></label><select name="<?php echo esc_attr( $name( 'channel' ) ); ?>"><?php foreach ( array( 'all' => 'Website + Mobile App', 'website' => 'Website only', 'mobile' => 'Mobile App only' ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['channel'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Maximum bundles', 'mobishop' ); ?></label><input type="number" min="1" max="20" name="<?php echo esc_attr( $name( 'limit' ) ); ?>" value="<?php echo esc_attr( (string) $settings['limit'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Columns', 'mobishop' ); ?></label><input type="number" min="1" max="3" name="<?php echo esc_attr( $name( 'columns' ) ); ?>" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Primary action', 'mobishop' ); ?></label><select name="<?php echo esc_attr( $name( 'cta_mode' ) ); ?>"><option value="auto" <?php selected( 'auto', $settings['cta_mode'] ); ?>>Automatic by bundle type</option><option value="add" <?php selected( 'add', $settings['cta_mode'] ); ?>>Add bundle</option><option value="customize" <?php selected( 'customize', $settings['cta_mode'] ); ?>>Customize bundle</option></select></div>
			<div class="mobishop-builder-field"><label><input type="checkbox" name="<?php echo esc_attr( $name( 'show_image' ) ); ?>" value="1" <?php checked( ! empty( $settings['show_image'] ) ); ?>> <?php esc_html_e( 'Show image', 'mobishop' ); ?></label></div>
			<div class="mobishop-builder-field"><label><input type="checkbox" name="<?php echo esc_attr( $name( 'show_price' ) ); ?>" value="1" <?php checked( ! empty( $settings['show_price'] ) ); ?>> <?php esc_html_e( 'Show price', 'mobishop' ); ?></label></div>
			<div class="mobishop-builder-field"><label><input type="checkbox" name="<?php echo esc_attr( $name( 'show_discount' ) ); ?>" value="1" <?php checked( ! empty( $settings['show_discount'] ) ); ?>> <?php esc_html_e( 'Show discount', 'mobishop' ); ?></label></div>
			<div class="mobishop-builder-field"><label><input type="checkbox" name="<?php echo esc_attr( $name( 'hide_unavailable' ) ); ?>" value="1" <?php checked( ! empty( $settings['hide_unavailable'] ) ); ?>> <?php esc_html_e( 'Hide unavailable bundles', 'mobishop' ); ?></label></div>
		</div>
		<?php
	}
}
