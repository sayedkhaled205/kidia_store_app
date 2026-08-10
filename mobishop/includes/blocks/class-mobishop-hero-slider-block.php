<?php
/**
 * Hero Slider Home Builder block.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'MobiShop_Hero_Slider_Block', false ) ) {
	return;
}

final class MobiShop_Hero_Slider_Block extends MobiShop_Block {

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
		return __( 'Hero Slider', 'mobishop' );
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
			'mobishop'
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

			$button_position = sanitize_key( (string) ( $item['button_position'] ?? 'center_bottom' ) );
			if ( ! in_array( $button_position, array( 'left', 'center', 'right', 'center_bottom' ), true ) ) {
				$button_position = 'center_bottom';
			}

			$button_link = $this->sanitize_http_url( $item['button_link'] ?? '' );
			if ( '' === $button_link && 'external' === $action_type ) {
				$button_link = $this->sanitize_http_url( $item['action_value'] ?? '' );
			}
			if ( '' !== $button_link ) {
				$action_type = 'external';
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
				'button_label'    => sanitize_text_field( (string) ( $item['button_label'] ?? '' ) ),
				'button_position' => $button_position,
				'button_link'     => $button_link,
				'action_type'     => $action_type,
				'action_value'    => '' !== $button_link
					? $button_link
					: ( 'external' === $action_type
						? $this->sanitize_http_url( $item['action_value'] ?? '' )
						: sanitize_text_field( (string) ( $item['action_value'] ?? '' ) ) ),
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
				'button_label'    => ! empty( $item['button_label'] ) ? $item['button_label'] : null,
				'button_position' => $item['button_position'] ?? 'center_bottom',
				'button_link'     => ! empty( $item['button_link'] ) ? $item['button_link'] : null,
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
		<div class="mobishop-builder-grid">
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--aspect-ratio">
				<label>
					<?php echo esc_html__( 'Aspect Ratio', 'mobishop' ); ?>
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

			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--interval">
				<label>
					<?php echo esc_html__( 'Interval', 'mobishop' ); ?>
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

			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--image-fit"><label><?php esc_html_e( 'Image Fit', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_fit]"><option value="cover" <?php selected( 'cover', $settings['image_fit'] ); ?>><?php esc_html_e( 'Cover', 'mobishop' ); ?></option><option value="contain" <?php selected( 'contain', $settings['image_fit'] ); ?>><?php esc_html_e( 'Contain', 'mobishop' ); ?></option></select></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--border-radius"><label><?php esc_html_e( 'Border Radius', 'mobishop' ); ?></label><input type="number" min="0" max="48" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][border_radius]" value="<?php echo esc_attr( (string) $settings['border_radius'] ); ?>"></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--horizontal-padding"><label><?php esc_html_e( 'Horizontal Padding', 'mobishop' ); ?></label><input type="number" min="0" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][horizontal_padding]" value="<?php echo esc_attr( (string) $settings['horizontal_padding'] ); ?>"></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--text-color"><label><?php esc_html_e( 'Text Color', 'mobishop' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][text_color]" value="<?php echo esc_attr( (string) $settings['text_color'] ); ?>"></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--text-position"><label><?php esc_html_e( 'Text Position', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][overlay_position]"><option value="start" <?php selected( 'start', $settings['overlay_position'] ); ?>><?php esc_html_e( 'Start', 'mobishop' ); ?></option><option value="center" <?php selected( 'center', $settings['overlay_position'] ); ?>><?php esc_html_e( 'Center', 'mobishop' ); ?></option><option value="end" <?php selected( 'end', $settings['overlay_position'] ); ?>><?php esc_html_e( 'End', 'mobishop' ); ?></option></select></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--overlay-strength"><label><?php esc_html_e( 'Overlay Strength %', 'mobishop' ); ?></label><input type="number" min="0" max="95" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][overlay_strength]" value="<?php echo esc_attr( (string) $settings['overlay_strength'] ); ?>"></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--indicator-position"><label><?php esc_html_e( 'Indicator Position', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][indicator_position]"><option value="below" <?php selected( 'below', $settings['indicator_position'] ); ?>><?php esc_html_e( 'Below image', 'mobishop' ); ?></option><option value="image_bottom" <?php selected( 'image_bottom', $settings['indicator_position'] ); ?>><?php esc_html_e( 'Inside image at bottom', 'mobishop' ); ?></option></select></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--indicator-style"><label><?php esc_html_e( 'Indicator Style', 'mobishop' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][indicator_style]"><option value="pill" <?php selected( 'pill', $settings['indicator_style'] ); ?>><?php esc_html_e( 'Pill', 'mobishop' ); ?></option><option value="dots" <?php selected( 'dots', $settings['indicator_style'] ); ?>><?php esc_html_e( 'Dots', 'mobishop' ); ?></option></select></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--auto-play"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][auto_play]" value="1" <?php checked( true, (bool) $settings['auto_play'] ); ?>> <?php echo esc_html__( 'Auto Play', 'mobishop' ); ?></label></div>
			<div class="mobishop-builder-field mobishop-slider-image-setting mobishop-slider-image-setting--show-indicators"><label><input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_indicators]" value="1" <?php checked( true, ! empty( $settings['show_indicators'] ) ); ?>> <?php esc_html_e( 'Show Indicators', 'mobishop' ); ?></label></div>
		</div>

		<div
			class="mobishop-hero-block-items"
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

		<script type="text/html" class="tmpl-mobishop-hero-block-item">
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
			'button_label'    => '',
			'button_position' => 'center_bottom',
			'button_link'     => '',
			'action_type'     => '',
			'action_value'    => '',
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
		$button_link = (string) ( $item['button_link'] ?? '' );
		if ( '' === $button_link && 'external' === ( $item['action_type'] ?? '' ) ) {
			$button_link = (string) ( $item['action_value'] ?? '' );
		}
		$button_position = sanitize_key( (string) ( $item['button_position'] ?? 'center_bottom' ) );

		?>
		<div class="mobishop-hero-block-item mobishop-slider-editor-item">
			<div class="mobishop-hero-block-item__header">
				<strong>
					<?php echo esc_html__( 'Slide', 'mobishop' ); ?>
				</strong>

				<div class="mobishop-repeatable-item-actions">
					<button type="button" class="button mobishop-repeatable-remove mobishop-remove-hero-block-item"><?php echo esc_html__( 'Remove', 'mobishop' ); ?></button>
					<button type="button" class="button mobishop-repeatable-add mobishop-add-hero-block-item"><?php echo esc_html__( '+ Add Slide', 'mobishop' ); ?></button>
					<label class="mobishop-page-master-toggle mobishop-slider-item-toggle" aria-label="<?php esc_attr_e( 'Turn slide on or off', 'mobishop' ); ?>">
						<input type="hidden" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][enabled]" value="0">
						<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][enabled]" value="1" <?php checked( true, (bool) $item['enabled'] ); ?>>
						<span class="mobishop-toggle-state"></span>
					</label>
				</div>
			</div>

			<input
				type="hidden"
				name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][id]"
				value="<?php echo esc_attr( (string) $item['id'] ); ?>"
			>

			<p class="mobishop-builder-field mobishop-repeatable-field--image-url">
				<label>
					<?php echo esc_html__( 'Image URL', 'mobishop' ); ?>
				</label>

				<input
					type="url"
					class="mobishop-hero-block-image-url"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][image_url]"
					value="<?php echo esc_attr( $image_url ); ?>"
				>
			</p>

			<p class="mobishop-builder-field mobishop-builder-field--media mobishop-repeatable-field--media">
				<button
					type="button"
					class="button mobishop-select-hero-block-image"
				>
					<?php echo esc_html__( 'Select Image', 'mobishop' ); ?>
				</button>

				<img
					class="mobishop-hero-block-image-preview"
					src="<?php echo esc_url( $image_url ); ?>"
					alt=""
					<?php echo empty( $image_url ) ? 'style="display:none;"' : ''; ?>
				>
			</p>

			<p class="mobishop-builder-field mobishop-repeatable-field--title">
				<label>
					<?php echo esc_html__( 'Title', 'mobishop' ); ?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][title]"
					value="<?php echo esc_attr( (string) $item['title'] ); ?>"
				>
			</p>

			<p class="mobishop-builder-field mobishop-repeatable-field--subtitle">
				<label>
					<?php echo esc_html__( 'Subtitle', 'mobishop' ); ?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][subtitle]"
					value="<?php echo esc_attr( (string) $item['subtitle'] ); ?>"
				>
			</p>

			<p class="mobishop-builder-field mobishop-repeatable-field--button-label">
				<label><?php echo esc_html__( 'Button Label', 'mobishop' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][button_label]" value="<?php echo esc_attr( (string) $item['button_label'] ); ?>">
			</p>

			<p class="mobishop-builder-field mobishop-repeatable-field--button-position">
				<label><?php echo esc_html__( 'Button Position', 'mobishop' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][button_position]">
					<option value="right" <?php selected( 'right', $button_position ); ?>><?php esc_html_e( 'Right', 'mobishop' ); ?></option>
					<option value="center" <?php selected( 'center', $button_position ); ?>><?php esc_html_e( 'Center', 'mobishop' ); ?></option>
					<option value="left" <?php selected( 'left', $button_position ); ?>><?php esc_html_e( 'Left', 'mobishop' ); ?></option>
					<option value="center_bottom" <?php selected( 'center_bottom', $button_position ); ?>><?php esc_html_e( 'Center Bottom', 'mobishop' ); ?></option>
				</select>
			</p>

			<p class="mobishop-builder-field mobishop-repeatable-field--button-link">
				<label><?php echo esc_html__( 'Button Link', 'mobishop' ); ?></label>
				<input type="url" placeholder="https://example.com" name="blocks[<?php echo esc_attr( (string) $block_index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][button_link]" value="<?php echo esc_attr( $button_link ); ?>">
			</p>
		</div>
		<?php
	}
}
