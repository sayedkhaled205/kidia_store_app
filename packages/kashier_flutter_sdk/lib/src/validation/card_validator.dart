import '../models/kashier_card.dart';

/// Pure Dart card validation utilities.
///
/// No Flutter imports — reusable across SDKs.
class CardValidator {
  CardValidator._();

  /// Validates a card number using the Luhn algorithm.
  static bool luhnCheck(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;

    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  /// Detects the card brand from the card number prefix.
  static KashierCardBrand detectBrand(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return KashierCardBrand.unknown;

    // Visa: starts with 4
    if (digits.startsWith('4')) return KashierCardBrand.visa;

    // Mastercard: 51-55 or 2221-2720
    if (digits.length >= 2) {
      final first2 = int.tryParse(digits.substring(0, 2)) ?? 0;
      if (first2 >= 51 && first2 <= 55) return KashierCardBrand.mastercard;
    }
    if (digits.length >= 4) {
      final first4 = int.tryParse(digits.substring(0, 4)) ?? 0;
      if (first4 >= 2221 && first4 <= 2720) return KashierCardBrand.mastercard;
    }

    // Meeza: starts with 6
    // if (digits.startsWith('6')) return KashierCardBrand.meeza;
    if (digits.length >= 6) {
      final bin = int.tryParse(digits.substring(0, 6)) ?? 0;
      if (bin >= 507803 && bin <= 507960) return KashierCardBrand.meeza;
    }
    return KashierCardBrand.unknown;
  }

  /// Validates a card number: 16 digits + Luhn check.
  static bool validateCardNumber(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return digits.length == 16 && luhnCheck(digits);
  }

  /// Validates that the expiry date is not in the past.
  ///
  /// [mm] — month as 1-2 digit string (e.g., "1" or "01").
  /// [yy] — year as 2-digit string (e.g., "26").
  static bool validateExpiry(String mm, String yy) {
    final month = int.tryParse(mm);
    final year = int.tryParse(yy);
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;

    final now = DateTime.now();
    final fullYear = 2000 + year;
    if (fullYear < now.year) return false;
    if (fullYear == now.year && month < now.month) return false;
    return true;
  }

  /// Validates a CVV: 3 digits (4 for Amex, but we don't support Amex).
  static bool validateCvv(String cvv, KashierCardBrand brand) {
    final digits = cvv.replaceAll(RegExp(r'\D'), '');
    return digits.length == 3;
  }

  /// Validates name on card: letters and spaces, 2-50 characters.
  static bool validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 50) return false;
    return RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed);
  }

  /// Formats a card number with spaces every 4 digits.
  static String formatCardNumber(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
