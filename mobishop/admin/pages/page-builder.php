<?php
/** Shared builder UI for application content pages. */
defined( 'ABSPATH' ) || exit;

$field_section = static function ( string $key ): string {
	if ( in_array( $key, array( 'margin_top', 'margin_bottom', 'space_up', 'space_down', 'background_color' ), true ) ) { return 'Section Layout Settings'; }
	if ( 0 === strpos( $key, 'show_' ) || in_array( $key, array( 'sticky', 'enabled' ), true ) ) { return 'Visibility & display'; }
	if ( false !== strpos( $key, 'image' ) || false !== strpos( $key, 'logo' ) || false !== strpos( $key, 'thumbnail' ) ) { return 'Images'; }
	if ( false !== strpos( $key, 'search' ) ) { return 'Search'; }
	if ( false !== strpos( $key, 'cart' ) ) { return 'Cart'; }
	if ( false !== strpos( $key, 'wishlist' ) || false !== strpos( $key, 'like' ) ) { return 'Wishlist & like'; }
	if ( false !== strpos( $key, 'account' ) ) { return 'Account'; }
	if ( false !== strpos( $key, 'share' ) ) { return 'Share'; }
	if ( false !== strpos( $key, 'filter' ) || false !== strpos( $key, 'sort' ) ) { return 'Filters & sorting'; }
	if ( in_array( $key, array( 'source', 'category_id', 'manual_product_ids', 'limit', 'products_per_page' ), true ) ) { return 'Products & data'; }
	if ( false !== strpos( $key, 'color' ) || false !== strpos( $key, 'background' ) || false !== strpos( $key, 'shadow' ) || false !== strpos( $key, 'border' ) ) { return 'Colors & appearance'; }
	if ( false !== strpos( $key, 'size' ) || false !== strpos( $key, 'height' ) || false !== strpos( $key, 'width' ) || false !== strpos( $key, 'radius' ) || false !== strpos( $key, 'gap' ) || false !== strpos( $key, 'padding' ) || false !== strpos( $key, 'margin' ) || in_array( $key, array( 'columns', 'aspect_ratio', 'fit' ), true ) ) { return 'Layout & Spacing'; }
	if ( false !== strpos( $key, 'label' ) || false !== strpos( $key, 'title' ) || false !== strpos( $key, 'text' ) || false !== strpos( $key, 'placeholder' ) ) { return 'Text'; }
	return 'General';
};

