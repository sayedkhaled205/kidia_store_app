abstract final class CatalogJson {
  const CatalogJson._();

  static Map<String, dynamic>? object(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static List<dynamic> list(dynamic value) {
    return value is List ? value : const <dynamic>[];
  }

  static String string(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static int integer(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(string(value)) ?? fallback;
  }

  static double decimal(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(string(value)) ?? fallback;
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    switch (string(value).toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return fallback;
    }
  }

  static Uri? webUri(dynamic value) {
    final Uri? uri = Uri.tryParse(string(value));
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return uri;
  }

  static String minorAmount(dynamic value) {
    final String source = string(value);
    return RegExp(r'^-?\d+$').hasMatch(source) ? source : '';
  }

  static List<int> positiveIds(dynamic value) {
    final Set<int> ids = <int>{};
    for (final dynamic item in list(value)) {
      final int id = integer(item);
      if (id > 0) {
        ids.add(id);
      }
    }
    return List<int>.unmodifiable(ids);
  }
}
