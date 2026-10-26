import 'dart:convert';

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
    return distinct(
      raw
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
          .toList(growable: false),
    );
  }

  /// Equivalent optional empty fields and key order do not create another card.
  /// Nonempty contact/company/custom fields remain part of the identity.
  static List<SavedCheckoutAddress92> distinct(
    Iterable<SavedCheckoutAddress92> rows, {
    Map<String, String> defaults = const {},
  }) {
    final ids = <String>{};
    final addresses = <String>{};
    return rows
        .where((row) {
          final values = {...defaults, ...row.values};
          final keys =
              values.keys
                  .where((key) => values[key]!.trim().isNotEmpty)
                  .toList()
                ..sort();
          final identity = jsonEncode({
            for (final key in keys) key: values[key]!.trim(),
          });
          if (ids.contains(row.id) || addresses.contains(identity)) {
            return false;
          }
          ids.add(row.id);
          addresses.add(identity);
          return true;
        })
        .toList(growable: false);
  }
}
