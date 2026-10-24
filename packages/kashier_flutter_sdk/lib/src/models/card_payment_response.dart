/// Internal response model for card payment API calls.
///
/// This class is not exported to merchants. The handler interprets the
/// status and decides whether to show a result sheet, open 3DS WebView,
/// or display an inline error.
class CardPaymentResponse {
  /// API status: CAPTURED, AUTHENTICATION_INITIATED, AUTHENTICATION_UNSUCCESSFUL, FAILURE, etc.
  final String status;

  /// 3DS redirect URL (present when [needs3DS] is true).
  final String? redirectUrl;

  /// The Kashier order ID.
  final String? orderId;

  /// The transaction ID (e.g., "TX-35524544753").
  final String? transactionId;

  /// The full API response body for constructing KashierPaymentResult.
  final Map<String, dynamic> rawBody;

  const CardPaymentResponse({
    required this.status,
    this.redirectUrl,
    this.orderId,
    this.transactionId,
    required this.rawBody,
  });

  /// Payment was captured successfully.
  bool get isSuccess => status == 'CAPTURED' || status == 'SUCCESS';

  /// 3DS authentication is required — open the [redirectUrl] in a WebView.
  bool get needs3DS => status == 'AUTHENTICATION_INITIATED';

  /// 3DS authentication failed (user failed challenge or bank rejected).
  bool get isAuthFailed => status == 'AUTHENTICATION_UNSUCCESSFUL';

  /// Generic failure from the API.
  bool get isFailure => status == 'FAILURE';

  /// Extracts a human-readable error message for inline display.
  ///
  /// Checks `error.cause`, then `messages.en`, then falls back to a default.
  String get errorMessage {
    final error = rawBody['error'] as Map<String, dynamic>?;
    if (error != null) {
      final cause = error['cause'] as String?;
      if (cause != null && cause.isNotEmpty) return cause;
    }

    final messages = rawBody['messages'] as Map<String, dynamic>?;
    if (messages != null) {
      final en = messages['en'] as String?;
      if (en != null && en.isNotEmpty) return en;
    }

    final response = rawBody['response'] as Map<String, dynamic>?;
    if (response != null) {
      final txnMessages =
          response['transactionResponseMessage'] as Map<String, dynamic>?;
      if (txnMessages != null) {
        final en = txnMessages['en'] as String?;
        if (en != null && en.isNotEmpty) return en;
      }
    }

    return 'Payment failed. Please try again.';
  }

  /// Extracts an Arabic error message for inline display.
  String get errorMessageAr {
    final messages = rawBody['messages'] as Map<String, dynamic>?;
    if (messages != null) {
      final ar = messages['ar'] as String?;
      if (ar != null && ar.isNotEmpty) return ar;
    }

    final response = rawBody['response'] as Map<String, dynamic>?;
    if (response != null) {
      final txnMessages =
          response['transactionResponseMessage'] as Map<String, dynamic>?;
      if (txnMessages != null) {
        final ar = txnMessages['ar'] as String?;
        if (ar != null && ar.isNotEmpty) return ar;
      }
    }

    return 'فشل الدفع. يرجى المحاولة مرة أخرى.';
  }

  /// Creates a [CardPaymentResponse] from the /v3/orders API response.
  factory CardPaymentResponse.fromApiResponse(Map<String, dynamic> body) {
    final response = body['response'] as Map<String, dynamic>? ?? {};

    // 3DS redirect URL can be at response.redirectUrl or response.authentication.redirectUrl
    String? redirectUrl = response['redirectUrl'] as String?;
    if (redirectUrl == null) {
      final auth = response['authentication'] as Map<String, dynamic>?;
      redirectUrl = auth?['redirectUrl'] as String?;
    }

    return CardPaymentResponse(
      status: response['status'] as String? ??
          body['status'] as String? ??
          'FAILURE',
      redirectUrl: redirectUrl,
      orderId: response['orderId'] as String?,
      transactionId: response['transactionId'] as String?,
      rawBody: body,
    );
  }
}
