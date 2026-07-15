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

	public function get_type(): string {
		return 'text_block';
	}

	public function get_label(): string {
		return __( 'Text Block', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-text';
	}

	public function get_description(): string {
		return __( 'Custom text block.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title'      => '',
			'content'    => '',
			'alignment'  => 'right',
			'background' => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		return array(

			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'content' => sanitize_textarea_field(
				$settings['content'] ?? ''
			),

			'alignment' => sanitize_key(
				$settings['alignment'] ?? 'right'
			),

			'background' => sanitize_hex_color(
				$settings['background'] ?? ''
			),

		);
	}
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

    	public function get_type(): string {
    		return 'text_block';
    	}

    	public function get_label(): string {
    		return __( 'Text Block', 'kidia-mobile-cms' );
    	}

    	public function get_icon(): string {
    		return 'dashicons-text';
    	}

    	public function get_description(): string {
    		return __( 'Custom text block.', 'kidia-mobile-cms' );
    	}

    	public function get_default_settings(): array {
    		return array(
    			'title'      => '',
    			'content'    => '',
    			'alignment'  => 'right',
    			'background' => '',
    		);
    	}

    	public function sanitize_settings(
    		array $settings
    	): array {

    		return array(

    			'title' => sanitize_text_field(
    				$settings['title'] ?? ''
    			),

    			'content' => sanitize_textarea_field(
    				$settings['content'] ?? ''
    			),

    			'alignment' => sanitize_key(
    				$settings['alignment'] ?? 'right'
    			),

    			'background' => sanitize_hex_color(
    				$settings['background'] ?? ''
    			),

    		);
    	}