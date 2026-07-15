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

	public function get_type(): string {
		return 'video_banner';
	}

	public function get_label(): string {
		return __( 'Video Banner', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-video-alt3';
	}

	public function get_description(): string {
		return __( 'Video banner.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'video_url'    => '',
			'poster_url'   => '',
			'aspect_ratio' => 1.8,
			'auto_play'    => false,
			'muted'        => true,
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

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
					(float) ( $settings['aspect_ratio'] ?? 1.8 )
				)
			),

			'auto_play' => ! empty(
				$settings['auto_play']
			),

			'muted' => ! empty(
				$settings['muted']
			),

		);
	}
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

    	public function get_type(): string {
    		return 'video_banner';
    	}

    	public function get_label(): string {
    		return __( 'Video Banner', 'kidia-mobile-cms' );
    	}

    	public function get_icon(): string {
    		return 'dashicons-video-alt3';
    	}

    	public function get_description(): string {
    		return __( 'Video banner.', 'kidia-mobile-cms' );
    	}

    	public function get_default_settings(): array {
    		return array(
    			'video_url'    => '',
    			'poster_url'   => '',
    			'aspect_ratio' => 1.8,
    			'auto_play'    => false,
    			'muted'        => true,
    		);
    	}

    	public function sanitize_settings(
    		array $settings
    	): array {

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
    					(float) ( $settings['aspect_ratio'] ?? 1.8 )
    				)
    			),

    			'auto_play' => ! empty(
    				$settings['auto_play']
    			),

    			'muted' => ! empty(
    				$settings['muted']
    			),

    		);
    	}