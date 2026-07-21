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
		?><div class="kidia-settings-section-title"><?php echo esc_html( $section ); ?></div><?php
	foreach ( $section_fields as $field ) {
		$key = $field['key'];
		$value = $settings[ $key ] ?? $field['default'];
		$name = $name_prefix . '[settings][' . $key . ']';
		?>
		<div class="kidia-page-field<?php echo 'image' === $field['type'] ? ' kidia-page-field--image' : ''; ?><?php echo 'Section Layout Settings' === $section ? ' kidia-section-layout-field' : ''; ?>">
			<label><?php echo esc_html( $field['label'] ); ?></label>
			<?php if ( 'checkbox' === $field['type'] ) : ?>
				<label class="kidia-page-toggle"><input type="hidden" name="<?php echo esc_attr( $name ); ?>" value="0"><input type="checkbox" name="<?php echo esc_attr( $name ); ?>" value="1" <?php checked( ! empty( $value ) ); ?>><span></span><b><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></b></label>
			<?php elseif ( 'product_position' === $field['type'] ) : ?>
				<div class="kidia-product-position" role="radiogroup" aria-label="<?php echo esc_attr( $field['label'] ); ?>">
					<div class="kidia-product-position__image" aria-hidden="true"></div>
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
				<div class="kidia-page-media"><input class="kidia-page-media-url" type="url" name="<?php echo esc_attr( $name ); ?>" value="<?php echo esc_attr( (string) $value ); ?>"><button type="button" class="button kidia-page-media-choose"><?php esc_html_e( 'Choose image', 'kidia-mobile-cms' ); ?></button></div>
				<img class="kidia-page-media-preview" src="<?php echo esc_url( (string) $value ); ?>" alt="" <?php echo empty( $value ) ? 'hidden' : ''; ?>>
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
<div class="wrap kidia-page-builder" data-page="<?php echo esc_attr( $page ); ?>">
	<header class="kidia-page-builder__heading">
		<div><h1><?php echo esc_html( sprintf( __( '%s Builder', 'kidia-mobile-cms' ), $page_label ) ); ?></h1><p><?php esc_html_e( 'Header and footer stay fixed. Reorder the page-specific elements and control every visible section.', 'kidia-mobile-cms' ); ?></p></div>
	</header>
	<?php if ( isset( $_GET['updated'] ) ) : ?><div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Page layout saved successfully.', 'kidia-mobile-cms' ); ?></p></div><?php endif; ?>
	<div class="kidia-page-workspace">
		<aside class="kidia-page-preview">
			<div class="kidia-page-phone"><div class="kidia-page-phone__speaker"></div><div class="kidia-page-phone__screen"><div id="kidia-page-live-preview"></div></div></div>
			<p><?php esc_html_e( 'Live mobile preview', 'kidia-mobile-cms' ); ?></p>
		</aside>
		<form class="kidia-page-editor" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="kidia_mobile_save_page_builder"><input type="hidden" name="builder_page" value="<?php echo esc_attr( $page ); ?>">
			<?php wp_nonce_field( 'kidia_mobile_save_page_builder', 'kidia_mobile_page_builder_nonce' ); ?>
			<div class="kidia-page-toolbar"><strong><?php echo esc_html( $page_label ); ?></strong><?php submit_button( __( 'Save Page Layout', 'kidia-mobile-cms' ), 'primary', 'submit', false ); ?></div>

			<?php $chrome_layout = $layout; $chrome_part = 'header'; $chrome_page = $page; $chrome_name_prefix = 'layout[header]'; include KIDIA_MOBILE_CMS_PATH . 'admin/pages/fixed-chrome-card.php'; ?>

			<div id="kidia-page-elements" class="kidia-page-elements">
			<?php foreach ( $layout['elements'] as $index => $element ) :
				$definition = $definition_map[ $element['id'] ] ?? null;
				if ( ! is_array( $definition ) ) { continue; }
				?>
				<section class="kidia-page-card" data-element="<?php echo esc_attr( $element['id'] ); ?>" draggable="false">
					<input type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][id]" value="<?php echo esc_attr( $element['id'] ); ?>">
					<div class="kidia-page-card__header"><div class="kidia-page-card__identity"><span class="dashicons dashicons-move kidia-page-drag"></span><span class="dashicons <?php echo esc_attr( $definition['icon'] ); ?>"></span><strong><?php echo esc_html( $definition['label'] ); ?></strong></div><div class="kidia-card-actions"><span class="kidia-card-action-placeholder kidia-card-action--primary" aria-hidden="true"></span><span class="kidia-card-action-placeholder kidia-card-action--secondary" aria-hidden="true"></span><button type="button" class="button kidia-page-expand kidia-card-action kidia-card-action--expand"><span class="dashicons dashicons-arrow-down-alt2"></span></button><label class="kidia-page-master-toggle kidia-card-action kidia-card-action--toggle"><input type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][enabled]" value="0"><input type="checkbox" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][enabled]" value="1" <?php checked( ! empty( $element['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></span></label></div></div>
					<div class="kidia-page-card__body" hidden><div class="kidia-page-fields"><?php
						$render_fields( 'layout[elements][' . $index . ']', $definition['fields'], $element['settings'] );
					?></div></div>
				</section>
			<?php endforeach; ?>
			</div>

			<?php $chrome_layout = $layout; $chrome_part = 'footer'; $chrome_page = $page; $chrome_name_prefix = 'layout[footer]'; include KIDIA_MOBILE_CMS_PATH . 'admin/pages/fixed-chrome-card.php'; ?>
		</form>
	</div>
</div>
