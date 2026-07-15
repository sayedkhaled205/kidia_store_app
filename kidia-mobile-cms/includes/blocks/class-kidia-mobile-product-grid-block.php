<?php
/**
 * Product Grid Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Product_Grid_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Product_Grid_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'product_grid';
	}

	public function get_label(): string {
		return __( 'Product Grid', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-screenoptions';
	}

	public function get_description(): string {
		return __(
			'WooCommerce Product Grid.',
			'kidia-mobile-cms'
		);
	}

	public function get_default_settings(): array {
		return array(
			'title'          => '',
			'subtitle'       => '',
			'source'         => 'latest',
			'limit'          => 8,
			'columns'        => 2,
			'category_id'    => 0,
			'show_view_all'  => true,
			'view_all_label' => '',
			'action_type'    => '',
			'action_value'   => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(

			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'subtitle' => sanitize_textarea_field(
				$settings['subtitle'] ?? ''
			),

			'source' => sanitize_key(
				$settings['source'] ?? 'latest'
			),

			'limit' => max(
				1,
				min(
					50,
					absint(
						$settings['limit'] ?? 8
					)
				)
			),

			'columns' => max(
				2,
				min(
					4,
					absint(
						$settings['columns'] ?? 2
					)
				)
			),

			'category_id' => absint(
				$settings['category_id'] ?? 0
			),

			'show_view_all' => ! empty(
				$settings['show_view_all']
			),

			'view_all_label' => sanitize_text_field(
				$settings['view_all_label'] ?? ''
			),

			'action_type' => sanitize_key(
				$settings['action_type'] ?? ''
			),

			'action_value' => sanitize_text_field(
				$settings['action_value'] ?? ''
			),

		);
	}
}
	public function build_api_data(
		array $settings
	): ?array {

		$settings = $this->sanitize_settings(
			wp_parse_args(
				$settings,
				$this->get_default_settings()
			)
		);

		return array(
			'title'          => $settings['title'],
			'subtitle'       => $settings['subtitle'],
			'source'         => $settings['source'],
			'limit'          => $settings['limit'],
			'columns'        => $settings['columns'],
			'category_id'    => $settings['category_id'],
			'show_view_all'  => $settings['show_view_all'],
			'view_all_label' => $settings['view_all_label'],
			'action'         => $this->build_action(
				$settings['action_type'],
				$settings['action_value']
			),
		);
	}

	public function render_settings(
		int $index,
		array $settings
	): void {

		$settings = wp_parse_args(
			$settings,
			$this->get_default_settings()
		);

?>

<div class="kidia-builder-grid">

	<div class="kidia-builder-field">

		<label>Title</label>

		<input
			type="text"
			name="blocks[<?php echo esc_attr( $index ); ?>][settings][title]"
			value="<?php echo esc_attr( $settings['title'] ); ?>"
		>

	</div>

	<div class="kidia-builder-field">

		<label>Subtitle</label>

		<input
			type="text"
			name="blocks[<?php echo esc_attr( $index ); ?>][settings][subtitle]"
			value="<?php echo esc_attr( $settings['subtitle'] ); ?>"
		>

	</div>

	<div class="kidia-builder-field">

		<label>Source</label>

		<select
			name="blocks[<?php echo esc_attr( $index ); ?>][settings][source]"
		>

			<option value="latest" <?php selected( 'latest', $settings['source'] ); ?>>Latest</option>
			<option value="featured" <?php selected( 'featured', $settings['source'] ); ?>>Featured</option>
			<option value="sale" <?php selected( 'sale', $settings['source'] ); ?>>Sale</option>
			<option value="category" <?php selected( 'category', $settings['source'] ); ?>>Category</option>
			<option value="manual" <?php selected( 'manual', $settings['source'] ); ?>>Manual</option>

		</select>

	</div>

	<div class="kidia-builder-field">

		<label>Limit</label>

		<input
			type="number"
			min="1"
			max="50"
			name="blocks[<?php echo esc_attr( $index ); ?>][settings][limit]"
			value="<?php echo esc_attr( $settings['limit'] ); ?>"
		>

	</div>

	<div class="kidia-builder-field">

		<label>Columns</label>

		<input
			type="number"
			min="2"
			max="4"
			name="blocks[<?php echo esc_attr( $index ); ?>][settings][columns]"
			value="<?php echo esc_attr( $settings['columns'] ); ?>"
		>

	</div>

</div>

<?php
	}
}