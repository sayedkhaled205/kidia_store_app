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
	<ul class="mobishop-category-list" data-parent-id="<?php echo esc_attr( (string) $parent_id ); ?>">
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
			<li class="mobishop-category-row" data-term-id="<?php echo esc_attr( (string) $id ); ?>" data-default-name="<?php echo esc_attr( $term->name ); ?>" data-default-image="<?php echo esc_url( $default_image_url ); ?>">
				<div class="mobishop-category-card">
					<span class="dashicons dashicons-move mobishop-category-handle" aria-hidden="true"></span>
					<div class="mobishop-category-image">
						<?php if ( $image_url ) : ?><img src="<?php echo esc_url( $image_url ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?>
					</div>
					<div class="mobishop-category-name">
						<label for="mobishop-category-name-<?php echo esc_attr( (string) $id ); ?>"><?php esc_html_e( 'App display name', 'mobishop' ); ?></label>
						<input id="mobishop-category-name-<?php echo esc_attr( (string) $id ); ?>" class="mobishop-category-name-input" type="text" name="categories[<?php echo esc_attr( (string) $id ); ?>][name]" value="<?php echo esc_attr( $app_name ); ?>" placeholder="<?php echo esc_attr( $term->name ); ?>">
						<?php /* translators: Placeholder values are supplied at runtime. */ ?>
						<small><?php echo esc_html( sprintf( __( 'WooCommerce: %1$s · %2$d products · ID %3$d', 'mobishop' ), $term->name, (int) $term->count, $id ) ); ?></small>
					</div>
					<input class="mobishop-category-order" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][order]" value="<?php echo esc_attr( (string) $index ); ?>">
					<input class="mobishop-category-image-id" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_id]" value="<?php echo esc_attr( (string) $image_id ); ?>">
					<div class="mobishop-category-image-actions">
						<button type="button" class="button button-secondary mobishop-category-image-button<?php echo $image_id ? ' is-active' : ''; ?>" aria-pressed="<?php echo $image_id ? 'true' : 'false'; ?>"><?php esc_html_e( 'Change image', 'mobishop' ); ?></button>
						<button type="button" class="button button-secondary mobishop-category-image-clear<?php echo $image_id ? '' : ' is-active'; ?>" aria-pressed="<?php echo $image_id ? 'false' : 'true'; ?>"><?php esc_html_e( 'Use WooCommerce image', 'mobishop' ); ?></button>
					</div>
					<label class="mobishop-category-visibility mobishop-page-master-toggle">
						<input type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][hidden]" value="1">
						<input type="checkbox" name="categories[<?php echo esc_attr( (string) $id ); ?>][hidden]" value="0" <?php checked( empty( $setting['hidden'] ) ); ?>>
						<span class="mobishop-toggle-state"></span>
					</label>
					<?php if ( $has_children ) : ?>
						<button type="button" class="button mobishop-category-expand" aria-expanded="false" aria-label="<?php esc_attr_e( 'Expand subcategories', 'mobishop' ); ?>"><span class="dashicons dashicons-arrow-down-alt2"></span></button>
					<?php else : ?><span class="mobishop-category-expand-placeholder"></span><?php endif; ?>
				</div>
				<?php if ( $has_children ) : ?><div class="mobishop-category-children" hidden><?php $render_level( $id ); ?></div><?php endif; ?>
			</li>
		<?php endforeach; ?>
	</ul>
	<?php
};
?>

