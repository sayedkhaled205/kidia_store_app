<?php
/** Platform configuration regression tests using public, synthetic fixtures. */
define( 'ABSPATH', __DIR__ );
define( 'MINUTE_IN_SECONDS', 60 );
$cache = array();
function get_transient( $key ) { global $cache; return $cache[ $key ] ?? false; }
function set_transient( $key, $value, $ttl ) { global $cache; $cache[ $key ] = $value; }
function sanitize_text_field( $text ) { return trim( strip_tags( $text ) ); }
function is_wp_error( $value ) { return false; }
class MobiShop_License_Manager {
    public static array $fixtures = array();
    public static array $calls = array();
    public function firebase_config_file( $platform ) {
        self::$calls[] = $platform;
        return self::$fixtures[ $platform ];
    }
}
require __DIR__ . '/../includes/class-mobishop-push-service.php';
$method = new ReflectionMethod( MobiShop_Push_Service::class, 'firebase_client_options' );
$method->setAccessible( true );
function check( $condition, $message ) {
    if ( ! $condition ) { throw new RuntimeException( $message ); }
}
MobiShop_License_Manager::$fixtures['android'] = json_encode( array(
    'project_info' => array( 'project_number' => '123', 'project_id' => 'fixture', 'storage_bucket' => 'bucket' ),
    'client' => array( array( 'client_info' => array( 'mobilesdk_app_id' => '1:123:android:abc' ), 'api_key' => array( array( 'current_key' => 'public-key' ) ) ) ),
) );
$plist = '<?xml version="1.0"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>API_KEY</key><string>public-key</string><key>GOOGLE_APP_ID</key><string>1:123:ios:def</string><key>GCM_SENDER_ID</key><string>123</string><key>PROJECT_ID</key><string>fixture</string><key>BUNDLE_ID</key><string>app.example.store</string><key>PRIVATE_KEY</key><string>must-not-export</string></dict></plist>';
MobiShop_License_Manager::$fixtures['ios'] = $plist;
$android = $method->invoke( null, 'android' );
$ios = $method->invoke( null, 'ios' );
check( $android['appId'] === '1:123:android:abc', 'Android ID' );
check( $ios['appId'] === '1:123:ios:def', 'iOS ID' );
check( $ios['iosBundleId'] === 'app.example.store', 'iOS bundle identity' );
check( ! in_array( 'must-not-export', $ios, true ), 'Only SDK allowlist is public' );
check( $method->invoke( null, 'android' ) === $android, 'Android cache remains isolated' );
check( $method->invoke( null, 'ios' ) === $ios, 'iOS cache remains isolated' );
check( count( MobiShop_License_Manager::$calls ) === 2, 'Cache prevents repeated provider requests' );
check( $method->invoke( null, 'windows' ) === array(), 'Unsupported platform rejected' );
foreach ( array( '<plist>', str_replace( 'ios:def', 'android:def', $plist ), str_replace( '<key>PROJECT_ID</key><string>fixture</string>', '', $plist ), '<!DOCTYPE plist [<!ENTITY test SYSTEM "file:///etc/passwd">]><plist><dict/></plist>' ) as $invalid ) {
    $cache = array();
    MobiShop_License_Manager::$fixtures['ios'] = $invalid;
    check( $method->invoke( null, 'ios' ) === array(), 'Invalid or cross-platform plist rejected' );
}
$cache = array();
MobiShop_License_Manager::$fixtures['android'] = str_replace( '"project_id":"fixture",', '', MobiShop_License_Manager::$fixtures['android'] );
check( $method->invoke( null, 'android' ) === array(), 'Optional bucket cannot substitute for required project ID' );
echo "Firebase platform configuration tests passed.\n";