$render_fields = static function ( string $name_prefix, array $fields, array $settings ) use ( $field_section ): void {
	$groups = array();
	foreach ( $fields as $field ) { $groups[ $field_section( $field['key'] ) ][] = $field; }
	foreach ( $groups as $section => $section_fields ) {
		?><div class="mobishop-settings-section-title"><?php echo esc_html( $section ); ?></div><?php
	foreach ( $section_fields as $field ) {
		$key = $field['key'];
		$value = $settings[ $key ] ?? $field['default'];
		$name = $name_prefix . '[settings][' . $key . ']';
		?>
		<div class="mobishop-page-field<?php echo 'image' === $field['type'] ? ' mobishop-page-field--image' : ''; ?><?php echo 'Section Layout Settings' === $section ? ' mobishop-section-layout-field' : ''; ?>">
			<label><?php echo esc_html( $field['label'] ); ?></label>
			<?php if ( 'checkbox' === $field['type'] ) : ?>
				<label class="mobishop-page-toggle"><input type="hidden" name="<?php echo esc_attr( $name ); ?>" value="0"><input type="checkbox" name="<?php echo esc_attr( $name ); ?>" value="1" <?php checked( ! empty( $value ) ); ?>><span></span><b><?php esc_html_e( 'Show', 'mobishop' ); ?></b></label>
			<?php elseif ( 'product_position' === $field['type'] ) : ?>
				<div class="mobishop-product-position" role="radiogroup" aria-label="<?php echo esc_attr( $field['label'] ); ?>">
					<div class="mobishop-product-position__image" aria-hidden="true"></div>
					<?php foreach ( $field['options'] as $option_value => $option_label ) : ?>
						<label class="is-<?php echo esc_attr( $option_value ); ?>" title="<?php echo esc_attr( $option_label ); ?>"><input type="radio" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( $option_value ); ?>" <?php checked( (string) $value, (string) $option_value ); ?>><span></span></label>
					<?php endforeach; ?>
				</div>
			<?php elseif ( 'select' === $field['type'] ) : ?>
				<select name="<?php echo esc_attr( $name ); ?>"><?php foreach ( $field['options'] as $option_value => $option_label ) : ?><option value="<?php echo esc_attr( $option_value ); ?>" <?php selected( (string) $value, (string) $option_value ); ?>><?php echo esc_html( $option_label ); ?></option><?php endforeach; ?></select>
			<?php elseif ( 'color' === $field['type'] ) : ?>
				<input type="color" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( sanitize_hex_color( (string) $value ) ?: (string) $field['default'] ); ?>">
			<?php elseif ( 'number' === $field['type'] ) : ?>
				<input type="number" name="<?php echo esc_attr( $name ); ?>" min="<?php echo esc_attr( (string) $field['min'] ); ?>" max="<?php echo esc_attr( (string) $field['max'] ); ?>" step="<?php echo esc_attr( (string) $field['step'] ); ?>" value="<?php echo esc_attr( (string) $value ); ?>">
			<?php elseif ( 'image' === $field['type'] ) : ?>
				<div class="mobishop-page-media"><input class="mobishop-page-media-url" type="url" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><button type="button" class="button mobishop-page-media-choose"><?php esc_html_e( 'Choose image', 'mobishop' ); ?></button></div>
				<img class="mobishop-page-media-preview" src="<?php echo esc_url( (string) $value ); ?>" alt="" <?php echo empty( $value ) ? 'hidden' : ''; ?>>
			<?php elseif ( 'tabs' === $field['type'] ) :
				$tabs = json_decode( (string) $value, true );
				$tabs = is_array( $tabs ) ? $tabs : array();
				$tab_targets = array(
					'overview' => __( 'Overview / product information', 'mobishop' ),
					'variations' => __( 'Variations', 'mobishop' ),
					'description' => __( 'Description', 'mobishop' ),
					'reviews' => __( 'Reviews', 'mobishop' ),
					'recommend' => __( 'Related products', 'mobishop' ),
				);
				?>
				<div class="mobishop-product-tabs-editor">
					<input type="hidden" class="mobishop-product-tabs-json" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>">
					<div class="mobishop-product-tabs-rows">
						<?php foreach ( array_slice( $tabs, 0, 10 ) as $tab ) : ?>
							<div class="mobishop-product-tab-row">
								<input type="text" class="mobishop-product-tab-label" value="<?php echo esc_attr( (string) ( $tab['label'] ?? '' ) ); ?>" placeholder="<?php esc_attr_e( 'Tab label', 'mobishop' ); ?>">
								<select class="mobishop-product-tab-target"><?php foreach ( $tab_targets as $target => $target_label ) : ?><option value="<?php echo esc_attr( $target ); ?>" <?php selected( (string) ( $tab['target'] ?? 'overview' ), $target ); ?>><?php echo esc_html( $target_label ); ?></option><?php endforeach; ?></select>
								<label class="mobishop-product-tab-enabled"><input type="checkbox" <?php checked( ! empty( $tab['enabled'] ) ); ?>><?php esc_html_e( 'Show', 'mobishop' ); ?></label>
								<button type="button" class="button mobishop-product-tab-remove" aria-label="<?php esc_attr_e( 'Remove tab', 'mobishop' ); ?>"><span class="dashicons dashicons-trash"></span></button>
							</div>
						<?php endforeach; ?>
					</div>
					<button type="button" class="button mobishop-product-tab-add"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add tab', 'mobishop' ); ?></button>
				</div>
			<?php else : ?>
				<input type="text" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>">
			<?php endif; ?>
		</div>
		<?php
	}
	}
};

