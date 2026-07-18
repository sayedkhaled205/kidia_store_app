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
			'action_type'     => '',
			'action_value'    => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(

			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'subtitle' => sanitize_textarea_field(
				$settings['subtitle'] ?? ''
			),

			'show_view_all' => ! empty(
				$settings['show_view_all']
			),

			'view_all_label' => sanitize_text_field(
				$settings['view_all_label'] ?? ''
			),

			'action_type' => sanitize_key(
				$settings['action_type'] ?? ''
			),

			'action_value' => sanitize_text_field(
				$settings['action_value'] ?? ''
			),

		);
	}
		public function build_api_data(
    		array $settings
    	): ?array {

    		$settings = $this->sanitize_settings(
    			wp_parse_args(
    				$settings,
    				$this->get_default_settings()
    			)
    		);

			if ( '' === $settings['title'] ) {
				return null;
			}

			return array(
				'title'          => $settings['title'],
				'subtitle'       => $settings['subtitle'],
				'action_label'   => $settings['show_view_all']
					? $settings['view_all_label']
					: '',
				'action'         => $settings['show_view_all']
					? $this->build_action(
						$settings['action_type'],
						$settings['action_value']
					)
					: null,
    		);
    	}

    	public function render_settings(
    		int $index,
    		array $settings
    	): void {

    		$settings = wp_parse_args(
    			$settings,
    			$this->get_default_settings()
    		);

    ?>
    <div class="kidia-builder-grid">

		<div class="kidia-builder-field">

    		<label>Title</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][title]"
    			value="<?php echo esc_attr( $settings['title'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Subtitle</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][subtitle]"
    			value="<?php echo esc_attr( $settings['subtitle'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>

    			<input
    				type="checkbox"
    				name="blocks[<?php echo esc_attr( $index ); ?>][settings][show_view_all]"
    				value="1"
    				<?php checked(
    					true,
    					(bool) $settings['show_view_all']
    				); ?>
    			>

    			Show View All

    		</label>

    	</div>

    	<div class="kidia-builder-field">

    		<label>View All Label</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][view_all_label]"
    			value="<?php echo esc_attr( $settings['view_all_label'] ); ?>"
    		>

		</div>

		<div class="kidia-builder-field">

			<label>Action Type</label>

			<select name="blocks[<?php echo esc_attr( (string) $index ); ?>][settings][action_type]">
				<option value="" <?php selected( '', $settings['action_type'] ); ?>>No Action</option>
				<option value="collection" <?php selected( 'collection', $settings['action_type'] ); ?>>Collection</option>
				<option value="category" <?php selected( 'category', $settings['action_type'] ); ?>>Category</option>
				<option value="product" <?php selected( 'product', $settings['action_type'] ); ?>>Product</option>
				<option value="brand" <?php selected( 'brand', $settings['action_type'] ); ?>>Brand</option>
				<option value="brands" <?php selected( 'brands', $settings['action_type'] ); ?>>All Brands</option>
				<option value="search" <?php selected( 'search', $settings['action_type'] ); ?>>Search</option>
				<option value="external" <?php selected( 'external', $settings['action_type'] ); ?>>External URL</option>
			</select>

		</div>

		<div class="kidia-builder-field kidia-builder-field--full">

			<label>Action Value</label>

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
