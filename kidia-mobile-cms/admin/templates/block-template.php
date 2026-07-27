<?php
/**
 * Home Builder block template.
 *
 * Available variables:
 *
 * @var Kidia_Mobile_Block $block
 * @var array<string,mixed> $block_data
 * @var int|string $index
 */

defined( 'ABSPATH' ) || exit;

$type = isset( $block_data['type'] )
	? (string) $block_data['type']
	: '';

$name = isset( $block_data['name'] )
	? (string) $block_data['name']
	: $block->get_label();

$library_id = isset( $block_data['library_id'] )
	? (string) $block_data['library_id']
	: (string) $block_data['id'];

$status = 'published' === ( $block_data['status'] ?? 'draft' )
	? 'published'
	: 'draft';
$settings = isset( $block_data['settings'] ) && is_array( $block_data['settings'] ) ? $block_data['settings'] : $block->get_default_settings();

if ( ! isset( $GLOBALS['kidia_mobile_element_card_styles_printed'] ) ) {
	$GLOBALS['kidia_mobile_element_card_styles_printed'] = true;
	?>
	<style id="kidia-mobile-element-card-actions">
		.kidia-builder-block__header {
			display: grid;
			grid-template-columns: minmax(0, 1fr);
			gap: 10px;
			min-height: 0;
			padding: 12px;
		}

		.kidia-builder-block__left {
			display: grid;
			grid-template-columns: 38px minmax(0, 1fr);
			align-items: center;
			gap: 10px;
			width: 100%;
		}

		.kidia-builder-drag {
			width: 38px;
			height: 38px;
			flex-basis: 38px;
			border: 1px solid #d9e8e3;
			background: #f2f8f6;
		}

		.kidia-builder-block__title {
			display: grid;
			grid-template-columns: minmax(0, 1fr) max-content max-content;
			align-items: center;
			gap: 6px;
		}

		.kidia-builder-block__title strong {
			grid-column: auto;
			min-width: 0;
			font-size: 14px;
		}

		.kidia-builder-block__actions {
			display: grid;
			grid-template-columns: minmax(112px, auto) minmax(108px, auto) minmax(108px, auto) minmax(102px, auto);
			align-items: stretch;
			justify-content: start;
			gap: 8px;
			width: 100%;
			padding-top: 10px;
			border-top: 1px solid #e8efed;
			direction: rtl;
		}

		.kidia-builder-block__actions .button,
		.kidia-builder-block__actions .kidia-builder-switch--card {
			box-sizing: border-box;
			width: 100%;
			min-height: 38px;
			margin: 0;
			border-radius: 7px;
		}

		.kidia-builder-block__actions .button {
			display: inline-flex;
			align-items: center;
			justify-content: center;
			gap: 6px;
			padding-inline: 12px;
			font-weight: 600;
		}

		.kidia-builder-block__actions .kidia-toggle-block-settings {
			width: 100%;
			padding-inline: 12px;
			border-color: #2f806e;
			color: #236b59;
		}

		.kidia-builder-block__actions .kidia-builder-switch--card {
			display: inline-flex;
			align-items: center;
			justify-content: center;
			gap: 8px;
			padding-inline: 10px;
			border: 1px solid #d8e5e1;
			background: #f7fbfa;
		}

		.kidia-builder-block__actions .kidia-builder-switch--card::before {
			content: "Visible";
			color: #2c3338;
			font-size: 12px;
			font-weight: 600;
		}

		.kidia-builder-block__actions .kidia-builder-switch__state {
			display: none;
		}

		.kidia-builder-block__actions .kidia-delete-block {
			background: #fff8f8;
		}

		.kidia-builder-block__actions .dashicons {
			width: 18px;
			height: 18px;
			font-size: 18px;
		}

		@media (max-width: 1180px) {
			.kidia-builder-block__actions {
				grid-template-columns: repeat(2, minmax(0, 1fr));
			}
		}

		@media (max-width: 782px) {
			.kidia-builder-block__title {
				grid-template-columns: minmax(0, 1fr);
			}

			.kidia-builder-block__type,
			.kidia-builder-status {
				display: none;
			}

			.kidia-builder-block__actions {
				grid-template-columns: minmax(0, 1fr);
			}
		}
	</style>
	<?php
}
?>

<div
	class="kidia-builder-block is-collapsed"
	draggable="true"
	data-type="<?php echo esc_attr( $type ); ?>"
	data-library-id="<?php echo esc_attr( $library_id ); ?>"
	data-label="<?php echo esc_attr( $block->get_label() ); ?>"
