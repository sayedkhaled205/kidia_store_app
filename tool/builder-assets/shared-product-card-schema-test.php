<?php
require $argv[1];
$class = new ReflectionClass(App\Services\SavedBuilderNativeDesign::class);
$cast = $class->getMethod('castFields');
$fields = json_decode($class->getConstant('FIELD_TYPES_JSON'), true, 64, JSON_THROW_ON_ERROR)['pages']['catalog']['product_grid'];
foreach ([true, false, 1, 0, '1', '0'] as $value) {
    $actual = $cast->invoke(null, ['share_style_across_app' => $value], $fields, 'product_grid')['share_style_across_app'];
    if ($actual !== (bool)$value) throw new RuntimeException('Shared appearance choice lost');
}
foreach (['unknown', [], '<script>'] as $value) {
    $rejected = false;
    try { $cast->invoke(null, ['share_style_across_app' => $value], $fields, 'product_grid'); }
    catch (Throwable $error) { $rejected = true; }
    if (!$rejected) throw new RuntimeException('Invalid shared appearance choice accepted');
}
echo "9 shared product card publication checks passed\n";
