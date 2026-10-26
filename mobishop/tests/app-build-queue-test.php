<?php
/**
 * Runtime contract for the non-blocking APK queue.
 */

define( 'ABSPATH', __DIR__ );
define( 'MOBISHOP_VERSION', 'test' );

$GLOBALS['mobishop_test_options'] = array();
$GLOBALS['mobishop_test_scheduled'] = array();
$GLOBALS['mobishop_test_schedule_count'] = 0;
$GLOBALS['mobishop_test_assertions'] = 0;

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

final class MobiShop_License_Manager {
	public static int $requests = 0;
	public static array $bodies = array();
	public static bool $fail_push_once = false;
	public static bool $return_artifacts_list = false;
	public static $on_request = null;

	public function is_active(): bool {
		return true;
	}

	public function build_service_request( string $path = '', string $method = 'GET', array $body = array() ) {
		self::$requests++;
		self::$bodies[] = $body;
		if ( self::$on_request ) {
			$hook = self::$on_request;
			self::$on_request = null;
			$result = $hook( $path, $method, $body );
			if ( null !== $result ) return $result;
		}
		if ( str_ends_with( $path, '/download-link' ) && ! self::$return_artifacts_list ) {
			return array(
				'build' => array(
					'id' => 'build-123',
					'status' => 'finished',
					'progress' => 100,
					'download_url' => 'https://downloads.example.test/fresh-build-files.zip',
					'file_name' => 'queue-test-build-files.zip',
				),
			);
		}
		if ( self::$return_artifacts_list ) {
			return array(
				'data' => array(
					'build' => array(
						'_id' => 'codemagic-build-456',
						'workflow_status' => 'success',
						'progress' => 100,
						'artifacts' => array(
							array(
								'name' => 'app-release.aab',
								'url' => 'https://downloads.example.test/app-release.aab',
							),
							array(
								'name' => 'mobishop-build-files.zip',
								'url' => 'https://downloads.example.test/mobishop-build-files.zip?signature=fresh',
							),
						),
					),
				),
			);
		}
		if ( 'POST' === $method ) {
			if ( self::$fail_push_once && ! empty( $body['provision_push'] ) ) {
				self::$fail_push_once = false;
				return new WP_Error( 'push_provisioning_unavailable', 'Managed Push is not ready.' );
			}
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

final class MobiShop_Setup_Wizard {
	public function identity(): array {
		return array(
			'app_name' => 'Queue Test',
			'language' => 'ar',
			'direction' => 'rtl',
			'logo_url' => 'https://store.example.test/wp-content/uploads/icon.png',
			'primary_color' => '#2F806E',
			'secondary_color' => '#EAF6F2',
			'enabled_pages' => array( 'home' ),
		);
	}

	public static function setup_pages(): array {
		return array( 'home' => array() );
	}
}

final class MobiShop_Push_Service {
	public static function client_configuration(): array {
		return array( 'enabled' => true );
	}

	public static function provision_project(): array {
		return array( 'ok' => true );
	}
}

function __( string $message ): string {
	return $message;
}

function get_option( string $name, $default = false ) {
	return $GLOBALS['mobishop_test_options'][ $name ] ?? $default;
}

function update_option( string $name, $value ): bool {
	$GLOBALS['mobishop_test_options'][ $name ] = $value;
	return true;
}

function delete_option( string $name ): bool {
	unset( $GLOBALS['mobishop_test_options'][ $name ] );
	return true;
}

function add_option( string $name, $value, $deprecated = '', $autoload = false ): bool {
	// WordPress checks existence before hooks, then uses an upsert, not insert-if-absent.
	if ( array_key_exists( $name, $GLOBALS['mobishop_test_options'] ) ) return false;
	if ( isset( $GLOBALS['before_add'] ) ) {
		$hook = $GLOBALS['before_add']; unset( $GLOBALS['before_add'] ); $hook();
	}
	$GLOBALS['mobishop_test_options'][ $name ] = $value;
	return true;
}
function maybe_serialize( $value ): string { return serialize( $value ); }
function wp_cache_delete( $key, $group ): bool { return true; }
final class BuildTestDatabase {
	public string $options = 'wp_options';
	public $before_write = null;
	public bool $fail_next = false;
	public function prepare( $sql, ...$args ) { return array( $sql, $args ); }
	public function query( $prepared ) {
		[$sql, $args] = $prepared;
		$insert = str_starts_with( $sql, 'INSERT IGNORE ' );
		if ( $insert && isset( $GLOBALS['before_add'] ) ) {
			$hook = $GLOBALS['before_add']; unset( $GLOBALS['before_add'] ); $hook();
		}
		if ( $this->before_write ) {
			$hook = $this->before_write; $this->before_write = null; $hook();
		}
		if ( $this->fail_next ) { $this->fail_next = false; return false; }
		if ( $insert ) {
			[$name, $value, $autoload] = $args;
			if ( 'no' !== $autoload ) throw new RuntimeException( 'Build state must not autoload.' );
			if ( array_key_exists( $name, $GLOBALS['mobishop_test_options'] ) ) return 0;
			$GLOBALS['mobishop_test_options'][ $name ] = unserialize( $value );
			return 1;
		}
		$delete = str_starts_with( $sql, 'DELETE ' );
		[$name, $expected] = $delete ? $args : array_slice( $args, 1 );
		if ( ! array_key_exists( $name, $GLOBALS['mobishop_test_options'] )
			|| serialize( $GLOBALS['mobishop_test_options'][ $name ] ) !== $expected ) return 0;
		if ( $delete ) unset( $GLOBALS['mobishop_test_options'][ $name ] );
		else $GLOBALS['mobishop_test_options'][ $name ] = unserialize( $args[0] );
		return 1;
	}
}
$GLOBALS['wpdb'] = new BuildTestDatabase();
final class BuildJsonResponse extends RuntimeException {
	public function __construct( public bool $success, public array $data, public int $status ) { parent::__construct( 'AJAX response' ); }
}
function current_user_can( $capability ): bool { return true; }
function check_ajax_referer( $action, $name ): void {}
function wp_unslash( $value ) { return $value; }
function wp_send_json_success( $data, $status = 200 ): void { throw new BuildJsonResponse( true, $data, $status ); }
function wp_send_json_error( $data, $status = 400 ): void { throw new BuildJsonResponse( false, $data, $status ); }
function cancel_fixture( $exporter, string $id = '' ): BuildJsonResponse {
	$_POST = array( 'buildId' => $id );
	try { $exporter->handle_build_cancel(); } catch ( BuildJsonResponse $response ) { return $response; }
	throw new RuntimeException( 'Cancel did not return a response.' );
}
function race_state( string $token, string $id = 'new-build', string $status = 'building' ): array {
	return array_merge( MobiShop_App_Exporter::state(), array(
		'request_token' => $token, 'build_id' => $id, 'status' => $status,
		'started_at' => time(), 'completed_at' => 0, 'download_url' => '',
	) );
}

function wp_parse_args( $args, array $defaults = array() ): array {
	return array_merge( $defaults, is_array( $args ) ? $args : array() );
}

function wp_generate_uuid4(): string {
	static $counter = 0;
	return sprintf( '12345678-1234-4123-8123-%012d', ++$counter );
}

function as_enqueue_async_action( string $hook, array $args, string $group, bool $unique ): int {
	$GLOBALS['mobishop_test_schedule_count']++;
	$GLOBALS['mobishop_test_scheduled'] = compact( 'hook', 'args', 'group', 'unique' );
	if ( isset( $GLOBALS['schedule_hook'] ) ) {
		$callback = $GLOBALS['schedule_hook']; unset( $GLOBALS['schedule_hook'] );
		return $callback();
	}
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

function mobishop_build_assert( bool $condition, string $message ): void {
	$GLOBALS['mobishop_test_assertions']++;
	if ( ! $condition ) {
		throw new RuntimeException( $message );
	}
}

$source = defined( 'MOBISHOP_EXPORTER_SOURCE' ) ? MOBISHOP_EXPORTER_SOURCE
	: ( $argv[1] ?? dirname( __DIR__ ) . '/includes/class-mobishop-app-exporter.php' );
require_once $source;
$exporter = new MobiShop_App_Exporter();
$started = microtime( true );
$queued = $exporter->queue_build();
$elapsed = microtime( true ) - $started;

mobishop_build_assert( ! is_wp_error( $queued ), 'Queueing must succeed.' );
mobishop_build_assert( $elapsed < 0.25, 'Queueing must not wait for the remote APK service.' );
mobishop_build_assert( 'queued' === $queued['status'], 'A new APK must enter queued state.' );
mobishop_build_assert( '' === $queued['build_id'], 'The remote build ID must be populated by the background action.' );
mobishop_build_assert( 0 === MobiShop_License_Manager::$requests, 'The Overview request must not contact the slow remote service.' );
mobishop_build_assert( 'mobishop_process_app_build' === $GLOBALS['mobishop_test_scheduled']['hook'], 'The APK background hook must be scheduled.' );
mobishop_build_assert( 'mobishop' === $GLOBALS['mobishop_test_scheduled']['group'], 'The background action must use the plugin group.' );

$exporter->process_queued_build( $queued['request_token'] );
$remote = MobiShop_App_Exporter::state();
mobishop_build_assert( 1 === MobiShop_License_Manager::$requests, 'The background action must contact the remote build service once.' );
mobishop_build_assert( 'build-123' === $remote['build_id'], 'The background action must persist the remote build ID.' );
mobishop_build_assert( 'queued' === $remote['status'], 'Remote queued status must remain pollable.' );
$request_body = MobiShop_License_Manager::$bodies[0];
mobishop_build_assert( 'both' === $request_body['platform'], 'One request must target both mobile platforms.' );
mobishop_build_assert( 'zip' === $request_body['artifact'], 'The download must contain the combined build files.' );
mobishop_build_assert( array( 'android', 'ios' ) === $request_body['settings_snapshot']['build_targets'], 'The validated snapshot must preserve both build targets.' );
mobishop_build_assert( 'wordpress-plugin' === $request_body['settings_snapshot']['builder_project'], 'WordPress requests must select the plugin project rather than the central builder branch.' );
mobishop_build_assert( MobiShop_App_Exporter::manifest()['application']['language'] === $request_body['store_locale'], 'The build must retain the selected store language.' );
mobishop_build_assert( 'ar' === $request_body['store_locale'], 'Arabic must not silently fall back to English.' );
mobishop_build_assert( 'https://store.example.test/wp-content/uploads/icon.png' === $request_body['settings_snapshot']['app_icon_url'], 'The selected logo must reach native icon generation.' );
mobishop_build_assert( 'https://store.example.test/wp-json/mobishop/v1/push/config' === $request_body['push_config_url'], 'The build must receive its HTTPS Firebase bootstrap endpoint.' );
mobishop_build_assert( isset( $request_body['configuration_hash'] ), 'The build service requires the canonical configuration_hash field.' );
mobishop_build_assert( isset( $request_body['plugin_version'] ), 'The build service requires the canonical plugin_version field.' );
mobishop_build_assert( true === $request_body['provision_push'], 'The first build attempt should provision managed Push.' );
mobishop_build_assert( ! isset( $request_body['configurationHash'] ), 'Legacy camelCase build fields must not fail Laravel validation again.' );

$duplicate = $exporter->queue_build();
mobishop_build_assert( is_wp_error( $duplicate ), 'A second queued or active build must be rejected.' );
mobishop_build_assert( 'build_already_active' === $duplicate->get_error_code(), 'The duplicate build rejection must be explicit.' );

$remote['status'] = 'failed';
update_option( 'mobishop_app_export_state_v1', $remote );
MobiShop_License_Manager::$fail_push_once = true;
$fallback_queued = $exporter->queue_build();
$exporter->process_queued_build( $fallback_queued['request_token'] );
$fallback_build = MobiShop_App_Exporter::state();
$last_two_bodies = array_slice( MobiShop_License_Manager::$bodies, -2 );
mobishop_build_assert( true === $last_two_bodies[0]['provision_push'], 'Managed Push should be attempted first.' );
mobishop_build_assert( false === $last_two_bodies[1]['provision_push'], 'An unavailable optional Push provisioner must not prevent the APK build.' );
mobishop_build_assert( 'build-123' === $fallback_build['build_id'], 'The APK must still receive a build ID when optional Push provisioning is unavailable.' );

$fallback_build['status'] = 'ready';
$fallback_build['download_url'] = 'https://downloads.example.test/expired-app.apk';
update_option( 'mobishop_app_export_state_v1', $fallback_build );
$refreshed = $exporter->refresh_build( true );
mobishop_build_assert( 4 === MobiShop_License_Manager::$requests, 'Download must refresh the ready remote build.' );
mobishop_build_assert( 'ready' === $refreshed['status'], 'Finished must normalize to a ready APK.' );
mobishop_build_assert( 'https://downloads.example.test/fresh-build-files.zip' === $refreshed['download_url'], 'Download must replace an expired signed URL.' );
mobishop_build_assert( 'queue-test-build-files.zip' === $refreshed['apk_file_name'], 'Download must keep the build bundle filename.' );

MobiShop_License_Manager::$return_artifacts_list = true;
$refreshed = $exporter->refresh_build( true );
mobishop_build_assert( 'ready' === $refreshed['status'], 'A Codemagic success status must become a ready APK.' );
mobishop_build_assert( 'codemagic-build-456' === $refreshed['build_id'], 'Codemagic underscore IDs must be preserved.' );
mobishop_build_assert( 'https://downloads.example.test/mobishop-build-files.zip?signature=fresh' === $refreshed['download_url'], 'The combined build bundle must be selected from a Codemagic artifacts list.' );
mobishop_build_assert( 'mobishop-build-files.zip' === $refreshed['apk_file_name'], 'The combined build bundle filename must be preserved.' );

// A slow response must never restore cancelled A or replace a newer B.
MobiShop_License_Manager::$return_artifacts_list = false;
$key = 'mobishop_app_export_state_v1';
$old = race_state( 'old-token', 'old-build' ); update_option( $key, $old );
$new = race_state( 'new-token' );
MobiShop_License_Manager::$on_request = function () use ( $key, $new ) { update_option( $key, $new ); };
$polled = $exporter->refresh_build();
mobishop_build_assert( MobiShop_App_Exporter::state() === $new && $polled === $new, 'Late polling must retain and return the newer build.' );

update_option( $key, $old );
MobiShop_License_Manager::$on_request = function () use ( $key, $new ) { update_option( $key, $new ); return array( 'status' => 'cancelled' ); };
$cancel = cancel_fixture( $exporter, 'old-build' );
mobishop_build_assert( ! $cancel->success && $cancel->status === 409 && MobiShop_App_Exporter::state() === $new, 'Late cancellation must not delete the newer build.' );

// Move B into the SQL read/write gap, after any PHP identity check.
update_option( $key, $old );
$GLOBALS['wpdb']->before_write = function () use ( $key, $new ) { update_option( $key, $new ); };
$exporter->refresh_build();
mobishop_build_assert( MobiShop_App_Exporter::state() === $new, 'The conditional SQL write must reject an intervening build.' );

// Two poll responses for the same build also must not regress a completed build.
update_option( $key, $old );
MobiShop_License_Manager::$on_request = function () use ( $exporter ) {
	$exporter->refresh_build();
	return array( 'id' => 'old-build', 'status' => 'queued' );
};
$exporter->refresh_build();
mobishop_build_assert( MobiShop_App_Exporter::state()['status'] === 'ready', 'A late queued response must not replace a completed state.' );

// A failure belonging to A must not fail B or trigger a second provider request.
delete_option( $key );
$queued = $exporter->queue_build(); $before = MobiShop_License_Manager::$requests;
MobiShop_License_Manager::$on_request = function () use ( $key, $new ) {
	update_option( $key, $new );
	return new WP_Error( 'push_provisioning_unavailable', 'Old request failed.' );
};
$exporter->process_queued_build( $queued['request_token'] );
mobishop_build_assert( MobiShop_App_Exporter::state() === $new, 'An old dispatch error must not fail the newer request.' );
mobishop_build_assert( MobiShop_License_Manager::$requests === $before + 1, 'An obsolete dispatch must not retry the provider.' );

// Claim the queued job before network I/O: a second worker and Cancel cannot lose it.
delete_option( $key ); $queued = $exporter->queue_build(); $before = MobiShop_License_Manager::$requests;
MobiShop_License_Manager::$on_request = function () use ( $exporter, $queued ) {
	mobishop_build_assert( MobiShop_App_Exporter::state()['status'] === 'building', 'The worker must claim queued state before dispatch.' );
	$exporter->process_queued_build( $queued['request_token'] );
	$result = cancel_fixture( $exporter );
	mobishop_build_assert( $result->status === 409 && ! $result->success, 'Cancellation during acceptance must retain the pending provider identity.' );
};
$exporter->process_queued_build( $queued['request_token'] );
mobishop_build_assert( MobiShop_License_Manager::$requests === $before + 1, 'Duplicate queue workers must issue one provider request.' );
mobishop_build_assert( MobiShop_App_Exporter::state()['build_id'] === 'build-123', 'The claimed worker must retain the accepted provider ID.' );

// Cancellation wins before the claim: the old scheduled action does nothing.
delete_option( $key ); $queued = $exporter->queue_build(); $before = MobiShop_License_Manager::$requests;
$result = cancel_fixture( $exporter ); $exporter->process_queued_build( $queued['request_token'] );
mobishop_build_assert( $result->success && MobiShop_App_Exporter::state()['status'] === 'idle', 'Queued cancellation must stay cancelled.' );
mobishop_build_assert( MobiShop_License_Manager::$requests === $before, 'A cancelled queued action must not dispatch later.' );

// First creation and replacement of a legacy partial option are both atomic.
$schedule_count = $GLOBALS['mobishop_test_schedule_count'];
$GLOBALS['before_add'] = function () use ( $exporter ) { $GLOBALS['winning_build'] = $exporter->queue_build(); };
$loser = $exporter->queue_build();
mobishop_build_assert( is_wp_error( $loser ) && MobiShop_App_Exporter::state() === $GLOBALS['winning_build'], 'Concurrent first starts must retain one queued request.' );
mobishop_build_assert( $GLOBALS['mobishop_test_schedule_count'] === $schedule_count + 1, 'Concurrent first starts must schedule only the winning request.' );
update_option( $key, array( 'status' => 'failed' ) );
$GLOBALS['wpdb']->before_write = function () use ( $exporter ) { $GLOBALS['winning_build'] = $exporter->queue_build(); };
$loser = $exporter->queue_build();
mobishop_build_assert( is_wp_error( $loser ) && MobiShop_App_Exporter::state() === $GLOBALS['winning_build'], 'Legacy partial state replacement must compare the raw stored value atomically.' );

// Failed scheduling and timeout of A cannot mark an unrelated B as failed.
delete_option( $key );
$GLOBALS['schedule_hook'] = function () use ( $key, $new ) { update_option( $key, $new ); return 0; };
$exporter->queue_build();
mobishop_build_assert( MobiShop_App_Exporter::state() === $new, 'A stale scheduling error must preserve B.' );
$expired = $old; $expired['build_id'] = ''; $expired['started_at'] = time() - 181;
update_option( $key, $expired );
$GLOBALS['wpdb']->before_write = function () use ( $key, $new ) { update_option( $key, $new ); };
$exporter->refresh_build();
mobishop_build_assert( MobiShop_App_Exporter::state() === $new, 'An old startup timeout must preserve B.' );

// Remote failure does not clear a valid build; completed OK remains acknowledgement.
update_option( $key, $old );
MobiShop_License_Manager::$on_request = function () { return new WP_Error( 'unavailable', 'Provider unavailable.' ); };
$result = cancel_fixture( $exporter, 'old-build' );
mobishop_build_assert( $result->status === 502 && MobiShop_App_Exporter::state() === $old, 'Provider cancellation failure must preserve state.' );
$ready = $old; $ready['status'] = 'ready'; $ready['download_url'] = 'https://downloads.example.test/app.apk';
update_option( $key, $ready ); $before = MobiShop_License_Manager::$requests;
$result = cancel_fixture( $exporter, 'old-build' );
mobishop_build_assert( $result->success && MobiShop_App_Exporter::state()['dismissed_build_id'] === 'old-build', 'Ready OK must acknowledge without deleting the build.' );
mobishop_build_assert( MobiShop_App_Exporter::state()['download_url'] === $ready['download_url'] && MobiShop_License_Manager::$requests === $before, 'Ready acknowledgement must retain downloads and never cancel remotely.' );

update_option( $key, array( 'status' => 'failed' ) );
$GLOBALS['wpdb']->fail_next = true;
$result = $exporter->queue_build();
mobishop_build_assert( is_wp_error( $result ) && MobiShop_App_Exporter::state()['status'] === 'failed', 'Database write failure must not report a queued build.' );
delete_option( $key );
$schedule_count = $GLOBALS['mobishop_test_schedule_count'];
$before = MobiShop_License_Manager::$requests;
$GLOBALS['wpdb']->fail_next = true;
$result = $exporter->queue_build();
mobishop_build_assert( is_wp_error( $result ) && ! array_key_exists( $key, $GLOBALS['mobishop_test_options'] ), 'Failed first insert must leave the option absent and report failure.' );
mobishop_build_assert( $GLOBALS['mobishop_test_schedule_count'] === $schedule_count && MobiShop_License_Manager::$requests === $before, 'Failed first insert must neither schedule nor dispatch a build.' );
// The interactive start uses the same atomic claim and reports persistence failures.
delete_option( $key );
$GLOBALS['before_add'] = function () use ( $exporter ) { $GLOBALS['winning_build'] = $exporter->queue_build(); };
$before = MobiShop_License_Manager::$requests;
try { $exporter->handle_build_start(); throw new RuntimeException( 'Missing AJAX response.' ); }
catch ( BuildJsonResponse $response ) {
	mobishop_build_assert( $response->status === 409 && ! $response->success, 'A losing interactive start must report a conflict.' );
}
mobishop_build_assert( MobiShop_App_Exporter::state() === $GLOBALS['winning_build'] && MobiShop_License_Manager::$requests === $before, 'A losing interactive start must not dispatch another build.' );

delete_option( $key );
MobiShop_License_Manager::$on_request = function () { $GLOBALS['wpdb']->fail_next = true; };
try { $exporter->handle_build_start(); throw new RuntimeException( 'Missing AJAX response.' ); }
catch ( BuildJsonResponse $response ) {
	mobishop_build_assert( $response->status === 502 && ! $response->success, 'Failed persistence after provider acceptance must not report success.' );
}
$pending = MobiShop_App_Exporter::state(); $before = MobiShop_License_Manager::$requests;
$exporter->process_queued_build( $pending['request_token'] );
mobishop_build_assert( $pending['status'] === 'building' && MobiShop_License_Manager::$requests === $before, 'An accepted but unsaved build must not be dispatched by the queue again.' );

// The DELETE itself must also reject a replacement after its identity check.
update_option( $key, $old );
$GLOBALS['wpdb']->before_write = function () use ( $key, $new ) { update_option( $key, $new ); };
$result = cancel_fixture( $exporter, 'old-build' );
mobishop_build_assert( $result->status === 409 && MobiShop_App_Exporter::state() === $new, 'The SQL delete must preserve an intervening replacement build.' );

// Genuine failures of the current request still become recoverable failed states.
delete_option( $key ); $queued = $exporter->queue_build();
MobiShop_License_Manager::$on_request = function () { return new WP_Error( 'build_service_unavailable', 'Unavailable.' ); };
$exporter->process_queued_build( $queued['request_token'] );
mobishop_build_assert( MobiShop_App_Exporter::state()['status'] === 'failed', 'The current provider failure must still become failed.' );
$result = $exporter->queue_build();
mobishop_build_assert( ! is_wp_error( $result ) && $result['request_token'] !== $queued['request_token'], 'Retry after failure must get a new request identity.' );

echo 'Build queue, downloads and concurrency: ' . $GLOBALS['mobishop_test_assertions'] . " assertions passed.\n";
