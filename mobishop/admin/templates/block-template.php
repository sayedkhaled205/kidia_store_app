<?php
/**
 * Home Builder block template.
 *
 * Available variables:
 *
 * @var MobiShop_Block $block
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
$element_icon = isset( $block_data['element_icon'] ) ? (string) $block_data['element_icon'] : 'dashicons-screenoptions';
$element_category_key = isset( $block_data['element_category_key'] ) ? (string) $block_data['element_category_key'] : 'content';
$element_category_label = isset( $block_data['element_category_label'] ) ? (string) $block_data['element_category_label'] : __( 'Content', 'mobishop' );
?>

<div
	class="mobishop-builder-block is-collapsed"
	draggable="true"
	data-type="<?php echo esc_attr( $type ); ?>"
	data-library-id="<?php echo esc_attr( $library_id ); ?>"
	data-label="<?php echo esc_attr( $block->get_label() ); ?>"
	data-element-category="<?php echo esc_attr( $element_category_key ); ?>"
>
	<div class="mobishop-builder-block__header">

		<div class="mobishop-builder-block__left">

			<span class="dashicons dashicons-move mobishop-builder-drag" title="<?php esc_attr_e( 'Drag to reorder', 'mobishop' ); ?>"></span>

			<span class="mobishop-builder-block__icon" aria-hidden="true">
				<span class="dashicons <?php echo esc_attr( $element_icon ); ?>"></span>
			</span>

			<div class="mobishop-builder-block__title">

				<strong class="mobishop-block-name">
					<?php echo esc_html( $name ); ?>
				</strong>

			</div>

		</div>

		<div class="mobishop-builder-block__actions mobishop-card-actions">

			<button
				type="button"
				class="button mobishop-duplicate-block mobishop-card-action mobishop-card-action--primary"
			>
				<span class="dashicons dashicons-admin-page" aria-hidden="true"></span>
				<?php esc_html_e(
					'Duplicate',
					'mobishop'
				); ?>
			</button>

			<button
				type="button"
				class="button mobishop-delete-block mobishop-card-action mobishop-card-action--secondary"
				aria-label="<?php esc_attr_e( 'Remove this element', 'mobishop' ); ?>"
			>
				<span class="dashicons dashicons-trash" aria-hidden="true"></span>
				<?php esc_html_e( 'Remove', 'mobishop' ); ?>
			</button>

			<button
				type="button"
				class="button mobishop-toggle-block-settings mobishop-card-action mobishop-card-action--expand"
				aria-label="<?php esc_attr_e( 'Open element settings', 'mobishop' ); ?>"
				aria-expanded="false"
			>
				<span class="dashicons dashicons-arrow-down-alt2" aria-hidden="true"></span>
			</button>

			<label class="mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle" title="<?php esc_attr_e( 'Show or hide this element', 'mobishop' ); ?>">
				<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][enabled]" value="1" <?php checked( true, ! empty( $block_data['enabled'] ) ); ?>>
				<span class="mobishop-builder-switch__track"></span>
				<span class="mobishop-builder-switch__state"></span>
			</label>

		</div>

	</div>
	<div class="mobishop-builder-block__body">
		<input
			type="hidden"
			class="mobishop-block-id"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][id]"
			value="<?php echo esc_attr( (string) $block_data['id'] ); ?>"
		>

		<input
			type="hidden"
			class="mobishop-block-library-id"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][library_id]"
			value="<?php echo esc_attr( $library_id ); ?>"
		>

		<input
			type="hidden"
			class="mobishop-block-source-library-id"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][source_library_id]"
			value=""
		>

		<input
			type="hidden"
			class="mobishop-block-create-intent"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][create_intent]"
			value="0"
		>

		<input
			type="hidden"
			class="mobishop-block-type"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][type]"
			value="<?php echo esc_attr( $type ); ?>"
		>

		<input
			type="hidden"
			class="mobishop-block-order"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][order]"
			value="<?php echo esc_attr( (string) $block_data['order'] ); ?>"
		>

		<input
			type="hidden"
			class="mobishop-block-status"
			name="blocks[<?php echo esc_attr( (string) $index ); ?>][status]"
			value="<?php echo esc_attr( $status ); ?>"
		>

		<div class="mobishop-builder-essentials">

			<div class="mobishop-builder-field mobishop-builder-field--name">

			<label>

				<?php
				esc_html_e(
					'Element Name',
					'mobishop'
				);
				?>

			</label>

			<input
				type="text"
				class="mobishop-block-name-input"
				name="blocks[<?php echo esc_attr( (string) $index ); ?>][name]"
				value="<?php echo esc_attr( $name ); ?>"
			>

			</div>

			<div class="mobishop-builder-field mobishop-builder-field--visibility">
				<label for="mobishop-status-<?php echo esc_attr( (string) $index ); ?>">
					<?php esc_html_e( 'Visibility', 'mobishop' ); ?>
				</label>
				<select class="mobishop-block-status-select" id="mobishop-status-<?php echo esc_attr( (string) $index ); ?>">
					<option value="published" <?php selected( 'published', $status ); ?>><?php esc_html_e( 'Published', 'mobishop' ); ?></option>
					<option value="draft" <?php selected( 'draft', $status ); ?>><?php esc_html_e( 'Draft', 'mobishop' ); ?></option>
				</select>
			</div>

		</div>

		<div class="mobishop-builder-inline-settings">
			<div class="mobishop-builder-settings-heading">
				<span class="dashicons dashicons-admin-generic" aria-hidden="true"></span>
				<strong><?php esc_html_e( 'Element Settings', 'mobishop' ); ?></strong>
			</div>

			<div class="mobishop-builder-settings-content">
				<div class="mobishop-builder-field mobishop-section-layout-field"><label><?php esc_html_e( 'Merge up', 'mobishop' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][margin_top]" value="<?php echo esc_attr( (string) ( $settings['margin_top'] ?? 0 ) ); ?>"></div>
				<div class="mobishop-builder-field mobishop-section-layout-field"><label><?php esc_html_e( 'Merge down', 'mobishop' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][margin_bottom]" value="<?php echo esc_attr( (string) ( $settings['margin_bottom'] ?? 0 ) ); ?>"></div>
				<div class="mobishop-builder-field mobishop-section-layout-field"><label><?php esc_html_e( 'Space up', 'mobishop' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][space_up]" value="<?php echo esc_attr( (string) ( $settings['space_up'] ?? $settings['padding_vertical'] ?? 0 ) ); ?>"></div>
				<div class="mobishop-builder-field mobishop-section-layout-field"><label><?php esc_html_e( 'Space down', 'mobishop' ); ?></label><input type="number" min="0" max="80" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][space_down]" value="<?php echo esc_attr( (string) ( $settings['space_down'] ?? $settings['padding_vertical'] ?? 0 ) ); ?>"></div>
				<div class="mobishop-builder-field mobishop-builder-field--background mobishop-section-layout-field"><label><?php esc_html_e( 'Background color', 'mobishop' ); ?></label><div class="mobishop-builder-background-control"><input type="color" class="mobishop-block-background-picker" value="<?php echo esc_attr( sanitize_hex_color( (string) ( $settings['block_background'] ?? '' ) ) ?: '#FFFFFF' ); ?>"><input type="text" class="mobishop-block-background-value" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][block_background]" value="<?php echo esc_attr( (string) ( $settings['block_background'] ?? '' ) ); ?>" placeholder="transparent"></div></div>
				<?php
				$block->render_settings( (int) $index, $settings );
				?>
			</div>
		</div>

	</div>

</div>
