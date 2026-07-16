class CatalogMoney {
  const CatalogMoney({
    required this.currencyCode,
    required this.currencyMinorUnit,
    required this.priceMinor,
    this.currencySymbol = '',
    this.currencyPrefix = '',
    this.currencySuffix = '',
    this.regularPriceMinor = '',
    this.salePriceMinor = '',
    this.priceRange,
  });

  final String currencyCode;
  final String currencySymbol;
  final String currencyPrefix;
  final String currencySuffix;
  final int currencyMinorUnit;

  /// Values are intentionally kept as strings because the Store API returns
  /// prices in the smallest currency unit and they can exceed 64-bit integers.
  final String priceMinor;
  final String regularPriceMinor;
  final String salePriceMinor;
  final CatalogPriceRange? priceRange;

  bool get hasPrice => priceMinor.isNotEmpty;
  bool get isDiscounted =>
      salePriceMinor.isNotEmpty &&
      regularPriceMinor.isNotEmpty &&
      _compareMinor(salePriceMinor, regularPriceMinor) < 0;

  String decimalAmount(String minorAmount) {
    final String digits = _normalizedMinor(minorAmount);
    if (digits.isEmpty) {
      return '';
    }

    final bool isNegative = digits.startsWith('-');
    final String absolute = isNegative ? digits.substring(1) : digits;
    final int scale = currencyMinorUnit < 0 ? 0 : currencyMinorUnit;

    if (scale == 0) {
      return '${isNegative ? '-' : ''}$absolute';
    }

    final String padded = absolute.padLeft(scale + 1, '0');
    final int splitAt = padded.length - scale;
    return '${isNegative ? '-' : ''}${padded.substring(0, splitAt)}.${padded.substring(splitAt)}';
  }

  String displayAmount(String minorAmount) {
    final String amount = decimalAmount(minorAmount);
    if (amount.isEmpty) {
      return '';
    }

    if (currencyPrefix.isEmpty &&
        currencySuffix.isEmpty &&
        currencySymbol.isNotEmpty) {
      return '$currencySymbol$amount';
    }

    return '$currencyPrefix$amount$currencySuffix';
  }

  static int _compareMinor(String left, String right) {
    final BigInt? leftValue = BigInt.tryParse(_normalizedMinor(left));
    final BigInt? rightValue = BigInt.tryParse(_normalizedMinor(right));
    if (leftValue == null || rightValue == null) {
      return 0;
    }
    return leftValue.compareTo(rightValue);
  }

  static String _normalizedMinor(String source) {
    final String trimmed = source.trim();
    return RegExp(r'^-?\d+$').hasMatch(trimmed) ? trimmed : '';
  }
}

class CatalogPriceRange {
  const CatalogPriceRange({
    required this.minimumMinor,
    required this.maximumMinor,
  });

  final String minimumMinor;
  final String maximumMinor;
}
