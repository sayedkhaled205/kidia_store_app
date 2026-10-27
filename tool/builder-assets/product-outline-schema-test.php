<?php
require $argv[1];
$class = new ReflectionClass(App\Services\SavedBuilderNativeDesign::class);
$page = $class->getMethod('castFields');
$home = $class->getMethod('homeSettings');
$schema = json_decode($class->getConstant('FIELD_TYPES_JSON'), true, 64, JSON_THROW_ON_ERROR);
$checks = 0;
foreach (['catalog' => 'product_grid', 'wishlist' => 'wishlist_grid', 'product' => 'related_products'] as $name => $type) {
    $result = $page->invoke(null, ['card_style' => 'outlined', 'card_outline_color' => '#347A89'], $schema['pages'][$name][$type], $name);
    if ($result['card_outline_color'] !== '#347A89') throw new RuntimeException('Outline dropped');
    $checks++;
    foreach ([0, 0.5, 2, 6] as $width) {
        $result = $page->invoke(null, ['card_outline_width' => $width], $schema['pages'][$name][$type], $name);
        if ((float) $result['card_outline_width'] !== (float) $width) throw new RuntimeException('Outline width dropped');
        $checks++;
    }
    foreach ([-1, 7, 'invalid', [], INF] as $width) {
        $rejected = false;
        try { $page->invoke(null, ['card_outline_width' => $width], $schema['pages'][$name][$type], $name); }
        catch (Throwable $error) { $rejected = true; }
        if (!$rejected) throw new RuntimeException('Invalid outline width accepted');
        $checks++;
    }
    foreach (['invalid', '<script>', ['#ffffff']] as $invalid) {
        $rejected = false;
        try { $page->invoke(null, ['card_outline_color' => $invalid], $schema['pages'][$name][$type], $name); }
        catch (Throwable $error) { $rejected = true; }
        if (!$rejected) throw new RuntimeException('Invalid color accepted');
        $checks++;
    }
}
foreach (['product_grid', 'product_carousel'] as $type) {
    if ($home->invoke(null, $type, ['card_outline_width' => 2.5])['card_outline_width'] !== 2.5) throw new RuntimeException('Home outline width dropped');
    $checks++;
    if ($home->invoke(null, $type, ['card_outline_color' => '#dc713a'])['card_outline_color'] !== '#dc713a') throw new RuntimeException('Home outline dropped');
    $checks++;
    $rejected = false;
    try { $home->invoke(null, $type, ['not_a_supported_field' => 'yes']); }
    catch (Throwable $error) { $rejected = true; }
    if (!$rejected) throw new RuntimeException('Unknown field accepted');
    $checks++;
}
echo "$checks outline schema checks passed\n";
