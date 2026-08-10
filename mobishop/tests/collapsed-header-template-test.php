<?php
/** Collapsed-header editor placement, toggle and persistence contract test. */
declare( strict_types=1 );

define( 'ABSPATH', __DIR__ );

$GLOBALS['mobishop_collapsed_header_options'] = array();

function __( string $value, string $domain = '' ): string { unset( $domain ); return $value; }
function sanitize_key( $value ): string { return preg_replace( '/[^a-z0-9_\-]/', '', strtolower( (string) $value ) ) ?: ''; }
function sanitize_text_field( $value ): string { return trim( strip_tags( (string) $value ) ); }
function sanitize_hex_color( $value ) { return preg_match( '/^#[0-9a-f]{6}$/i', (string) $value ) ? (string) $value : null; }
function esc_url_raw( $value ): string { return filter_var( (string) $value, FILTER_VALIDATE_URL ) ? (string) $value : ''; }
function wp_json_encode( $value ): string { return json_encode( $value, JSON_UNESCAPED_SLASHES ); }
function get_option( string $name, $default = false ) { return $GLOBALS['mobishop_collapsed_header_options'][ $name ] ?? $default; }
function update_option( string $name, $value, bool $autoload = false ): bool { unset( $autoload ); $GLOBALS['mobishop_collapsed_header_options'][ $name ] = $value; return true; }
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
function mobishop_collapsed_header_assert( bool $condition, string $message ): void {
	if ( ! $condition ) { throw new RuntimeException( $message ); }
}

require dirname( __DIR__ ) . '/includes/class-mobishop-page-layout-store.php';

$store          = new MobiShop_Page_Layout_Store();
$chrome_layout  = $store->get_layout( 'home' );
$chrome_part    = 'header';
$chrome_page    = 'home';
$header_fields  = MobiShop_Page_Layout_Store::header_fields();
$footer_fields  = MobiShop_Page_Layout_Store::footer_fields();

ob_start();
require dirname( __DIR__ ) . '/admin/pages/fixed-chrome-card.php';
$markup = (string) ob_get_clean();

$regular_position   = strpos( $markup, 'Regular header' );
$collapsed_position = strpos( $markup, 'data-variant="collapsed"' );
$settings_position  = strpos( $markup, 'mobishop-collapsed-header-settings' );
$toggle_name        = 'name="layout[header][settings][collapse_on_scroll]"';

