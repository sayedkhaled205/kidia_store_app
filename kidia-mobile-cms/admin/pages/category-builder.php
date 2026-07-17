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
			?>
			<li class="kidia-category-row" data-term-id="<?php echo esc_attr( (string) $id ); ?>">
				<div class="kidia-category-card">
					<span class="dashicons dashicons-move kidia-category-handle" aria-hidden="true"></span>
					<div class="kidia-category-image">
						<?php if ( $image_url ) : ?><img src="<?php echo esc_url( $image_url ); ?>" alt=""><?php else : ?><span class="dashicons dashicons-format-image"></span><?php endif; ?>
					</div>
					<div class="kidia-category-name">
						<strong><?php echo esc_html( $term->name ); ?></strong>
						<small><?php echo esc_html( sprintf( __( '%d products · ID %d', 'kidia-mobile-cms' ), (int) $term->count, $id ) ); ?></small>
					</div>
					<input class="kidia-category-order" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][order]" value="<?php echo esc_attr( (string) $index ); ?>">
					<input class="kidia-category-image-id" type="hidden" name="categories[<?php echo esc_attr( (string) $id ); ?>][image_id]" value="<?php echo esc_attr( (string) $image_id ); ?>">
					<button type="button" class="button kidia-category-image-button"><?php esc_html_e( 'Change image', 'kidia-mobile-cms' ); ?></button>
					<button type="button" class="button-link kidia-category-image-clear" <?php echo $image_id ? '' : 'hidden'; ?>><?php esc_html_e( 'Use store image', 'kidia-mobile-cms' ); ?></button>
					<label class="kidia-category-visibility">
						<input type="checkbox" name="categories[<?php echo esc_attr( (string) $id ); ?>][hidden]" value="1" <?php checked( ! empty( $setting['hidden'] ) ); ?>>
						<?php esc_html_e( 'Hide in app', 'kidia-mobile-cms' ); ?>
					</label>
				</div>
				<?php $render_level( $id ); ?>
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
