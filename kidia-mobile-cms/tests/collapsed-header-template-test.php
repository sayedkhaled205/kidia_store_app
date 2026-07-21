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
function esc_url( $value ): string { return filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : ''; }
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
kidia_collapsed_header_assert( false !== strpos( $markup, 'kidia-collapsed-header-settings' ), 'Collapsed appearance settings must remain a separate hideable section below the persistent composer.' );
kidia_collapsed_header_assert( false === strpos( $markup, 'Preview collapsed header' ), 'The old preview-only control must not be rendered.' );
kidia_collapsed_header_assert( false === strpos( $markup, 'scroll_up_header' ), 'The obsolete scroll-up selector must not be rendered.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_transition]"' ), 'Collapsed transition options must render below the collapsed composer.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_speed]"' ), 'Collapsed transition speed must render below the collapsed composer.' );
kidia_collapsed_header_assert( false === strpos( $markup, 'collapse_preset' ), 'Collapsed presets must be removed.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'smooth_compact' ), 'The smooth compact Search + Cart behavior must be available as a transition.' );
kidia_collapsed_header_assert( false === strpos( $markup, 'Collapsed header behavior and appearance' ), 'The redundant collapsed-header explanation block must be removed.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'data-chrome-copy' ) && false !== strpos( $markup, 'data-chrome-paste' ), 'Every fixed header card must expose Copy and Paste actions.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'kidia-page-field--image' ) && false !== strpos( $markup, 'kidia-page-media-preview' ), 'The logo image field must expose the shared working media-picker wrapper and preview.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'kidia-page-media-clear' ), 'The logo image field must allow switching back to the configured text logo.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][logo_text]"' ), 'The logo section must expose a text fallback.' );
kidia_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][logo_text_color]"' ), 'The logo section must expose a text color.' );

$chrome_layout = $store->get_layout( 'product' );
$chrome_part   = 'footer';
$chrome_page   = 'product';
ob_start();
require dirname( __DIR__ ) . '/admin/pages/fixed-chrome-card.php';
$footer_markup = (string) ob_get_clean();
kidia_collapsed_header_assert( 1 === substr_count( $footer_markup, '<h3>Footer Icons</h3>' ), 'Footer icon controls must be grouped in one Footer Icons section.' );
$share_section_start = strpos( $footer_markup, 'data-item-section="share"' );
$share_section_end   = false === $share_section_start ? false : strpos( $footer_markup, '</section>', $share_section_start );
$share_section       = false === $share_section_start || false === $share_section_end ? '' : substr( $footer_markup, $share_section_start, $share_section_end - $share_section_start );
kidia_collapsed_header_assert( false !== strpos( $share_section, 'share_icon_variant' ), 'Share icon shapes must render inside Share Settings.' );
kidia_collapsed_header_assert( false !== strpos( $footer_markup, 'name="layout[footer][settings][button_width_percent]"' ), 'Add to bag settings must expose button width.' );
kidia_collapsed_header_assert( false !== strpos( $footer_markup, 'name="layout[footer][settings][button_height]"' ), 'Add to bag settings must expose button height.' );
kidia_collapsed_header_assert( false !== strpos( $footer_markup, 'name="layout[footer][settings][button_style]"' ) && false !== strpos( $footer_markup, 'name="layout[footer][settings][button_shape]"' ), 'Add to bag settings must expose button style and shape.' );

$category_template = (string) file_get_contents( dirname( __DIR__ ) . '/admin/pages/category-builder.php' );
kidia_collapsed_header_assert( false !== strpos( $category_template, 'kidia-category-visibility kidia-page-master-toggle' ), 'Category and subcategory visibility must use the shared On/Off toggle.' );
kidia_collapsed_header_assert( false !== strpos( $category_template, '<span class="kidia-toggle-state"></span>' ), 'Every category visibility control must display On or Off instead of Show.' );

$admin_theme = (string) file_get_contents( dirname( __DIR__ ) . '/admin/assets/admin-theme.css' );
kidia_collapsed_header_assert( false !== strpos( $admin_theme, '--kidia-admin-button-radius: 10px' ), 'CMS buttons must keep square or rectangular proportions with lightly rounded corners.' );
$chrome_template = (string) file_get_contents( dirname( __DIR__ ) . '/admin/pages/fixed-chrome-card.php' );
kidia_collapsed_header_assert( false !== strpos( $chrome_template, 'kidia-chrome-setting--section-layout' ), 'Header and Footer must render their own Section Layout Settings panel.' );
kidia_collapsed_header_assert( false !== strpos( $chrome_template, "array( 'margin_top', 'margin_bottom' )" ) && false !== strpos( $chrome_template, "array( 'space_up', 'space_down' )" ), 'Header and Footer must stack Merge and Space controls in the requested columns.' );
$admin_controller = (string) file_get_contents( dirname( __DIR__ ) . '/admin/class-kidia-mobile-cms-admin.php' );
kidia_collapsed_header_assert( false !== strpos( $admin_controller, 'admin/assets/admin-theme.css' ), 'The shared rounded button theme must load on every Kidia CMS page.' );

$off = $store->save_layout( 'home', array(
	'header' => array( 'enabled' => '1', 'settings' => array( 'collapse_on_scroll' => '0' ) ),
	'footer' => array( 'enabled' => '1' ),
) );
kidia_collapsed_header_assert( false === $off['header']['settings']['collapse_on_scroll'], 'Turning the collapsed header Off must save.' );

$on = $store->save_layout( 'home', array(
	'header' => array( 'enabled' => '1', 'settings' => array( 'collapse_on_scroll' => '1', 'collapse_transition' => 'smooth_compact', 'collapse_speed' => 'slow', 'logo_url' => '', 'logo_text' => 'KIDIACO', 'logo_text_color' => '#2F806E' ) ),
	'footer' => array( 'enabled' => '1' ),
) );
kidia_collapsed_header_assert( true === $on['header']['settings']['collapse_on_scroll'], 'Turning the collapsed header On must save.' );
kidia_collapsed_header_assert( 'slow' === $on['header']['settings']['collapse_speed'], 'The collapsed transition speed must save.' );
kidia_collapsed_header_assert( 'smooth_compact' === $on['header']['settings']['collapse_transition'], 'The smooth compact transition must save.' );
kidia_collapsed_header_assert( true === $store->get_layout( 'home' )['header']['settings']['collapse_on_scroll'], 'The saved On state must survive reload.' );
kidia_collapsed_header_assert( 'KIDIACO' === $store->get_layout( 'home' )['header']['settings']['logo_text'], 'Custom logo text must survive save and reload.' );
kidia_collapsed_header_assert( '' === $store->get_layout( 'home' )['header']['settings']['logo_url'], 'Using logo text must keep the image cleared after reload.' );

fwrite( STDOUT, "Collapsed-header editor placement, toggle and save passed.\n" );
