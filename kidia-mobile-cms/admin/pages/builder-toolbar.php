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

		/* Fixed header/footer cards: icon, name, status, expand, copy and paste. */
		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-page-card__header {
			display: flex;
			align-items: center;
			justify-content: flex-start;
			gap: 10px;
			direction: rtl;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-fixed-chrome-identity {
			display: inline-flex;
			align-items: center;
			gap: 7px;
			margin-inline-end: 0;
			white-space: nowrap;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-card-actions {
			display: flex;
			align-items: center;
			flex: 1;
			gap: 8px;
			direction: rtl;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-fixed-chrome-toggle { order: 1; }
		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-fixed-chrome-expand { order: 2; }
		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-chrome-transfer-actions {
			order: 3;
			display: inline-flex;
			align-items: center;
			gap: 8px;
			direction: rtl;
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-builder-switch__state::before {
			content: "Inactive";
		}

		.kidia-builder-wrap .kidia-fixed-chrome-card .kidia-builder-switch input:checked ~ .kidia-builder-switch__state::before {
			content: "Active";
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
