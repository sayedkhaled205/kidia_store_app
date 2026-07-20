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

			<span class="dashicons dashicons-move kidia-builder-drag"></span>

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

		<div class="kidia-builder-block__actions">

			<label class="kidia-builder-switch kidia-builder-switch--card" title="<?php esc_attr_e( 'Show or hide this element', 'kidia-mobile-cms' ); ?>">
				<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][enabled]" value="1" <?php checked( true, ! empty( $block_data['enabled'] ) ); ?>>
				<span class="kidia-builder-switch__track"></span>
				<span class="kidia-builder-switch__state"></span>
			</label>

			<button
				type="button"
				class="button kidia-toggle-block-settings"
			>
				<span class="dashicons dashicons-arrow-down-alt2"></span>
			</button>

			<button
				type="button"
				class="button kidia-duplicate-block"
			>
				<?php esc_html_e(
					'Duplicate',
					'kidia-mobile-cms'
				); ?>
			</button>

			<button
				type="button"
				class="button button-link-delete kidia-delete-block"
			>
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
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Merge up', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][margin_top]" value="<?php echo esc_attr( (string) ( $settings['margin_top'] ?? 0 ) ); ?>"></div>
				<div class="kidia-builder-field"><label><?php esc_html_e( 'Merge down', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][margin_bottom]" value="<?php echo esc_attr( (string) ( $settings['margin_bottom'] ?? 0 ) ); ?>"></div>
				<div class="kidia-builder-field kidia-builder-field--background"><label><?php esc_html_e( 'Background color', 'kidia-mobile-cms' ); ?></label><div class="kidia-builder-background-control"><input type="color" class="kidia-block-background-picker" value="<?php echo esc_attr( sanitize_hex_color( (string) ( $settings['block_background'] ?? '' ) ) ?: '#FFFFFF' ); ?>"><input type="text" class="kidia-block-background-value" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][block_background]" value="<?php echo esc_attr( (string) ( $settings['block_background'] ?? '' ) ); ?>" placeholder="transparent"></div></div>
				<?php
				$block->render_settings( (int) $index, $settings );
				?>
			</div>
		</div>

	</div>

</div>
