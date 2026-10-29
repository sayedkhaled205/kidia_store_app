<?php
require $argv[1];
$class = new ReflectionClass(App\Services\SavedBuilderNativeDesign::class);
$cast = $class->getMethod('castFields');
$fields = json_decode($class->getConstant('FIELD_TYPES_JSON'), true, 64, JSON_THROW_ON_ERROR)['footer'];
foreach (['button', 'wishlist_button'] as $value) {
    if ($cast->invoke(null, ['quick_add_layout' => $value], $fields, 'footer')['quick_add_layout'] !== $value) throw new RuntimeException('Footer choice lost');
}
foreach (['unknown', '', 1, [], '<script>'] as $value) {
    $rejected = false;
    try { $cast->invoke(null, ['quick_add_layout' => $value], $fields, 'footer'); }
    catch (Throwable $error) { $rejected = true; }
    if (!$rejected) throw new RuntimeException('Invalid footer choice accepted');
}
echo "7 quick-add publication schema checks passed\n";
