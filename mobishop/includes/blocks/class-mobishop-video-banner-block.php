<?php
/**
 * Video Banner Home Builder block.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'MobiShop_Video_Banner_Block', false ) ) {
	return;
}

final class MobiShop_Video_Banner_Block extends MobiShop_Block {

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
			'mobishop'
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
			'mobishop'
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
				0.45,
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
		<div class="mobishop-builder-grid">

			<div class="mobishop-builder-field mobishop-builder-field--full">

				<label>
					<?php
					esc_html_e(
						'Video URL',
						'mobishop'
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

			<div class="mobishop-builder-field mobishop-builder-field--full">

				<label>
					<?php
					esc_html_e(
						'Poster Image URL',
						'mobishop'
					);
					?>
				</label>

				<div class="mobishop-builder-media-field">

					<input
						type="url"
						class="mobishop-media-url"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][poster_url]"
						value="<?php echo esc_attr( $settings['poster_url'] ); ?>"
					>

					<button
						type="button"
						class="button mobishop-select-media"
					>
						<?php
						esc_html_e(
							'Select Image',
							'mobishop'
						);
						?>
					</button>

				</div>

				<img
					class="mobishop-media-preview"
					src="<?php echo esc_url( $settings['poster_url'] ); ?>"
					alt=""
					<?php echo empty( $settings['poster_url'] ) ? 'hidden' : ''; ?>
				>

			</div>

			<div class="mobishop-builder-field">

				<label>
					<?php
					esc_html_e(
						'Aspect Ratio',
						'mobishop'
					);
					?>
				</label>

				<input
					type="number"
					min="0.45"
					max="4"
					step="0.1"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][aspect_ratio]"
					value="<?php echo esc_attr( (string) $settings['aspect_ratio'] ); ?>"
				>

			</div>

			<div class="mobishop-builder-field">

				<label class="mobishop-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][auto_play]"
						value="1"
						<?php checked( true, $settings['auto_play'] ); ?>
					>

					<span class="mobishop-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Autoplay',
						'mobishop'
					);
					?>
				</span>

			</div>

			<div class="mobishop-builder-field">

				<label class="mobishop-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][muted]"
						value="1"
						<?php checked( true, $settings['muted'] ); ?>
					>

					<span class="mobishop-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Muted',
						'mobishop'
					);
					?>
				</span>

			</div>

			<div class="mobishop-builder-field">

				<label class="mobishop-builder-switch">

					<input
						type="checkbox"
						name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][loop]"
						value="1"
						<?php checked( true, $settings['loop'] ); ?>
					>

					<span class="mobishop-builder-switch__track"></span>

				</label>

				<span>
					<?php
					esc_html_e(
						'Loop',
						'mobishop'
					);
					?>
				</span>

			</div>

			<div class="mobishop-builder-field">

				<label>
					<?php
					esc_html_e(
						'Action Type',
						'mobishop'
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
							'mobishop'
						);
						?>
					</option>

					<option
						value="product"
						<?php selected( 'product', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Product', 'mobishop' ); ?>
					</option>

					<option
						value="category"
						<?php selected( 'category', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Category', 'mobishop' ); ?>
					</option>

					<option
						value="collection"
						<?php selected( 'collection', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Collection', 'mobishop' ); ?>
					</option>

					<option
						value="search"
						<?php selected( 'search', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'Search', 'mobishop' ); ?>
					</option>

					<option
						value="external"
						<?php selected( 'external', $settings['action_type'] ); ?>
					>
						<?php esc_html_e( 'External URL', 'mobishop' ); ?>
					</option>
				</select>

			</div>

			<div class="mobishop-builder-field">

				<label>
					<?php
					esc_html_e(
						'Action Value',
						'mobishop'
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
