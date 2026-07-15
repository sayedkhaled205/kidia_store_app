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

$type = (string) $block_data['type'];

$settings = isset( $block_data['settings'] ) && is_array( $block_data['settings'] )
	? $block_data['settings']
	: array();
?>

<div
	class="kidia-builder-block"
	draggable="true"
	data-label="<?php echo esc_attr( $block->get_label() ); ?>"
>

	<div class="kidia-builder-block__header">

		<span class="dashicons dashicons-move kidia-builder-drag"></span>

		<div class="kidia-builder-block__title">

			<strong>
				<?php echo esc_html( $block->get_label() ); ?>
			</strong>

			<span class="kidia-builder-block__type">
				<?php echo esc_html( $type ); ?>
			</span>

		</div>

		<div class="kidia-builder-block__actions">

			<button
				type="button"
				class="button kidia-toggle-block-settings"
			>
				⚙
			</button>

			<button
				type="button"
				class="button kidia-duplicate-block"
			>
				Duplicate
			</button>

			<button
				type="button"
				class="button button-link-delete kidia-delete-block"
			>
				Delete
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

		<p>

			<label class="kidia-builder-switch">

				<input
					type="checkbox"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][enabled]"
					value="1"
					<?php checked(
						true,
						(bool) $block_data['enabled']
					); ?>
				>

				<span class="kidia-builder-switch__track"></span>

			</label>

		</p>

		<?php
		$block->render_settings(
			is_numeric( $index ) ? (int) $index : 0,
			$settings
		);
		?>

	</div>

</div>