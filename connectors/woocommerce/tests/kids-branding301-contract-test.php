<?php
/** Offline wizard contract: Kids defaults, identity, and other-theme isolation. */
declare(strict_types=1);
define('ABSPATH', __DIR__);
function __($value, $domain = '') { return $value; }
function wp_json_encode($value) { return json_encode($value); }
function update_option(...$arguments) { throw new RuntimeException('Preview defaults must not write merchant settings.'); }
class MobiShop_Page_Layout_Store {
    public function default_layout(string $page): array {
        return [
            'page' => $page, 'settings' => [], 'elements' => [],
            'header' => ['settings' => ['logo_width' => 118, 'logo_height' => 38, 'logo_fit' => 'contain']],
            'footer' => ['settings' => []],
        ];
    }
}
$source = getenv('MOBISHOP_CONNECTOR_TEST_ROOT') ?: dirname(__DIR__) . '/source';
require $source . '/includes/class-mobishop-setup-wizard.php';
$wizard = (new ReflectionClass(MobiShop_Setup_Wizard::class))->newInstanceWithoutConstructor();
$splash = new ReflectionMethod($wizard, 'build_splash_settings');
$page = new ReflectionMethod($wizard, 'build_page_layout');
function same301($actual, $expected, $message): void {
    if ($actual !== $expected) { throw new RuntimeException($message); }
}
$logo = 'https://store.example/uploads/wide-brand.png';
$base = ['surface' => '#FFFFFF', 'ink' => '#253A46', 'soft' => '#F0F5F2', 'header_style' => 'standard', 'radius' => 0, 'search_style' => 'bar', 'card_style' => 'no_shadow'];
$kids = $base + ['layout_profile' => 'kids_baby'];
$result = $splash->invoke($wizard, $kids, '#EEDDCC', '#221144', 'My family store', $logo);
same301($result, [
    'enabled' => true, 'image_url' => $logo,
    'background_color' => '#FFFFFF', 'background_color_end' => '#FFFFFF',
    // Preserve the accepted shared-theme splash sizing.
    'duration_ms' => 1300, 'image_width' => 264, 'image_height' => 108,
    'image_fit' => 'contain', 'image_shape' => 'none',
    'show_store_name' => false, 'store_name' => 'My family store',
    'text_color' => '#253A46', 'show_loader' => true, 'loader_color' => '#4EA999',
], 'Kids splash is not the compact neutral composition with the actual store identity.');
$header = $page->invoke($wizard, 'home', $kids, '#EEDDCC', '#221144', 'My family store', $logo)['header']['settings'];
same301([$header['logo_width'], $header['logo_height'], $header['logo_fit']], [90, 30.6, 'contain'], 'Kids logo frame is stretched or cropped by default.');
same301($header['logo_url'], $logo, 'Kids header replaced the merchant logo.');
same301([$header['row_1_height'], $header['row_gap']], [52, 2], 'Compact header geometry changed.');
foreach (['fashion', 'beauty', 'electronics', 'home_living', 'family_pop', 'unknown'] as $profile) {
    $theme = $base + ['layout_profile' => $profile];
    foreach ([['#101010', '#202020', '#FFFFFF'], ['#FFFFFF', '#EEEEEE', '#111111']] as [$primary, $secondary, $foreground]) {
        $result = $splash->invoke($wizard, $theme, $primary, $secondary, 'Other store', $logo);
        same301($result, [
            'enabled' => true, 'image_url' => $logo,
            'background_color' => $primary, 'background_color_end' => $secondary,
            'duration_ms' => 1800, 'image_width' => 140, 'image_height' => 140,
            'image_fit' => 'contain', 'image_shape' => 'none',
            'show_store_name' => true, 'store_name' => 'Other store',
            'text_color' => $foreground, 'show_loader' => true, 'loader_color' => $foreground,
        ], 'Kids branding leaked into another profile: ' . $profile);
    }
}
echo "KIDS_BRANDING301_CONTRACTS_PASSED\n";
