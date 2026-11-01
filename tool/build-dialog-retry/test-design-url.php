<?php
// Run against the live class before staging (red), then the staged class (green).
require $argv[1];
$validator = new ReflectionMethod(App\Services\NativeBuildRouting::class, 'publicDesign');
$checks = 0;
function validateDesign(mixed $value, bool $allowed): void {
    global $validator, $checks;
    try { $validator->invoke(null, $value); $actual = true; }
    catch (RuntimeException $error) { $actual = false; }
    if ($actual !== $allowed) throw new RuntimeException('Unexpected validation result at case '.($checks + 1));
    $checks++;
}
foreach ([
    'https://cdn.example.test/uploads/2026/ملابس-أطفال.jpg',
    'https://cdn.example.test/商品/😀.png',
    'https://cdn.example.test/a%20b.jpg',
    'https://cdn.example.test/image.jpg?label=أطفال',
    'https://cdn.example.test/image.jpg',
] as $url) validateDesign(['image_url' => $url], true);
foreach ([
    'http://cdn.example.test/ملابس.jpg',
    'https://user:pass@cdn.example.test/ملابس.jpg',
    'https:///ملابس.jpg',
    'https://bad host.test/ملابس.jpg',
    'https://مثال.test/image.jpg',
    "https://cdn.example.test/bad\xFF.jpg",
    'https://cdn.example.test/a b.jpg',
    'javascript:alert(1)',
    'data:image/png;base64,abc',
    'https://cdn.example.test/ملابس.jpg?token=fixture',
    'https://cdn.example.test/ملابس.jpg?%74oken=fixture',
    'https://cdn.example.test/ملابس.jpg?customer_id=1',
    'https://cdn.example.test/ملابس.jpg?api_key=fixture',
    "https://cdn.example.test/ملابس\n.jpg",
] as $url) validateDesign(['image_url' => $url], false);
validateDesign(['access_token' => 'fixture'], false);
validateDesign(['customer_email' => 'fixture@example.invalid'], false);
validateDesign(['settings_json' => '{"token":"fixture"}'], false);
validateDesign(['label' => 'أهلاً بكم'], true);
echo json_encode(['passed' => $checks]).PHP_EOL;
