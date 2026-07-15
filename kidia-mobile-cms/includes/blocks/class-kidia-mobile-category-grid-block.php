<?php
/**
 * Category Grid Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Category_Grid_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Category_Grid_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'category_grid';
	}

	public function get_label(): string {
		return __( 'Category Grid', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-grid-view';
	}

	public function get_description(): string {
		return __( 'WooCommerce Categories Grid', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title'       => '',
			'subtitle'    => '',
			'columns'     => 4,
			'limit'       => 8,
			'parent_id'   => 0,
			'hide_empty'  => true,
			'show_names'  => true,
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

			'columns' => max(
				2,
				min(
					6,
					absint( $settings['columns'] ?? 4 )
				)
			),

			'limit' => max(
				1,
				min(
					50,
					absint( $settings['limit'] ?? 8 )
				)
			),

			'parent_id' => absint(
				$settings['parent_id'] ?? 0
			),

			'hide_empty' => ! empty(
				$settings['hide_empty']
			),

			'show_names' => ! empty(
				$settings['show_names']
			),
		);
	}

	public function build_api_data(
		array $settings
	): ?array {

		return $this->sanitize_settings(
			$settings
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

				<label>Columns</label>

				<input
					type="number"
					min="2"
					max="6"
					name="blocks[<?php echo esc_attr( $index ); ?>][settings][columns]"
					value="<?php echo esc_attr( $settings['columns'] ); ?>"
				>

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

		</div>

		<?php
	}
}