<?php
/** Shared toolbar used by every CMS layout builder. */

defined( 'ABSPATH' ) || exit;

$kidia_toolbar_save_label = isset( $kidia_toolbar_save_label ) ? (string) $kidia_toolbar_save_label : __( 'Save Layout', 'kidia-mobile-cms' );
$kidia_toolbar_show_add = ! empty( $kidia_toolbar_show_add );
$kidia_toolbar_restore_product = ! empty( $kidia_toolbar_restore_product );
$kidia_toolbar_page_toggle = ! empty( $kidia_toolbar_page_toggle );
$kidia_toolbar_page_enabled = ! isset( $kidia_toolbar_page_enabled ) || ! empty( $kidia_toolbar_page_enabled );

if ( ! isset( $GLOBALS['kidia_mobile_home_builder_ui_styles_printed'] ) ) {
	$GLOBALS['kidia_mobile_home_builder_ui_styles_printed'] = true;
	?>
	<style id="kidia-mobile-home-builder-ui-refinements">
		/* Keep the phone preview completely visible on common laptop screens. */
		.kidia-builder-wrap .kidia-mobile-preview__device {
			box-sizing: border-box;
			width: min(313.5px, calc((100vh - 205px) * .45));
			min-width: 220px;
			aspect-ratio: 313.5 / 672.89;
		}

		.kidia-builder-wrap .kidia-mobile-preview__screen {
			height: auto;
			aspect-ratio: 360 / 800;
		}

		.kidia-builder-wrap .kidia-mobile-preview__screen > .kidia-flutter-preview {
			position: absolute;
			inset: 0;
			width: 100%;
			height: 100%;
			zoom: 1;
		}

		/* Keep the three main Home Builder actions together in one row. */
		.kidia-builder-toolbar--home {
			align-items: center;
		}

		.kidia-builder-toolbar--home .kidia-builder-toolbar__primary-actions {
			display: flex;
			align-items: stretch;
			flex-wrap: nowrap;
			gap: 8px;
			direction: rtl;
		}

		.kidia-builder-toolbar--home .kidia-builder-toolbar__primary-actions > .button,
		.kidia-builder-toolbar--home .kidia-page-availability {
			box-sizing: border-box;
			min-height: 42px;
			margin: 0;
			white-space: nowrap;
		}

		.kidia-builder-toolbar--home .kidia-builder-toolbar__secondary-actions {
			display: flex;
			align-items: center;
			gap: 7px;
		}

		/* Keep card controls readable and centered at every browser zoom level. */
		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-page-card__header {
			display: flex !important;
			align-items: center;
			justify-content: space-between;
			flex-wrap: wrap;
			gap: 10px 14px;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-fixed-chrome-identity {
			min-width: 0;
			margin-inline-start: auto;
			white-space: nowrap;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-card-actions,
		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-chrome-transfer-actions {
			display: inline-flex !important;
			align-items: center;
			flex-wrap: nowrap;
			gap: 8px;
			width: auto;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-card-actions .button {
			display: inline-flex !important;
			align-items: center;
			justify-content: center;
			width: auto !important;
			min-width: 42px;
			height: 38px;
			min-height: 38px;
			margin: 0;
			padding-inline: 12px;
			border-color: #2f806e;
			border-radius: 7px;
			color: #236b59;
			font-weight: 600;
			line-height: 1;
			white-space: nowrap;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-card-actions .kidia-card-action--expand {
			width: 42px !important;
			padding-inline: 0;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-builder-switch--card {
			display: inline-flex !important;
			align-items: center;
			justify-content: center;
			gap: 7px;
			width: auto !important;
			min-height: 0;
			margin: 0;
			padding: 0;
			border: 0;
			background: transparent;
			white-space: nowrap;
		}

		@media (max-width: 1120px) {
			.kidia-builder-toolbar--home {
				align-items: stretch;
				flex-direction: column;
			}

			.kidia-builder-toolbar--home .kidia-builder-toolbar__primary-actions {
				width: 100%;
			}

			.kidia-builder-toolbar--home .kidia-builder-toolbar__primary-actions > * {
				flex: 1 1 0;
			}
		}
	</style>
	<?php
}
?>
<div class="kidia-builder-toolbar kidia-shared-builder-toolbar<?php echo $kidia_toolbar_show_add && $kidia_toolbar_page_toggle ? ' kidia-builder-toolbar--home' : ''; ?>">
	<?php if ( $kidia_toolbar_show_add && $kidia_toolbar_page_toggle ) : ?>
		<div class="kidia-builder-toolbar__primary-actions">
			<button type="button" class="button button-primary" id="kidia-add-element"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Element', 'kidia-mobile-cms' ); ?></button>
			<label class="kidia-page-availability" aria-label="<?php esc_attr_e( 'Page availability', 'kidia-mobile-cms' ); ?>">
				<input type="hidden" name="layout[enabled]" value="0">
				<input type="checkbox" name="layout[enabled]" value="1" <?php checked( $kidia_toolbar_page_enabled ); ?>>
				<span class="kidia-page-availability__icon"><span class="dashicons dashicons-visibility"></span></span>
				<span class="kidia-page-availability__copy"><strong><?php esc_html_e( 'Page status', 'kidia-mobile-cms' ); ?></strong><small class="kidia-toggle-state"></small></span>
			</label>
			<?php submit_button( $kidia_toolbar_save_label, 'primary', 'submit', false ); ?>
		</div>
		<div class="kidia-builder-toolbar__secondary-actions">
			<button type="button" class="button" id="kidia-collapse-all"><?php esc_html_e( 'Collapse All', 'kidia-mobile-cms' ); ?></button>
			<button type="button" class="button" id="kidia-expand-all"><?php esc_html_e( 'Expand All', 'kidia-mobile-cms' ); ?></button>
		</div>
	<?php else : ?>
		<div class="kidia-builder-toolbar__actions">
			<?php if ( $kidia_toolbar_show_add ) : ?>
				<button type="button" class="button button-primary" id="kidia-add-element"><span class="dashicons dashicons-plus-alt2"></span><?php esc_html_e( 'Add Element', 'kidia-mobile-cms' ); ?></button>
			<?php endif; ?>
			<button type="button" class="button" id="kidia-collapse-all"><?php esc_html_e( 'Collapse All', 'kidia-mobile-cms' ); ?></button>
			<button type="button" class="button" id="kidia-expand-all"><?php esc_html_e( 'Expand All', 'kidia-mobile-cms' ); ?></button>
		</div>
		<div class="kidia-builder-toolbar__save">
			<?php if ( $kidia_toolbar_page_toggle ) : ?>
				<label class="kidia-page-availability" aria-label="<?php esc_attr_e( 'Page availability', 'kidia-mobile-cms' ); ?>">
					<input type="hidden" name="layout[enabled]" value="0">
					<input type="checkbox" name="layout[enabled]" value="1" <?php checked( $kidia_toolbar_page_enabled ); ?>>
					<span class="kidia-page-availability__icon"><span class="dashicons dashicons-visibility"></span></span>
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
