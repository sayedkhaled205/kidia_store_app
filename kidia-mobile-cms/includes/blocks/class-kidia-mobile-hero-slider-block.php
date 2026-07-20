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
			'border_radius' => 24,
			'horizontal_padding' => 16,
			'image_fit' => 'cover',
			'overlay_position' => 'start',
			'overlay_strength' => 72,
			'text_color' => '#FFFFFF',
			'show_indicators' => true,
			'indicator_style' => 'pill',
			'indicator_position' => 'below',
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
			0.45,
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
		$image_fit = sanitize_key( (string) ( $settings['image_fit'] ?? 'cover' ) );
		$overlay_position = sanitize_key( (string) ( $settings['overlay_position'] ?? 'start' ) );
		$indicator_style = sanitize_key( (string) ( $settings['indicator_style'] ?? 'pill' ) );
		$indicator_position = sanitize_key( (string) ( $settings['indicator_position'] ?? 'below' ) );

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
				'brand',
				'brands',
				'search',
				'external',
			);

			if ( ! in_array( $action_type, $allowed_action_types, true ) ) {
				$action_type = '';
			}

			$item_id = sanitize_key( (string) ( $item['id'] ?? '' ) );
			if ( '' === $item_id ) {
				$item_id = 'hero_slide_' . ( absint( $index ) + 1 );
			}

			$sanitized_items[] = array(
				'id'           => $item_id,
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
				'button_label' => sanitize_text_field( (string) ( $item['button_label'] ?? '' ) ),
				'action_type'  => $action_type,
				'action_value' => 'external' === $action_type
					? $this->sanitize_http_url( $item['action_value'] ?? '' )
					: sanitize_text_field( (string) ( $item['action_value'] ?? '' ) ),
			);
		}

		return array(
			'aspect_ratio' => $aspect_ratio,
			'auto_play'    => isset( $settings['auto_play'] )
				? (bool) $settings['auto_play']
				: false,
			'interval_ms'  => $interval_ms,
			'border_radius' => max( 0, min( 48, absint( $settings['border_radius'] ?? 24 ) ) ),
			'horizontal_padding' => max( 0, min( 32, absint( $settings['horizontal_padding'] ?? 16 ) ) ),
			'image_fit' => in_array( $image_fit, array( 'cover', 'contain' ), true ) ? $image_fit : 'cover',
			'overlay_position' => in_array( $overlay_position, array( 'start', 'center', 'end' ), true ) ? $overlay_position : 'start',
			'overlay_strength' => max( 0, min( 95, absint( $settings['overlay_strength'] ?? 72 ) ) ),
			'text_color' => sanitize_hex_color( $settings['text_color'] ?? '' ) ?: '#FFFFFF',
			'show_indicators' => ! empty( $settings['show_indicators'] ),
			'indicator_style' => in_array( $indicator_style, array( 'pill', 'dots' ), true ) ? $indicator_style : 'pill',
			'indicator_position' => in_array( $indicator_position, array( 'below', 'image_bottom' ), true ) ? $indicator_position : 'below',
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
				'button_label' => ! empty( $item['button_label'] ) ? $item['button_label'] : null,
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
			'border_radius' => $settings['border_radius'],
			'horizontal_padding' => $settings['horizontal_padding'],
			'image_fit' => $settings['image_fit'],
			'overlay_position' => $settings['overlay_position'],
			'overlay_strength' => $settings['overlay_strength'],
			'text_color' => $settings['text_color'],
			'show_indicators' => $settings['show_indicators'],
			'indicator_style' => $settings['indicator_style'],
			'indicator_position' => $settings['indicator_position'],
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
					min="0.45"
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

			<div class="kidia-builder-field"><label><?php esc_html_e( 'Border Radius', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="48" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][border_radius]" value="<?php echo esc_attr( (string) $settings['border_radius'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Horizontal Padding', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][horizontal_padding]" value="<?php echo esc_attr( (string) $settings['horizontal_padding'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Image Fit', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_fit]"><option value="cover" <?php selected( 'cover', $settings['image_fit'] ); ?>><?php esc_html_e( 'Cover', 'kidia-mobile-cms' ); ?></option><option value="contain" <?php selected( 'contain', $settings['image_fit'] ); ?>><?php esc_html_e( 'Contain', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Text Position', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][overlay_position]"><option value="start" <?php selected( 'start', $settings['overlay_position'] ); ?>><?php esc_html_e( 'Start', 'kidia-mobile-cms' ); ?></option><option value="center" <?php selected( 'center', $settings['overlay_position'] ); ?>><?php esc_html_e( 'Center', 'kidia-mobile-cms' ); ?></option><option value="end" <?php selected( 'end', $settings['overlay_position'] ); ?>><?php esc_html_e( 'End', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Overlay Strength %', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="95" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][overlay_strength]" value="<?php echo esc_attr( (string) $settings['overlay_strength'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Text Color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][text_color]" value="<?php echo esc_attr( (string) $settings['text_color'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Indicator Style', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][indicator_style]"><option value="pill" <?php selected( 'pill', $settings['indicator_style'] ); ?>><?php esc_html_e( 'Pill', 'kidia-mobile-cms' ); ?></option><option value="dots" <?php selected( 'dots', $settings['indicator_style'] ); ?>><?php esc_html_e( 'Dots', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Indicator Position', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][indicator_position]"><option value="below" <?php selected( 'below', $settings['indicator_position'] ); ?>><?php esc_html_e( 'Below image', 'kidia-mobile-cms' ); ?></option><option value="image_bottom" <?php selected( 'image_bottom', $settings['indicator_position'] ); ?>><?php esc_html_e( 'Inside image at bottom', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_indicators]" value="1" <?php checked( true, ! empty( $settings['show_indicators'] ) ); ?>> <?php esc_html_e( 'Show Indicators', 'kidia-mobile-cms' ); ?></label></div>
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
				class="button kidia-add-repeatable-control kidia-add-hero-block-item"
			>
				<?php echo esc_html__( 'Add Slide +', 'kidia-mobile-cms' ); ?>
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
			'button_label' => '',
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

					<?php echo esc_html__( 'Show', 'kidia-mobile-cms' ); ?>
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
				<label><?php echo esc_html__( 'Button Label', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][button_label]" value="<?php echo esc_attr( (string) $item['button_label'] ); ?>">
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

					<option value="brand" <?php selected( 'brand', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'Brand', 'kidia-mobile-cms' ); ?>
					</option>

					<option value="brands" <?php selected( 'brands', $item['action_type'] ); ?>>
						<?php echo esc_html__( 'All Brands', 'kidia-mobile-cms' ); ?>
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
