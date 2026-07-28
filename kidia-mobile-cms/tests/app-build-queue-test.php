<?php
/**
 * Runtime contract for the non-blocking APK queue.
 */

define( 'ABSPATH', __DIR__ );
define( 'KIDIA_MOBILE_CMS_VERSION', 'test' );

$GLOBALS['kidia_test_options'] = array();
$GLOBALS['kidia_test_scheduled'] = array();

class WP_Error {
	private string $code;
	private string $message;

	public function __construct( string $code, string $message ) {
		$this->code = $code;
		$this->message = $message;
	}

	public function get_error_code(): string {
		return $this->code;
	}

	public function get_error_message(): string {
		return $this->message;
	}
}

final class Kidia_Mobile_License_Manager {
	public static int $requests = 0;

	public function is_active(): bool {
		return true;
	}

	public function build_service_request( string $path = '', string $method = 'GET', array $body = array() ): array {
		self::$requests++;
		if ( 'POST' === $method ) {
			return array(
				'data' => array(
					'build' => array(
						'id' => 'build-123',
						'status' => 'queued',
						'progress' => 2,
					),
				),
			);
		}

		return array(
			'result' => array(
				'id' => 'build-123',
				'status' => 'finished',
				'progress' => 100,
				'artifact' => array(
					'url' => 'https://downloads.example.test/fresh-app.apk',
					'fileName' => 'fresh-app.apk',
				),
			),
		);
	}
}

final class Kidia_Mobile_Setup_Wizard {
	public function identity(): array {
		return array(
			'app_name' => 'Queue Test',
			'language' => 'en',
			'direction' => 'ltr',
			'primary_color' => '#2F806E',
			'secondary_color' => '#EAF6F2',
			'enabled_pages' => array( 'home' ),
		);
	}

	public static function setup_pages(): array {
		return array( 'home' => array() );
	}
}

final class Kidia_Mobile_Push_Service {
	public static function client_configuration(): array {
		return array( 'enabled' => true );
	}
}

function __( string $message ): string {
	return $message;
}

function get_option( string $name, $default = false ) {
	return $GLOBALS['kidia_test_options'][ $name ] ?? $default;
}

function update_option( string $name, $value ): bool {
	$GLOBALS['kidia_test_options'][ $name ] = $value;
	return true;
}

function wp_parse_args( $args, array $defaults = array() ): array {
	return array_merge( $defaults, is_array( $args ) ? $args : array() );
}

function wp_generate_uuid4(): string {
	return '12345678-1234-4123-8123-123456789abc';
}

function as_enqueue_async_action( string $hook, array $args, string $group, bool $unique ): int {
	$GLOBALS['kidia_test_scheduled'] = compact( 'hook', 'args', 'group', 'unique' );
	return 17;
}

function is_wp_error( $value ): bool {
	return $value instanceof WP_Error;
}

function sanitize_title( string $value ): string {
	return strtolower( preg_replace( '/[^a-z0-9]+/i', '-', trim( $value ) ) );
}

function sanitize_key( string $value ): string {
	return strtolower( preg_replace( '/[^a-z0-9_-]/i', '', $value ) );
}

function sanitize_text_field( string $value ): string {
	return trim( $value );
}

function sanitize_file_name( string $value ): string {
	return basename( $value );
}

function esc_url_raw( string $value ): string {
	return $value;
}

function absint( $value ): int {
	return abs( (int) $value );
}

function wp_json_encode( $value ): string {
	return (string) json_encode( $value );
}

function home_url( string $path = '' ): string {
	return 'https://store.example.test' . $path;
}

function rest_url( string $path = '' ): string {
	return 'https://store.example.test/wp-json/' . ltrim( $path, '/' );
}

function get_bloginfo( string $field ): string {
	return 'Queue Test';
}

function kidia_build_assert( bool $condition, string $message ): void {
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

require_once dirname( __DIR__ ) . '/includes/class-kidia-mobile-app-exporter.php';

$exporter = new Kidia_Mobile_App_Exporter();
$started = microtime( true );
$queued = $exporter->queue_build();
$elapsed = microtime( true ) - $started;

kidia_build_assert( ! is_wp_error( $queued ), 'Queueing must succeed.' );
kidia_build_assert( $elapsed < 0.25, 'Queueing must not wait for the remote APK service.' );
kidia_build_assert( 'queued' === $queued['status'], 'A new APK must enter queued state.' );
kidia_build_assert( '' === $queued['build_id'], 'The remote build ID must be populated by the background action.' );
kidia_build_assert( 0 === Kidia_Mobile_License_Manager::$requests, 'The Overview request must not contact the slow remote service.' );
kidia_build_assert( 'kidia_mobile_process_app_build' === $GLOBALS['kidia_test_scheduled']['hook'], 'The APK background hook must be scheduled.' );
kidia_build_assert( 'kidia-mobile-cms' === $GLOBALS['kidia_test_scheduled']['group'], 'The background action must use the plugin group.' );

$exporter->process_queued_build( $queued['request_token'] );
$remote = Kidia_Mobile_App_Exporter::state();
kidia_build_assert( 1 === Kidia_Mobile_License_Manager::$requests, 'The background action must contact the remote build service once.' );
kidia_build_assert( 'build-123' === $remote['build_id'], 'The background action must persist the remote build ID.' );
kidia_build_assert( 'queued' === $remote['status'], 'Remote queued status must remain pollable.' );

$remote['status'] = 'ready';
$remote['download_url'] = 'https://downloads.example.test/expired-app.apk';
update_option( 'kidia_mobile_app_export_state_v1', $remote );
$refreshed = $exporter->refresh_build( true );
kidia_build_assert( 2 === Kidia_Mobile_License_Manager::$requests, 'Download must refresh the ready remote build.' );
kidia_build_assert( 'ready' === $refreshed['status'], 'Finished must normalize to a ready APK.' );
kidia_build_assert( 'https://downloads.example.test/fresh-app.apk' === $refreshed['download_url'], 'Download must replace an expired signed URL.' );

echo "APK background queue and fresh download URL tests passed.\n";