<div class="wrap mobishop-category-builder">
	<?php if ( isset( $_GET['restored'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Category page restored to defaults.', 'mobishop' ); ?></p></div><?php elseif ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Category page saved successfully.', 'mobishop' ); ?></p></div><?php endif; ?>
	<div class="mobishop-category-workspace">
		<aside class="mobishop-category-mobile-preview" aria-label="<?php echo esc_attr__( 'Live category preview', 'mobishop' ); ?>">
			<div class="mobishop-category-phone">
				<div class="mobishop-category-phone__screen">
				<?php if ( file_exists( MOBISHOP_PATH . 'admin/flutter-preview/index.html' ) ) : ?>
					<iframe id="mobishop-flutter-preview" class="mobishop-flutter-preview" title="<?php echo esc_attr__( 'Flutter mobile preview', 'mobishop' ); ?>" src="<?php echo esc_url( add_query_arg( array( 'page' => 'category', 'v' => MOBISHOP_VERSION ), MOBISHOP_URL . 'admin/flutter-preview/index.html' ) ); ?>"></iframe>
					<div id="mobishop-category-live-preview" class="mobishop-category-phone__content mobishop-legacy-preview-fallback" hidden></div>
				<?php else : ?>
					<div id="mobishop-category-live-preview" class="mobishop-category-phone__content"></div>
				<?php endif; ?>
				</div>
			</div>
		</aside>
		<div class="mobishop-category-editor">
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
				<input type="hidden" name="action" value="mobishop_save_category_builder">
				<?php wp_nonce_field( 'mobishop_save_category_builder', 'mobishop_category_builder_nonce' ); ?>
				<?php
				/* translators: Placeholder values are supplied at runtime. */
				$mobishop_toolbar_title = sprintf( __( '%d WooCommerce categories', 'mobishop' ), count( $terms ) );
				$mobishop_toolbar_save_label = __( 'Save Category Page', 'mobishop' );
				$mobishop_toolbar_show_add = false;
				$mobishop_toolbar_show_restore = true;
				$mobishop_toolbar_page_toggle = true;
				$mobishop_toolbar_page_enabled = ! empty( $category_layout['enabled'] );
				include MOBISHOP_PATH . 'admin/pages/builder-toolbar.php';
				?>

				<div class="mobishop-builder-cards-scroll" data-mobishop-builder-cards-scroll>
				<?php $chrome_layout = $category_layout; $chrome_part = 'header'; $chrome_page = 'category'; include MOBISHOP_PATH . 'admin/pages/fixed-chrome-card.php'; ?>

				<section class="mobishop-page-card mobishop-category-element" data-element="category">
					<div class="mobishop-page-card__header">
						<div class="mobishop-page-card__identity"><span class="dashicons dashicons-category"></span><strong><?php esc_html_e( 'Category', 'mobishop' ); ?></strong><small><?php esc_html_e( 'All category and subcategory content', 'mobishop' ); ?></small></div>
						<div class="mobishop-card-actions"><span class="mobishop-card-action-placeholder mobishop-card-action--primary" aria-hidden="true"></span><span class="mobishop-card-action-placeholder mobishop-card-action--secondary" aria-hidden="true"></span><button type="button" class="button mobishop-page-expand mobishop-category-element-expand mobishop-card-action mobishop-card-action--expand" aria-expanded="false"><span class="dashicons dashicons-arrow-down-alt2"></span></button><label class="mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle"><input type="hidden" name="category_element_enabled" value="0"><input class="mobishop-category-element-enabled" type="checkbox" name="category_element_enabled" value="1" <?php checked( $category_enabled ); ?>><span class="mobishop-builder-switch__track"></span><span class="mobishop-builder-switch__state"></span></label></div>
					</div>
					<div class="mobishop-page-card__body" hidden>
						<section class="mobishop-category-general">
							<h3><?php esc_html_e( 'General Settings', 'mobishop' ); ?></h3>
							<p><?php esc_html_e( 'These appearance settings apply to every category and subcategory.', 'mobishop' ); ?></p>
							<div class="mobishop-category-general-fields">
								<div class="mobishop-settings-section-title"><?php esc_html_e( 'Layout & Spacing', 'mobishop' ); ?></div>
								<label><?php esc_html_e( 'Layout', 'mobishop' ); ?><select name="category_general[category_layout]">
									<?php foreach ( array( 'default' => __( 'Default Layout', 'mobishop' ), 'visual_grid' => __( 'Two-column Cards', 'mobishop' ), 'circular_grid' => __( 'Circular Grid', 'mobishop' ), 'compact_grid' => __( 'Compact Grid', 'mobishop' ), 'sidebar' => __( 'Sidebar & Subcategories', 'mobishop' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $category_general['category_layout'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?>
								</select></label>
								<label><?php esc_html_e( 'Open categories', 'mobishop' ); ?><select name="category_general[navigation_mode]">
									<option value="expand_inline" <?php selected( $category_general['navigation_mode'], 'expand_inline' ); ?>><?php esc_html_e( 'Expand in the same page', 'mobishop' ); ?></option>
									<option value="separate_page" <?php selected( $category_general['navigation_mode'], 'separate_page' ); ?>><?php esc_html_e( 'Open in a new page', 'mobishop' ); ?></option>
								</select></label>
								<label><?php esc_html_e( 'Grid columns', 'mobishop' ); ?><select name="category_general[grid_columns]"><?php foreach ( array( 2, 3, 4 ) as $value ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( $category_general['grid_columns'], $value ); ?>><?php echo esc_html( (string) $value ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Card height (0 = automatic)', 'mobishop' ); ?><input type="number" min="0" max="320" step="4" name="category_general[card_height]" value="<?php echo esc_attr( (string) $category_general['card_height'] ); ?>"></label>
								<label><?php esc_html_e( 'Card radius', 'mobishop' ); ?><input type="number" min="0" max="32" step="1" name="category_general[card_radius]" value="<?php echo esc_attr( (string) $category_general['card_radius'] ); ?>"></label>
								<label><?php esc_html_e( 'Card spacing', 'mobishop' ); ?><input type="number" min="0" max="24" step="1" name="category_general[card_gap]" value="<?php echo esc_attr( (string) $category_general['card_gap'] ); ?>"></label>
								<label><?php esc_html_e( 'Card width', 'mobishop' ); ?><input type="number" min="40" max="100" step="1" name="category_general[card_width_percent]" value="<?php echo esc_attr( (string) $category_general['card_width_percent'] ); ?>"></label>
								<label class="mobishop-category-toggle-field"><b><?php esc_html_e( 'Show arrow', 'mobishop' ); ?></b><span class="mobishop-page-master-toggle"><input type="hidden" name="category_general[show_arrow]" value="0"><input type="checkbox" name="category_general[show_arrow]" value="1" <?php checked( ! empty( $category_general['show_arrow'] ) ); ?>><span class="mobishop-toggle-state"></span></span></label>
								<label><?php esc_html_e( 'Merge up', 'mobishop' ); ?><input type="number" min="0" max="80" name="category_general[margin_top]" value="<?php echo esc_attr( (string) $category_general['margin_top'] ); ?>"></label>
								<label><?php esc_html_e( 'Merge down', 'mobishop' ); ?><input type="number" min="0" max="80" name="category_general[margin_bottom]" value="<?php echo esc_attr( (string) $category_general['margin_bottom'] ); ?>"></label>
								<label><?php esc_html_e( 'Space up', 'mobishop' ); ?><input type="number" min="0" max="80" name="category_general[space_up]" value="<?php echo esc_attr( (string) $category_general['space_up'] ); ?>"></label>
								<label><?php esc_html_e( 'Space down', 'mobishop' ); ?><input type="number" min="0" max="80" name="category_general[space_down]" value="<?php echo esc_attr( (string) $category_general['space_down'] ); ?>"></label>
								<div class="mobishop-settings-section-title"><?php esc_html_e( 'Colors & Appearance', 'mobishop' ); ?></div>
								<label><?php esc_html_e( 'Page background', 'mobishop' ); ?><input type="color" name="category_general[page_background_color]" value="<?php echo esc_attr( $category_general['page_background_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Background color', 'mobishop' ); ?><input type="color" name="category_general[element_background_color]" value="<?php echo esc_attr( $category_general['element_background_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Card style', 'mobishop' ); ?><select name="category_general[card_style]"><option value="minimal" <?php selected( 'minimal', $category_general['card_style'] ); ?>><?php esc_html_e( 'Minimal', 'mobishop' ); ?></option><option value="no_shadow" <?php selected( 'no_shadow', $category_general['card_style'] ); ?>><?php esc_html_e( 'No shadow', 'mobishop' ); ?></option><option value="outlined" <?php selected( 'outlined', $category_general['card_style'] ); ?>><?php esc_html_e( 'Outlined', 'mobishop' ); ?></option><option value="elevated" <?php selected( 'elevated', $category_general['card_style'] ); ?>><?php esc_html_e( 'Elevated', 'mobishop' ); ?></option></select></label>
								<label><?php esc_html_e( 'Card background', 'mobishop' ); ?><input type="color" name="category_general[card_background_color]" value="<?php echo esc_attr( $category_general['card_background_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow color', 'mobishop' ); ?><input type="color" name="category_general[card_shadow_color]" value="<?php echo esc_attr( $category_general['card_shadow_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow strength', 'mobishop' ); ?><input type="number" min="0" max="40" name="category_general[card_shadow_strength]" value="<?php echo esc_attr( (string) $category_general['card_shadow_strength'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow blur', 'mobishop' ); ?><input type="number" min="0" max="40" name="category_general[card_shadow_blur]" value="<?php echo esc_attr( (string) $category_general['card_shadow_blur'] ); ?>"></label>
								<label><?php esc_html_e( 'Shadow vertical offset', 'mobishop' ); ?><input type="number" min="-20" max="20" name="category_general[card_shadow_offset_y]" value="<?php echo esc_attr( (string) $category_general['card_shadow_offset_y'] ); ?>"></label>
								<div class="mobishop-settings-section-title"><?php esc_html_e( 'Image size & shape', 'mobishop' ); ?></div>
								<label><?php esc_html_e( 'Size', 'mobishop' ); ?><input type="number" min="32" max="120" step="4" name="category_general[image_size]" value="<?php echo esc_attr( (string) $category_general['image_size'] ); ?>"></label>
								<label><?php esc_html_e( 'Shape', 'mobishop' ); ?><select name="category_general[image_shape]"><option value="square" <?php selected( $category_general['image_shape'], 'square' ); ?>><?php esc_html_e( 'Square', 'mobishop' ); ?></option><option value="rounded" <?php selected( $category_general['image_shape'], 'rounded' ); ?>><?php esc_html_e( 'Rounded', 'mobishop' ); ?></option><option value="circle" <?php selected( $category_general['image_shape'], 'circle' ); ?>><?php esc_html_e( 'Circle', 'mobishop' ); ?></option></select></label>
								<label><?php esc_html_e( 'Round amount', 'mobishop' ); ?><input type="number" min="0" max="50" step="1" name="category_general[image_radius]" value="<?php echo esc_attr( (string) $category_general['image_radius'] ); ?>"></label>
								<label><?php esc_html_e( 'Image fit', 'mobishop' ); ?><select name="category_general[image_fit]"><option value="contain" <?php selected( $category_general['image_fit'], 'contain' ); ?>><?php esc_html_e( 'Show complete image', 'mobishop' ); ?></option><option value="cover" <?php selected( $category_general['image_fit'], 'cover' ); ?>><?php esc_html_e( 'Fill and crop', 'mobishop' ); ?></option></select></label>
								<label><?php esc_html_e( 'Effect', 'mobishop' ); ?><select name="category_general[image_effect]"><option value="none" <?php selected( $category_general['image_effect'], 'none' ); ?>><?php esc_html_e( 'None', 'mobishop' ); ?></option><option value="shadow" <?php selected( $category_general['image_effect'], 'shadow' ); ?>><?php esc_html_e( 'Shadow', 'mobishop' ); ?></option><option value="grayscale" <?php selected( $category_general['image_effect'], 'grayscale' ); ?>><?php esc_html_e( 'Black and white', 'mobishop' ); ?></option></select></label>
								<label><?php esc_html_e( 'Zoom', 'mobishop' ); ?><input type="number" min="80" max="150" step="5" name="category_general[image_scale]" value="<?php echo esc_attr( (string) $category_general['image_scale'] ); ?>"></label>
								<label><?php esc_html_e( 'Position', 'mobishop' ); ?><select name="category_general[image_position]"><?php foreach ( array( 'center' => __( 'Center', 'mobishop' ), 'top' => __( 'Top', 'mobishop' ), 'bottom' => __( 'Bottom', 'mobishop' ), 'right' => __( 'Right', 'mobishop' ), 'left' => __( 'Left', 'mobishop' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( $value ); ?>" <?php selected( $category_general['image_position'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Border width', 'mobishop' ); ?><input type="number" min="0" max="8" name="category_general[border_width]" value="<?php echo esc_attr( (string) $category_general['border_width'] ); ?>"></label>
								<label><?php esc_html_e( 'Border color', 'mobishop' ); ?><input type="color" name="category_general[border_color]" value="<?php echo esc_attr( $category_general['border_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Image background', 'mobishop' ); ?><input type="color" name="category_general[background_color]" value="<?php echo esc_attr( $category_general['background_color'] ); ?>"></label>
								<div class="mobishop-settings-section-title"><?php esc_html_e( 'Text and spacing', 'mobishop' ); ?></div>
								<label><?php esc_html_e( 'Image–text gap', 'mobishop' ); ?><input type="number" min="0" max="40" step="1" name="category_general[image_text_gap]" value="<?php echo esc_attr( (string) $category_general['image_text_gap'] ); ?>"></label>
								<label><?php esc_html_e( 'Font size', 'mobishop' ); ?><input type="number" min="10" max="30" step="1" name="category_general[font_size]" value="<?php echo esc_attr( (string) $category_general['font_size'] ); ?>"></label>
								<label><?php esc_html_e( 'Font color', 'mobishop' ); ?><input type="color" name="category_general[font_color]" value="<?php echo esc_attr( $category_general['font_color'] ); ?>"></label>
								<label><?php esc_html_e( 'Font weight', 'mobishop' ); ?><select name="category_general[font_weight]"><?php foreach ( array( 400 => __( 'Regular', 'mobishop' ), 500 => __( 'Medium', 'mobishop' ), 600 => __( 'Semi bold', 'mobishop' ), 700 => __( 'Bold', 'mobishop' ), 800 => __( 'Extra bold', 'mobishop' ), 900 => __( 'Black', 'mobishop' ) ) as $value => $label ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( $category_general['font_weight'], $value ); ?>><?php echo esc_html( $label ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Text alignment', 'mobishop' ); ?><select name="category_general[text_align]"><option value="start" <?php selected( $category_general['text_align'], 'start' ); ?>><?php esc_html_e( 'Start', 'mobishop' ); ?></option><option value="center" <?php selected( $category_general['text_align'], 'center' ); ?>><?php esc_html_e( 'Center', 'mobishop' ); ?></option><option value="end" <?php selected( $category_general['text_align'], 'end' ); ?>><?php esc_html_e( 'End', 'mobishop' ); ?></option></select></label>
								<label><?php esc_html_e( 'Maximum lines', 'mobishop' ); ?><select name="category_general[text_max_lines]"><?php foreach ( array( 1, 2, 3 ) as $value ) : ?><option value="<?php echo esc_attr( (string) $value ); ?>" <?php selected( $category_general['text_max_lines'], $value ); ?>><?php echo esc_html( (string) $value ); ?></option><?php endforeach; ?></select></label>
								<label><?php esc_html_e( 'Line height', 'mobishop' ); ?><input type="number" min="100" max="200" step="5" name="category_general[line_height]" value="<?php echo esc_attr( (string) $category_general['line_height'] ); ?>"></label>
							</div>
						</section>

						<section class="mobishop-category-items" data-navigation-mode="<?php echo esc_attr( $category_general['navigation_mode'] ); ?>" data-category-layout="<?php echo esc_attr( $category_general['category_layout'] ); ?>">
							<div class="mobishop-category-items__heading"><h3><?php esc_html_e( 'Categories & Subcategories', 'mobishop' ); ?></h3><p><?php esc_html_e( 'Drag to reorder. Each row only changes its app name, app image and visibility.', 'mobishop' ); ?></p></div>
							<?php if ( empty( $terms ) ) : ?><div class="notice notice-warning inline"><p><?php esc_html_e( 'No WooCommerce product categories were found.', 'mobishop' ); ?></p></div><?php else : ?><?php $render_level( 0 ); ?><?php endif; ?>
						</section>
					</div>
				</section>

				<?php $chrome_layout = $category_layout; $chrome_part = 'footer'; $chrome_page = 'category'; include MOBISHOP_PATH . 'admin/pages/fixed-chrome-card.php'; ?>
				</div>
			</form>
		</div>
	</div>
</div>
