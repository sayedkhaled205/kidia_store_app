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
			return $left_order === $right_order ? strcasecmp( $left->name, $right->name ) : $left_order <=> $right_order;
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
			$id                = (int) $term->term_id;
			$setting           = is_array( $settings[ $id ] ?? null ) ? $settings[ $id ] : array();
			$image_id          = absint( $setting['image_id'] ?? 0 );
			$default_image     = absint( get_term_meta( $id, 'thumbnail_id', true ) );
			$preview_id        = $image_id ?: $default_image;
			$image_url         = $preview_id ? wp_get_attachment_image_url( $preview_id, 'thumbnail' ) : '';
			$default_image_url = $default_image ? wp_get_attachment_image_url( $default_image, 'thumbnail' ) : '';
			$has_children      = ! empty( $by_parent[ $id ] );
			$app_name          = (string) ( $setting['name'] ?? '' );
			?>
			<li class="kidia-category-row" data-term-id="<?php echo esc_attr( (string) $id ); ?>" data-default-name="<?php echo esc_attr( $term->name ); ?>" data-default-image="<?php echo esc_url( $default_image_url ); ?>">
				<div class="kidia-category-card">
					<span class="dashicons dashicons-move kidia-category-handle" aria-hidden="true"></span>
					<div class="kidia-category-image">
						<?php if ( $image_url ) : ?><img src="<?php echo esc_url( $image_url ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?>
					</div>
					<div class="kidia-category-name">
						<label for="kidia-category-name-<?php echo esc_attr( (string) $id ); ?>"><?php esc_html_e( 'App display name', 'kidia-mobile-cms' ); ?></label>
						<input id="kidia-category-name-<?php echo esc_attr( (string) $id ); ?>" class="kidia-category-name-input" type="text" name="categories[<?php echo esc_attr( (string) $id ); ?>][name]" value="<?php echo esc_attr( $app_name ); ?>" placeholder="<?php echo esc_attr( $term->name ); ?>">
						<small><?php echo esc_html( sprintf( __( 'WooCommerce: %1$s · %2$d products · ID %3$d', 'kidia-mobile-cms' ), $term->name, (int) $term->count, $id ) ); ?></small>
					</div>
					<input class="kidia-category-order" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][order]" value="<?php echo esc_attr( (string) $index ); ?>">
					<input class="kidia-category-image-id" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_id]" value="<?php echo esc_attr( (string) $image_id ); ?>">
					<div class="kidia-category-image-actions">
						<button type="button" class="button button-secondary kidia-category-image-button<?php echo $image_id ? ' is-active' : ''; ?>" aria-pressed="<?php echo $image_id ? 'true' : 'false'; ?>"><?php esc_html_e( 'Change image', 'kidia-mobile-cms' ); ?></button>
						<button type="button" class="button button-secondary kidia-category-image-clear<?php echo $image_id ? '' : ' is-active'; ?>" aria-pressed="<?php echo $image_id ? 'false' : 'true'; ?>"><?php esc_html_e( 'Use WooCommerce image', 'kidia-mobile-cms' ); ?></button>
					</div>
					<label class="kidia-category-visibility kidia-page-master-toggle">
						<input type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][hidden]" value="1">
						<input type="checkbox" name="categories[<?php echo esc_attr( (string) $id ); ?>][hidden]" value="0" <?php checked( empty( $setting['hidden'] ) ); ?>>
						<span class="kidia-toggle-state"></span>
					</label>
					<?php if ( $has_children ) : ?>
						<button type="button" class="button kidia-category-expand" aria-expanded="false" aria-label="<?php esc_attr_e( 'Expand subcategories', 'kidia-mobile-cms' ); ?>"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
					<?php else : ?><span class="kidia-category-expand-placeholder"></span><?php endif; ?>
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
	<p class="description"><?php esc_html_e( 'Control the Category element once, then reorder, show, rename or replace the image of each category for the app only.', 'kidia-mobile-cms' ); ?></p>
	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Category page saved successfully.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<div class="kidia-category-workspace">
		<aside class="kidia-category-mobile-preview" aria-label="<?php echo esc_attr__( 'Live category preview', 'kidia-mobile-cms' ); ?>">
			<div class="kidia-category-phone">
				<div class="kidia-category-phone__speaker"></div>
				<div class="kidia-category-phone__screen">
					<div id="kidia-category-live-preview" class="kidia-category-phone__content"></div>
				</div>
			</div>
			<p><?php esc_html_e( 'Live preview — scroll it to preview the collapsed header.', 'kidia-mobile-cms' ); ?></p>
		</aside>
		<div class="kidia-category-editor">
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
				<input type="hidden" name="action" value="kidia_mobile_save_category_builder">
				<?php wp_nonce_field( 'kidia_mobile_save_category_builder', 'kidia_mobile_category_builder_nonce' ); ?>
				<div class="kidia-category-toolbar">
					<strong><?php echo esc_html( sprintf( __( '%d WooCommerce categories', 'kidia-mobile-cms' ), count( $terms ) ) ); ?></strong>
					<?php submit_button( __( 'Save Category Page', 'kidia-mobile-cms' ), 'primary', 'submit', false ); ?>
				</div>

				<?php $chrome_layout = $category_layout; $chrome_part = 'header'; $chrome_page = 'category'; include KIDIA_MOBILE_CMS_PATH . 'admin/pages/fixed-chrome-card.php'; ?>

				<section class="kidia-page-card kidia-category-element" data-element="category">
					<div class="kidia-page-card__header">
						<div class="kidia-page-card__identity"><span class="dashicons dashicons-category"></span><strong><?php esc_html_e( 'Category', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'All category and subcategory content', 'kidia-mobile-cms' ); ?></small></div>
						<div class="kidia-card-actions"><span class="kidia-card-action-placeholder kidia-card-action--primary" aria-hidden="true"></span><span class="kidia-card-action-placeholder kidia-card-action--secondary" aria-hidden="true"></span><button type="button" class="button kidia-page-expand kidia-category-element-expand kidia-card-action kidia-card-action--expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button><label class="kidia-page-master-toggle kidia-card-action kidia-card-action--toggle"><input type="hidden" name="category_element_enabled" value="0"><input class="kidia-category-element-enabled" type="checkbox" name="category_element_enabled" value="1" <?php checked( $category_enabled ); ?>><span class="kidia-toggle-state"></span></label></div>
					</div>
					<div class="kidia-page-card__body" hidden>
						<section class="kidia-category-general">
							<h3><?php esc_html_e( 'General Settings', 'kidia-mobile-cms' ); ?></h3>
							<p><?php esc_html_e( 'These appearance settings apply to every category and subcategory.', 'kidia-mobile-cms' ); ?></p>
							<div class="kidia-category-general-fields">
								<div class="kidia-settings-section-title"><?php esc_html_e( 'Layout & Spacing', 'kidia-mobile-cms' ); ?></div>
								<label><?php esc_html_e( 'Layout', 'kidia-mobile-cms' ); ?><select name="category_general[category_layout]">
									<?php foreach ( array( 'default' => __( 'Default Layout', 'kidia-mobile-cms' ), 'visual_grid' => __( 'Two-column Cards', 'kidia-mobile-cms' ), 'circular_grid' => __( 'Circular Grid', 'kidia-mobile-cms' ), 'compact_grid' => __( 'Compact Grid', 'kidia-mobile-cms' ), 'sidebar' => __( 'Sidebar & Subcategories', 'kidia-mobile-cms' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $category_general['category_layout'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?>
								</select></label>
								<label><?php esc_html_e( 'Grid columns', 'kidia-mobile-cms' ); ?><select name="category_general[grid_columns]"><?php foreach ( array( 2, 3, 4 ) as $value ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( $category_general['grid_columns'], $value ); ?>><?php echo esc_html( (string) $value ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Card radius', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['card_radius'] ); ?>px</span><input type="range" min="0" max="32" step="1" name="category_general[card_radius]" value="<?php echo esc_attr( (string) $category_general['card_radius'] ); ?>"></label>
								<label><?php esc_html_e( 'Card spacing', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['card_gap'] ); ?>px</span><input type="range" min="0" max="24" step="1" name="category_general[card_gap]" value="<?php echo esc_attr( (string) $category_general['card_gap'] ); ?>"></label>
								<label><?php esc_html_e( 'Card width', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['card_width_percent'] ); ?>%</span><input type="range" min="40" max="100" step="1" name="category_general[card_width_percent]" value="<?php echo esc_attr( (string) $category_general['card_width_percent'] ); ?>"></label>
								<label><?php esc_html_e( 'Card height (0 = automatic)', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['card_height'] ); ?>px</span><input type="range" min="0" max="320" step="4" name="category_general[card_height]" value="<?php echo esc_attr( (string) $category_general['card_height'] ); ?>"></label>
								<label><?php esc_html_e( 'Merge up', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['margin_top'] ); ?>px</span><input type="range" min="0" max="80" name="category_general[margin_top]" value="<?php echo esc_attr( (string) $category_general['margin_top'] ); ?>"></label>
								<label><?php esc_html_e( 'Merge down', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['margin_bottom'] ); ?>px</span><input type="range" min="0" max="80" name="category_general[margin_bottom]" value="<?php echo esc_attr( (string) $category_general['margin_bottom'] ); ?>"></label>
								<label><?php esc_html_e( 'Space up', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['space_up'] ); ?>px</span><input type="range" min="0" max="80" name="category_general[space_up]" value="<?php echo esc_attr( (string) $category_general['space_up'] ); ?>"></label>
								<label><?php esc_html_e( 'Space down', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['space_down'] ); ?>px</span><input type="range" min="0" max="80" name="category_general[space_down]" value="<?php echo esc_attr( (string) $category_general['space_down'] ); ?>"></label>
								<div class="kidia-settings-section-title"><?php esc_html_e( 'Colors & Appearance', 'kidia-mobile-cms' ); ?></div>
								<label><?php esc_html_e( 'Page background', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[page_background_color]" value="<?php echo esc_attr( $category_general['page_background_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Background color', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[element_background_color]" value="<?php echo esc_attr( $category_general['element_background_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Card style', 'kidia-mobile-cms' ); ?><select name="category_general[card_style]"><option value="minimal" <?php selected( 'minimal', $category_general['card_style'] ); ?>><?php esc_html_e( 'Minimal', 'kidia-mobile-cms' ); ?></option><option value="no_shadow" <?php selected( 'no_shadow', $category_general['card_style'] ); ?>><?php esc_html_e( 'No shadow', 'kidia-mobile-cms' ); ?></option><option value="outlined" <?php selected( 'outlined', $category_general['card_style'] ); ?>><?php esc_html_e( 'Outlined', 'kidia-mobile-cms' ); ?></option><option value="elevated" <?php selected( 'elevated', $category_general['card_style'] ); ?>><?php esc_html_e( 'Elevated', 'kidia-mobile-cms' ); ?></option></select></label>
								<label><?php esc_html_e( 'Card background', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[card_background_color]" value="<?php echo esc_attr( $category_general['card_background_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow color', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[card_shadow_color]" value="<?php echo esc_attr( $category_general['card_shadow_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow strength', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['card_shadow_strength'] ); ?>%</span><input type="range" min="0" max="40" name="category_general[card_shadow_strength]" value="<?php echo esc_attr( (string) $category_general['card_shadow_strength'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow blur', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['card_shadow_blur'] ); ?>px</span><input type="range" min="0" max="40" name="category_general[card_shadow_blur]" value="<?php echo esc_attr( (string) $category_general['card_shadow_blur'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow vertical offset', 'kidia-mobile-cms' ); ?><input type="number" min="-20" max="20" name="category_general[card_shadow_offset_y]" value="<?php echo esc_attr( (string) $category_general['card_shadow_offset_y'] ); ?>"></label>
								<label class="kidia-category-toggle-field"><b><?php esc_html_e( 'Show arrow', 'kidia-mobile-cms' ); ?></b><span class="kidia-page-master-toggle"><input type="hidden" name="category_general[show_arrow]" value="0"><input type="checkbox" name="category_general[show_arrow]" value="1" <?php checked( ! empty( $category_general['show_arrow'] ) ); ?>><span class="kidia-toggle-state"></span></span></label>
								<div class="kidia-settings-section-title"><?php esc_html_e( 'Image size & shape', 'kidia-mobile-cms' ); ?></div>
								<label><?php esc_html_e( 'Size', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['image_size'] ); ?>px</span><input type="range" min="32" max="120" step="4" name="category_general[image_size]" value="<?php echo esc_attr( (string) $category_general['image_size'] ); ?>"></label>
								<label><?php esc_html_e( 'Shape', 'kidia-mobile-cms' ); ?><select name="category_general[image_shape]"><option value="square" <?php selected( $category_general['image_shape'], 'square' ); ?>><?php esc_html_e( 'Square', 'kidia-mobile-cms' ); ?></option><option value="rounded" <?php selected( $category_general['image_shape'], 'rounded' ); ?>><?php esc_html_e( 'Rounded', 'kidia-mobile-cms' ); ?></option><option value="circle" <?php selected( $category_general['image_shape'], 'circle' ); ?>><?php esc_html_e( 'Circle', 'kidia-mobile-cms' ); ?></option></select></label>
								<label><?php esc_html_e( 'Round amount', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['image_radius'] ); ?>%</span><input type="range" min="0" max="50" step="1" name="category_general[image_radius]" value="<?php echo esc_attr( (string) $category_general['image_radius'] ); ?>"></label>
								<label><?php esc_html_e( 'Image fit', 'kidia-mobile-cms' ); ?><select name="category_general[image_fit]"><option value="contain" <?php selected( $category_general['image_fit'], 'contain' ); ?>><?php esc_html_e( 'Show complete image', 'kidia-mobile-cms' ); ?></option><option value="cover" <?php selected( $category_general['image_fit'], 'cover' ); ?>><?php esc_html_e( 'Fill and crop', 'kidia-mobile-cms' ); ?></option></select></label>
								<label><?php esc_html_e( 'Effect', 'kidia-mobile-cms' ); ?><select name="category_general[image_effect]"><option value="none" <?php selected( $category_general['image_effect'], 'none' ); ?>><?php esc_html_e( 'None', 'kidia-mobile-cms' ); ?></option><option value="shadow" <?php selected( $category_general['image_effect'], 'shadow' ); ?>><?php esc_html_e( 'Shadow', 'kidia-mobile-cms' ); ?></option><option value="grayscale" <?php selected( $category_general['image_effect'], 'grayscale' ); ?>><?php esc_html_e( 'Black and white', 'kidia-mobile-cms' ); ?></option></select></label>
								<label><?php esc_html_e( 'Zoom', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['image_scale'] ); ?>%</span><input type="range" min="80" max="150" step="5" name="category_general[image_scale]" value="<?php echo esc_attr( (string) $category_general['image_scale'] ); ?>"></label>
								<label><?php esc_html_e( 'Position', 'kidia-mobile-cms' ); ?><select name="category_general[image_position]"><?php foreach ( array( 'center' => __( 'Center', 'kidia-mobile-cms' ), 'top' => __( 'Top', 'kidia-mobile-cms' ), 'bottom' => __( 'Bottom', 'kidia-mobile-cms' ), 'right' => __( 'Right', 'kidia-mobile-cms' ), 'left' => __( 'Left', 'kidia-mobile-cms' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $category_general['image_position'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Border width', 'kidia-mobile-cms' ); ?><input type="number" min="0" max="8" name="category_general[border_width]" value="<?php echo esc_attr( (string) $category_general['border_width'] ); ?>"></label>
								<label><?php esc_html_e( 'Border color', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[border_color]" value="<?php echo esc_attr( $category_general['border_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Image background', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[background_color]" value="<?php echo esc_attr( $category_general['background_color'] ); ?>"></label>
								<div class="kidia-settings-section-title"><?php esc_html_e( 'Text and spacing', 'kidia-mobile-cms' ); ?></div>
								<label><?php esc_html_e( 'Image–text gap', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['image_text_gap'] ); ?>px</span><input type="range" min="0" max="40" step="1" name="category_general[image_text_gap]" value="<?php echo esc_attr( (string) $category_general['image_text_gap'] ); ?>"></label>
								<label><?php esc_html_e( 'Font size', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( (string) $category_general['font_size'] ); ?>px</span><input type="range" min="10" max="30" step="1" name="category_general[font_size]" value="<?php echo esc_attr( (string) $category_general['font_size'] ); ?>"></label>
								<label><?php esc_html_e( 'Font color', 'kidia-mobile-cms' ); ?><input type="color" name="category_general[font_color]" value="<?php echo esc_attr( $category_general['font_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Font weight', 'kidia-mobile-cms' ); ?><select name="category_general[font_weight]"><?php foreach ( array( 400 => __( 'Regular', 'kidia-mobile-cms' ), 500 => __( 'Medium', 'kidia-mobile-cms' ), 600 => __( 'Semi bold', 'kidia-mobile-cms' ), 700 => __( 'Bold', 'kidia-mobile-cms' ), 800 => __( 'Extra bold', 'kidia-mobile-cms' ), 900 => __( 'Black', 'kidia-mobile-cms' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( $category_general['font_weight'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Text alignment', 'kidia-mobile-cms' ); ?><select name="category_general[text_align]"><option value="start" <?php selected( $category_general['text_align'], 'start' ); ?>><?php esc_html_e( 'Start', 'kidia-mobile-cms' ); ?></option><option value="center" <?php selected( $category_general['text_align'], 'center' ); ?>><?php esc_html_e( 'Center', 'kidia-mobile-cms' ); ?></option><option value="end" <?php selected( $category_general['text_align'], 'end' ); ?>><?php esc_html_e( 'End', 'kidia-mobile-cms' ); ?></option></select></label>
								<label><?php esc_html_e( 'Maximum lines', 'kidia-mobile-cms' ); ?><select name="category_general[text_max_lines]"><?php foreach ( array( 1, 2, 3 ) as $value ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( $category_general['text_max_lines'], $value ); ?>><?php echo esc_html( (string) $value ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Line height', 'kidia-mobile-cms' ); ?><span class="kidia-range-value"><?php echo esc_html( number_format_i18n( $category_general['line_height'] / 100, 2 ) ); ?></span><input type="range" min="100" max="200" step="5" name="category_general[line_height]" value="<?php echo esc_attr( (string) $category_general['line_height'] ); ?>"></label>
							</div>
						</section>

						<section class="kidia-category-items">
							<div class="kidia-category-items__heading"><h3><?php esc_html_e( 'Categories & Subcategories', 'kidia-mobile-cms' ); ?></h3><p><?php esc_html_e( 'Drag to reorder. Each row only changes its app name, app image and visibility.', 'kidia-mobile-cms' ); ?></p></div>
							<?php if ( empty( $terms ) ) : ?><div class="notice notice-warning inline"><p><?php esc_html_e( 'No WooCommerce product categories were found.', 'kidia-mobile-cms' ); ?></p></div><?php else : ?><?php $render_level( 0 ); ?><?php endif; ?>
						</section>
					</div>
				</section>

				<?php $chrome_layout = $category_layout; $chrome_part = 'footer'; $chrome_page = 'category'; include KIDIA_MOBILE_CMS_PATH . 'admin/pages/fixed-chrome-card.php'; ?>
			</form>
		</div>
	</div>
</div>
