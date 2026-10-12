/// Builder selector keys resolve to fonts bundled with the application.
String? builderFontFamily(String key) => switch (key) {
  'poppins' => 'Poppins',
  'roboto' => 'Roboto',
  'noto_sans_arabic' => 'Noto Sans Arabic',
  'serif' => 'Noto Serif',
  'monospace' => 'Roboto Mono',
  _ => null,
};