>

	<div class="kidia-builder-block__header">

		<div class="kidia-builder-block__left">

			<span class="dashicons dashicons-move kidia-builder-drag" title="<?php esc_attr_e( 'Drag to reorder', 'kidia-mobile-cms' ); ?>"></span>

			<div class="kidia-builder-block__title">

				<strong class="kidia-block-name">
					<?php echo esc_html( $name ); ?>
				</strong>

				<span class="kidia-builder-block__type">
					<?php echo esc_html( $block->get_label() ); ?>
				</span>

				<span
					class="kidia-builder-status kidia-builder-status--<?php echo esc_attr( $status ); ?>"
				>
					<?php
					echo esc_html(
						'published' === $status
							? __( 'Published', 'kidia-mobile-cms' )
							: __( 'Draft', 'kidia-mobile-cms' )
					);
					?>
				</span>

			</div>

		</div>

		<div class="kidia-builder-block__actions kidia-card-actions">

			<label class="kidia-builder-switch kidia-builder-switch--card kidia-card-action kidia-card-action--toggle" title="<?php esc_attr_e( 'Show or hide this element', 'kidia-mobile-cms' ); ?>">
				<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][enabled]" value="1" <?php checked( true, ! empty( $block_data['enabled'] ) ); ?>>
				<span class="kidia-builder-switch__track"></span>
				<span class="kidia-builder-switch__state"></span>
			</label>

			<button
				type="button"
				class="button kidia-toggle-block-settings kidia-card-action kidia-card-action--expand"
				aria-label="<?php esc_attr_e( 'Open element settings', 'kidia-mobile-cms' ); ?>"
			>
				<span class="dashicons dashicons-arrow-down-alt2" aria-hidden="true"></span>
				<span><?php esc_html_e( 'Settings', 'kidia-mobile-cms' ); ?></span>
			</button>

			<button
				type="button"
				class="button kidia-duplicate-block kidia-card-action kidia-card-action--secondary"
			>
				<span class="dashicons dashicons-admin-page" aria-hidden="true"></span>
				<?php esc_html_e(
					'Duplicate',
					'kidia-mobile-cms'
				); ?>
			</button>

			<button
				type="button"
				class="button button-link-delete kidia-delete-block kidia-card-action kidia-card-action--primary"
			>
				<span class="dashicons dashicons-trash" aria-hidden="true"></span>
				<?php esc_html_e(
					'Remove',
					'kidia-mobile-cms'
				); ?>
			</button>

		</div>

	</div>
	<div class="kidia-builder-block__body">

		<input
			type="hidden"
			class="kidia-block-id"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][id]"
			value="<?php echo esc_attr( (string) $block_data['id'] ); ?>"
		>

		<input
			type="hidden"
			class="kidia-block-library-id"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][library_id]"
			value="<?php echo esc_attr( $library_id ); ?>"
		>

		<input
			type="hidden"
			class="kidia-block-source-library-id"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][source_library_id]"
			value=""
		>

		<input
			type="hidden"
			class="kidia-block-create-intent"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][create_intent]"
			value="0"
		>

		<input
			type="hidden"
			class="kidia-block-type"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][type]"
			value="<?php echo esc_attr( $type ); ?>"
		>

		<input
			type="hidden"
			class="kidia-block-order"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][order]"
			value="<?php echo esc_attr( (string) $block_data['order'] ); ?>"
		>

		<input
			type="hidden"
			class="kidia-block-status"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][status]"
			value="<?php echo esc_attr( $status ); ?>"
		>

		<div class="kidia-builder-essentials">

			<div class="kidia-builder-field kidia-builder-field--name">

			<label>

				<?php
				esc_html_e(
					'Element Name',
					'kidia-mobile-cms'
				);
				?>

			</label>

			<input
				type="text"
				class="kidia-block-name-input"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][name]"
				value="<?php echo esc_attr( $name ); ?>"
			>

			</div>

			<div class="kidia-builder-field kidia-builder-field--visibility">
				<label for="kidia-status-<?php echo esc_attr( (string) $index ); ?>">
					<?php esc_html_e( 'Visibility', 'kidia-mobile-cms' ); ?>
				</label>
				<select class="kidia-block-status-select" id="kidia-status-<?php echo esc_attr( (string) $index ); ?>">
					<option value="published" <?php selected( 'published', $status ); ?>><?php esc_html_e( 'Published', 'kidia-mobile-cms' ); ?></option>
					<option value="draft" <?php selected( 'draft', $status ); ?>><?php esc_html_e( 'Draft', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

		</div>

		<div class="kidia-builder-inline-settings">
			<div class="kidia-builder-settings-heading">
				<span class="dashicons dashicons-admin-generic" aria-hidden="true"></span>
				<strong><?php esc_html_e( 'Element Settings', 'kidia-mobile-cms' ); ?></strong>
			</div>

			<div class="kidia-builder-settings-content">
				<div class="kidia-builder-field kidia-section-layout-field"><label><?php esc_html_e( 'Merge up', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][margin_top]" value="<?php echo esc_attr( (string) ( $settings['margin_top'] ?? 0 ) ); ?>"></div>
				<div class="kidia-builder-field kidia-section-layout-field"><label><?php esc_html_e( 'Merge down', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][margin_bottom]" value="<?php echo esc_attr( (string) ( $settings['margin_bottom'] ?? 0 ) ); ?>"></div>
				<div class="kidia-builder-field kidia-section-layout-field"><label><?php esc_html_e( 'Space up', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][space_up]" value="<?php echo esc_attr( (string) ( $settings['space_up'] ?? $settings['padding_vertical'] ?? 0 ) ); ?>"></div>
				<div class="kidia-builder-field kidia-section-layout-field"><label><?php esc_html_e( 'Space down', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][space_down]" value="<?php echo esc_attr( (string) ( $settings['space_down'] ?? $settings['padding_vertical'] ?? 0 ) ); ?>"></div>
				<div class="kidia-builder-field kidia-builder-field--background kidia-section-layout-field"><label><?php esc_html_e( 'Background color', 'kidia-mobile-cms' ); ?></label><div class="kidia-builder-background-control"><input type="color" class="kidia-block-background-picker" value="<?php echo esc_attr( sanitize_hex_color( (string) ( $settings['block_background'] ?? '' ) ) ?: '#FFFFFF' ); ?>"><input type="text" class="kidia-block-background-value" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][block_background]" value="<?php echo esc_attr( (string) ( $settings['block_background'] ?? '' ) ); ?>" placeholder="transparent"></div></div>
				<?php
				$block->render_settings( (int) $index, $settings );
				?>
			</div>
		</div>

	</div>

</div>