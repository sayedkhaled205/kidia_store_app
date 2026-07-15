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
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Aspect Ratio', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="1" max="4" step="0.1" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][aspect_ratio]" value="<?php echo esc_attr( (string) $settings['aspect_ratio'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Interval (ms)', 'kidia-mobile-cms' ); ?></label>
				<input type="number" min="2000" max="15000" step="500" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][interval_ms]" value="<?php echo esc_attr( (string) $settings['interval_ms'] ); ?>">
			</div>
			<div class="kidia-builder-field kidia-builder-field--full">
				<label>
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][auto_play]" value="1" <?php checked( true, $settings['auto_play'] ); ?>>
					<?php esc_html_e( 'Auto Play', 'kidia-mobile-cms' ); ?>
				</label>
			</div>
		</div>
		<div class="kidia-hero-gallery">
			<div class="kidia-hero-gallery__items">
				<?php foreach ( $settings['items'] as $item_index => $item ) : ?>
					<?php if ( ! empty( $item['image_url'] ) ) : ?>
						<div class="kidia-hero-gallery__item">
							<img src="<?php echo esc_url( (string) $item['image_url'] ); ?>" alt="">
							<input type="hidden" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][items][<?php echo esc_attr( (string) $item_index ); ?>][image_url]" value="<?php echo esc_attr( (string) $item['image_url'] ); ?>">
							<button type="button" class="button-link-delete kidia-hero-gallery__remove"><?php esc_html_e( 'Remove', 'kidia-mobile-cms' ); ?></button>
						</div>
					<?php endif; ?>
				<?php endforeach; ?>
			</div>
			<button type="button" class="button kidia-hero-gallery__select"><?php esc_html_e( 'Select Images', 'kidia-mobile-cms' ); ?></button>
			<p class="description"><?php esc_html_e( 'Each selected image becomes one slide. Drag the block to position the complete slider.', 'kidia-mobile-cms' ); ?></p>
		</div>
		<?php
	}
}
