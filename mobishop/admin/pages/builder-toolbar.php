<?php
/** Shared toolbar used by every CMS layout builder. */

defined( 'ABSPATH' ) || exit;

$mobishop_toolbar_save_label = isset( $mobishop_toolbar_save_label ) ? (string) $mobishop_toolbar_save_label : __( 'Save Layout', 'mobishop' );
$mobishop_toolbar_show_add = ! empty( $mobishop_toolbar_show_add );
$mobishop_toolbar_show_restore = ! empty( $mobishop_toolbar_show_restore ) || ! empty( $mobishop_toolbar_restore_product );
$mobishop_toolbar_page_toggle = ! empty( $mobishop_toolbar_page_toggle );
$mobishop_toolbar_page_enabled = ! isset( $mobishop_toolbar_page_enabled ) || ! empty( $mobishop_toolbar_page_enabled );
$mobishop_render_add_button = static function (): void {
	?>
	<button type="button" class="button button-primary" id="mobishop-add-element"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Element', 'mobishop' ); ?></button>
	<?php
};
?>
<div class="mobishop-builder-toolbar mobishop-shared-builder-toolbar<?php echo $mobishop_toolbar_show_add && $mobishop_toolbar_page_toggle ? ' mobishop-builder-toolbar--home' : ''; ?>">
	<?php if ( $mobishop_toolbar_show_add && $mobishop_toolbar_page_toggle ) : ?>
		<div class="mobishop-builder-toolbar__primary-actions">
			<?php $mobishop_render_add_button(); ?>
			<label class="mobishop-page-availability" aria-label="<?php esc_attr_e( 'Page availability', 'mobishop' ); ?>">
				<input type="hidden" name="layout[enabled]" value="0">
				<input type="checkbox" name="layout[enabled]" value="1" <?php checked( $mobishop_toolbar_page_enabled ); ?>>
				<span class="mobishop-page-availability__copy"><strong><?php esc_html_e( 'Page status', 'mobishop' ); ?></strong><small class="mobishop-toggle-state"></small></span>
			</label>
		</div>
		<div class="mobishop-builder-toolbar__secondary-actions">
			<button type="button" class="button" id="mobishop-collapse-all"><?php esc_html_e( 'Collapse All', 'mobishop' ); ?></button>
			<button type="button" class="button" id="mobishop-expand-all"><?php esc_html_e( 'Expand All', 'mobishop' ); ?></button>
			<?php if ( $mobishop_toolbar_show_restore ) : ?>
				<button type="submit" class="button mobishop-restore-defaults" name="restore_defaults" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Restore this page to its default settings? Other pages will not be affected.', 'mobishop' ) ); ?>');"><?php esc_html_e( 'Restore Defaults', 'mobishop' ); ?></button>
			<?php endif; ?>
			<?php submit_button( $mobishop_toolbar_save_label, 'primary', 'submit', false ); ?>
		</div>
	<?php else : ?>
		<div class="mobishop-builder-toolbar__actions">
			<?php if ( $mobishop_toolbar_show_add ) : ?>
				<?php $mobishop_render_add_button(); ?>
			<?php endif; ?>
			<button type="button" class="button" id="mobishop-collapse-all"><?php esc_html_e( 'Collapse All', 'mobishop' ); ?></button>
			<button type="button" class="button" id="mobishop-expand-all"><?php esc_html_e( 'Expand All', 'mobishop' ); ?></button>
		</div>
		<div class="mobishop-builder-toolbar__save">
			<?php if ( $mobishop_toolbar_page_toggle ) : ?>
				<label class="mobishop-page-availability" aria-label="<?php esc_attr_e( 'Page availability', 'mobishop' ); ?>">
					<input type="hidden" name="layout[enabled]" value="0">
					<input type="checkbox" name="layout[enabled]" value="1" <?php checked( $mobishop_toolbar_page_enabled ); ?>>
					<span class="mobishop-page-availability__copy"><strong><?php esc_html_e( 'Page status', 'mobishop' ); ?></strong><small class="mobishop-toggle-state"></small></span>
				</label>
			<?php endif; ?>
			<?php if ( $mobishop_toolbar_show_restore ) : ?>
				<button type="submit" class="button mobishop-restore-defaults" name="restore_defaults" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Restore this page to its default settings? Other pages will not be affected.', 'mobishop' ) ); ?>');"><?php esc_html_e( 'Restore Defaults', 'mobishop' ); ?></button>
			<?php endif; ?>
			<?php submit_button( $mobishop_toolbar_save_label, 'primary', 'submit', false ); ?>
		</div>
	<?php endif; ?>
</div>
