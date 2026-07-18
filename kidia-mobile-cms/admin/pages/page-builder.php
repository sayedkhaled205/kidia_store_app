<?php
/** Shared builder UI for application content pages. */
defined( 'ABSPATH' ) || exit;

$render_fields = static function ( string $name_prefix, array $fields, array $settings ): void {
	foreach ( $fields as $field ) {
		$key = $field['key'];
		$value = $settings[ $key ] ?? $field['default'];
		$name = $name_prefix . '[settings][' . $key . ']';
		?>
		<div class="kidia-page-field<?php echo 'image' === $field['type'] ? ' kidia-page-field--image' : ''; ?>">
			<label><?php echo esc_html( $field['label'] ); ?></label>
			<?php if ( 'checkbox' === $field['type'] ) : ?>
				<label class="kidia-page-toggle"><input type="hidden" name="<?php echo esc_attr( $name ); ?>" value="0"><input type="checkbox" name="<?php echo esc_attr( $name ); ?>" value="1" <?php checked( ! empty( $value ) ); ?>><span></span><b><?php echo esc_html( ! empty( $value ) ? __( 'Visible', 'kidia-mobile-cms' ) : __( 'Hidden', 'kidia-mobile-cms' ) ); ?></b></label>
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
			<div class="kidia-page-phone"><div class="kidia-page-phone__speaker"></div><div class="kidia-page-phone__screen"><div class="kidia-page-phone__status"><span>9:41</span><span>● ◒ ▰</span></div><div id="kidia-page-live-preview"></div></div></div>
			<p><?php esc_html_e( 'Live mobile preview', 'kidia-mobile-cms' ); ?></p>
		</aside>
		<form class="kidia-page-editor" method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
			<input type="hidden" name="action" value="kidia_mobile_save_page_builder"><input type="hidden" name="builder_page" value="<?php echo esc_attr( $page ); ?>">
			<?php wp_nonce_field( 'kidia_mobile_save_page_builder', 'kidia_mobile_page_builder_nonce' ); ?>
			<div class="kidia-page-toolbar"><strong><?php echo esc_html( $page_label ); ?></strong><?php submit_button( __( 'Save Page Layout', 'kidia-mobile-cms' ), 'primary', 'submit', false ); ?></div>

			<section class="kidia-page-card kidia-page-card--locked" data-element="header">
				<div class="kidia-page-card__header"><div><span class="dashicons dashicons-lock"></span><strong><?php esc_html_e( 'Fixed Header', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'Cannot be moved or removed', 'kidia-mobile-cms' ); ?></small></div><label class="kidia-page-master-toggle"><input type="hidden" name="layout[header][enabled]" value="0"><input type="checkbox" name="layout[header][enabled]" value="1" <?php checked( ! empty( $layout['header']['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></span></label><button type="button" class="button kidia-page-expand"><span class="dashicons dashicons-arrow-down-alt2"></span></button></div>
				<div class="kidia-page-card__body" hidden><div class="kidia-page-fields"><?php $render_fields( 'layout[header]', $header_fields, $layout['header']['settings'] ); ?></div></div>
			</section>

			<div id="kidia-page-elements" class="kidia-page-elements">
			<?php foreach ( $layout['elements'] as $index => $element ) :
				$definition = $definition_map[ $element['id'] ] ?? null;
				if ( ! is_array( $definition ) ) { continue; }
				?>
				<section class="kidia-page-card" data-element="<?php echo esc_attr( $element['id'] ); ?>" draggable="false">
					<input type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][id]" value="<?php echo esc_attr( $element['id'] ); ?>">
					<div class="kidia-page-card__header"><div class="kidia-page-card__identity"><span class="dashicons dashicons-move kidia-page-drag"></span><span class="dashicons <?php echo esc_attr( $definition['icon'] ); ?>"></span><strong><?php echo esc_html( $definition['label'] ); ?></strong></div><label class="kidia-page-master-toggle"><input type="hidden" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][enabled]" value="0"><input type="checkbox" name="layout[elements][<?php echo esc_attr( (string) $index ); ?>][enabled]" value="1" <?php checked( ! empty( $element['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></span></label><button type="button" class="button kidia-page-expand"><span class="dashicons dashicons-arrow-down-alt2"></span></button></div>
					<div class="kidia-page-card__body" hidden><div class="kidia-page-fields"><?php $render_fields( 'layout[elements][' . $index . ']', $definition['fields'], $element['settings'] ); ?></div></div>
				</section>
			<?php endforeach; ?>
			</div>

			<section class="kidia-page-card kidia-page-card--locked" data-element="footer">
				<div class="kidia-page-card__header"><div><span class="dashicons dashicons-lock"></span><strong><?php esc_html_e( 'Fixed Footer', 'kidia-mobile-cms' ); ?></strong><small><?php esc_html_e( 'Cannot be moved or removed', 'kidia-mobile-cms' ); ?></small></div><label class="kidia-page-master-toggle"><input type="hidden" name="layout[footer][enabled]" value="0"><input type="checkbox" name="layout[footer][enabled]" value="1" <?php checked( ! empty( $layout['footer']['enabled'] ) ); ?>><span><?php esc_html_e( 'Show', 'kidia-mobile-cms' ); ?></span></label><button type="button" class="button kidia-page-expand"><span class="dashicons dashicons-arrow-down-alt2"></span></button></div>
				<div class="kidia-page-card__body" hidden><div class="kidia-page-fields"><?php $render_fields( 'layout[footer]', $footer_fields, $layout['footer']['settings'] ); ?></div></div>
			</section>
		</form>
	</div>
</div>
