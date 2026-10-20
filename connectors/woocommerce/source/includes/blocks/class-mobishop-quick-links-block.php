<?php
/**
 * Quick Links Home Builder block.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'MobiShop_Quick_Links_Block', false ) ) {
	return;
}

/** Displays manually curated image shortcuts in a grid or horizontal row. */
final class MobiShop_Quick_Links_Block extends MobiShop_Block {

	public function get_type(): string {
		return 'quick_links';
	}

	public function get_label(): string {
		return __( 'Quick Links', 'mobi2app-connector' );
	}

	public function get_icon(): string {
		return 'dashicons-admin-links';
	}

	public function get_description(): string {
		return __( 'Image or icon shortcuts for categories, collections, searches, products, brands, or URLs.', 'mobi2app-connector' );
	}

	/** @return array<string,mixed> */
	public function get_default_settings(): array {
		return array(
			'title'       => '',
			'subtitle'    => '',
			'layout'      => 'carousel',
			'columns'     => 4,
			'image_shape' => 'circle',
			'item_size'   => 76,
			'gap'         => 12,
			'show_labels' => true,
			'label_color' => '#1F2933',
			'label_size'  => 13,
			'items'       => array(),
		);
	}

	/** @param array<string,mixed> $settings Raw settings. @return array<string,mixed> */
	public function sanitize_settings( array $settings ): array {
		$layout = sanitize_key( (string) ( $settings['layout'] ?? 'carousel' ) );
		$shape  = sanitize_key( (string) ( $settings['image_shape'] ?? 'circle' ) );
		$layout = in_array( $layout, array( 'carousel', 'grid', 'service' ), true ) ? $layout : 'carousel';
		$shape  = in_array( $shape, array( 'circle', 'rounded', 'square' ), true ) ? $shape : 'circle';
		$items  = isset( $settings['items'] ) && is_array( $settings['items'] ) ? $settings['items'] : array();
		$clean  = array();

		foreach ( $items as $item_index => $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}

			$image_url = $this->sanitize_http_url( $item['image_url'] ?? '' );
			$label     = sanitize_text_field( (string) ( $item['label'] ?? '' ) );

			if ( '' === $image_url || '' === $label ) {
				continue;
			}

			$action_type = sanitize_key( (string) ( $item['action_type'] ?? '' ) );
			if ( ! in_array( $action_type, array( '', 'product', 'category', 'collection', 'brand', 'brands', 'search', 'external' ), true ) ) {
				$action_type = '';
			}
			$item_id = sanitize_key( (string) ( $item['id'] ?? '' ) );
			if ( '' === $item_id ) {
				$item_id = 'quick_link_' . ( absint( $item_index ) + 1 );
			}

			$clean[] = array(
				'id'           => $item_id,
				'image_url'    => $image_url,
				'label'        => $label,
				'subtitle'     => sanitize_text_field( (string) ( $item['subtitle'] ?? '' ) ),
				'action_type'  => $action_type,
				'action_value' => 'external' === $action_type
					? $this->sanitize_http_url( $item['action_value'] ?? '' )
					: sanitize_text_field( (string) ( $item['action_value'] ?? '' ) ),
			);
		}

