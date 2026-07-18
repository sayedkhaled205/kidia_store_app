<?php
/** Category Page Builder admin page. */
defined( 'ABSPATH' ) || exit;

$by_parent = array();
foreach ( $terms as $term ) {
	$by_parent[ (int) $term->parent ][] = $term;
}

$sort_terms = static function ( array &$items ) use ( $settings ): void {
	usort(
		$items,
		static function ( $left, $right ) use ( $settings ): int {
			$left_order  = isset( $settings[ $left->term_id ]['order'] ) ? (int) $settings[ $left->term_id ]['order'] : PHP_INT_MAX;
			$right_order = isset( $settings[ $right->term_id ]['order'] ) ? (int) $settings[ $right->term_id ]['order'] : PHP_INT_MAX;
			return $left_order === $right_order
				? strcasecmp( $left->name, $right->name )
				: $left_order <=> $right_order;
		}
	);
};
foreach ( $by_parent as &$siblings ) {
	$sort_terms( $siblings );
}
unset( $siblings );

$render_level = static function ( int $parent_id ) use ( &$render_level, $by_parent, $settings ): void {
	$children = $by_parent[ $parent_id ] ?? array();
	if ( empty( $children ) ) {
		return;
	}
	?>
	<ul class="kidia-category-list" data-parent-id="<?php echo esc_attr( (string) $parent_id ); ?>">
		<?php foreach ( $children as $index => $term ) :
			$id            = (int) $term->term_id;
			$setting       = is_array( $settings[ $id ] ?? null ) ? $settings[ $id ] : array();
			$image_id      = absint( $setting['image_id'] ?? 0 );
			$default_image = absint( get_term_meta( $id, 'thumbnail_id', true ) );
			$preview_id    = $image_id ?: $default_image;
			$image_url     = $preview_id ? wp_get_attachment_image_url( $preview_id, 'thumbnail' ) : '';
			$default_image_url = $default_image ? wp_get_attachment_image_url( $default_image, 'thumbnail' ) : '';
			$has_children  = ! empty( $by_parent[ $id ] );
			$image_size    = min( 120, max( 32, absint( $setting['image_size'] ?? 68 ) ) );
			?>
			<li class="kidia-category-row" data-term-id="<?php echo esc_attr( (string) $id ); ?>" data-term-name="<?php echo esc_attr( $term->name ); ?>" data-default-image="<?php echo esc_url( $default_image_url ); ?>">
				<div class="kidia-category-card">
					<span class="dashicons dashicons-move kidia-category-handle" aria-hidden="true"></span>
					<?php if ( $has_children ) : ?>
						<button type="button" class="button-link kidia-category-expand" aria-expanded="false" aria-label="<?php esc_attr_e( 'Expand subcategories', 'kidia-mobile-cms' ); ?>"><span class="dashicons dashicons-arrow-left-alt2"></span></button>
					<?php else : ?><span class="kidia-category-expand-placeholder"></span><?php endif; ?>
					<div class="kidia-category-image" style="--preview-size:<?php echo esc_attr( (string) min( 72, $image_size ) ); ?>px">
						<?php if ( $image_url ) : ?><img src="<?php echo esc_url( $image_url ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?>
					</div>
					<div class="kidia-category-name">
						<strong><?php echo esc_html( $term->name ); ?></strong>
						<small><?php echo esc_html( sprintf( __( '%d products · ID %d', 'kidia-mobile-cms' ), (int) $term->count, $id ) ); ?></small>
					</div>
					<input class="kidia-category-order" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][order]" value="<?php echo esc_attr( (string) $index ); ?>">
					<input class="kidia-category-image-id" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_id]" value="<?php echo esc_attr( (string) $image_id ); ?>">
					<button type="button" class="button kidia-category-settings-toggle" aria-expanded="false"><span class="dashicons dashicons-format-image"></span> <?php esc_html_e( 'Image settings', 'kidia-mobile-cms' ); ?></button>
					<label class="kidia-category-visibility">
						<input type="checkbox" name="categories[<?php echo esc_attr( (string) $id ); ?>][hidden]" value="1" <?php checked( ! empty( $setting['hidden'] ) ); ?>>
						<?php esc_html_e( 'Hide in app', 'kidia-mobile-cms' ); ?>
					</label>
					<div class="kidia-category-settings" hidden>
						<div class="kidia-category-image-actions">
							<button type="button" class="button button-secondary kidia-category-image-button"><?php esc_html_e( 'Choose image', 'kidia-mobile-cms' ); ?></button>
							<button type="button" class="button-link kidia-category-image-clear" <?php echo $image_id ? '' : 'hidden'; ?>><?php esc_html_e( 'Use WooCommerce image', 'kidia-mobile-cms' ); ?></button>
						</div>
						<label><?php esc_html_e( 'Size', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $image_size ); ?>px</span><input type="range" min="32" max="120" step="4" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_size]" value="<?php echo esc_attr( (string) $image_size ); ?>"></label>
						<label><?php esc_html_e( 'Shape', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][image_shape]"><option value="square" <?php selected( $setting['image_shape'] ?? '', 'square' ); ?>><?php esc_html_e( 'Square', 'kidia-mobile-cms' ); ?></option><option value="rounded" <?php selected( $setting['image_shape'] ?? 'rounded', 'rounded' ); ?>><?php esc_html_e( 'Rounded', 'kidia-mobile-cms' ); ?></option><option value="circle" <?php selected( $setting['image_shape'] ?? '', 'circle' ); ?>><?php esc_html_e( 'Circle', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><?php esc_html_e( 'Round amount', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) min( 50, max( 0, absint( $setting['image_radius'] ?? 18 ) ) ) ); ?>%</span><input type="range" min="0" max="50" step="1" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_radius]" value="<?php echo esc_attr( (string) min( 50, max( 0, absint( $setting['image_radius'] ?? 18 ) ) ) ); ?>"></label>
						<label><?php esc_html_e( 'Image fit', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][image_fit]"><option value="contain" <?php selected( $setting['image_fit'] ?? 'contain', 'contain' ); ?>><?php esc_html_e( 'Show complete image', 'kidia-mobile-cms' ); ?></option><option value="cover" <?php selected( $setting['image_fit'] ?? '', 'cover' ); ?>><?php esc_html_e( 'Fill and crop', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><?php esc_html_e( 'Effect', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][image_effect]"><option value="none" <?php selected( $setting['image_effect'] ?? 'none', 'none' ); ?>><?php esc_html_e( 'None', 'kidia-mobile-cms' ); ?></option><option value="shadow" <?php selected( $setting['image_effect'] ?? '', 'shadow' ); ?>><?php esc_html_e( 'Shadow', 'kidia-mobile-cms' ); ?></option><option value="grayscale" <?php selected( $setting['image_effect'] ?? '', 'grayscale' ); ?>><?php esc_html_e( 'Black and white', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><?php esc_html_e( 'Zoom', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) min( 150, max( 80, absint( $setting['image_scale'] ?? 100 ) ) ) ); ?>%</span><input type="range" min="80" max="150" step="5" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_scale]" value="<?php echo esc_attr( (string) min( 150, max( 80, absint( $setting['image_scale'] ?? 100 ) ) ) ); ?>"></label>
						<label><?php esc_html_e( 'Position', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][image_position]"><?php foreach ( array( 'center' => __( 'Center', 'kidia-mobile-cms' ), 'top' => __( 'Top', 'kidia-mobile-cms' ), 'bottom' => __( 'Bottom', 'kidia-mobile-cms' ), 'right' => __( 'Right', 'kidia-mobile-cms' ), 'left' => __( 'Left', 'kidia-mobile-cms' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $setting['image_position'] ?? 'center', $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
						<label><?php esc_html_e( 'Border width', 'kidia-mobile-cms' ); ?><input type="number" min="0" max="8" name="categories[<?php echo esc_attr( (string) $id ); ?>][border_width]" value="<?php echo esc_attr( (string) min( 8, absint( $setting['border_width'] ?? 0 ) ) ); ?>"></label>
						<label><?php esc_html_e( 'Border color', 'kidia-mobile-cms' ); ?><input type="color" name="categories[<?php echo esc_attr( (string) $id ); ?>][border_color]" value="<?php echo esc_attr( sanitize_hex_color( $setting['border_color'] ?? '' ) ?: '#DDE5E2' ); ?>"></label>
						<label><?php esc_html_e( 'Background', 'kidia-mobile-cms' ); ?><input type="color" name="categories[<?php echo esc_attr( (string) $id ); ?>][background_color]" value="<?php echo esc_attr( sanitize_hex_color( $setting['background_color'] ?? '' ) ?: '#FFFFFF' ); ?>"></label>
						<div class="kidia-settings-section-title"><?php esc_html_e( 'Text and spacing', 'kidia-mobile-cms' ); ?></div>
						<label><?php esc_html_e( 'Image–text gap', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) min( 40, max( 0, absint( $setting['image_text_gap'] ?? 10 ) ) ) ); ?>px</span><input type="range" min="0" max="40" step="1" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_text_gap]" value="<?php echo esc_attr( (string) min( 40, max( 0, absint( $setting['image_text_gap'] ?? 10 ) ) ) ); ?>"></label>
						<label><?php esc_html_e( 'Font size', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) min( 30, max( 10, absint( $setting['font_size'] ?? 16 ) ) ) ); ?>px</span><input type="range" min="10" max="30" step="1" name="categories[<?php echo esc_attr( (string) $id ); ?>][font_size]" value="<?php echo esc_attr( (string) min( 30, max( 10, absint( $setting['font_size'] ?? 16 ) ) ) ); ?>"></label>
						<label><?php esc_html_e( 'Font color', 'kidia-mobile-cms' ); ?><input type="color" name="categories[<?php echo esc_attr( (string) $id ); ?>][font_color]" value="<?php echo esc_attr( sanitize_hex_color( $setting['font_color'] ?? '' ) ?: '#1F2933' ); ?>"></label>
						<label><?php esc_html_e( 'Font weight', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][font_weight]"><?php foreach ( array( 400 => __( 'Regular', 'kidia-mobile-cms' ), 500 => __( 'Medium', 'kidia-mobile-cms' ), 600 => __( 'Semi bold', 'kidia-mobile-cms' ), 700 => __( 'Bold', 'kidia-mobile-cms' ), 800 => __( 'Extra bold', 'kidia-mobile-cms' ), 900 => __( 'Black', 'kidia-mobile-cms' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( absint( $setting['font_weight'] ?? 800 ), $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
						<label><?php esc_html_e( 'Text alignment', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][text_align]"><option value="start" <?php selected( $setting['text_align'] ?? 'start', 'start' ); ?>><?php esc_html_e( 'Start', 'kidia-mobile-cms' ); ?></option><option value="center" <?php selected( $setting['text_align'] ?? '', 'center' ); ?>><?php esc_html_e( 'Center', 'kidia-mobile-cms' ); ?></option><option value="end" <?php selected( $setting['text_align'] ?? '', 'end' ); ?>><?php esc_html_e( 'End', 'kidia-mobile-cms' ); ?></option></select></label>
						<label><?php esc_html_e( 'Maximum lines', 'kidia-mobile-cms' ); ?><select name="categories[<?php echo esc_attr( (string) $id ); ?>][text_max_lines]"><?php foreach ( array( 1, 2, 3 ) as $value ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( absint( $setting['text_max_lines'] ?? 2 ), $value ); ?>><?php echo esc_html( (string) $value ); ?></option><?php endforeach; ?></select></label>
						<label><?php esc_html_e( 'Line height', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( number_format_i18n( min( 200, max( 100, absint( $setting['line_height'] ?? 125 ) ) ) / 100, 2 ) ); ?></span><input type="range" min="100" max="200" step="5" name="categories[<?php echo esc_attr( (string) $id ); ?>][line_height]" value="<?php echo esc_attr( (string) min( 200, max( 100, absint( $setting['line_height'] ?? 125 ) ) ) ); ?>"></label>
					</div>
				</div>
				<?php if ( $has_children ) : ?><div class="kidia-category-children" hidden><?php $render_level( $id ); ?></div><?php endif; ?>
			</li>
		<?php endforeach; ?>
	</ul>
	<?php
};
?>

<div class="wrap kidia-category-builder">
	<h1><?php esc_html_e( 'Category Page Builder', 'kidia-mobile-cms' ); ?></h1>
	<p class="description"><?php esc_html_e( 'Drag categories and subcategories within their level, replace their app image, or hide a complete branch.', 'kidia-mobile-cms' ); ?></p>
	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Category page saved successfully.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<div class="kidia-category-workspace">
		<aside class="kidia-category-mobile-preview" aria-label="<?php echo esc_attr__( 'Live category preview', 'kidia-mobile-cms' ); ?>">
			<div class="kidia-category-phone">
				<div class="kidia-category-phone__speaker"></div>
				<div class="kidia-category-phone__screen">
					<div class="kidia-category-phone__status"><span>9:41</span><span>● ◒ ▰</span></div>
					<div class="kidia-category-phone__header"><?php esc_html_e( 'Categories', 'kidia-mobile-cms' ); ?></div>
					<div id="kidia-category-live-preview" class="kidia-category-phone__content"></div>
				</div>
			</div>
			<p><?php esc_html_e( 'Live preview — category changes appear instantly.', 'kidia-mobile-cms' ); ?></p>
		</aside>
		<div class="kidia-category-editor">
	<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
		<input type="hidden" name="action" value="kidia_mobile_save_category_builder">
		<?php wp_nonce_field( 'kidia_mobile_save_category_builder', 'kidia_mobile_category_builder_nonce' ); ?>
		<div class="kidia-category-toolbar">
			<strong><?php echo esc_html( sprintf( __( '%d WooCommerce categories', 'kidia-mobile-cms' ), count( $terms ) ) ); ?></strong>
			<?php submit_button( __( 'Save Category Page', 'kidia-mobile-cms' ), 'primary', 'submit', false ); ?>
		</div>
		<?php if ( empty( $terms ) ) : ?><div class="notice notice-warning inline"><p><?php esc_html_e( 'No WooCommerce product categories were found.', 'kidia-mobile-cms' ); ?></p></div><?php else : ?><?php $render_level( 0 ); ?><?php endif; ?>
	</form>
		</div>
	</div>
</div>
