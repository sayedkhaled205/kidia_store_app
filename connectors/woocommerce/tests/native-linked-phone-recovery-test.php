<?php
/** Linked-phone routing and existing website recovery; synthetic accounts only. */
function get_permalink( $id ) { return $id > 0 ? 'https://shop.example.test/page-' . $id . '/' : false; }
function add_query_arg( $key, $value, $url ) { return $url . '?' . $key . '=' . $value; }
function wc_get_page_id( $name ) { return $GLOBALS['recovery_woo_page'] ?? 0; }
function wc_get_endpoint_url( $endpoint, $value, $base ) { return $base . $endpoint . '/'; }
function wp_lostpassword_url() { return 'https://shop.example.test/wp-login.php?action=lostpassword'; }
function esc_url_raw( $url, $protocols = array() ) { return str_starts_with( $url, 'https://' ) ? $url : ''; }
class Kidia_Store_Custom_Login_Page_V020 {
    public static function instance() { return new self(); }
    public function get_page_id() { return $GLOBALS['recovery_kidia_page'] ?? 0; }
}
require __DIR__ . '/native-auth-contract-test.php';
$before = $GLOBALS['native_checks'];
$GLOBALS['recovery_kidia_page'] = 17;
$GLOBALS['recovery_woo_page'] = 23;
$config = native_data( $endpoint->config( native_request( array() ) ), 'Kidia recovery' );
native_assert( $config['password_reset_url'] === 'https://shop.example.test/page-17/?kidia_stage=forgot', 'Kidia uses its existing recovery stage' );
$GLOBALS['recovery_kidia_page'] = 0;
$config = native_data( $endpoint->config( native_request( array() ) ), 'Woo recovery' );
native_assert( $config['password_reset_url'] === 'https://shop.example.test/page-23/lost-password/', 'Woo recovery uses the actual account page' );
$GLOBALS['recovery_woo_page'] = 0;
$config = native_data( $endpoint->config( native_request( array() ) ), 'WordPress recovery' );
native_assert( $config['password_reset_url'] === wp_lostpassword_url(), 'WordPress recovery remains the last fallback' );
$meta_snapshot = $GLOBALS['native_meta'];
$issued = count( $GLOBALS['native_issued'] );
$GLOBALS['native_meta'][10] = array( 'kidia_login_phone' => '+201244444444' );
native_clear_rate();
$identity = native_data( $endpoint->identify( native_request( array( 'identifier' => '01244444444', 'supports_email_password_recovery' => true ) ) ), 'Protected phone identity' );
native_assert( $identity['methods'] === array( 'email_password' ), 'Protected phone offers original email proof instead of doomed OTP/password phone attempts' );
native_assert( ! isset( $identity['accounts'] ) && ! isset( $identity['ticket'] ) && ! isset( $identity['user'] ), 'Protected phone does not reveal or authorize an account' );
native_assert( count( $GLOBALS['native_issued'] ) === $issued, 'Method selection never issues a session' );
native_clear_rate();
$legacy = native_data( $endpoint->identify( native_request( array( 'identifier' => '01244444444' ) ) ), 'Previous client identity' );
native_assert( ! in_array( 'email_password', $legacy['methods'], true ), 'Existing clients do not receive a method they cannot render' );
$GLOBALS['native_meta'] = $meta_snapshot;
echo 'Linked phone recovery: ' . ( $GLOBALS['native_checks'] - $before ) . " checks passed.\n";
