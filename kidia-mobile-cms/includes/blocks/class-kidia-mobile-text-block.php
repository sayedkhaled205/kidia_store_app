<?php
/**
 * Text Block Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Text_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Text_Block extends Kidia_Mobile_Block {

	/**
	 * Returns block type.
	 *
	 * @return string
	 */
	public function get_type(): string {
		return 'text_block';
	}

	/**
	 * Returns block label.
	 *
	 * @return string
	 */
	public function get_label(): string {
		return __(
			'Text Block',
			'kidia-mobile-cms'
		);
	}

	/**
	 * Returns block icon.
	 *
	 * @return string
	 */
	public function get_icon(): string {
		return 'dashicons-text';
	}

	/**
	 * Returns block description.
	 *
	 * @return string
	 */
	public function get_description(): string {
		return __(
			'Display a custom text block.',
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
			'title'      => '',
			'content'    => '',
			'alignment'  => 'right',
			'background' => '',
			'text_color' => '#111111',
			'title_size' => 22,
			'content_size' => 15,
			'font_weight' => 'normal',
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

		$alignment = sanitize_key(
			$settings['alignment'] ?? 'right'
		);

		if (
			! in_array(
				$alignment,
				array(
					'left',
					'center',
					'right',
				),
				true
			)
		) {
			$alignment = 'right';
		}

		$background = sanitize_hex_color(
			(string) (
				$settings['background']
				?? ''
			)
		);

		$text_color = sanitize_hex_color(
			(string) (
				$settings['text_color']
				?? '#111111'
			)
		);
		$font_weight = sanitize_key( (string) ( $settings['font_weight'] ?? 'normal' ) );

		return array(
			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'content' => sanitize_textarea_field(
				$settings['content'] ?? ''
			),

			'alignment' => $alignment,

			'background' => $background ?: '',

			'text_color' => $text_color ?: '#111111',
			'title_size' => max( 12, min( 48, absint( $settings['title_size'] ?? 22 ) ) ),
			'content_size' => max( 10, min( 32, absint( $settings['content_size'] ?? 15 ) ) ),
			'font_weight' => in_array( $font_weight, array( 'normal', 'medium', 'bold' ), true ) ? $font_weight : 'normal',
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

		if (
			'' === $settings['title']
			&& '' === $settings['content']
		) {
			return null;
		}

		return array(
			'title'      => $settings['title'],
			'content'    => $settings['content'],
			'alignment'  => $settings['alignment'],
			'background' => $settings['background'],
			'text_color' => $settings['text_color'],
			'title_size' => $settings['title_size'],
			'content_size' => $settings['content_size'],
			'font_weight' => $settings['font_weight'],
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

			<div class="kidia-builder-field kidia-builder-field--full">

				<label>
					<?php
					esc_html_e(
						'Content',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<textarea
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][content]"
					rows="8"
				><?php echo esc_textarea( $settings['content'] ); ?></textarea>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Text Alignment',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<select
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][alignment]"
				>
					<option
						value="left"
						<?php selected( 'left', $settings['alignment'] ); ?>
					>
						<?php
						esc_html_e(
							'Left',
							'kidia-mobile-cms'
						);
						?>
					</option>

					<option
						value="center"
						<?php selected( 'center', $settings['alignment'] ); ?>
					>
						<?php
						esc_html_e(
							'Center',
							'kidia-mobile-cms'
						);
						?>
					</option>

					<option
						value="right"
						<?php selected( 'right', $settings['alignment'] ); ?>
					>
						<?php
						esc_html_e(
							'Right',
							'kidia-mobile-cms'
						);
						?>
					</option>
				</select>

			</div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Title Size', 'kidia-mobile-cms' ); ?></label><input type="number" min="12" max="48" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title_size]" value="<?php echo esc_attr( (string) $settings['title_size'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Content Size', 'kidia-mobile-cms' ); ?></label><input type="number" min="10" max="32" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][content_size]" value="<?php echo esc_attr( (string) $settings['content_size'] ); ?>"></div>
			<div class="kidia-builder-field"><label><?php esc_html_e( 'Font Weight', 'kidia-mobile-cms' ); ?></label><select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][font_weight]"><option value="normal" <?php selected( 'normal', $settings['font_weight'] ); ?>><?php esc_html_e( 'Normal', 'kidia-mobile-cms' ); ?></option><option value="medium" <?php selected( 'medium', $settings['font_weight'] ); ?>><?php esc_html_e( 'Medium', 'kidia-mobile-cms' ); ?></option><option value="bold" <?php selected( 'bold', $settings['font_weight'] ); ?>><?php esc_html_e( 'Bold', 'kidia-mobile-cms' ); ?></option></select></div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Background Color',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="color"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][background]"
					value="<?php echo esc_attr(
						$settings['background'] ?: '#ffffff'
					); ?>"
				>

			</div>

			<div class="kidia-builder-field">

				<label>
					<?php
					esc_html_e(
						'Text Color',
						'kidia-mobile-cms'
					);
					?>
				</label>

				<input
					type="color"
					name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][text_color]"
					value="<?php echo esc_attr( $settings['text_color'] ); ?>"
				>

			</div>

		</div>
		<?php
	}
}
