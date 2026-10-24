/// Represents the result of a successful Kashier payment.
class KashierPaymentResult {
  /// The session ID for this payment.
  final String sessionId;

  /// The payment status (e.g., "SUCCESS", "CAPTURED").
  final String status;

  /// The Kashier order ID (systemOrderId).
  final String? orderId;

  /// The merchant order reference.
  final String? orderReference;

  /// The transaction ID (e.g., "TX-35524544753").
  final String? transactionId;

  /// The authorization number from the issuer.
  final String? authorizationNumber;

  /// The amount that was charged.
  final num? amount;

  /// The currency of the charge.
  final String? currency;

  /// Card details used for the payment.
  final KashierCardInfo? card;

  /// Localized success message in English.
  final String? message;

  /// Localized success message in Arabic.
  final String? messageAr;

  /// The full response data from the API.
  final Map<String, dynamic>? transactionData;

  const KashierPaymentResult({
    required this.sessionId,
    required this.status,
    this.orderId,
    this.orderReference,
    this.transactionId,
    this.authorizationNumber,
    this.amount,
    this.currency,
    this.card,
    this.message,
    this.messageAr,
    this.transactionData,
  });

  /// Creates a [KashierPaymentResult] from the /v3/orders success response.
  factory KashierPaymentResult.fromApiResponse(
    Map<String, dynamic> body, {
    required String sessionId,
  }) {
    final response = body['response'] as Map<String, dynamic>? ?? {};
    final messages = body['messages'] as Map<String, dynamic>?;
    final paymentMethod = response['paymentMethod'] as Map<String, dynamic>?;
    final cardData = paymentMethod?['card'] as Map<String, dynamic>?;
    final order = response['order'] as Map<String, dynamic>?;

    KashierCardInfo? card;
    if (cardData != null) {
      card = KashierCardInfo(
        brand: cardData['cardBrand'] as String?,
        maskedNumber: cardData['number'] as String?,
        wallet: cardData['digitalWallet'] as String?,
      );
    }

    return KashierPaymentResult(
      sessionId: sessionId,
      status: response['status'] as String? ??
          body['status'] as String? ??
          'SUCCESS',
      orderId:
          response['orderId'] as String? ?? order?['systemOrderId'] as String?,
      orderReference: response['orderReference'] as String? ??
          order?['reference'] as String?,
      transactionId: response['transactionId'] as String?,
      authorizationNumber: response['authorizationNumber'] as String?,
      amount: response['amount'] as num?,
      currency: response['currency'] as String?,
      card: card,
      message: messages?['en'] as String?,
      messageAr: messages?['ar'] as String?,
      transactionData: body,
    );
  }

  /// Creates a [KashierPaymentResult] from a simple JSON map (for tests).
  factory KashierPaymentResult.fromJson(Map<String, dynamic> json) {
    return KashierPaymentResult(
      sessionId: json['sessionId'] as String,
      status: json['status'] as String,
      transactionData: json['transactionData'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() =>
      'KashierPaymentResult(sessionId: $sessionId, status: $status)';
}

/// Display-safe card details returned with a successful payment.
///
/// Describes the instrument used to pay: the card [brand], the
/// [maskedNumber] as returned by the gateway (e.g. `541674******7777`),
/// and — when the payment went through a digital wallet — the [wallet]
/// type (e.g. `APPLE_PAY`). It never carries the full card number, CVV,
/// or card token, so it is safe to show in receipts and order summaries.
class KashierCardInfo {
  /// Card brand (e.g., "Mastercard", "Visa").
  final String? brand;

  /// Masked card number (e.g., "541674******7777").
  final String? maskedNumber;

  /// Digital wallet type (e.g., "APPLE_PAY").
  final String? wallet;

  const KashierCardInfo({
    this.brand,
    this.maskedNumber,
    this.wallet,
  });

  @override
  String toString() => 'KashierCardInfo($brand $maskedNumber)';
}
