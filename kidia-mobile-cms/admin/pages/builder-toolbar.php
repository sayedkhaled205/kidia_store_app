<?php
/** Shared toolbar used by every CMS layout builder. */

defined( 'ABSPATH' ) || exit;

$kidia_toolbar_title = isset( $kidia_toolbar_title ) ? (string) $kidia_toolbar_title : '';
$kidia_toolbar_save_label = isset( $kidia_toolbar_save_label ) ? (string) $kidia_toolbar_save_label : __( 'Save Layout', 'kidia-mobile-cms' );
$kidia_toolbar_show_add = ! empty( $kidia_toolbar_show_add );
$kidia_toolbar_restore_product = ! empty( $kidia_toolbar_restore_product );
?>
<div class="kidia-builder-toolbar kidia-shared-builder-toolbar">
	<div class="kidia-builder-toolbar__actions">
		<?php if ( $kidia_toolbar_show_add ) : ?>
			<button type="button" class="button button-primary" id="kidia-add-element"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Element', 'kidia-mobile-cms' ); ?></button>
		<?php endif; ?>
		<button type="button" class="button" id="kidia-collapse-all"><?php esc_html_e( 'Collapse All', 'kidia-mobile-cms' ); ?></button>
		<button type="button" class="button" id="kidia-expand-all"><?php esc_html_e( 'Expand All', 'kidia-mobile-cms' ); ?></button>
		<?php if ( '' !== $kidia_toolbar_title ) : ?><strong class="kidia-builder-toolbar__context"><?php echo esc_html( $kidia_toolbar_title ); ?></strong><?php endif; ?>
	</div>
	<div class="kidia-builder-toolbar__save">
		<?php if ( $kidia_toolbar_restore_product ) : ?>
			<button type="submit" class="button kidia-restore-product-defaults" name="restore_product_defaults" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Restore every Product Page setting to its default value? This does not affect any other page.', 'kidia-mobile-cms' ) ); ?>');"><?php esc_html_e( 'Restore Product Defaults', 'kidia-mobile-cms' ); ?></button>
		<?php endif; ?>
		<?php submit_button( $kidia_toolbar_save_label, 'primary', 'submit', false ); ?>
	</div>
</div>
