/// Error codes returned by the Kashier SDK.
enum KashierErrorCode {
  /// The payment session has expired.
  sessionExpired,

  /// The payment session was not found.
  sessionNotFound,

  /// Apple Pay is not available on this device.
  applePayNotAvailable,

  /// The user cancelled the payment.
  userCancelled,

  /// Merchant validation with Apple Pay failed.
  validationFailed,

  /// Apple Pay merchant configuration error (wrong merchant ID, missing
  /// certificate, or running on Simulator).
  applePayConfigError,

  /// Merchant validation failed during the Apple Pay session.
  merchantValidationFailed,

  /// Processing the Apple Pay token failed.
  tokenProcessingFailed,

  /// The payment was declined by the issuer/processor.
  paymentDeclined,

  /// Authorization/authentication failed (403, invalid hash, etc.).
  authorizationFailed,

  /// A network error occurred.
  networkError,

  /// Polling exceeded the maximum duration waiting for wallet payment.
  paymentTimeout,

  /// The wallet INITIATE_R2P API call failed.
  walletInitFailed,

  /// Failed to retrieve saved cards from the API.
  cardRetrievalFailed,

  /// Failed to delete a saved card.
  cardDeletionFailed,

  /// The card details provided are invalid.
  invalidCardDetails,

  /// 3DS authentication failed.
  authenticationFailed,

  /// An unknown error occurred.
  unknownError,
}

/// Represents an error that occurred during a Kashier payment.
class KashierPaymentError {
  /// The error code identifying the type of error.
  final KashierErrorCode code;

  /// A human-readable error message in English.
  final String message;

  /// A human-readable error message in Arabic, if available.
  final String? messageAr;

  /// The issuer/processor response code (e.g., "57"), if available.
  final String? responseCode;

  /// Optional additional details about the error.
  final Object? details;

  const KashierPaymentError({
    required this.code,
    required this.message,
    this.messageAr,
    this.responseCode,
    this.details,
  });

  /// Creates an error from an error code with a default message.
  factory KashierPaymentError.fromCode(
    KashierErrorCode code, {
    String? message,
    String? messageAr,
    String? responseCode,
    Object? details,
  }) {
    return KashierPaymentError(
      code: code,
      message: message ?? _defaultMessage(code),
      messageAr: messageAr ?? _defaultMessageAr(code),
      responseCode: responseCode,
      details: details,
    );
  }

  /// Creates an error from a Kashier API error response body.
  ///
  /// Handles both generic errors (`{ "error": {...}, "messages": {...} }`)
  /// and issuer-declined errors (`{ "response": {...}, "messages": {...} }`).
  factory KashierPaymentError.fromApiResponse(
    Map<String, dynamic> body, {
    required int statusCode,
  }) {
    final messages = body['messages'] as Map<String, dynamic>?;
    final messageEn = messages?['en'] as String?;
    final messageAr = messages?['ar'] as String?;

    // Check if this is an issuer-declined response (has "response" with result=FAILURE).
    final response = body['response'] as Map<String, dynamic>?;
    if (response != null) {
      final result = response['result'] as String?;
      if (result == 'FAILURE') {
        final txnResponseCode = response['transactionResponseCode'] as String?;
        final txnMessages =
            response['transactionResponseMessage'] as Map<String, dynamic>?;

        return KashierPaymentError(
          code: KashierErrorCode.paymentDeclined,
          message: txnMessages?['en'] as String? ??
              messageEn ??
              'Payment was declined.',
          messageAr: txnMessages?['ar'] as String? ?? messageAr,
          responseCode: txnResponseCode,
          details: body,
        );
      }
    }

    // Generic API error (403 forbidden, 500 server error, etc.).
    final KashierErrorCode code;
    if (statusCode == 403) {
      code = KashierErrorCode.authorizationFailed;
    } else if (statusCode == 500) {
      code = KashierErrorCode.unknownError;
    } else {
      code = KashierErrorCode.unknownError;
    }

    return KashierPaymentError(
      code: code,
      message: messageEn ?? 'Payment failed: HTTP $statusCode',
      messageAr: messageAr,
      details: body,
    );
  }

