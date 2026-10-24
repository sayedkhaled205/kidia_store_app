/// Card brand detected from the card number.
enum KashierCardBrand {
  visa,
  mastercard,
  meeza,
  unknown,
}

/// A saved card returned by the Kashier API.
class KashierCard {
  final String maskedNumber;
  final String cardToken;
  final String? nameOnCard;
  final String? expiryMonth;
  final String? expiryYear;
  final KashierCardBrand brand;

  const KashierCard({
    required this.maskedNumber,
    required this.cardToken,
    this.nameOnCard,
    this.expiryMonth,
    this.expiryYear,
    required this.brand,
  });

  /// Parses a saved card from the backend payload.
  ///
  /// Real shape from `/v3/cards/customer`:
  /// ```json
  /// {
  ///   "number": "4573********7118",
  ///   "nameOnCard": "wageeh",
  ///   "cardToken": "fe31...",
  ///   "expiry": { "month": "10", "year": "24" },
  ///   "type": "card_on_file"
  /// }
  /// ```
  /// The backend does not include a brand — we infer it from the masked
  /// number's BIN prefix (the first 6 digits are always unmasked).
  factory KashierCard.fromJson(Map<String, dynamic> json) {
    final number = json['number'] as String? ?? '';
    final expiry = json['expiry'] as Map<String, dynamic>?;

    return KashierCard(
      maskedNumber: number,
      cardToken: json['cardToken'] as String? ?? '',
      nameOnCard: json['nameOnCard'] as String?,
      expiryMonth: expiry?['month'] as String?,
      expiryYear: expiry?['year'] as String?,
      brand: _brandFromBin(number),
    );
  }

  /// Last 4 digits of the card number for display.
  String get last4 {
    if (maskedNumber.length >= 4) {
      return maskedNumber.substring(maskedNumber.length - 4);
    }
    return maskedNumber;
  }

  /// Infers the card brand from the first 6 digits of a (possibly masked)
  /// card number. Mirrors [CardValidator.detectBrand] — duplicated here to
  /// avoid a circular import from the validation layer.
  static KashierCardBrand _brandFromBin(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return KashierCardBrand.unknown;

    if (digits.startsWith('4')) return KashierCardBrand.visa;

    if (digits.length >= 2) {
      final first2 = int.tryParse(digits.substring(0, 2)) ?? 0;
      if (first2 >= 51 && first2 <= 55) return KashierCardBrand.mastercard;
    }
    if (digits.length >= 4) {
      final first4 = int.tryParse(digits.substring(0, 4)) ?? 0;
      if (first4 >= 2221 && first4 <= 2720) return KashierCardBrand.mastercard;
    }

    if (digits.startsWith('6')) return KashierCardBrand.meeza;

    return KashierCardBrand.unknown;
  }
}

/// Internal model for new card input (not exported to merchants).
class KashierCardInput {
  final String cardNumber;
  final String nameOnCard;
  final String expiryMonth;
  final String expiryYear;
  final String cvv;
  final bool saveCard;

  const KashierCardInput({
    required this.cardNumber,
    required this.nameOnCard,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cvv,
    this.saveCard = false,
  });
}
