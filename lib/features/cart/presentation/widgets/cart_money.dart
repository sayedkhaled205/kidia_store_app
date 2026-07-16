import 'package:kidia_store_app/features/cart/domain/entities/cart_totals.dart';

String formatCartMoney(String minorValue, CartCurrency currency) {
  final BigInt? parsed = BigInt.tryParse(minorValue.trim());
  if (parsed == null) {
    return minorValue;
  }

  final bool negative = parsed.isNegative;
  final String digits = parsed.abs().toString();
  final int decimals = currency.minorUnit.clamp(0, 18);
  final String padded = digits.padLeft(decimals + 1, '0');
  final int split = padded.length - decimals;
  final String integer = _groupDigits(
    padded.substring(0, split),
    currency.thousandSeparator,
  );
  final String fraction = decimals == 0
      ? ''
      : '${currency.decimalSeparator}${padded.substring(split)}';

  String prefix = _decodeCurrencyText(currency.prefix);
  final String suffix = _decodeCurrencyText(currency.suffix);
  if (prefix.isEmpty && suffix.isEmpty) {
    prefix = currency.symbol.isNotEmpty ? currency.symbol : '${currency.code} ';
  }

  return '${negative ? '-' : ''}$prefix$integer$fraction$suffix';
}

bool cartMinorIsPositive(String value) {
  return (BigInt.tryParse(value.trim()) ?? BigInt.zero) > BigInt.zero;
}

String _groupDigits(String digits, String separator) {
  if (separator.isEmpty || digits.length < 4) {
    return digits;
  }

  final StringBuffer result = StringBuffer();
  final int leading = digits.length % 3;
  int index = 0;
  if (leading > 0) {
    result.write(digits.substring(0, leading));
    index = leading;
  }
  while (index < digits.length) {
    if (result.isNotEmpty) {
      result.write(separator);
    }
    result.write(digits.substring(index, index + 3));
    index += 3;
  }
  return result.toString();
}

String _decodeCurrencyText(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#160;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (Match match) {
        final int? codePoint = int.tryParse(match.group(1) ?? '');
        if (codePoint == null ||
            codePoint < 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
          return match.group(0) ?? '';
        }
        return String.fromCharCode(codePoint);
      });
}
