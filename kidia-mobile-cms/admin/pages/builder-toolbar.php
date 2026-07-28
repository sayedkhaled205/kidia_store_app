<?php
/** Shared toolbar used by every CMS layout builder. */

defined( 'ABSPATH' ) || exit;

$kidia_toolbar_save_label = isset( $kidia_toolbar_save_label ) ? (string) $kidia_toolbar_save_label : __( 'Save Layout', 'kidia-mobile-cms' );
$kidia_toolbar_show_add = ! empty( $kidia_toolbar_show_add );
$kidia_toolbar_restore_product = ! empty( $kidia_toolbar_restore_product );
$kidia_toolbar_page_toggle = ! empty( $kidia_toolbar_page_toggle );
$kidia_toolbar_page_enabled = ! isset( $kidia_toolbar_page_enabled ) || ! empty( $kidia_toolbar_page_enabled );
$kidia_render_add_button = static function (): void {
	?>
	<button type="button" class="button button-primary" id="kidia-add-element"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Element', 'kidia-mobile-cms' ); ?></button>
	<?php
};
?>
<div class="kidia-builder-toolbar kidia-shared-builder-toolbar<?php echo $kidia_toolbar_show_add && $kidia_toolbar_page_toggle ? ' kidia-builder-toolbar--home' : ''; ?>">
	<?php if ( $kidia_toolbar_show_add && $kidia_toolbar_page_toggle ) : ?>
		<div class="kidia-builder-toolbar__primary-actions">
			<?php $kidia_render_add_button(); ?>
			<label class="kidia-page-availability" aria-label="<?php esc_attr_e( 'Page availability', 'kidia-mobile-cms' ); ?>">
				<input type="hidden" name="layout[enabled]" value="0">
				<input type="checkbox" name="layout[enabled]" value="1" <?php checked( $kidia_toolbar_page_enabled ); ?>>
				<span class="kidia-page-availability__copy"><strong><?php esc_html_e( 'Page status', 'kidia-mobile-cms' ); ?></strong><small class="kidia-toggle-state"></small></span>
			</label>
		</div>
		<div class="kidia-builder-toolbar__secondary-actions">
			<button type="button" class="button" id="kidia-collapse-all"><?php esc_html_e( 'Collapse All', 'kidia-mobile-cms' ); ?></button>
			<button type="button" class="button" id="kidia-expand-all"><?php esc_html_e( 'Expand All', 'kidia-mobile-cms' ); ?></button>
			<?php submit_button( $kidia_toolbar_save_label, 'primary', 'submit', false ); ?>
		</div>
	<?php else : ?>
		<div class="kidia-builder-toolbar__actions">
			<?php if ( $kidia_toolbar_show_add ) : ?>
				<?php $kidia_render_add_button(); ?>
			<?php endif; ?>
			<button type="button" class="button" id="kidia-collapse-all"><?php esc_html_e( 'Collapse All', 'kidia-mobile-cms' ); ?></button>
			<button type="button" class="button" id="kidia-expand-all"><?php esc_html_e( 'Expand All', 'kidia-mobile-cms' ); ?></button>
		</div>
		<div class="kidia-builder-toolbar__save">
			<?php if ( $kidia_toolbar_page_toggle ) : ?>
				<label class="kidia-page-availability" aria-label="<?php esc_attr_e( 'Page availability', 'kidia-mobile-cms' ); ?>">
					<input type="hidden" name="layout[enabled]" value="0">
					<input type="checkbox" name="layout[enabled]" value="1" <?php checked( $kidia_toolbar_page_enabled ); ?>>
					<span class="kidia-page-availability__copy"><strong><?php esc_html_e( 'Page status', 'kidia-mobile-cms' ); ?></strong><small class="kidia-toggle-state"></small></span>
				</label>
			<?php endif; ?>
			<?php if ( $kidia_toolbar_restore_product ) : ?>
				<button type="submit" class="button kidia-restore-product-defaults" name="restore_product_defaults" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Restore every Product Page setting to its default value? This does not affect any other page.', 'kidia-mobile-cms' ) ); ?>');"><?php esc_html_e( 'Restore Product Defaults', 'kidia-mobile-cms' ); ?></button>
			<?php endif; ?>
			<?php submit_button( $kidia_toolbar_save_label, 'primary', 'submit', false ); ?>
		</div>
	<?php endif; ?>
</div>
