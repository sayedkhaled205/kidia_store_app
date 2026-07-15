<?php
/**
 * Section Header Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Section_Header_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Section_Header_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'section_header';
	}

	public function get_label(): string {
		return __( 'Section Header', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-heading';
	}

	public function get_description(): string {
		return __(
			'Displays a section title with optional subtitle and action.',
			'kidia-mobile-cms'
		);
	}

	public function get_default_settings(): array {
		return array(
			'title'           => '',
			'subtitle'        => '',
			'show_view_all'   => true,
			'view_all_label'  => '',
			'alignment'       => 'start',
			'icon'            => '',
			'divider_style'   => 'none',
			'action_type'     => '',
			'action_value'    => '',
		);
	}

	public function sanitize_settings( array $settings ): array {
		$alignment = sanitize_key( (string) ( $settings['alignment'] ?? 'start' ) );

		if ( ! in_array( $alignment, array( 'start', 'center', 'end' ), true ) ) {
			$alignment = 'start';
		}

		$divider_style = sanitize_key( (string) ( $settings['divider_style'] ?? 'none' ) );

		if ( ! in_array( $divider_style, array( 'none', 'line', 'underline' ), true ) ) {
			$divider_style = 'none';
		}

		$action_type = sanitize_key( (string) ( $settings['action_type'] ?? '' ) );
		$allowed_action_types = array(
			'',
			'collection',
			'category',
			'product',
			'search',
			'external',
		);

		if ( ! in_array( $action_type, $allowed_action_types, true ) ) {
			$action_type = '';
		}

		$view_all_label = isset( $settings['view_all_label'] )
			&& '' !== trim( (string) $settings['view_all_label'] )
				? $settings['view_all_label']
				: ( $settings['action_label'] ?? '' );

		return array(
			'title'          => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'       => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'show_view_all'  => ! empty( $settings['show_view_all'] ),
			'view_all_label' => sanitize_text_field( (string) $view_all_label ),
			'alignment'      => $alignment,
			'icon'           => sanitize_key( (string) ( $settings['icon'] ?? '' ) ),
			'divider_style'  => $divider_style,
			'action_type'    => $action_type,
			'action_value'   => sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) ),
		);
	}

	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);

		return array(
			'title'          => $settings['title'],
			'subtitle'       => $settings['subtitle'],
			'show_view_all'  => $settings['show_view_all'],
			'view_all_label' => $settings['view_all_label'],
			'alignment'      => $settings['alignment'],
			'icon'           => '' !== $settings['icon'] ? $settings['icon'] : null,
			'divider_style'  => $settings['divider_style'],
			'action'         => $this->build_action(
				$settings['action_type'],
				$settings['action_value']
			),
		);
	}

	public function render_settings( int $index, array $settings ): void {
		$settings = $this->sanitize_settings(
			wp_parse_args( $settings, $this->get_default_settings() )
		);
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>">
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label>
				<textarea name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" rows="3"><?php echo esc_textarea( $settings['subtitle'] ); ?></textarea>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Alignment', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][alignment]">
					<option value="start" <?php selected( 'start', $settings['alignment'] ); ?>><?php esc_html_e( 'Start', 'kidia-mobile-cms' ); ?></option>
					<option value="center" <?php selected( 'center', $settings['alignment'] ); ?>><?php esc_html_e( 'Center', 'kidia-mobile-cms' ); ?></option>
					<option value="end" <?php selected( 'end', $settings['alignment'] ); ?>><?php esc_html_e( 'End', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Icon', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][icon]" value="<?php echo esc_attr( $settings['icon'] ); ?>" placeholder="star">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Divider', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][divider_style]">
					<option value="none" <?php selected( 'none', $settings['divider_style'] ); ?>><?php esc_html_e( 'None', 'kidia-mobile-cms' ); ?></option>
					<option value="line" <?php selected( 'line', $settings['divider_style'] ); ?>><?php esc_html_e( 'Line', 'kidia-mobile-cms' ); ?></option>
					<option value="underline" <?php selected( 'underline', $settings['divider_style'] ); ?>><?php esc_html_e( 'Underline', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field">
				<label>
					<input type="checkbox" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][show_view_all]" value="1" <?php checked( true, $settings['show_view_all'] ); ?>>
					<?php esc_html_e( 'Show View All', 'kidia-mobile-cms' ); ?>
				</label>
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'View All Label', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][view_all_label]" value="<?php echo esc_attr( $settings['view_all_label'] ); ?>">
			</div>

			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Action Type', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
					<option value="" <?php selected( '', $settings['action_type'] ); ?>><?php esc_html_e( 'No Action', 'kidia-mobile-cms' ); ?></option>
					<option value="collection" <?php selected( 'collection', $settings['action_type'] ); ?>><?php esc_html_e( 'Collection', 'kidia-mobile-cms' ); ?></option>
					<option value="category" <?php selected( 'category', $settings['action_type'] ); ?>><?php esc_html_e( 'Category', 'kidia-mobile-cms' ); ?></option>
					<option value="product" <?php selected( 'product', $settings['action_type'] ); ?>><?php esc_html_e( 'Product', 'kidia-mobile-cms' ); ?></option>
					<option value="search" <?php selected( 'search', $settings['action_type'] ); ?>><?php esc_html_e( 'Search', 'kidia-mobile-cms' ); ?></option>
					<option value="external" <?php selected( 'external', $settings['action_type'] ); ?>><?php esc_html_e( 'External URL', 'kidia-mobile-cms' ); ?></option>
				</select>
			</div>

			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Action Value', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_value]" value="<?php echo esc_attr( $settings['action_value'] ); ?>">
			</div>
		</div>
		<?php
	}
}
