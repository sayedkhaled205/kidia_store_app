<?php
/**
 * Video Banner Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Video_Banner_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Video_Banner_Block extends Kidia_Mobile_Block {

	/**
	 * Returns block type.
	 *
	 * @return string
	 */
	public function get_type(): string {
		return 'video_banner';
	}

	/**
	 * Returns block label.
	 *
	 * @return string
	 */
	public function get_label(): string {
		return __(
			'Video Banner',
			'kidia-mobile-cms'
		);
	}

	/**
	 * Returns block icon.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-video-alt3';
	}

	/**
	 * Returns block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return __(
			'Display a promotional video banner.',
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
			'video_url'    => '',
			'poster_url'   => '',
			'aspect_ratio' => 1.8,
			'auto_play'    => false,
			'muted'        => true,
			'loop'         => false,
			'action_type'  => '',
			'action_value' => '',
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

		$action_type = sanitize_key(
			$settings['action_type'] ?? ''
		);

		$allowed_action_types = array(
			'',
			'product',
			'category',
			'collection',
			'search',
			'external',
		);

		if (
			! in_array(
				$action_type,
				$allowed_action_types,
				true
			)
		) {
			$action_type = '';
		}

		return array(
			'video_url' => esc_url_raw(
				$settings['video_url'] ?? ''
			),

			'poster_url' => esc_url_raw(
				$settings['poster_url'] ?? ''
			),

			'aspect_ratio' => max(
				1,
				min(
					4,
					(float) (
						$settings['aspect_ratio']
						?? 1.8
					)
				)
			),

			'auto_play' => ! empty(
				$settings['auto_play']
			),

			'muted' => ! empty(
				$settings['muted']
			),

			'loop' => ! empty(
				$settings['loop']
			),

			'action_type' => $action_type,

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

		if ( empty( $settings['video_url'] ) ) {
			return null;
		}

		return array(
			'video_url'    => $settings['video_url'],
			'poster_url'   => $settings['poster_url'],
			'aspect_ratio' => $settings['aspect_ratio'],
			'auto_play'    => $settings['auto_play'],
			'muted'        => $settings['muted'],
			'loop'         => $settings['loop'],
			'action'       => $this->build_action(
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

			<div class="kidia-builder-field kidia-builder-field--full">

				<label>
					<?php
					esc_html_e(
						'Video URL',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="url"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][video_url]"
					value="<?php echo esc_attr( $settings['video_url'] ); ?>"
					placeholder="https://example.com/video.mp4"
				>

			</div>

			<div class="kidia-builder-field kidia-builder-field--full">

				<label>
					<?php
					esc_html_e(
						'Poster Image URL',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<div class="kidia-builder-media-field">

					<input
						type="url"
						class="kidia-media-url"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][poster_url]"
						value="<?php echo esc_attr( $settings['poster_url'] ); ?>"
					>

					<button
						type="button"
						class="button kidia-select-media"
					>
						<?php
						esc_html_e(
							'Select Image',
							'kidia-mobile-cms'
						);
						?>
					</button>

				</div>

				<img
					class="kidia-media-preview"
					src="<?php echo esc_url( $settings['poster_url'] ); ?>"
					alt=""
					<?php echo empty( $settings['poster_url'] ) ? 'hidden' : ''; ?>
				>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Aspect Ratio',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="number"
					min="1"
					max="4"
					step="0.1"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][aspect_ratio]"
					value="<?php echo esc_attr( (string) $settings['aspect_ratio'] ); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label class="kidia-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][auto_play]"
						value="1"
						<?php checked( true, $settings['auto_play'] ); ?>
					>

					<span class="kidia-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Autoplay',
						'kidia-mobile-cms'
					);
					?>
				</span>

			</div>

			<div class="kidia-builder-field">

				<label class="kidia-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][muted]"
						value="1"
						<?php checked( true, $settings['muted'] ); ?>
					>

					<span class="kidia-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Muted',
						'kidia-mobile-cms'
					);
					?>
				</span>

			</div>

			<div class="kidia-builder-field">

				<label class="kidia-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][loop]"
						value="1"
						<?php checked( true, $settings['loop'] ); ?>
					>

					<span class="kidia-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Loop',
						'kidia-mobile-cms'
					);
					?>
				</span>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Action Type',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<select
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]"
				>
					<option value="">
						<?php
						esc_html_e(
							'No Action',
							'kidia-mobile-cms'
						);
						?>
					</option>

					<option
						value="product"
						<?php selected( 'product', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Product', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="category"
						<?php selected( 'category', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Category', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="collection"
						<?php selected( 'collection', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Collection', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="search"
						<?php selected( 'search', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Search', 'kidia-mobile-cms' ); ?>
					</option>

					<option
						value="external"
						<?php selected( 'external', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'External URL', 'kidia-mobile-cms' ); ?>
					</option>
				</select>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Action Value',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="text"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]"
					value="<?php echo esc_attr( $settings['action_value'] ); ?>"
				>

			</div>

		</div>
		<?php
	}
}