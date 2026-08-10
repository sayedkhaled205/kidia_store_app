<?php
/**
 * Banner Grid Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Banner_Grid_Block', false ) ) {
	return;
}

/** Displays multiple editorial or promotional images in flexible groups. */
final class Kidia_Mobile_Banner_Grid_Block extends Kidia_Mobile_Block {

	public function get_type(): string { return 'banner_grid'; }
	public function get_label(): string { return __( 'Banner Grid', 'mobishop' ); }
	public function get_icon(): string { return 'dashicons-layout'; }
	public function get_description(): string { return __( 'Equal, featured, or mosaic promotional banner groups.', 'mobishop' ); }

	/** @return array<string,mixed> */
	public function get_default_settings(): array {
		return array(
			'title' => '', 'subtitle' => '', 'layout' => 'equal', 'columns' => 2,
			'gap' => 10, 'aspect_ratio' => 1, 'border_radius' => 16,
			'image_fit' => 'cover', 'overlay_strength' => 35, 'text_color' => '#FFFFFF',
			'items' => array(),
		);
	}

	/** @param array<string,mixed> $settings Raw settings. @return array<string,mixed> */
	public function sanitize_settings( array $settings ): array {
		$layout = sanitize_key( (string) ( $settings['layout'] ?? 'equal' ) );
		$fit    = sanitize_key( (string) ( $settings['image_fit'] ?? 'cover' ) );
		$layout = in_array( $layout, array( 'equal', 'featured', 'mosaic', 'carousel' ), true ) ? $layout : 'equal';
		$fit    = in_array( $fit, array( 'cover', 'contain' ), true ) ? $fit : 'cover';
		$items  = isset( $settings['items'] ) && is_array( $settings['items'] ) ? $settings['items'] : array();
		$clean  = array();

		foreach ( $items as $item_index => $item ) {
			if ( ! is_array( $item ) ) { continue; }
			$image_url = $this->sanitize_http_url( $item['image_url'] ?? '' );
			if ( '' === $image_url ) { continue; }
			$action_type = sanitize_key( (string) ( $item['action_type'] ?? '' ) );
			if ( ! in_array( $action_type, array( '', 'product', 'category', 'collection', 'brand', 'brands', 'search', 'external' ), true ) ) { $action_type = ''; }
			$item_id = sanitize_key( (string) ( $item['id'] ?? '' ) );
			if ( '' === $item_id ) { $item_id = 'banner_' . ( absint( $item_index ) + 1 ); }
			$clean[] = array(
				'id' => $item_id,
				'enabled' => isset( $item['enabled'] ) ? (bool) $item['enabled'] : true,
				'image_url' => $image_url,
				'title' => sanitize_text_field( (string) ( $item['title'] ?? '' ) ),
				'subtitle' => sanitize_text_field( (string) ( $item['subtitle'] ?? '' ) ),
				'button_label' => sanitize_text_field( (string) ( $item['button_label'] ?? '' ) ),
				'action_type' => $action_type,
				'action_value' => 'external' === $action_type ? $this->sanitize_http_url( $item['action_value'] ?? '' ) : sanitize_text_field( (string) ( $item['action_value'] ?? '' ) ),
			);
		}

		return array(
			'title' => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle' => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'layout' => $layout,
			'columns' => max( 1, min( 3, absint( $settings['columns'] ?? 2 ) ) ),
			'gap' => max( 0, min( 32, absint( $settings['gap'] ?? 10 ) ) ),
			'aspect_ratio' => max( 0.45, min( 5, (float) ( $settings['aspect_ratio'] ?? 1 ) ) ),
			'border_radius' => max( 0, min( 48, absint( $settings['border_radius'] ?? 16 ) ) ),
			'image_fit' => $fit,
			'overlay_strength' => max( 0, min( 90, absint( $settings['overlay_strength'] ?? 35 ) ) ),
			'text_color' => sanitize_hex_color( $settings['text_color'] ?? '' ) ?: '#FFFFFF',
			'items' => $clean,
		);
	}