$definition_map = array();
foreach ( $element_definitions as $definition ) {
	$definition_map[ $definition['id'] ] = $definition;
}
?>
<?php
$flutter_preview_product_id = 1;
if ( 'product' === $page && function_exists( 'wc_get_products' ) ) {
	$flutter_preview_products = wc_get_products( array( 'status' => 'publish', 'limit' => 1, 'return' => 'ids' ) );
	if ( ! empty( $flutter_preview_products[0] ) ) {
		$flutter_preview_product_id = absint( $flutter_preview_products[0] );
	}
}
?>
<div class="wrap mobishop-page-builder" data-page="<?php echo esc_attr( $page ); ?>">
	<?php if ( isset( $_GET['restored'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Page settings restored to defaults.', 'mobishop' ); ?></p></div><?php elseif ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Page layout saved successfully.', 'mobishop' ); ?></p></div><?php endif; ?>
	<div class="mobishop-page-workspace">
		<aside class="mobishop-page-preview">
			<div class="mobishop-page-phone"><div class="mobishop-page-phone__screen">
				<?php if ( file_exists( MOBISHOP_PATH . 'admin/flutter-preview/index.html' ) ) : ?>
					<iframe id="mobishop-flutter-preview" class="mobishop-flutter-preview" title="<?php echo esc_attr__( 'Flutter mobile preview', 'mobishop' ); ?>" src="<?php echo esc_url( add_query_arg( array( 'page' => $page, 'product' => $flutter_preview_product_id, 'v' => MOBISHOP_VERSION ), MOBISHOP_URL . 'admin/flutter-preview/index.html' ) ); ?>"></iframe>
					<div id="mobishop-page-live-preview" class="mobishop-legacy-preview-fallback" hidden></div>
				<?php else : ?>
					<div id="mobishop-page-live-preview"></div>
				<?php endif; ?>
			</div></div>
		</aside>
		<form class="mobishop-page-editor" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="mobishop_save_page_builder"><input type="hidden" name="builder_page" value="<?php echo esc_attr( $page ); ?>">
			<?php wp_nonce_field( 'mobishop_save_page_builder', 'mobishop_page_builder_nonce' ); ?>
			<?php
			$mobishop_toolbar_title = $page_label;
			$mobishop_toolbar_save_label = __( 'Save Page Layout', 'mobishop' );
			$mobishop_toolbar_show_add = 'wishlist' === $page;
			$mobishop_toolbar_show_restore = true;
			$mobishop_toolbar_page_toggle = true;
			$mobishop_toolbar_page_enabled = ! empty( $layout['enabled'] );
			include MOBISHOP_PATH . 'admin/pages/builder-toolbar.php';
			?>
			<div class="mobishop-builder-cards-scroll" data-mobishop-builder-cards-scroll>
				<section class="mobishop-page-card mobishop-page-settings-card">
					<div class="mobishop-page-card__header">
						<div class="mobishop-page-card__identity"><span class="dashicons dashicons-admin-appearance"></span><strong><?php esc_html_e( 'Page Settings', 'mobishop' ); ?></strong></div>
						<label class="mobishop-page-card__header-color"><span><?php esc_html_e( 'Page background color', 'mobishop' ); ?></span><input type="color" name="layout[settings][page_background_color]" value="<?php echo esc_attr( sanitize_hex_color( (string) ( $layout['settings']['page_background_color'] ?? '' ) ) ?: '#FFFFFF' ); ?>"></label>
					</div>
					<div class="mobishop-page-card__body">
						<div class="mobishop-field-grid">
							<label><span><?php esc_html_e( 'Application font', 'mobishop' ); ?></span><select name="layout[settings][font_family]"><option value="system" <?php selected( (string) ( $layout['settings']['font_family'] ?? 'system' ), 'system' ); ?>><?php esc_html_e( 'System font', 'mobishop' ); ?></option><option value="poppins" <?php selected( (string) ( $layout['settings']['font_family'] ?? 'system' ), 'poppins' ); ?>>Poppins</option><option value="roboto" <?php selected( (string) ( $layout['settings']['font_family'] ?? '' ), 'roboto' ); ?>>Roboto</option><option value="noto_sans_arabic" <?php selected( (string) ( $layout['settings']['font_family'] ?? '' ), 'noto_sans_arabic' ); ?>>Noto Sans Arabic</option><option value="serif" <?php selected( (string) ( $layout['settings']['font_family'] ?? '' ), 'serif' ); ?>>Serif</option><option value="monospace" <?php selected( (string) ( $layout['settings']['font_family'] ?? '' ), 'monospace' ); ?>>Monospace</option></select></label>
							<label><span><?php esc_html_e( 'Content side padding', 'mobishop' ); ?></span><input type="number" min="0" max="40" name="layout[settings][content_horizontal_padding]" value="<?php echo esc_attr( (string) absint( $layout['settings']['content_horizontal_padding'] ?? 20 ) ); ?>"></label>
						</div>
					</div>
				</section>

			<?php if ( 'wishlist' === $page ) : ?>
				<section class="mobishop-page-card is-open mobishop-wishlist-access-mode">
					<div class="mobishop-page-card__header"><div class="mobishop-page-card__identity"><span class="dashicons dashicons-heart"></span><strong><?php esc_html_e( 'Wishlist access mode', 'mobishop' ); ?></strong></div></div>
					<div class="mobishop-page-card__body">
						<div class="mobishop-category-navigation-modes mobishop-wishlist-access-options">
							<label class="mobishop-wishlist-access-option" data-wishlist-access-mode="guest"><input type="radio" name="layout[settings][wishlist_access_mode]" value="guest" <?php checked( (string) ( $layout['settings']['wishlist_access_mode'] ?? 'sign_in_required' ), 'guest' ); ?>><span><b><?php esc_html_e( 'Guest wishlist', 'mobishop' ); ?></b><small><?php esc_html_e( 'Allow adding products without signing in.', 'mobishop' ); ?></small><i class="dashicons dashicons-unlock"></i></span></label>
							<label class="mobishop-wishlist-access-option" data-wishlist-access-mode="sign_in_required"><input type="radio" name="layout[settings][wishlist_access_mode]" value="sign_in_required" <?php checked( (string) ( $layout['settings']['wishlist_access_mode'] ?? 'sign_in_required' ), 'sign_in_required' ); ?>><span><b><?php esc_html_e( 'Sign in required', 'mobishop' ); ?></b><small><?php esc_html_e( 'Show the sign-in wishlist page for signed-out customers.', 'mobishop' ); ?></small><i class="dashicons dashicons-lock"></i></span></label>
						</div>
						<div class="mobishop-wishlist-preview-heading">
							<strong><?php esc_html_e( 'Preview and edit a wishlist state', 'mobishop' ); ?></strong>
							<small><?php esc_html_e( 'Each state keeps its own settings. Choose one to show its element directly below.', 'mobishop' ); ?></small>
						</div>
						<div class="mobishop-category-navigation-modes mobishop-wishlist-preview-modes">
							<label class="mobishop-wishlist-preview-option" data-wishlist-preview-state="sign_in"><input type="radio" name="layout[settings][wishlist_preview_state]" value="sign_in" <?php checked( (string) ( $layout['settings']['wishlist_preview_state'] ?? 'products' ), 'sign_in' ); ?>><span><b><?php esc_html_e( 'Sign-in Wishlist', 'mobishop' ); ?></b><small><?php esc_html_e( 'Edit the page shown to signed-out customers.', 'mobishop' ); ?></small><i class="dashicons dashicons-lock"></i></span></label>
							<label class="mobishop-wishlist-preview-option" data-wishlist-preview-state="empty"><input type="radio" name="layout[settings][wishlist_preview_state]" value="empty" <?php checked( (string) ( $layout['settings']['wishlist_preview_state'] ?? 'products' ), 'empty' ); ?>><span><b><?php esc_html_e( 'Empty Wishlist Settings', 'mobishop' ); ?></b><small><?php esc_html_e( 'Edit and preview the screen shown before products are saved.', 'mobishop' ); ?></small><i class="dashicons dashicons-heart"></i></span></label>
							<label class="mobishop-wishlist-preview-option" data-wishlist-preview-state="products"><input type="radio" name="layout[settings][wishlist_preview_state]" value="products" <?php checked( (string) ( $layout['settings']['wishlist_preview_state'] ?? 'products' ), 'products' ); ?>><span><b><?php esc_html_e( 'Product Wishlist', 'mobishop' ); ?></b><small><?php esc_html_e( 'Edit and preview the wishlist when saved products exist.', 'mobishop' ); ?></small><i class="dashicons dashicons-grid-view"></i></span></label>
						</div>
					</div>
				</section>
			<?php endif; ?>
			<?php $chrome_layout = $layout; $chrome_part = 'header'; $chrome_page = $page; $chrome_name_prefix = 'layout[header]'; include MOBISHOP_PATH . 'admin/pages/fixed-chrome-card.php'; ?>

			<?php if ( 'wishlist' === $page ) : ?>
				<?php
				$wishlist_state_map = array(
					'sign_in_state' => 'sign_in',
					'sign_in_recommendations' => 'sign_in',
					'empty_state' => 'empty',
					'empty_recommendations' => 'empty',
					'wishlist_grid' => 'products',
					'products_recommendations' => 'products',
				);
				?>
			<?php endif; ?>

			<div id="mobishop-page-elements" class="mobishop-page-elements">
			<?php foreach ( $layout['elements'] as $index => $element ) :
				$element_type = sanitize_key( (string) ( $element['type'] ?? $element['id'] ?? '' ) );
				$element_id = sanitize_key( (string) ( $element['id'] ?? $element_type ) );
				$definition = $definition_map[ $element_type ] ?? null;
				if ( ! is_array( $definition ) ) { continue; }
				?>
				<section class="mobishop-page-card" data-element="<?php echo esc_attr( $element_type ); ?>" data-instance-id="<?php echo esc_attr( $element_id ); ?>"<?php if ( 'wishlist' === $page && isset( $wishlist_state_map[ $element_type ] ) ) : ?> data-wishlist-state="<?php echo esc_attr( $wishlist_state_map[ $element_type ] ); ?>"<?php endif; ?> draggable="false">
					<input class="mobishop-page-element-id" type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][id]" value="<?php echo esc_attr( $element_id ); ?>">
					<input type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][type]" value="<?php echo esc_attr( $element_type ); ?>">
					<div class="mobishop-page-card__header"><div class="mobishop-page-card__identity"><span class="dashicons dashicons-move mobishop-page-drag"></span><span class="dashicons <?php echo esc_attr( $definition['icon'] ); ?>"></span><strong><?php echo esc_html( $definition['label'] ); ?></strong></div><div class="mobishop-card-actions"><?php if ( 'wishlist' === $page && str_ends_with( $element_type, '_recommendations' ) ) : ?><button type="button" class="button mobishop-recommendation-copy mobishop-card-action mobishop-card-action--primary"><span class="dashicons dashicons-admin-page"></span><?php esc_html_e( 'Copy', 'mobishop' ); ?></button><button type="button" class="button mobishop-recommendation-paste mobishop-card-action mobishop-card-action--secondary"><span class="dashicons dashicons-clipboard"></span><?php esc_html_e( 'Paste', 'mobishop' ); ?></button><?php elseif ( 'wishlist' === $page ) : ?><button type="button" class="button mobishop-page-duplicate mobishop-card-action mobishop-card-action--primary"><span class="dashicons dashicons-admin-page"></span><?php esc_html_e( 'Duplicate', 'mobishop' ); ?></button><button type="button" class="button mobishop-page-remove mobishop-card-action mobishop-card-action--secondary" <?php echo $element_id === $element_type ? 'hidden' : ''; ?>><span class="dashicons dashicons-trash"></span><?php esc_html_e( 'Remove', 'mobishop' ); ?></button><?php else : ?><span class="mobishop-card-action-placeholder mobishop-card-action--primary" aria-hidden="true"></span><span class="mobishop-card-action-placeholder mobishop-card-action--secondary" aria-hidden="true"></span><?php endif; ?><button type="button" class="button mobishop-page-expand mobishop-card-action mobishop-card-action--expand"><span class="dashicons dashicons-arrow-down-alt2"></span></button><label class="mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle"><input type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][enabled]" value="0"><input type="checkbox" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][enabled]" value="1" <?php checked( ! empty( $element['enabled'] ) ); ?>><span class="mobishop-builder-switch__track"></span><span class="mobishop-builder-switch__state"></span></label></div></div>
					<div class="mobishop-page-card__body" hidden><div class="mobishop-page-fields"><?php
						$render_fields( 'layout[elements][' . $index . ']', $definition['fields'], $element['settings'] );
					?></div></div>
				</section>
			<?php endforeach; ?>
			</div>

			<?php $chrome_layout = $layout; $chrome_part = 'footer'; $chrome_page = $page; $chrome_name_prefix = 'layout[footer]'; include MOBISHOP_PATH . 'admin/pages/fixed-chrome-card.php'; ?>
			</div>
		</form>
	</div>
	<?php if ( 'wishlist' === $page ) : ?>
		<div id="mobishop-wishlist-element-picker" class="mobishop-wishlist-element-picker" hidden aria-hidden="true">
			<div class="mobishop-wishlist-element-picker__overlay" data-mobishop-close-wishlist-picker></div>
			<div class="mobishop-wishlist-element-picker__panel" role="dialog" aria-modal="true" aria-labelledby="mobishop-wishlist-element-picker-title">
				<header class="mobishop-wishlist-element-picker__header">
					<div>
						<h2 id="mobishop-wishlist-element-picker-title"><?php esc_html_e( 'Add Element', 'mobishop' ); ?></h2>
						<p><?php esc_html_e( 'Choose an element to add below the currently selected wishlist state.', 'mobishop' ); ?></p>
					</div>
					<button type="button" class="button-link mobishop-wishlist-element-picker__close" data-mobishop-close-wishlist-picker aria-label="<?php esc_attr_e( 'Close', 'mobishop' ); ?>"><span class="dashicons dashicons-no-alt"></span></button>
				</header>
				<div class="mobishop-wishlist-element-picker__grid">
					<?php foreach ( $element_definitions as $wishlist_definition ) : ?>
						<?php $wishlist_definition_state = $wishlist_state_map[ $wishlist_definition['id'] ] ?? ''; ?>
						<?php if ( $wishlist_definition_state ) : ?>
							<button type="button" class="mobishop-wishlist-element-choice" data-wishlist-add-type="<?php echo esc_attr( $wishlist_definition['id'] ); ?>" data-wishlist-state="<?php echo esc_attr( $wishlist_definition_state ); ?>">
								<span class="dashicons <?php echo esc_attr( $wishlist_definition['icon'] ); ?>"></span>
								<strong><?php echo esc_html( $wishlist_definition['label'] ); ?></strong>
							</button>
						<?php endif; ?>
					<?php endforeach; ?>
				</div>
			</div>
		</div>
	<?php endif; ?>
</div>
