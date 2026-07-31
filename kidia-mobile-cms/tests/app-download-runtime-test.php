<?php
/**
 * Runtime contract for redirecting a large build bundle without proxying it.
 */

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_redirect'] = array();

function __( string $message ): string {
	return $message;
}

function wp_parse_url( string $url, int $component ) {
	return parse_url( $url, $component );
}

function nocache_headers(): void {}

function wp_redirect( string $url, int $status, string $application ): bool {
	$GLOBALS['kidia_redirect'] = compact( 'url', 'status', 'application' );
	return true;
}

require_once dirname( __DIR__ ) . '/includes/class-kidia-mobile-app-exporter.php';

$method = new ReflectionMethod( Kidia_Mobile_App_Exporter::class, 'redirect_to_artifact' );
$method->setAccessible( true );
$result = $method->invoke(
	new Kidia_Mobile_App_Exporter(),
	'https://api.codemagic.io/artifacts/signed-build-files.zip'
);

if ( true !== $result ) {
	throw new RuntimeException( 'The direct artifact redirect was not accepted.' );
}
if ( 'https://api.codemagic.io/artifacts/signed-build-files.zip' !== $GLOBALS['kidia_redirect']['url'] ) {
	throw new RuntimeException( 'The browser was not redirected to the Codemagic artifact.' );
}
if ( 302 !== $GLOBALS['kidia_redirect']['status'] ) {
	throw new RuntimeException( 'The artifact redirect must be temporary.' );
}
if ( false !== $method->invoke( new Kidia_Mobile_App_Exporter(), 'http://unsafe.example.test/file.zip' ) ) {
	throw new RuntimeException( 'An insecure artifact URL must be rejected.' );
}

echo "Direct build bundle redirect runtime test passed.\n";