	/** @param array<string,mixed> $settings Settings. @return array<string,mixed>|null */
	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings( wp_parse_args( $settings, $this->get_default_settings() ) );
		if ( empty( $settings['items'] ) ) { return null; }
		$items = array();
		foreach ( $settings['items'] as $item ) {
			if ( empty( $item['enabled'] ) ) { continue; }
			$items[] = array(
				'id' => $item['id'], 'image_url' => $item['image_url'],
				'title' => '' !== $item['title'] ? $item['title'] : null,
				'subtitle' => '' !== $item['subtitle'] ? $item['subtitle'] : null,
				'button_label' => '' !== $item['button_label'] ? $item['button_label'] : null,
				'action' => $this->build_action( $item['action_type'], $item['action_value'] ),
			);
		}
		return array(
			'title' => $settings['title'], 'subtitle' => $settings['subtitle'],
			'layout' => $settings['layout'], 'columns' => $settings['columns'], 'gap' => $settings['gap'],
			'aspect_ratio' => $settings['aspect_ratio'], 'border_radius' => $settings['border_radius'],
			'image_fit' => $settings['image_fit'], 'overlay_strength' => $settings['overlay_strength'],
			'text_color' => $settings['text_color'], 'items' => $items,
		);
	}

	/** @param int $index Block index. @param array<string,mixed> $settings Settings. */
	public function render_settings( int $index, array $settings ): void {
		$settings = wp_parse_args( $settings, $this->get_default_settings() );
		$items = isset( $settings['items'] ) && is_array( $settings['items'] ) ? array_values( $settings['items'] ) : array();
		if ( empty( $items ) ) { $items[] = $this->empty_item(); }
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Title', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( (string) $settings['title'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Subtitle', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( (string) $settings['subtitle'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Layout', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][layout]"><option value="equal" <?php selected( 'equal', $settings['layout'] ); ?>><?php esc_html_e( 'Equal Grid', 'mobishop' ); ?></option><option value="featured" <?php selected( 'featured', $settings['layout'] ); ?>><?php esc_html_e( 'Featured First', 'mobishop' ); ?></option><option value="mosaic" <?php selected( 'mosaic', $settings['layout'] ); ?>><?php esc_html_e( 'Mosaic', 'mobishop' ); ?></option><option value="carousel" <?php selected( 'carousel', $settings['layout'] ); ?>><?php esc_html_e( 'Horizontal cards', 'mobishop' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Columns', 'mobishop' ); ?></label><input type="number" min="1" max="3" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]" value="<?php echo esc_attr( (string) $settings['columns'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Aspect Ratio', 'mobishop' ); ?></label><input type="number" min="0.45" max="5" step="0.05" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][aspect_ratio]" value="<?php echo esc_attr( (string) $settings['aspect_ratio'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Gap', 'mobishop' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][gap]" value="<?php echo esc_attr( (string) $settings['gap'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Border Radius', 'mobishop' ); ?></label><input type="number" min="0" max="48" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][border_radius]" value="<?php echo esc_attr( (string) $settings['border_radius'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Image Fit', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_fit]"><option value="cover" <?php selected( 'cover', $settings['image_fit'] ); ?>><?php esc_html_e( 'Cover', 'mobishop' ); ?></option><option value="contain" <?php selected( 'contain', $settings['image_fit'] ); ?>><?php esc_html_e( 'Contain', 'mobishop' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Overlay Strength %', 'mobishop' ); ?></label><input type="number" min="0" max="90" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][overlay_strength]" value="<?php echo esc_attr( (string) $settings['overlay_strength'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Text Color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][text_color]" value="<?php echo esc_attr( (string) $settings['text_color'] ); ?>"></div>
		</div>
		<div class="kidia-repeatable-items kidia-banner-grid-items"><?php foreach ( $items as $item_index => $item ) : $this->render_item( $index, $item_index, $item ); endforeach; ?></div>
		<script type="text/html" class="tmpl-kidia-repeatable-item"><?php $this->render_item( $index, '__ITEM_INDEX__', $this->empty_item() ); ?></script>
		<?php
	}

	/** @return array<string,mixed> */
	private function empty_item(): array { return array( 'id' => '', 'enabled' => true, 'image_url' => '', 'title' => '', 'subtitle' => '', 'button_label' => '', 'action_type' => '', 'action_value' => '' ); }

	/** @param int $block_index Block index. @param int|string $item_index Item index. @param array<string,mixed> $item Item. */
	private function render_item( int $block_index, $item_index, array $item ): void {
		$item = wp_parse_args( $item, $this->empty_item() );
		$actions = array( '' => __( 'No Action', 'mobishop' ), 'category' => __( 'Category', 'mobishop' ), 'collection' => __( 'Collection', 'mobishop' ), 'product' => __( 'Product', 'mobishop' ), 'brand' => __( 'Brand', 'mobishop' ), 'brands' => __( 'All Brands', 'mobishop' ), 'search' => __( 'Search', 'mobishop' ), 'external' => __( 'External URL', 'mobishop' ) );
		?>
		<div class="kidia-repeatable-item kidia-banner-editor-item">
			<div class="kidia-hero-block-item__header"><strong><?php esc_html_e( 'Banner', 'mobishop' ); ?></strong><div class="kidia-repeatable-item-actions"><button type="button" class="button kidia-repeatable-remove kidia-remove-repeatable-item"><?php esc_html_e( 'Remove', 'mobishop' ); ?></button><button type="button" class="button kidia-repeatable-add kidia-add-repeatable-item"><?php esc_html_e( '+ Add Banner', 'mobishop' ); ?></button><label class="kidia-page-master-toggle kidia-slider-item-toggle kidia-banner-item-toggle" aria-label="<?php echo esc_attr( __( 'Turn banner on or off', 'mobishop' ) ); ?>"><input type="hidden" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][enabled]" value="0"><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][enabled]" value="1" <?php checked( true, (bool) $item['enabled'] ); ?>><span class="kidia-toggle-state"></span></label></div></div>
			<input type="hidden" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][id]" value="<?php echo esc_attr( (string) $item['id'] ); ?>">
			<div class="kidia-builder-grid">
				<div class="kidia-builder-field kidia-repeatable-field--image-url"><label><?php esc_html_e( 'Image URL', 'mobishop' ); ?></label><input type="url" class="kidia-media-url" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][image_url]" value="<?php echo esc_attr( (string) $item['image_url'] ); ?>"></div>
				<div class="kidia-builder-field kidia-repeatable-field--title"><label><?php esc_html_e( 'Title', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][title]" value="<?php echo esc_attr( (string) $item['title'] ); ?>"></div>
				<div class="kidia-builder-field kidia-builder-field--media kidia-repeatable-field--media"><button type="button" class="button kidia-select-media"><?php esc_html_e( 'Select Image', 'mobishop' ); ?></button><img class="kidia-media-preview" src="<?php echo esc_url( (string) $item['image_url'] ); ?>" alt="" <?php echo empty( $item['image_url'] ) ? 'hidden' : ''; ?>></div>
				<div class="kidia-builder-field kidia-repeatable-field--subtitle"><label><?php esc_html_e( 'Subtitle', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][subtitle]" value="<?php echo esc_attr( (string) $item['subtitle'] ); ?>"></div>
				<div class="kidia-builder-field kidia-repeatable-field--button-label"><label><?php esc_html_e( 'Button Label', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][button_label]" value="<?php echo esc_attr( (string) $item['button_label'] ); ?>"></div>
				<div class="kidia-builder-field kidia-repeatable-field--action-value"><label><?php esc_html_e( 'Action Value', 'mobishop' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][action_value]" value="<?php echo esc_attr( (string) $item['action_value'] ); ?>"></div>
				<div class="kidia-builder-field kidia-repeatable-field--action-type"><label><?php esc_html_e( 'Action Type', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][action_type]"><?php foreach ( $actions as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $item['action_type'] ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></div>
			</div>
		</div>
		<?php
	}
}