  static String _defaultMessage(KashierErrorCode code) {
    return switch (code) {
      KashierErrorCode.sessionExpired => 'Payment session has expired.',
      KashierErrorCode.sessionNotFound => 'Payment session not found.',
      KashierErrorCode.applePayNotAvailable =>
        'Apple Pay is not available on this device.',
      KashierErrorCode.userCancelled => 'Payment was cancelled by the user.',
      KashierErrorCode.applePayConfigError =>
        'Apple Pay configuration error. Verify merchant ID and certificate.',
      KashierErrorCode.merchantValidationFailed =>
        'Apple Pay merchant validation failed during payment.',
      KashierErrorCode.validationFailed =>
        'Merchant validation failed. Please try again.',
      KashierErrorCode.tokenProcessingFailed =>
        'Failed to process payment token.',
      KashierErrorCode.paymentDeclined => 'Payment was declined.',
      KashierErrorCode.authorizationFailed => 'Authorization failed.',
      KashierErrorCode.networkError =>
        'A network error occurred. Please check your connection.',
      KashierErrorCode.paymentTimeout => 'Payment timed out. Please try again.',
      KashierErrorCode.walletInitFailed => 'Failed to initiate wallet payment.',
      KashierErrorCode.cardRetrievalFailed => 'Failed to retrieve saved cards.',
      KashierErrorCode.cardDeletionFailed => 'Failed to delete saved card.',
      KashierErrorCode.invalidCardDetails =>
        'The card details provided are invalid.',
      KashierErrorCode.authenticationFailed => '3DS authentication failed.',
      KashierErrorCode.unknownError => 'An unknown error occurred.',
    };
  }

  static String _defaultMessageAr(KashierErrorCode code) {
    return switch (code) {
      KashierErrorCode.sessionExpired => 'انتهت صلاحية جلسة الدفع.',
      KashierErrorCode.sessionNotFound => 'لم يتم العثور على جلسة الدفع.',
      KashierErrorCode.applePayNotAvailable =>
        'Apple Pay غير متاح على هذا الجهاز.',
      KashierErrorCode.userCancelled => 'تم إلغاء الدفع من قبل المستخدم.',
      KashierErrorCode.applePayConfigError =>
        'خطأ في إعداد Apple Pay. تحقق من معرّف التاجر والشهادة.',
      KashierErrorCode.merchantValidationFailed =>
        'فشل التحقق من التاجر أثناء عملية الدفع.',
      KashierErrorCode.validationFailed =>
        'فشل التحقق من التاجر. يرجى المحاولة مرة أخرى.',
      KashierErrorCode.tokenProcessingFailed => 'فشل في معالجة رمز الدفع.',
      KashierErrorCode.paymentDeclined => 'تم رفض عملية الدفع.',
      KashierErrorCode.authorizationFailed => 'فشل التفويض.',
      KashierErrorCode.networkError =>
        'حدث خطأ في الشبكة. يرجى التحقق من اتصالك.',
      KashierErrorCode.paymentTimeout =>
        'انتهت مهلة الدفع. يرجى المحاولة مرة أخرى.',
      KashierErrorCode.walletInitFailed => 'فشل في بدء الدفع بالمحفظة.',
      KashierErrorCode.cardRetrievalFailed =>
        'فشل في استرداد البطاقات المحفوظة.',
      KashierErrorCode.cardDeletionFailed => 'فشل في حذف البطاقة المحفوظة.',
      KashierErrorCode.invalidCardDetails =>
        'بيانات البطاقة المدخلة غير صحيحة.',
      KashierErrorCode.authenticationFailed => 'فشل التحقق من الهوية.',
      KashierErrorCode.unknownError => 'حدث خطأ غير معروف.',
    };
  }

  @override
  String toString() => 'KashierPaymentError(${code.name}: $message)';
}
