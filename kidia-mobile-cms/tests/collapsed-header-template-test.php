<?php
/** Collapsed-header editor placement, toggle and persistence contract test. */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['kidia_collapsed_header_options'] = array();

function __( string $value, string $domain = '' ): string { unset( $domain ); return $value; }
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_hex_color( $value ) { return preg_match( '/^#[0-9a-f]{6}$/i', (string) $value ) ? (string) $value : null; }
function esc_url_raw( $value ): string { return filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : ''; }
function wp_json_encode( $value ): string { return json_encode( $value, JSON_UNESCAPED_SLASHES ); }
function get_option( string $name, $default = false ) { return $GLOBALS['kidia_collapsed_header_options'][ $name ] ?? $default; }
function update_option( string $name, $value, bool $autoload = false ): bool { unset( $autoload ); $GLOBALS['kidia_collapsed_header_options'][ $name ] = $value; return true; }
function esc_attr( $value ): string { return htmlspecialchars( (string) $value, ENT_QUOTES, 'UTF-8' ); }
function esc_html( $value ): string { return htmlspecialchars( (string) $value, ENT_QUOTES, 'UTF-8' ); }
function esc_attr_e( string $value, string $domain = '' ): void { echo esc_attr( __( $value, $domain ) ); }
function esc_html_e( string $value, string $domain = '' ): void { echo esc_html( __( $value, $domain ) ); }
function checked( $checked, $current = true, bool $display = true ): string {
	$result = (string) $checked === (string) $current ? 'checked="checked"' : '';
	if ( $display ) { echo $result; }
	return $result;
}
function selected( $selected, $current = true, bool $display = true ): string {
	$result = (string) $selected === (string) $current ? 'selected="selected"' : '';
	if ( $display ) { echo $result; }
	return $result;
}
function kidia_collapsed_header_assert( bool $condition, string $message ): void {
	if ( ! $condition ) { throw new RuntimeException( $message ); }
}

require dirname( __DIR__ ) . '/includes/class-kidia-mobile-page-layout-store.php';

$store          = new Kidia_Mobile_Page_Layout_Store();
$chrome_layout  = $store->get_layout( 'home' );
$chrome_part    = 'header';
$chrome_page    = 'home';
$header_fields  = Kidia_Mobile_Page_Layout_Store::header_fields();
$footer_fields  = Kidia_Mobile_Page_Layout_Store::footer_fields();

ob_start();
require dirname( __DIR__ ) . '/admin/pages/fixed-chrome-card.php';
$markup = (string) ob_get_clean();

$regular_position   = strpos( $markup, 'Regular header' );
$collapsed_position = strpos( $markup, 'data-variant="collapsed"' );
$settings_position  = strpos( $markup, 'kidia-collapsed-header-settings' );
$toggle_name        = 'name="layout[header][settings][collapse_on_scroll]"';

kidia_collapsed_header_assert( false !== $regular_position, 'The regular header composer must be labelled.' );
kidia_collapsed_header_assert( false !== $collapsed_position && $collapsed_position > $regular_position, 'The collapsed header composer must sit directly after the regular header.' );
kidia_collapsed_header_assert( false !== $settings_position && $settings_position > $collapsed_position, 'Collapsed appearance settings must follow the collapsed composer.' );
kidia_collapsed_header_assert( 2 === substr_count( $markup, $toggle_name ), 'The collapsed On/Off control must submit both its unchecked and checked values.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'kidia-toggle-state' ), 'The collapsed control must display the shared On/Off state.' );
kidia_collapsed_header_assert( false === strpos( $markup, 'Preview collapsed header' ), 'The old preview-only control must not be rendered.' );
kidia_collapsed_header_assert( false === strpos( $markup, 'scroll_up_header' ), 'The obsolete scroll-up selector must not be rendered.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_transition]"' ), 'Collapsed transition options must render below the collapsed composer.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_speed]"' ), 'Collapsed transition speed must render below the collapsed composer.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_preset]"' ), 'Collapsed presets must render below the collapsed composer.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'Sticky Search + Cart' ), 'The compact sticky preset must use its generic product name.' );

$off = $store->save_layout( 'home', array(
	'header' => array( 'enabled' => '1', 'settings' => array( 'collapse_on_scroll' => '0' ) ),
	'footer' => array( 'enabled' => '1' ),
) );
kidia_collapsed_header_assert( false === $off['header']['settings']['collapse_on_scroll'], 'Turning the collapsed header Off must save.' );

$on = $store->save_layout( 'home', array(
	'header' => array( 'enabled' => '1', 'settings' => array( 'collapse_on_scroll' => '1', 'collapse_preset' => 'sticky_search_cart', 'collapse_transition' => 'scale', 'collapse_speed' => 'slow' ) ),
	'footer' => array( 'enabled' => '1' ),
) );
kidia_collapsed_header_assert( true === $on['header']['settings']['collapse_on_scroll'], 'Turning the collapsed header On must save.' );
kidia_collapsed_header_assert( 'scale' === $on['header']['settings']['collapse_transition'], 'The collapsed transition must save.' );
kidia_collapsed_header_assert( 'slow' === $on['header']['settings']['collapse_speed'], 'The collapsed transition speed must save.' );
kidia_collapsed_header_assert( 'sticky_search_cart' === $on['header']['settings']['collapse_preset'], 'The Sticky Search + Cart preset must save.' );
kidia_collapsed_header_assert( true === $store->get_layout( 'home' )['header']['settings']['collapse_on_scroll'], 'The saved On state must survive reload.' );

fwrite( STDOUT, "Collapsed-header editor placement, toggle and save passed.\n" );