mobishop_collapsed_header_assert( false !== $regular_position, 'The regular header composer must be labelled.' );
mobishop_collapsed_header_assert( false !== $collapsed_position && $collapsed_position > $regular_position, 'The collapsed header composer must sit directly after the regular header.' );
mobishop_collapsed_header_assert( false !== $settings_position && $settings_position > $collapsed_position, 'Collapsed appearance settings must follow the collapsed composer.' );
mobishop_collapsed_header_assert( 2 === substr_count( $markup, $toggle_name ), 'The collapsed On/Off control must submit both its unchecked and checked values.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'mobishop-toggle-state' ), 'The collapsed control must display the shared On/Off state.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'mobishop-collapsed-header-settings' ), 'Collapsed appearance settings must remain a separate hideable section below the persistent composer.' );
mobishop_collapsed_header_assert( false === strpos( $markup, 'Preview collapsed header' ), 'The old preview-only control must not be rendered.' );
mobishop_collapsed_header_assert( false === strpos( $markup, 'scroll_up_header' ), 'The obsolete scroll-up selector must not be rendered.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_transition]"' ), 'Collapsed transition options must render below the collapsed composer.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][collapse_speed]"' ), 'Collapsed transition speed must render below the collapsed composer.' );
mobishop_collapsed_header_assert( false === strpos( $markup, 'collapse_preset' ), 'Collapsed presets must be removed.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'smooth_compact' ), 'The smooth layout behavior must remain available as a transition.' );
mobishop_collapsed_header_assert( false === strpos( $markup, 'mobishop-compact-search-transition' ), 'No transition may replace the draggable collapsed-header Rows editor with a required Search row.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'compact_layout_json' ) && false !== strpos( $markup, 'mobishop-chrome-composer--collapsed' ), 'The collapsed header must persist its own independent row layout.' );
mobishop_collapsed_header_assert( false === strpos( $markup, 'Collapsed header behavior and appearance' ), 'The redundant collapsed-header explanation block must be removed.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'data-chrome-copy' ) && false !== strpos( $markup, 'data-chrome-paste' ), 'Every fixed header card must expose Copy and Paste actions.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'mobishop-page-field--image' ) && false !== strpos( $markup, 'mobishop-page-media-preview' ), 'The logo image field must expose the shared working media-picker wrapper and preview.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'mobishop-page-media-clear' ), 'The logo image field must allow switching back to the configured text logo.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][logo_text]"' ), 'The logo section must expose a text fallback.' );
mobishop_collapsed_header_assert( false !== strpos( $markup, 'name="layout[header][settings][logo_text_color]"' ), 'The logo section must expose a text color.' );

$chrome_layout = $store->get_layout( 'product' );
$chrome_part   = 'footer';
$chrome_page   = 'product';
ob_start();
require dirname( __DIR__ ) . '/admin/pages/fixed-chrome-card.php';
$footer_markup = (string) ob_get_clean();
mobishop_collapsed_header_assert( 1 === substr_count( $footer_markup, '<h3>Footer Icons</h3>' ), 'Footer icon controls must be grouped in one Footer Icons section.' );
$share_section_start = strpos( $footer_markup, 'data-item-section="share"' );
$share_section_end   = false === $share_section_start ? false : strpos( $footer_markup, '</section>', $share_section_start );
$share_section       = false === $share_section_start || false === $share_section_end ? '' : substr( $footer_markup, $share_section_start, $share_section_end - $share_section_start );
mobishop_collapsed_header_assert( false !== strpos( $share_section, 'share_icon_variant' ), 'Share icon shapes must render inside Share Settings.' );
mobishop_collapsed_header_assert( false !== strpos( $footer_markup, 'name="layout[footer][settings][button_width_percent]"' ), 'Add to bag settings must expose button width.' );
mobishop_collapsed_header_assert( false !== strpos( $footer_markup, 'name="layout[footer][settings][button_height]"' ), 'Add to bag settings must expose button height.' );
mobishop_collapsed_header_assert( false !== strpos( $footer_markup, 'name="layout[footer][settings][button_style]"' ) && false !== strpos( $footer_markup, 'name="layout[footer][settings][button_shape]"' ), 'Add to bag settings must expose button style and shape.' );

$category_template = (string) file_get_contents( dirname( __DIR__ ) . '/admin/pages/category-builder.php' );
mobishop_collapsed_header_assert( false !== strpos( $category_template, 'mobishop-category-visibility mobishop-page-master-toggle' ), 'Category and subcategory visibility must use the shared On/Off toggle.' );
mobishop_collapsed_header_assert( false !== strpos( $category_template, '<span class="mobishop-toggle-state"></span>' ), 'Every category visibility control must display On or Off instead of Show.' );

$admin_theme = (string) file_get_contents( dirname( __DIR__ ) . '/admin/assets/admin-theme.css' );
mobishop_collapsed_header_assert( false !== strpos( $admin_theme, '--mobishop-admin-button-radius: 10px' ), 'CMS buttons must keep square or rectangular proportions with lightly rounded corners.' );
$chrome_template = (string) file_get_contents( dirname( __DIR__ ) . '/admin/pages/fixed-chrome-card.php' );
mobishop_collapsed_header_assert( false !== strpos( $chrome_template, 'mobishop-chrome-setting--section-layout' ), 'Header and Footer must render their own Section Layout Settings panel.' );
mobishop_collapsed_header_assert( false !== strpos( $chrome_template, "array( 'margin_top', 'margin_bottom' )" ) && false !== strpos( $chrome_template, "array( 'space_up', 'space_down' )" ), 'Header and Footer must stack Merge and Space controls in the requested columns.' );
$admin_controller = (string) file_get_contents( dirname( __DIR__ ) . '/admin/class-mobishop-admin.php' );
mobishop_collapsed_header_assert( false !== strpos( $admin_controller, 'admin/assets/admin-theme.css' ), 'The shared rounded button theme must load on every MobiShop CMS page.' );

$off = $store->save_layout( 'home', array(
	'header' => array( 'enabled' => '1', 'settings' => array( 'collapse_on_scroll' => '0' ) ),
	'footer' => array( 'enabled' => '1' ),
) );
mobishop_collapsed_header_assert( false === $off['header']['settings']['collapse_on_scroll'], 'Turning the collapsed header Off must save.' );

$on = $store->save_layout( 'home', array(
	'header' => array( 'enabled' => '1', 'settings' => array( 'collapse_on_scroll' => '1', 'collapse_transition' => 'smooth_compact', 'compact_search_width_percent' => '73', 'collapse_speed' => 'slow', 'logo_url' => '', 'logo_text' => 'MOBISHOPCO', 'logo_text_color' => '#2F806E' ) ),
	'footer' => array( 'enabled' => '1' ),
) );
mobishop_collapsed_header_assert( true === $on['header']['settings']['collapse_on_scroll'], 'Turning the collapsed header On must save.' );
mobishop_collapsed_header_assert( 'slow' === $on['header']['settings']['collapse_speed'], 'The collapsed transition speed must save.' );
mobishop_collapsed_header_assert( 'smooth_compact' === $on['header']['settings']['collapse_transition'], 'The smooth compact transition must save.' );
mobishop_collapsed_header_assert( 73.0 === $on['header']['settings']['compact_search_width_percent'], 'The transition Search width may save below 100 percent.' );
mobishop_collapsed_header_assert( true === $store->get_layout( 'home' )['header']['settings']['collapse_on_scroll'], 'The saved On state must survive reload.' );
mobishop_collapsed_header_assert( 'MOBISHOPCO' === $store->get_layout( 'home' )['header']['settings']['logo_text'], 'Custom logo text must survive save and reload.' );
mobishop_collapsed_header_assert( '' === $store->get_layout( 'home' )['header']['settings']['logo_url'], 'Using logo text must keep the image cleared after reload.' );

fwrite( STDOUT, "Collapsed-header editor placement, toggle and save passed.\n" );
