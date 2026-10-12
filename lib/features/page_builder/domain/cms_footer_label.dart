/// Translate legacy defaults while preserving a merchant's custom label.
String cmsFooterLabel(String configured, String fallback, Iterable<String> defaults) {
  final value = configured.trim();
  if (value.isEmpty || defaults.any((label) => label.toLowerCase() == value.toLowerCase())) {
    return fallback;
  }
  return value;
}
