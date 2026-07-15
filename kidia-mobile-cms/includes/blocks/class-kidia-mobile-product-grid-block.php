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

	/**
	 * Returns block type.
	 *
	 * @return string
	 */
	public function get_type(): string {
		return 'product_grid';
	}

	/**
	 * Returns block label.
	 *
	 * @return string
	 */
	public function get_label(): string {
		return __(
			'Product Grid',
			'kidia-mobile-cms'
		);
	}

	/**
	 * Returns block icon.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-screenoptions';
	}

	/**
	 * Returns block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return __(
			'WooCommerce Product Grid.',
			'kidia-mobile-cms'
		);
	}

	/**
	 * Returns default settings.
	 *
	 * @return array<string,mixed>
	 */
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

	/**
	 * Sanitizes block settings.
	 *
	 * @param array<string,mixed> $settings Raw settings.
	 *
	 * @return array<string,mixed>
	 */
	public function sanitize_settings(
		array $settings
	): array {

		$source = sanitize_key(
			$settings['source'] ?? 'latest'
		);

		$allowed_sources = array(
			'latest',
			'featured',
			'on_sale',
			'category',
			'manual',
		);

		if (
			! in_array(
				$source,
				$allowed_sources,
				true
			)
		) {
			$source = 'latest';
		}

		return array(
			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'subtitle' => sanitize_textarea_field(
				$settings['subtitle'] ?? ''
			),

			'source' => $source,

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
				1,
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

	/**
	 * Builds API data.
	 *
	 * @param array<string,mixed> $settings Settings.
	 *
	 * @return array<string,mixed>|null
	 */
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

	/**
	 * Renders block settings.
	 *
	 * @param int                 $index    Block index.
	 * @param array<string,mixed> $settings Settings.
	 *
	 * @return void
	 */
	public function render_settings(
		int $index,
		array $settings
	): void {

		$settings = $this->sanitize_settings(
			wp_parse_args(
				$settings,
				$this->get_default_settings()
			)
		);

		?>
		<div class="kidia-builder-grid">

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Title',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]"
					value="<?php echo esc_attr( $settings['title'] ); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Subtitle',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]"
					value="<?php echo esc_attr( $settings['subtitle'] ); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Source',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<select
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][source]"
				>
					<option
						value="latest"
						<?php selected( 'latest', $settings['source'] ); ?>
					>
						<?php esc_html_e( 'Latest', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="featured"
						<?php selected( 'featured', $settings['source'] ); ?>
					>
						<?php esc_html_e( 'Featured', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="on_sale"
						<?php selected( 'on_sale', $settings['source'] ); ?>
					>
						<?php esc_html_e( 'On Sale', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="category"
						<?php selected( 'category', $settings['source'] ); ?>
					>
						<?php esc_html_e( 'Category', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="manual"
						<?php selected( 'manual', $settings['source'] ); ?>
					>
						<?php esc_html_e( 'Manual', 'kidia-mobile-cms' ); ?>
					</option>
				</select>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Limit',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="number"
					min="1"
					max="50"
					step="1"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][limit]"
					value="<?php echo esc_attr( (string) $settings['limit'] ); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Columns',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="number"
					min="1"
					max="4"
					step="1"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][columns]"
					value="<?php echo esc_attr( (string) $settings['columns'] ); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Category ID',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="number"
					min="0"
					step="1"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][category_id]"
					value="<?php echo esc_attr( (string) $settings['category_id'] ); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label class="kidia-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_view_all]"
						value="1"
						<?php checked( true, $settings['show_view_all'] ); ?>
					>

					<span class="kidia-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Show View All',
						'kidia-mobile-cms'
					);
					?>
				</span>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'View All Label',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][view_all_label]"
					value="<?php echo esc_attr( $settings['view_all_label'] ); ?>"
				>

			</div>

		</div>
		<?php
	}
}