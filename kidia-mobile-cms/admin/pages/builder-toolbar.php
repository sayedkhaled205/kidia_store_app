<?php
/** Shared toolbar used by every CMS layout builder. */

defined( 'ABSPATH' ) || exit;

$kidia_toolbar_save_label = isset( $kidia_toolbar_save_label ) ? (string) $kidia_toolbar_save_label : __( 'Save Layout', 'kidia-mobile-cms' );
$kidia_toolbar_show_add = ! empty( $kidia_toolbar_show_add );
$kidia_toolbar_show_restore = ! empty( $kidia_toolbar_show_restore ) || ! empty( $kidia_toolbar_restore_product );
$kidia_toolbar_page_toggle = ! empty( $kidia_toolbar_page_toggle );
$kidia_toolbar_page_enabled = ! isset( $kidia_toolbar_page_enabled ) || ! empty( $kidia_toolbar_page_enabled );
$kidia_toolbar_is_home = isset( $kidia_toolbar_title ) && 'Home Page' === (string) $kidia_toolbar_title;
$kidia_render_add_button = static function (): void {
	?>
	<button type="button" class="button button-primary" id="kidia-add-element"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Element', 'kidia-mobile-cms' ); ?></button>
	<?php
};
?>
<?php if ( $kidia_toolbar_is_home ) : ?>
	<style id="kidia-home-element-picker-card-fix">
		/* Home-only Add Element picker: remove category tabs and keep each card readable. */
		.kidia-element-picker__panel {
			grid-template-rows: auto auto minmax(0, 1fr) auto !important;
		}

		.kidia-element-picker__panel > .kidia-element-category-filter {
			display: none !important;
		}

		.kidia-element-picker__content {
			grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
			align-content: start !important;
			gap: 10px !important;
			padding: 14px !important;
		}

		.kidia-element-picker__content .kidia-element-group {
			display: block !important;
			min-width: 0 !important;
			min-height: 124px !important;
			overflow: visible !important;
		}

		.kidia-element-picker__content .kidia-element-group__summary {
			display: flex !important;
			min-height: 124px !important;
			align-items: center !important;
			justify-content: center !important;
			padding: 14px 10px !important;
		}

		.kidia-element-picker__content .kidia-element-group__identity {
			display: flex !important;
			width: 100% !important;
			min-width: 0 !important;
			flex-direction: column !important;
			align-items: center !important;
			justify-content: center !important;
			gap: 9px !important;
		}

		.kidia-element-picker__content .kidia-element-group__identity .dashicons {
			display: grid !important;
			width: 38px !important;
			height: 38px !important;
			place-items: center !important;
			font-size: 38px !important;
			line-height: 38px !important;
			overflow: visible !important;
		}

		.kidia-element-picker__content .kidia-element-group__identity strong {
			display: block !important;
			width: 100% !important;
			min-height: 20px !important;
			overflow: visible !important;
			color: #1d2327 !important;
			font-size: 13px !important;
			font-weight: 700 !important;
			line-height: 1.35 !important;
			text-align: center !important;
			text-overflow: clip !important;
			white-space: normal !important;
		}

		.kidia-element-picker__content .kidia-element-group__identity small {
			display: none !important;
		}

		@media (max-width: 700px) {
			.kidia-element-picker__content {
				grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
			}
		}

		@media (max-width: 480px) {
			.kidia-element-picker__content {
				grid-template-columns: 1fr !important;
			}
		}
	</style>
<?php endif; ?>
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
			<?php if ( $kidia_toolbar_show_restore ) : ?>
				<button type="submit" class="button kidia-restore-defaults" name="restore_defaults" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Restore this page to its default settings? Other pages will not be affected.', 'kidia-mobile-cms' ) ); ?>');"><?php esc_html_e( 'Restore Defaults', 'kidia-mobile-cms' ); ?></button>
			<?php endif; ?>
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
			<?php if ( $kidia_toolbar_show_restore ) : ?>
				<button type="submit" class="button kidia-restore-defaults" name="restore_defaults" value="1" formnovalidate onclick="return window.confirm('<?php echo esc_js( __( 'Restore this page to its default settings? Other pages will not be affected.', 'kidia-mobile-cms' ) ); ?>');"><?php esc_html_e( 'Restore Defaults', 'kidia-mobile-cms' ); ?></button>
			<?php endif; ?>
			<?php submit_button( $kidia_toolbar_save_label, 'primary', 'submit', false ); ?>
		</div>
	<?php endif; ?>
</div>
