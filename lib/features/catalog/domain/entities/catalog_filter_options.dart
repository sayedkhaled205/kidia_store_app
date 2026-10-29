/// Keep imported HTML fragments out of customer-facing filter choices.
String catalogFilterLabel(Object? source) {
  var label = '${source ?? ''}'
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
  if (RegExp(r'class\s*=|^/?i\s*/>', caseSensitive: false).hasMatch(label)) {
    return '';
  }
  label = label.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  return label;
}

class CatalogSizeOption {
  const CatalogSizeOption({
    required this.taxonomy,
    required this.term,
    required this.label,
  });
  final String taxonomy, term, label;
  String get key => '$taxonomy|$term';
  @override
  bool operator ==(Object other) =>
      other is CatalogSizeOption && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class CatalogTagOption {
  const CatalogTagOption({required this.id, required this.label});
  final int id;
  final String label;
  @override
  bool operator ==(Object other) => other is CatalogTagOption && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

class CatalogFilterOptions {
  const CatalogFilterOptions({
    this.tags = const [],
    this.sizes = const [],
    this.colors = const [],
  });
  final List<CatalogTagOption> tags;
  final List<CatalogSizeOption> sizes, colors;
  factory CatalogFilterOptions.fromJson(Map<String, dynamic> json) {
    List<CatalogSizeOption> options(String key) => [
      for (final item in json[key] is List ? json[key] : [])
        if (item is Map &&
            '${item['taxonomy'] ?? ''}'.startsWith('pa_') &&
            '${item['term'] ?? ''}'.isNotEmpty)
          CatalogSizeOption(
            taxonomy: '${item['taxonomy']}',
            term: '${item['term']}',
            label: '${item['label'] ?? item['term']}',
          ),
    ];
    return CatalogFilterOptions(
      tags: [
        for (final item in json['tags'] is List ? json['tags'] : [])
          if (item is Map && (int.tryParse('${item['id']}') ?? 0) > 0)
            CatalogTagOption(
              id: int.parse('${item['id']}'),
              label: '${item['label'] ?? ''}',
            ),
      ],
      sizes: options('sizes'),
      colors: options('colors'),
    );
  }
}

/// Optional capability: unsupported platforms never receive WooCommerce tags.
abstract interface class CatalogFilterOptionsSource {
  Future<CatalogFilterOptions> getFilterOptions();
}