		return array(
			'title'       => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'    => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'layout'      => $layout,
			'columns'     => max( 2, min( 6, absint( $settings['columns'] ?? 4 ) ) ),
			'image_shape' => $shape,
			'item_size'   => max( 48, min( 140, absint( $settings['item_size'] ?? 76 ) ) ),
			'gap'         => max( 0, min( 32, absint( $settings['gap'] ?? 12 ) ) ),
			'show_labels' => ! empty( $settings['show_labels'] ),
			'label_color' => sanitize_hex_color( $settings['label_color'] ?? '' ) ?: '#1F2933',
			'label_size'  => max( 10, min( 22, absint( $settings['label_size'] ?? 13 ) ) ),
			'label_weight' => max( 400, min( 700, absint( $settings['label_weight'] ?? 700 ) ) ),
			'items'       => $clean,
		);
	}

	/** @param array<string,mixed> $settings Settings. @return array<string,mixed>|null */
	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings( wp_parse_args( $settings, $this->get_default_settings() ) );

		if ( empty( $settings['items'] ) ) {
			return null;
		}

		$items = array();
		foreach ( $settings['items'] as $item ) {
			$items[] = array(
				'id'        => $item['id'],
				'image_url' => $item['image_url'],
				'label'     => $item['label'],
				'subtitle'  => '' !== $item['subtitle'] ? $item['subtitle'] : null,
				'action'    => $this->build_action( $item['action_type'], $item['action_value'] ),
			);
		}

		return array(
			'title'       => $settings['title'],
			'subtitle'    => $settings['subtitle'],
			'layout'      => $settings['layout'],
			'columns'     => $settings['columns'],
			'image_shape' => $settings['image_shape'],
			'item_size'   => $settings['item_size'],
			'gap'         => $settings['gap'],
			'show_labels' => $settings['show_labels'],
			'label_color' => $settings['label_color'],
			'label_size'  => $settings['label_size'],
			'label_weight' => $settings['label_weight'],
			'items'       => $items,
		);
	}

	/** @param int $index Block index. @param array<string,mixed> $settings Settings. */
	public function render_settings( int $index, array $settings ): void {
		$settings = wp_parse_args( $settings, $this->get_default_settings() );
		$items    = isset( $settings['items'] ) && is_array( $settings['items'] ) ? array_values( $settings['items'] ) : array();
		if ( empty( $items ) ) {
			$items[] = $this->empty_item();
		}
		?>
		<div class="mobishop-builder-grid">
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Title', 'mobi2app-connector' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( (string) $settings['title'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Subtitle', 'mobi2app-connector' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( (string) $settings['subtitle'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Layout', 'mobi2app-connector' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]"><option value="carousel" <?php selected( 'carousel', $settings['layout'] ); ?>><?php esc_html_e( 'Horizontal row', 'mobi2app-connector' ); ?></option><option value="grid" <?php selected( 'grid', $settings['layout'] ); ?>><?php esc_html_e( 'Grid', 'mobi2app-connector' ); ?></option><option value="service" <?php selected( 'service', $settings['layout'] ); ?>><?php esc_html_e( 'Service actions', 'mobi2app-connector' ); ?></option></select></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Columns', 'mobi2app-connector' ); ?></label><input type="number" min="2" max="6" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Image Shape', 'mobi2app-connector' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_shape]"><option value="circle" <?php selected( 'circle', $settings['image_shape'] ); ?>><?php esc_html_e( 'Circle', 'mobi2app-connector' ); ?></option><option value="rounded" <?php selected( 'rounded', $settings['image_shape'] ); ?>><?php esc_html_e( 'Rounded', 'mobi2app-connector' ); ?></option><option value="square" <?php selected( 'square', $settings['image_shape'] ); ?>><?php esc_html_e( 'Square', 'mobi2app-connector' ); ?></option></select></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Image Size', 'mobi2app-connector' ); ?></label><input type="number" min="48" max="140" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][item_size]" value="<?php echo esc_attr( (string) $settings['item_size'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Gap', 'mobi2app-connector' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][gap]" value="<?php echo esc_attr( (string) $settings['gap'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Label Size', 'mobi2app-connector' ); ?></label><input type="number" min="10" max="22" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][label_size]" value="<?php echo esc_attr( (string) $settings['label_size'] ); ?>"></div>
            <input type="hidden" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][label_weight]" value="<?php echo esc_attr( (string) $settings['label_weight'] ); ?>">
			<div class="mobishop-builder-field"><label><?php esc_html_e( 'Label Color', 'mobi2app-connector' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][label_color]" value="<?php echo esc_attr( (string) $settings['label_color'] ); ?>"></div>
			<div class="mobishop-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_labels]" value="1" <?php checked( true, ! empty( $settings['show_labels'] ) ); ?>> <?php esc_html_e( 'Show Labels', 'mobi2app-connector' ); ?></label></div>
		</div>
		<div class="mobishop-repeatable-items mobishop-quick-link-items">
			<?php foreach ( $items as $item_index => $item ) : $this->render_item( $index, $item_index, $item ); endforeach; ?>
		</div>
		<p><button type="button" class="button mobishop-add-repeatable-item"><?php esc_html_e( 'Add Quick Link', 'mobi2app-connector' ); ?></button></p>
		<script type="text/html" class="tmpl-mobishop-repeatable-item"><?php $this->render_item( $index, '__ITEM_INDEX__', $this->empty_item() ); ?></script>
		<?php
	}

	/** @return array<string,mixed> */
	private function empty_item(): array {
		return array( 'id' => '', 'image_url' => '', 'label' => '', 'subtitle' => '', 'action_type' => '', 'action_value' => '' );
	}

	/** @param int $block_index Block index. @param int|string $item_index Item index. @param array<string,mixed> $item Item. */
	private function render_item( int $block_index, $item_index, array $item ): void {
		$item = wp_parse_args( $item, $this->empty_item() );
		?>
		<div class="mobishop-repeatable-item">
			<div class="mobishop-hero-block-item__header"><strong><?php esc_html_e( 'Quick Link', 'mobi2app-connector' ); ?></strong><button type="button" class="button-link-delete mobishop-remove-repeatable-item"><?php esc_html_e( 'Remove', 'mobi2app-connector' ); ?></button></div>
			<input type="hidden" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][id]" value="<?php echo esc_attr( (string) $item['id'] ); ?>">
			<div class="mobishop-builder-grid">
				<div class="mobishop-builder-field mobishop-builder-field--full mobishop-builder-field--media"><label><?php esc_html_e( 'Image', 'mobi2app-connector' ); ?></label><div class="mobishop-builder-media-field"><input type="url" class="mobishop-media-url" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][image_url]" value="<?php echo esc_attr( (string) $item['image_url'] ); ?>"><button type="button" class="button mobishop-select-media"><?php esc_html_e( 'Select Image', 'mobi2app-connector' ); ?></button></div><img class="mobishop-media-preview" src="<?php echo esc_url( (string) $item['image_url'] ); ?>" alt="" <?php echo empty( $item['image_url'] ) ? 'hidden' : ''; ?>></div>
				<div class="mobishop-builder-field"><label><?php esc_html_e( 'Label', 'mobi2app-connector' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][label]" value="<?php echo esc_attr( (string) $item['label'] ); ?>"></div>
				<div class="mobishop-builder-field"><label><?php esc_html_e( 'Subtitle', 'mobi2app-connector' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][subtitle]" value="<?php echo esc_attr( (string) $item['subtitle'] ); ?>"></div>
				<div class="mobishop-builder-field"><label><?php esc_html_e( 'Action Type', 'mobi2app-connector' ); ?></label><?php $this->render_action_select( $block_index, $item_index, (string) $item['action_type'] ); ?></div>
				<div class="mobishop-builder-field"><label><?php esc_html_e( 'Action Value', 'mobi2app-connector' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][action_value]" value="<?php echo esc_attr( (string) $item['action_value'] ); ?>"></div>
			</div>
		</div>
		<?php
	}

	private function render_action_select( int $block_index, $item_index, string $selected ): void {
		$actions = array( '' => __( 'No Action', 'mobi2app-connector' ), 'category' => __( 'Category', 'mobi2app-connector' ), 'collection' => __( 'Collection', 'mobi2app-connector' ), 'product' => __( 'Product', 'mobi2app-connector' ), 'brand' => __( 'Brand', 'mobi2app-connector' ), 'brands' => __( 'All Brands', 'mobi2app-connector' ), 'search' => __( 'Search', 'mobi2app-connector' ), 'external' => __( 'External URL', 'mobi2app-connector' ) );
		?><select name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][action_type]"><?php foreach ( $actions as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $selected ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select><?php
	}
}
