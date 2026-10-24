class SavedCheckoutAddress92 {
  const SavedCheckoutAddress92({
    required this.id,
    required this.label,
    required this.values,
  });
  final String id;
  final String label;
  final Map<String, String> values;

  static List<SavedCheckoutAddress92> parse(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .take(30)
        .where((row) => row['id'] is String && row['values'] is Map)
        .map((row) {
          final values = <String, String>{};
          for (final entry in (row['values'] as Map).entries) {
            if (entry.key is String && entry.value is String) {
              values[entry.key as String] = entry.value as String;
            }
          }
          return SavedCheckoutAddress92(
            id: row['id'] as String,
            label: row['label'] is String ? row['label'] as String : '',
            values: Map.unmodifiable(values),
          );
        })
        .where((row) => row.values['address_1']?.isNotEmpty == true)
        .toList(growable: false);
  }
}
