<?php
/**
 * Countdown Home Builder block.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

if ( class_exists( 'Kidia_Mobile_Countdown_Block', false ) ) {
	return;
}

final class Kidia_Mobile_Countdown_Block extends Kidia_Mobile_Block {

	public function get_type(): string {
		return 'countdown';
	}

	public function get_label(): string {
		return __( 'Countdown', 'kidia-mobile-cms' );
	}

	public function get_icon(): string {
		return 'dashicons-clock';
	}

	public function get_description(): string {
		return __( 'Offer countdown timer.', 'kidia-mobile-cms' );
	}

	public function get_default_settings(): array {
		return array(
			'title' => '',
			'ends_at' => '',
			'expired_text' => 'Offer ended',
			'end_behavior' => 'message',
			'days_label' => 'Days',
			'hours_label' => 'Hours',
			'minutes_label' => 'Minutes',
			'seconds_label' => 'Seconds',
			'background_color' => '#111827',
			'text_color' => '#ffffff',
			'action_type' => '',
			'action_value' => '',
		);
	}

	public function sanitize_settings(
		array $settings
	): array {

		$end_behavior = sanitize_key( (string) ( $settings['end_behavior'] ?? 'message' ) );
		if ( ! in_array( $end_behavior, array( 'message', 'hide' ), true ) ) {
			$end_behavior = 'message';
		}

		$action_type = sanitize_key( (string) ( $settings['action_type'] ?? '' ) );
		if ( ! in_array( $action_type, array( '', 'product', 'category', 'collection', 'search', 'external' ), true ) ) {
			$action_type = '';
		}

		return array(

			'title' => sanitize_text_field(
				$settings['title'] ?? ''
			),

			'ends_at' => sanitize_text_field(
				$settings['ends_at'] ?? ''
			),

			'expired_text' => sanitize_text_field(
				$settings['expired_text'] ?? 'Offer ended'
			),

			'end_behavior' => $end_behavior,
			'days_label' => sanitize_text_field( (string) ( $settings['days_label'] ?? 'Days' ) ),
			'hours_label' => sanitize_text_field( (string) ( $settings['hours_label'] ?? 'Hours' ) ),
			'minutes_label' => sanitize_text_field( (string) ( $settings['minutes_label'] ?? 'Minutes' ) ),
			'seconds_label' => sanitize_text_field( (string) ( $settings['seconds_label'] ?? 'Seconds' ) ),
			'background_color' => sanitize_hex_color( (string) ( $settings['background_color'] ?? '#111827' ) ) ?: '#111827',
			'text_color' => sanitize_hex_color( (string) ( $settings['text_color'] ?? '#ffffff' ) ) ?: '#ffffff',
			'action_type' => $action_type,
			'action_value' => sanitize_text_field( (string) ( $settings['action_value'] ?? '' ) ),

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

			if ( '' === trim( $settings['ends_at'] ) ) {
				return null;
			}

			try {
				$end_date = new DateTimeImmutable( $settings['ends_at'], wp_timezone() );
			} catch ( Exception $exception ) {
				unset( $exception );
				return null;
			}

			$ends_at_utc = $end_date
				->setTimezone( new DateTimeZone( 'UTC' ) )
				->format( DATE_ATOM );

			return array(
				'title'            => $settings['title'],
				'ends_at'          => $ends_at_utc,
				'server_now'       => current_time( 'c', true ),
				'expired_text'     => $settings['expired_text'],
				'end_behavior'     => $settings['end_behavior'],
				'labels'           => array(
					'days'    => $settings['days_label'],
					'hours'   => $settings['hours_label'],
					'minutes' => $settings['minutes_label'],
					'seconds' => $settings['seconds_label'],
				),
				'background_color' => $settings['background_color'],
				'text_color'       => $settings['text_color'],
				'action'           => $this->build_action( $settings['action_type'], $settings['action_value'] ),
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

    		<label>Ends At</label>

    		<input
    			type="datetime-local"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][ends_at]"
    			value="<?php echo esc_attr( $settings['ends_at'] ); ?>"
    		>

    	</div>

    	<div class="kidia-builder-field">

    		<label>Expired Text</label>

    		<input
    			type="text"
    			name="blocks[<?php echo esc_attr( $index ); ?>][settings][expired_text]"
    			value="<?php echo esc_attr( $settings['expired_text'] ); ?>"
    		>

    	</div>

    </div>

    <?php
    	}
    }
