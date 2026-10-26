<?php
require $argv[1];
$class = new ReflectionClass(App\Services\SavedBuilderNativeDesign::class);
$page = $class->getMethod('castFields');
$home = $class->getMethod('homeSettings');
$schema = json_decode($class->getConstant('FIELD_TYPES_JSON'), true, 64, JSON_THROW_ON_ERROR);
$checks = 0;
foreach (['catalog' => 'product_grid', 'wishlist' => 'wishlist_grid'] as $name => $type) {
    $result = $page->invoke(null, ['card_style' => 'outlined', 'card_outline_color' => '#347A89'], $schema['pages'][$name][$type], $name);
    if ($result['card_outline_color'] !== '#347A89') throw new RuntimeException('Outline dropped');
    $checks++;
    foreach (['invalid', '<script>', ['#ffffff']] as $invalid) {
        $rejected = false;
        try { $page->invoke(null, ['card_outline_color' => $invalid], $schema['pages'][$name][$type], $name); }
        catch (Throwable $error) { $rejected = true; }
        if (!$rejected) throw new RuntimeException('Invalid color accepted');
        $checks++;
    }
}
foreach (['product_grid', 'product_carousel'] as $type) {
    if ($home->invoke(null, $type, ['card_outline_color' => '#dc713a'])['card_outline_color'] !== '#dc713a') throw new RuntimeException('Home outline dropped');
    $checks++;
    $rejected = false;
    try { $home->invoke(null, $type, ['not_a_supported_field' => 'yes']); }
    catch (Throwable $error) { $rejected = true; }
    if (!$rejected) throw new RuntimeException('Unknown field accepted');
    $checks++;
}
echo "$checks outline schema checks passed\n";
