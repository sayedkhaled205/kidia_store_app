<?php
/**
 * Hero Slider Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Hero_Slider_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Hero_Slider_Block extends Kidia_Mobile_Block {

	/**
	 * Returns block type.
	 *
	 * @return string
	 */
	public function get_type(): string {
		return 'hero_slider';
	}

	/**
	 * Returns block label.
	 *
	 * @return string
	 */
	public function get_label(): string {
		return __( 'Hero Slider', 'kidia-mobile-cms' );
	}

	/**
	 * Returns block icon.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-images-alt2';
	}

	/**
	 * Returns block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return __(
			'Main promotional slider displayed anywhere on the home page.',
			'kidia-mobile-cms'
		);
	}

	/**
	 * Returns default settings.
	 *
	 * @return array<string, mixed>
	 */
	public function get_default_settings(): array {
		return array(
			'aspect_ratio' => 1.8,
			'auto_play'    => true,
			'interval_ms'  => 4500,
			'items'        => array(),
		);
	}

	/**
	 * Sanitizes submitted settings.
	 *
	 * @param array<string, mixed> $settings Submitted settings.
	 *
	 * @return array<string, mixed>
	 */
	public function sanitize_settings(
		array $settings
	): array {
		$aspect_ratio = isset( $settings['aspect_ratio'] )
			? (float) $settings['aspect_ratio']
			: 1.8;

		$aspect_ratio = max(
			1,
			min( 4, $aspect_ratio )
		);

		$interval_ms = isset( $settings['interval_ms'] )
			? absint( $settings['interval_ms'] )
			: 4500;

		$interval_ms = max(
			2000,
			min( 15000, $interval_ms )
		);

		$items = isset( $settings['items'] )
			&& is_array( $settings['items'] )
				? $settings['items']
				: array();

		$sanitized_items = array();

		foreach ( $items as $index => $item ) {
			if ( ! is_array( $item ) ) {
				continue;
			}

			$image_url = isset( $item['image_url'] )
				? esc_url_raw( $item['image_url'] )
				: '';

			if ( empty( $image_url ) ) {
				continue;
			}

			$action_type = isset( $item['action_type'] )
				? sanitize_key( $item['action_type'] )
				: '';

			$allowed_action_types = array(
				'',
				'product',
				'category',
				'collection',
				'search',
				'external',
			);

			if ( ! in_array( $action_type, $allowed_action_types, true ) ) {
				$action_type = '';
			}

			$sanitized_items[] = array(
				'id'           => isset( $item['id'] )
					? sanitize_key( $item['id'] )
					: 'hero_slide_' . ( absint( $index ) + 1 ),
				'enabled'      => isset( $item['enabled'] )
					? (bool) $item['enabled']
					: true,
				'image_url'    => $image_url,
				'title'        => isset( $item['title'] )
					? sanitize_text_field( $item['title'] )
					: '',
				'subtitle'     => isset( $item['subtitle'] )
					? sanitize_textarea_field( $item['subtitle'] )
					: '',
				'action_type'  => $action_type,
				'action_value' => isset( $item['action_value'] )
					? sanitize_text_field( $item['action_value'] )
					: '',
			);
		}

		return array(
			'aspect_ratio' => $aspect_ratio,
			'auto_play'    => isset( $settings['auto_play'] )
				? (bool) $settings['auto_play']
				: false,
			'interval_ms'  => $interval_ms,
			'items'        => $sanitized_items,
		);
	}

	/**
	 * Builds REST API data.
	 *
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return array<string, mixed>|null
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

		$items = array();

		foreach ( $settings['items'] as $item ) {
			if (
				empty( $item['enabled'] )
				|| empty( $item['image_url'] )
			) {
				continue;
			}

			$items[] = array(
				'id'        => $item['id'],
				'image_url' => $item['image_url'],
				'title'     => ! empty( $item['title'] )
					? $item['title']
					: null,
				'subtitle'  => ! empty( $item['subtitle'] )
					? $item['subtitle']
					: null,
				'action'    => $this->build_action(
					$item['action_type'],
					$item['action_value']
				),
			);
		}

		if ( empty( $items ) ) {
			return null;
		}

		return array(
			'aspect_ratio' => $settings['aspect_ratio'],
			'auto_play'    => $settings['auto_play'],
			'interval_ms'  => $settings['interval_ms'],
			'items'        => $items,
		);
	}

	/**
	 * Renders settings fields.
	 *
	 * @param int                  $index    Block index.
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return void
	 */
	public function render_settings(
		int $index,
		array $settings
	): void {
		$settings = wp_parse_args(
			$settings,
			$this->get_default_settings()
		);

		$items = isset( $settings['items'] )
			&& is_array( $settings['items'] )
				? array_values( $settings['items'] )
				: array();

		if ( empty( $items ) ) {
			$items[] = $this->get_empty_item();
		}

		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Aspect Ratio', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="number"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][aspect_ratio]"
					value="<?php echo esc_attr( (string) $settings['aspect_ratio'] ); ?>"
					min="1"
					max="4"
					step="0.1"
				>
			</div>

			<div class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Interval', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="number"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][interval_ms]"
					value="<?php echo esc_attr( (string) $settings['interval_ms'] ); ?>"
					min="2000"
					max="15000"
					step="500"
				>
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label>
					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][auto_play]"
						value="1"
						<?php checked( true, (bool) $settings['auto_play'] ); ?>
					>

					<?php echo esc_html__( 'Auto Play', 'kidia-mobile-cms' ); ?>
				</label>
			</div>
		</div>

		<div
			class="kidia-hero-block-items"
			data-block-index="<?php echo esc_attr( (string) $index ); ?>"
		>
			<?php foreach ( $items as $item_index => $item ) : ?>
            	<?php
            	$this->render_item(
            		$index,
            		$item_index,
            		$item
            	);
            	?>
            <?php endforeach; ?>
		</div>

		<p>
			<button
				type="button"
				class="button kidia-add-hero-block-item"
			>
				<?php echo esc_html__( 'Add Slide', 'kidia-mobile-cms' ); ?>
			</button>
		</p>

		<script type="text/html" class="tmpl-kidia-hero-block-item">
			<?php
			$this->render_item(
				$index,
				'__ITEM_INDEX__',
				$this->get_empty_item()
			);
			?>
		</script>
		<?php
	}

	/**
	 * Returns empty slide data.
	 *
	 * @return array<string, mixed>
	 */
	private function get_empty_item(): array {
		return array(
			'id'           => '',
			'enabled'      => true,
			'image_url'    => '',
			'title'        => '',
			'subtitle'     => '',
			'action_type'  => '',
			'action_value' => '',
		);
	}

	/**
	 * Renders one slide editor.
	 *
	 * @param int        $block_index Block index.
	 * @param int|string $item_index  Slide index.
	 * @param array<string, mixed> $item Slide data.
	 *
	 * @return void
	 */
	private function render_item(
		int $block_index,
		$item_index,
		array $item
	): void {
		$item = wp_parse_args(
			$item,
			$this->get_empty_item()
		);

		$image_url = (string) $item['image_url'];

		?>
		<div class="kidia-hero-block-item">
			<div class="kidia-hero-block-item__header">
				<strong>
					<?php echo esc_html__( 'Slide', 'kidia-mobile-cms' ); ?>
				</strong>

				<button
					type="button"
					class="button-link-delete kidia-remove-hero-block-item"
				>
					<?php echo esc_html__( 'Remove', 'kidia-mobile-cms' ); ?>
				</button>
			</div>

			<input
				type="hidden"
				name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][id]"
				value="<?php echo esc_attr( (string) $item['id'] ); ?>"
			>

			<p class="kidia-builder-field kidia-builder-field--toggle">
				<label>
					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][enabled]"
						value="1"
						<?php checked( true, (bool) $item['enabled'] ); ?>
					>

					<?php echo esc_html__( 'Enabled', 'kidia-mobile-cms' ); ?>
				</label>
			</p>

			<p class="kidia-builder-field kidia-builder-field--full kidia-builder-field--media">
				<label>
					<?php echo esc_html__( 'Image URL', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="url"
					class="kidia-hero-block-image-url"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][image_url]"
					value="<?php echo esc_attr( $image_url ); ?>"
				>

				<button
					type="button"
					class="button kidia-select-hero-block-image"
				>
					<?php echo esc_html__( 'Select Image', 'kidia-mobile-cms' ); ?>
				</button>

				<img
					class="kidia-hero-block-image-preview"
					src="<?php echo esc_url( $image_url ); ?>"
					alt=""
					<?php echo empty( $image_url ) ? 'style="display:none;"' : ''; ?>
				>
			</p>

			<p class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Title', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][title]"
					value="<?php echo esc_attr( (string) $item['title'] ); ?>"
				>
			</p>

			<p class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Subtitle', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][subtitle]"
					value="<?php echo esc_attr( (string) $item['subtitle'] ); ?>"
				>
			</p>

			<p class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Action Type', 'kidia-mobile-cms' ); ?>
				</label>

				<select
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][action_type]"
				>
					<option value="">
						<?php echo esc_html__( 'No Action', 'kidia-mobile-cms' ); ?>
					</option>

					<option value="product" <?php selected( 'product', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'Product', 'kidia-mobile-cms' ); ?>
					</option>

					<option value="category" <?php selected( 'category', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'Category', 'kidia-mobile-cms' ); ?>
					</option>

					<option value="collection" <?php selected( 'collection', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'Collection', 'kidia-mobile-cms' ); ?>
					</option>

					<option value="search" <?php selected( 'search', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'Search', 'kidia-mobile-cms' ); ?>
					</option>

					<option value="external" <?php selected( 'external', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'External URL', 'kidia-mobile-cms' ); ?>
					</option>
				</select>
			</p>

			<p class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Action Value', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][action_value]"
					value="<?php echo esc_attr( (string) $item['action_value'] ); ?>"
				>
			</p>
		</div>
		<?php
	}
}
