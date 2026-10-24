/// Internal response model for the INITIATE_R2P wallet API call.
///
/// This class is not exported to merchants.
class WalletInitiateResponse {
  /// The order ID assigned by Kashier.
  final String orderId;

  /// The transaction ID (e.g., "TX-35524544764").
  final String transactionId;

  /// Localized success message in English.
  final String messageEn;

  /// Localized success message in Arabic.
  final String messageAr;

  /// The ISOQR payload (stored for future use).
  final String? isoqr;

  /// The validity period from the payload (stored for future use).
  final String? validity;

  const WalletInitiateResponse({
    required this.orderId,
    required this.transactionId,
    required this.messageEn,
    required this.messageAr,
    this.isoqr,
    this.validity,
  });

  /// Creates a [WalletInitiateResponse] from the INITIATE_R2P API response.
  factory WalletInitiateResponse.fromApiResponse(Map<String, dynamic> body) {
    final response = body['response'] as Map<String, dynamic>? ?? {};
    final messages = body['messages'] as Map<String, dynamic>? ?? {};
    final payload = response['payload'] as Map<String, dynamic>?;
    final payloadBody = payload?['body'] as Map<String, dynamic>?;

    return WalletInitiateResponse(
      orderId: response['orderId']?.toString() ?? '',
      transactionId: response['transactionId']?.toString() ?? '',
      messageEn: messages['en'] as String? ?? 'Payment initiated.',
      messageAr: messages['ar'] as String? ?? 'تم بدء الدفع.',
      isoqr: payloadBody?['ISOQR']?.toString(),
      validity: payloadBody?['Validity']?.toString(),
    );
  }
}

/// Internal response model for the RECONCILE wallet API call.
///
/// This class is not exported to merchants.
class WalletReconcileResponse {
  /// The reconcile result: "SUCCESS", "PENDING", or "FAILURE".
  final String result;

  /// The reconcile status (e.g., "CAPTURED", "PENDING", "FAILED").
  final String status;

  /// The transaction ID (available on SUCCESS).
  final String? transactionId;

  /// The order reference (available on SUCCESS).
  final String? orderReference;

  /// Localized message in English.
  final String messageEn;

  /// Localized message in Arabic.
  final String messageAr;

  /// The full response body for constructing KashierPaymentResult.
  final Map<String, dynamic> rawBody;

  const WalletReconcileResponse({
    required this.result,
    required this.status,
    required this.messageEn,
    required this.messageAr,
    required this.rawBody,
    this.transactionId,
    this.orderReference,
  });

  /// Whether this response indicates the payment succeeded.
  bool get isSuccess => result == 'SUCCESS';

  /// Whether this response indicates the payment is still pending.
  bool get isPending => result == 'PENDING';

  /// Whether this response indicates the payment failed.
  bool get isFailure => result == 'FAILURE';

  /// Creates a [WalletReconcileResponse] from the RECONCILE API response.
  factory WalletReconcileResponse.fromApiResponse(Map<String, dynamic> body) {
    final response = body['response'] as Map<String, dynamic>? ?? {};
    final messages = body['messages'] as Map<String, dynamic>? ?? {};
    final txnMessages =
        response['transactionResponseMessage'] as Map<String, dynamic>?;

    return WalletReconcileResponse(
      result: response['result'] as String? ?? body['status'] as String? ?? '',
      status: response['status'] as String? ?? '',
      transactionId: response['transactionId']?.toString(),
      orderReference: response['orderReference']?.toString(),
      messageEn:
          txnMessages?['en'] as String? ?? messages['en'] as String? ?? '',
      messageAr:
          txnMessages?['ar'] as String? ?? messages['ar'] as String? ?? '',
      rawBody: body,
    );
  }
}
