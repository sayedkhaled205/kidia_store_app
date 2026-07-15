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
		return __( 'Displays a section title with an optional subtitle and action.', 'kidia-mobile-cms' );
	}

	/**
	 * Returns canonical settings matching the schema and Flutter contract.
	 *
	 * @return array<string, mixed>
	 */
	public function get_default_settings(): array {
		return array(
			'title'        => '',
			'subtitle'     => '',
			'action_label' => '',
			'action_type'  => '',
			'action_value' => '',
		);
	}

	/**
	 * Sanitizes settings and migrates legacy View All field names in memory.
	 *
	 * @param array<string, mixed> $settings Raw settings.
	 *
	 * @return array<string, mixed>
	 */
	public function sanitize_settings( array $settings ): array {
		$action_label = array_key_exists( 'action_label', $settings )
			? (string) $settings['action_label']
			: (string) ( $settings['view_all_label'] ?? '' );

		// build_api_block() merges defaults before calling this method, so retain
		// the fallback for old instances that now also carry an empty default.
		if ( '' === trim( $action_label ) && ! empty( $settings['view_all_label'] ) ) {
			$action_label = (string) $settings['view_all_label'];
		}

		$legacy_action_disabled = array_key_exists( 'show_view_all', $settings )
			&& empty( $settings['show_view_all'] );

		$allowed_actions = array(
			'',
			'product',
			'category',
			'collection',
			'brand',
			'brands',
			'search',
			'external',
		);

		$action_type = $legacy_action_disabled
			? ''
			: sanitize_key( (string) ( $settings['action_type'] ?? '' ) );

		if ( ! in_array( $action_type, $allowed_actions, true ) ) {
			$action_type = '';
		}

		$action_value = 'external' === $action_type
			? esc_url_raw( (string) ( $settings['action_value'] ?? '' ) )
			: sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) );

		return array(
			'title'        => sanitize_text_field( (string) ( $settings['title'] ?? '' ) ),
			'subtitle'     => sanitize_textarea_field( (string) ( $settings['subtitle'] ?? '' ) ),
			'action_label' => $legacy_action_disabled
				? ''
				: sanitize_text_field( $action_label ),
			'action_type'  => $action_type,
			'action_value' => $legacy_action_disabled ? '' : $action_value,
		);
	}

	/**
	 * Builds the Section Header Flutter payload.
	 *
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return array<string, mixed>|null
	 */
	public function build_api_data( array $settings ): ?array {
		$settings = $this->sanitize_settings( $settings );

		if ( '' === $settings['title'] ) {
			return null;
		}

		$action = $this->build_action(
			$settings['action_type'],
			$settings['action_value']
		);

		return array(
			'title'        => $settings['title'],
			'subtitle'     => $settings['subtitle'],
			'action_label' => null === $action ? '' : $settings['action_label'],
			'action'       => $action,
		);
	}

	/**
	 * Renders settings for the legacy Home Builder form.
	 *
	 * @param int                  $index    Block index.
	 * @param array<string, mixed> $settings Saved settings.
	 *
	 * @return void
	 */
	public function render_settings( int $index, array $settings ): void {
		$settings = $this->sanitize_settings( $settings );

		$action_types = array(
			''           => __( 'No Action', 'kidia-mobile-cms' ),
			'collection' => __( 'Collection', 'kidia-mobile-cms' ),
			'category'   => __( 'Category', 'kidia-mobile-cms' ),
			'product'    => __( 'Product', 'kidia-mobile-cms' ),
			'brand'      => __( 'Brand', 'kidia-mobile-cms' ),
			'brands'     => __( 'All Brands', 'kidia-mobile-cms' ),
			'search'     => __( 'Search', 'kidia-mobile-cms' ),
			'external'   => __( 'External URL', 'kidia-mobile-cms' ),
		);
		?>
		<div class="kidia-builder-grid">
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Title', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][title]" value="<?php echo esc_attr( $settings['title'] ); ?>" required>
			</div>
			<div class="kidia-builder-field kidia-builder-field--full">
				<label><?php esc_html_e( 'Subtitle', 'kidia-mobile-cms' ); ?></label>
				<textarea name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][subtitle]" rows="3"><?php echo esc_textarea( $settings['subtitle'] ); ?></textarea>
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Action Label', 'kidia-mobile-cms' ); ?></label>
				<input type="text" name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_label]" value="<?php echo esc_attr( $settings['action_label'] ); ?>">
			</div>
			<div class="kidia-builder-field">
				<label><?php esc_html_e( 'Action Type', 'kidia-mobile-cms' ); ?></label>
				<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
					<?php foreach ( $action_types as $value => $label ) : ?>
						<option value="<?php echo esc_attr( $value ); ?>" <?php selected( $value, $settings['action_type'] ); ?>><?php echo esc_html( $label ); ?></option>
					<?php endforeach; ?>
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
