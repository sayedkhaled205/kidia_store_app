<?php
/** Fresh signed Apple proof is authorization to continue, never proof of erasure. */
require __DIR__ . '/native-auth-contract-test.php';
$before = $GLOBALS['native_checks'];
// This suite models raw metadata rows, including duplicate and malformed rows.
$GLOBALS['native_meta_rows_format'] = true;
$settings = $GLOBALS['native_options']['mobishop_native_auth_settings'];
$settings['apple_enabled'] = true;
$settings['ios_apple_native_ready'] = true;
$settings['firebase']['ios'] = array( 'apiKey' => 'fixture-ios-api', 'appId' => '1:123:ios:fixture', 'projectId' => 'test-project', 'messagingSenderId' => '123', 'iosBundleId' => 'app.fixture.native' );
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings;
$claims = array( 'aud' => 'test-project', 'iss' => 'https://securetoken.google.com/test-project', 'sub' => 'deletion-fixture-uid',
    'exp' => time() + 3600, 'iat' => time(), 'auth_time' => time(),
    'firebase' => array( 'sign_in_provider' => 'apple.com', 'identities' => array( 'apple.com' => array( 'deletion.apple.subject' ) ) ) );
// The shared auth harness models single metadata values. This validator explicitly
// reads all rows, so these fixtures use the array returned by WP for single=false.
$binding = array( '_mobishop_firebase_project' => array( 'test-project' ), '_mobishop_firebase_uid' => array( 'deletion-fixture-uid' ), '_mobishop_apple_subject' => array( 'deletion.apple.subject' ) );
$GLOBALS['native_meta'][7] = $binding;
$validator = new MobiShop_Native_Customer_Auth_Endpoint(
    static function () { throw new RuntimeException( 'Deletion proof must not issue a login.' ); },
    static fn( $user ) => in_array( 'customer', $user->roles, true ) && ! array_intersect( $user->roles, array( 'administrator', 'shop_manager' ) )
);
function deletion_proof_request( array $claims, array $extra = array() ) {
    return native_request( array_merge( array( 'id_token' => native_jwt( $claims ), 'platform' => 'ios' ), $extra ) );
}
function deletion_proof_check( $validator, array $claims, int $id, bool $valid, string $label, array $extra = array() ) {
    $keys = array( 'native_users', 'native_meta', 'native_options', 'native_issued', 'native_created', 'native_auth_calls', 'native_routes' );
    $snapshot = array();
    foreach ( $keys as $key ) $snapshot[$key] = $GLOBALS[$key];
    $result = $validator->validate_deletion_apple_proof( deletion_proof_request( $claims, $extra ), $id );
    native_assert( $valid ? $result === true : is_wp_error( $result ), $label );
    foreach ( $keys as $key ) native_assert( $GLOBALS[$key] === $snapshot[$key], $label . ': unchanged ' . $key );
    return $result;
}
deletion_proof_check( $validator, $claims, 7, false, 'Missing shared-identity checker fails closed' );
// Delayed declaration allows the missing-helper check above to exercise the real branch.
if ( ! class_exists( 'MobiShop_Customer_Identity_Links' ) ) {
    final class MobiShop_Customer_Identity_Links {
        public static $result = false;
        public static bool $throws = false;
        public static array $calls = array();
        public static function shared( int $id, array $link ) {
            self::$calls[] = array( $id, $link );
            if ( self::$throws ) throw new RuntimeException( 'Fixture private database failure' );
            return self::$result;
        }
    }
}
deletion_proof_check( $validator, $claims, 7, true, 'Fresh signed proof for exact captured owner accepted without email or verifier' );
native_assert( end( MobiShop_Customer_Identity_Links::$calls ) === array( 7, array( 'project' => 'test-project', 'uid' => 'deletion-fixture-uid', 'provider' => 'apple' ) ), 'Shared ownership checked against verified project and UID' );
deletion_proof_check( $validator, $claims, 9, false, 'Body ID cannot replace authenticated captured owner', array( 'user_id' => 7, 'account_id' => 7 ) );
deletion_proof_check( $validator, $claims, 7, true, 'Untrusted body IDs do not change target', array( 'user_id' => 9, 'account_id' => 9 ) );
foreach ( array( 0, -1, 999999 ) as $id ) deletion_proof_check( $validator, $claims, $id, false, 'Invalid or missing captured owner' );
foreach ( array( 8, 10 ) as $id ) {
    $GLOBALS['native_meta'][$id] = $binding;
    deletion_proof_check( $validator, $claims, $id, false, 'Privileged owner is rejected despite exact identity metadata' );
}
foreach ( array(
    array( 'aud' => 'other-project' ), array( 'iss' => 'https://securetoken.google.com/other-project' ), array( 'sub' => 'other-uid' ),
    array( 'sub' => str_repeat( 'x', 129 ) ), array( 'sub' => 7 ), array( 'auth_time' => time() - 601 ), array( 'auth_time' => time() + 60 ),
    array( 'auth_time' => null ), array( 'iat' => time() - 601 ), array( 'iat' => time() + 60 ), array( 'exp' => time() - 1 ),
    array( 'firebase' => array( 'sign_in_provider' => 'phone', 'identities' => array( 'apple.com' => array( 'deletion.apple.subject' ) ) ) ),
    array( 'firebase' => array( 'sign_in_provider' => 'apple.com', 'identities' => array( 'apple.com' => array( 'other.subject' ) ) ) ),
    array( 'firebase' => array( 'sign_in_provider' => 'apple.com', 'identities' => array( 'apple.com' => array( 'deletion.apple.subject', 'other' ) ) ) ),
    array( 'firebase' => array( 'sign_in_provider' => 'apple.com', 'identities' => array( 'apple.com' => array( 'unexpected' => 'deletion.apple.subject' ) ) ) ),
    array( 'firebase' => array( 'sign_in_provider' => 'apple.com', 'identities' => array() ) ),
) as $override ) deletion_proof_check( $validator, array_replace( $claims, $override ), 7, false, 'Wrong or stale signed claims rejected' );
foreach ( array( 'forged', null, array( 'id_token' => 'forged' ) ) as $token ) {
    deletion_proof_check( $validator, $claims, 7, false, 'Malformed token rejected', array( 'id_token' => $token ) );
}
// A structurally valid token signed by another key cannot bypass signature validation.
$real_key = $GLOBALS['native_private_key'];
$GLOBALS['native_private_key'] = openssl_pkey_new( $key_options );
$forged = native_jwt( $claims );
$GLOBALS['native_private_key'] = $real_key;
deletion_proof_check( $validator, $claims, 7, false, 'Foreign signing key rejected', array( 'id_token' => $forged ) );
foreach ( array_keys( $binding ) as $key ) {
    foreach ( array( array(), array( 'wrong' ), array( $binding[$key][0], $binding[$key][0] ), array( array( $binding[$key][0] ) ) ) as $value ) {
        $GLOBALS['native_meta'][7] = $binding;
        $GLOBALS['native_meta'][7][$key] = $value;
        deletion_proof_check( $validator, $claims, 7, false, 'Missing conflicting duplicate or malformed metadata blocks proof' );
    }
}
$GLOBALS['native_meta'][7] = $binding;
foreach ( array( true, null, 0 ) as $value ) {
    MobiShop_Customer_Identity_Links::$result = $value;
    deletion_proof_check( $validator, $claims, 7, false, 'Shared or indeterminate ownership fails closed' );
}
MobiShop_Customer_Identity_Links::$result = false;
MobiShop_Customer_Identity_Links::$throws = true;
$error = deletion_proof_check( $validator, $claims, 7, false, 'Shared lookup exception fails closed' );
native_assert( ! str_contains( $error->get_error_message(), 'private' ), 'Internal failure details never returned' );
MobiShop_Customer_Identity_Links::$throws = false;
deletion_proof_check( $validator, $claims, 7, false, 'Android cannot authorize Apple erasure', array( 'platform' => 'android' ) );
$GLOBALS['native_https'] = false;
deletion_proof_check( $validator, $claims, 7, false, 'HTTP transport rejected' );
$GLOBALS['native_https'] = true;
$GLOBALS['native_options']['mobishop_native_auth_settings']['firebase']['ios']['projectId'] = 'other-project';
deletion_proof_check( $validator, $claims, 7, false, 'Mismatched configured projects rejected', array( 'project_id' => 'test-project' ) );
$GLOBALS['native_options']['mobishop_native_auth_settings'] = $settings;
$GLOBALS['native_options']['mobishop_native_auth_settings']['ios_apple_native_ready'] = false;
deletion_proof_check( $validator, $claims, 7, false, 'Disabled Apple provider rejected' );
echo 'Apple deletion proof: ' . ( $GLOBALS['native_checks'] - $before ) . ' additional checks passed.' . PHP_EOL;
