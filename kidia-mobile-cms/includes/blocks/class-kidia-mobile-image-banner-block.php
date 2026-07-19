<?php
/**
 * Image Banner Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Image_Banner_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Image_Banner_Block extends Kidia_Mobile_Block {

	/**
	 * Returns block type.
	 *
	 * @return string
	 */
	public function get_type(): string {
		return 'image_banner';
	}

	/**
	 * Returns block label.
	 *
	 * @return string
	 */
	public function get_label(): string {
		return __( 'Image Banner', 'kidia-mobile-cms' );
	}

	/**
	 * Returns block icon.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-format-image';
	}

	/**
	 * Returns block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return __(
			'Clickable promotional image displayed anywhere on the home page.',
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
			'image_url'      => '',
			'semantic_label' => '',
			'aspect_ratio'   => 1,
			'border_radius'  => 18,
			'action_type'    => '',
			'action_value'   => '',
			'title'          => '',
			'subtitle'       => '',
			'button_label'   => __( 'SHOP NOW', 'kidia-mobile-cms' ),
			'image_fit'      => 'cover',
			'overlay_strength' => 0,
			'text_color'     => '#FFFFFF',
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

		$action_type = isset( $settings['action_type'] )
			? sanitize_key( $settings['action_type'] )
			: '';

		if ( ! in_array( $action_type, $allowed_action_types, true ) ) {
			$action_type = '';
		}

		$aspect_ratio = isset( $settings['aspect_ratio'] )
			? (float) $settings['aspect_ratio']
			: 2.4;

		$aspect_ratio = max(
			0.45,
			min( 5, $aspect_ratio )
		);

		$border_radius = isset( $settings['border_radius'] )
			? (float) $settings['border_radius']
			: 20;

		$border_radius = max(
			0,
			min( 48, $border_radius )
		);
		$image_fit = sanitize_key( (string) ( $settings['image_fit'] ?? 'cover' ) );

		return array(
			'image_url'      => isset( $settings['image_url'] )
				? esc_url_raw( $settings['image_url'] )
				: '',
			'semantic_label' => isset( $settings['semantic_label'] )
				? sanitize_text_field( $settings['semantic_label'] )
				: '',
			'aspect_ratio'   => $aspect_ratio,
			'border_radius'  => $border_radius,
			'action_type'    => $action_type,
			'action_value'   => 'external' === $action_type
				? $this->sanitize_http_url( $settings['action_value'] ?? '' )
				: sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) ),
			'title'          => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'       => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'button_label'   => sanitize_text_field( (string) ( $settings['button_label'] ?? '' ) ),
			'image_fit'      => in_array( $image_fit, array( 'cover', 'contain' ), true ) ? $image_fit : 'cover',
			'overlay_strength' => max( 0, min( 95, absint( $settings['overlay_strength'] ?? 0 ) ) ),
			'text_color'     => sanitize_hex_color( $settings['text_color'] ?? '' ) ?: '#FFFFFF',
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

		if ( empty( $settings['image_url'] ) ) {
			return null;
		}

		return array(
			'image_url'      => $settings['image_url'],
			'semantic_label' => ! empty( $settings['semantic_label'] )
				? $settings['semantic_label']
				: null,
			'aspect_ratio'   => $settings['aspect_ratio'],
			'border_radius'  => $settings['border_radius'],
			'title'          => '' !== $settings['title'] ? $settings['title'] : null,
			'subtitle'       => '' !== $settings['subtitle'] ? $settings['subtitle'] : null,
			'button_label'   => '' !== $settings['button_label'] ? $settings['button_label'] : null,
			'image_fit'      => $settings['image_fit'],
			'overlay_strength' => $settings['overlay_strength'],
			'text_color'     => $settings['text_color'],
			'action'         => $this->build_action(
				$settings['action_type'],
				$settings['action_value']
			),
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

		$image_url = isset( $settings['image_url'] )
			? (string) $settings['image_url']
			: '';

		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-builder-field--full kidia-builder-field--media">
				<label>
					<?php echo esc_html__( 'Banner Image', 'kidia-mobile-cms' ); ?>
				</label>

				<div class="kidia-builder-media-field">
					<input
						type="url"
						class="kidia-banner-image-url"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_url]"
						value="<?php echo esc_attr( $image_url ); ?>"
					>

					<button
						type="button"
						class="button kidia-select-banner-image"
					>
						<?php
						echo esc_html__(
							'Select from Media Library',
							'kidia-mobile-cms'
						);
						?>
					</button>
				</div>

				<img
					class="kidia-banner-image-preview"
					src="<?php echo esc_url( $image_url ); ?>"
					alt=""
					<?php echo empty( $image_url ) ? 'style="display:none;"' : ''; ?>
				>
			</div>

			<div class="kidia-builder-field">
				<label>
					<?php
					echo esc_html__(
						'Accessibility Label',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][semantic_label]"
					value="<?php echo esc_attr( (string) $settings['semantic_label'] ); ?>"
				>
			</div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Overlay Title', 'kidia-mobile-cms' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( (string) $settings['title'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Overlay Subtitle', 'kidia-mobile-cms' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" value="<?php echo esc_attr( (string) $settings['subtitle'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Button Label', 'kidia-mobile-cms' ); ?></label><input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][button_label]" value="<?php echo esc_attr( (string) $settings['button_label'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Image Fit', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][image_fit]"><option value="cover" <?php selected( 'cover', $settings['image_fit'] ); ?>><?php esc_html_e( 'Cover', 'kidia-mobile-cms' ); ?></option><option value="contain" <?php selected( 'contain', $settings['image_fit'] ); ?>><?php esc_html_e( 'Contain', 'kidia-mobile-cms' ); ?></option></select></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Overlay Strength %', 'kidia-mobile-cms' ); ?></label><input type="number" min="0" max="95" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][overlay_strength]" value="<?php echo esc_attr( (string) $settings['overlay_strength'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Text Color', 'kidia-mobile-cms' ); ?></label><input type="color" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][text_color]" value="<?php echo esc_attr( (string) $settings['text_color'] ); ?>"></div>

			<div class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Aspect Ratio', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="number"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][aspect_ratio]"
					value="<?php echo esc_attr( (string) $settings['aspect_ratio'] ); ?>"
					min="0.45"
					max="5"
					step="0.1"
				>
			</div>

			<div class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Border Radius', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="number"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][border_radius]"
					value="<?php echo esc_attr( (string) $settings['border_radius'] ); ?>"
					min="0"
					max="48"
					step="1"
				>
			</div>

			<div class="kidia-builder-field">
				<label>
					<?php echo esc_html__( 'Action Type', 'kidia-mobile-cms' ); ?>
				</label>

				<select
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]"
				>
					<option value="">
						<?php echo esc_html__( 'No Action', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="product"
						<?php selected( 'product', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'Product', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="category"
						<?php selected( 'category', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'Category', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="collection"
						<?php selected( 'collection', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'Collection', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="brand"
						<?php selected( 'brand', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'Brand', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="brands"
						<?php selected( 'brands', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'All Brands', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="search"
						<?php selected( 'search', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'Search', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="external"
						<?php selected( 'external', $settings['action_type'] ); ?>
					>
						<?php echo esc_html__( 'External URL', 'kidia-mobile-cms' ); ?>
					</option>
				</select>
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label>
					<?php echo esc_html__( 'Action Value', 'kidia-mobile-cms' ); ?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]"
					value="<?php echo esc_attr( (string) $settings['action_value'] ); ?>"
				>
			</div>
		</div>
		<?php
	}
}
