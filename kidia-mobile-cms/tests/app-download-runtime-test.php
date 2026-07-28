<?php
/**
 * Runtime contract for streaming a real binary APK attachment.
 */

if ( isset( $argv[1] ) && '--child' === $argv[1] ) {
	define( 'ABSPATH', __DIR__ );
	define( 'MB_IN_BYTES', 1024 * 1024 );

	$GLOBALS['kidia_apk_fixture'] = (string) $argv[2];

	class WP_Error {}

	function __( string $message ): string {
		return $message;
	}

	function esc_html__( string $message ): string {
		return $message;
	}

	function is_wp_error( $value ): bool {
		return $value instanceof WP_Error;
	}

	function wp_tempnam(): string {
		return tempnam( sys_get_temp_dir(), 'kidia-apk-download-' );
	}

	function wp_safe_remote_get( string $url, array $args ): array {
		if ( 'https://downloads.example.test/verified.apk' !== $url ) {
			throw new RuntimeException( 'The signed APK URL was not used.' );
		}
		if ( empty( $args['stream'] ) || empty( $args['filename'] ) ) {
			throw new RuntimeException( 'The APK response must stream to a temporary file.' );
		}
		copy( $GLOBALS['kidia_apk_fixture'], (string) $args['filename'] );
		return array( 'response' => array( 'code' => 200 ) );
	}

	function wp_remote_retrieve_response_code( array $response ): int {
		return (int) $response['response']['code'];
	}

	function wp_delete_file( string $path ): bool {
		return ! is_file( $path ) || unlink( $path );
	}

	function nocache_headers(): void {}

	function wp_die( string $message ): void {
		throw new RuntimeException( $message );
	}

	require_once dirname( __DIR__ ) . '/includes/class-kidia-mobile-app-exporter.php';

	$method = new ReflectionMethod( Kidia_Mobile_App_Exporter::class, 'stream_remote_apk' );
	$method->setAccessible( true );
	$method->invoke(
		new Kidia_Mobile_App_Exporter(),
		'https://downloads.example.test/verified.apk',
		'verified.apk'
	);
	exit( 2 );
}

define( 'MB_IN_BYTES', 1024 * 1024 );

$fixture = tempnam( sys_get_temp_dir(), 'kidia-valid-apk-' );
$payload = "PK\x03\x04" . str_repeat( "\0", MB_IN_BYTES + 128 );
file_put_contents( $fixture, $payload );

$command = escapeshellarg( PHP_BINARY )
	. ' '
	. escapeshellarg( __FILE__ )
	. ' --child '
	. escapeshellarg( $fixture );
$pipes   = array();
$process = proc_open(
	$command,
	array(
		0 => array( 'pipe', 'r' ),
		1 => array( 'pipe', 'w' ),
		2 => array( 'pipe', 'w' ),
	),
	$pipes
);
if ( ! is_resource( $process ) ) {
	throw new RuntimeException( 'Could not start the APK download runtime test.' );
}

fclose( $pipes[0] );
$downloaded = stream_get_contents( $pipes[1] );
$errors     = stream_get_contents( $pipes[2] );
fclose( $pipes[1] );
fclose( $pipes[2] );
$exit_code = proc_close( $process );
unlink( $fixture );

if ( 0 !== $exit_code ) {
	throw new RuntimeException( 'APK download child failed: ' . $errors );
}
if ( strlen( $downloaded ) !== strlen( $payload ) ) {
	throw new RuntimeException( 'The downloaded APK byte count did not match the artifact.' );
}
if ( ! hash_equals( hash( 'sha256', $payload ), hash( 'sha256', $downloaded ) ) ) {
	throw new RuntimeException( 'The downloaded APK bytes changed while being proxied.' );
}
if ( "PK\x03\x04" !== substr( $downloaded, 0, 4 ) ) {
	throw new RuntimeException( 'The downloaded file is not an Android APK/ZIP artifact.' );
}

echo "APK binary download runtime test passed.\n";
