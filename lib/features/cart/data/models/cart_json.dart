class CartJson {
  const CartJson._();

  static final RegExp _minorUnitsPattern = RegExp(r'^-?\d+$');

  static Map<String, dynamic> object(dynamic value, String field) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<dynamic, dynamic> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    throw FormatException('Cart field "$field" must be an object.');
  }

  static Map<String, dynamic> optionalObject(dynamic value, String field) {
    if (value == null) {
      return <String, dynamic>{};
    }
    return object(value, field);
  }

  static List<dynamic> list(dynamic value, String field) {
    if (value == null) {
      return <dynamic>[];
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    throw FormatException('Cart field "$field" must be an array.');
  }

  static String text(dynamic value, {String fallback = ''}) {
    return value == null ? fallback : value.toString();
  }

  static int integer(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? nullableInteger(dynamic value) {
    if (value == null) {
      return null;
    }
    return value is int ? value : int.tryParse(value.toString());
  }

  static double decimal(dynamic value, {double fallback = 0}) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  static String minorUnits(
    dynamic value,
    String field, {
    String fallback = '0',
  }) {
    if (value == null || value.toString().isEmpty) {
      return fallback;
    }
    final String minor = value.toString();
    if (!_minorUnitsPattern.hasMatch(minor)) {
      throw FormatException(
        'Cart monetary field "$field" must contain integer minor units.',
      );
    }
    return minor;
  }

  static String httpUrl(dynamic value) {
    final Uri? uri = Uri.tryParse(text(value).trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '';
    }
    return uri.toString();
  }
}
