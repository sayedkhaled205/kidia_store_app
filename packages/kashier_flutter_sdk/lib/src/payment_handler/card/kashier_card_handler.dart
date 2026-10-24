import '../../kashier_sdk.dart';
import '../../../models/kashier_language.dart';
import '../../../models/kashier_payment_error.dart';
import '../../../models/kashier_payment_pending.dart';
import '../../../models/kashier_payment_result.dart';
import '../../kashier_api.dart';
import '../../models/card_payment_response.dart';
import '../../models/kashier_card.dart';
import '../../models/kashier_session.dart';
import '../../models/wallet_initiate_response.dart';
import '../../validation/card_validator.dart';
import '../kashier_payment_handler.dart';

/// Card payment handler.
///
/// Orchestrates the card payment flow:
/// 1. UI calls [startPayment] to store session + callbacks
/// 2. UI calls [fetchSavedCards] to check for saved cards
/// 3. UI calls [payWithNewCard] or [payWithSavedCard]
/// 4. Handler returns [CardPaymentResponse] — UI decides:
///    - Success → call [completeWithSuccess]
///    - 3DS → open WebView, then call [complete3DS]
///    - Failure → show inline error
///
/// Unlike wallet handler, card handler returns responses to UI
/// instead of auto-firing callbacks. This is necessary because
/// the card flow has 3DS branching that the UI must handle.
class KashierCardHandler extends KashierPaymentHandler {
  final KashierApi _api;

  /// Post-OTP reconcile cadence: 8 attempts (4×5s then 4×10s), first at +5s,
  /// ~60s total. Used by [start3DSReconcile]; exhaustion routes to pending.
  static const _defaultPostOtpReconcileDelays = [
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
  ];

  /// Cancel/stuck-INITIATED safety-net cadence: 5 attempts, first immediate.
  /// Used by [reconcileAfter3DSCancel]; exhaustion routes to userCancelled.
  static const _defaultCancelReconcileDelays = [
    Duration.zero,
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  final List<Duration> _postOtpReconcileDelays;
  final List<Duration> _cancelReconcileDelays;

  bool _disposed = false;
  bool _paymentCompleted = false;
  bool _reconcileInFlight = false;

  KashierSession? _currentSession;
  void Function(KashierPaymentResult result)? _onSuccess;
  void Function(KashierPaymentError error)? _onFailure;
  void Function(KashierPaymentPending pending)? _onPending;

  /// Order ID (UUID) from the last card payment response — used by the
  /// reconcile safety net when the 3DS WebView closes without a result.
  /// Uses response.orderId (UUID) because the card device-update endpoint
  /// PUT /v3/orders/device/{orderId} requires the FEP internal UUID.
  String? _lastOrderId;

  KashierCardHandler({
    required KashierApi api,
    List<Duration>? postOtpReconcileDelays,
    List<Duration>? cancelReconcileDelays,
  })  : _api = api,
        _postOtpReconcileDelays = List<Duration>.unmodifiable(
          postOtpReconcileDelays ?? _defaultPostOtpReconcileDelays,
        ),
        _cancelReconcileDelays = List<Duration>.unmodifiable(
          cancelReconcileDelays ?? _defaultCancelReconcileDelays,
        );

  @override
  Future<bool> isAvailable() async {
    // Card payments are always available (pure Dart, no native dependency).
    return true;
  }

  @override
  Future<void> startPayment({
    required KashierSession session,
    required void Function(KashierPaymentResult result) onSuccess,
    required void Function(KashierPaymentError error) onFailure,
    void Function(KashierPaymentPending pending)? onPending,
  }) async {
    _currentSession = session;
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onPending = onPending;
    _paymentCompleted = false;
    _reconcileInFlight = false;
  }

  /// Fetches saved cards for the current session's customer.
  ///
  /// Returns an empty list on any error (network, API failure, etc.)
  /// so the UI can gracefully fall back to the new card form.
  Future<List<KashierCard>> fetchSavedCards() async {
    final session = _currentSession;
    if (session == null) return <KashierCard>[];


    try {
      final cards = await _api.getSavedCards(session: session);
      return cards;
    } catch (_) {
      return <KashierCard>[];
    }
  }

  /// Pays with a new card.
  ///
  /// Validates the card input before calling the API.
  /// Returns a [CardPaymentResponse] for the UI to interpret:
  /// - [CardPaymentResponse.isSuccess] → call [completeWithSuccess]
  /// - [CardPaymentResponse.needs3DS] → open WebView with [redirectUrl]
  /// - [CardPaymentResponse.isFailure] or [isAuthFailed] → show inline error
  ///
  /// Throws [KashierPaymentError] with [invalidCardDetails] on validation
  /// failure, or [networkError] on network issues.
  Future<CardPaymentResponse> payWithNewCard(KashierCardInput card) async {
    final session = _currentSession;
    if (session == null) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'No active session. Call startPayment() first.',
      );
    }

    // Validate card input.
    _validateCardInput(card);


    final response = await _api.payWithNewCard(session: session, card: card);

    _lastOrderId = response.orderId;
    return response;
  }

  /// Pays with a saved card token.
  ///
  /// Returns a [CardPaymentResponse] for the UI to interpret
  /// (same branching as [payWithNewCard]).
  ///
  /// Throws [KashierPaymentError] on network issues.
  Future<CardPaymentResponse> payWithSavedCard({
    required String cardToken,
    required String cvv,
  }) async {
    final session = _currentSession;
    if (session == null) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'No active session. Call startPayment() first.',
      );
    }

    if (cvv.replaceAll(RegExp(r'\D'), '').length != 3) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'Invalid CVV.',
      );
    }


    final response = await _api.payWithSavedCard(
      session: session,
      cardToken: cardToken,
      cvv: cvv,
    );

    _lastOrderId = response.orderId;
    return response;
  }

  /// Primary reconcile flow after the user submits the 3DS OTP.
  ///
  /// The first terminal result still wins: if a hidden-WebView redirect
  /// completes before reconcile returns, [_paymentCompleted] prevents
  /// double callbacks.
  Future<void> start3DSReconcile() async {
    if (_paymentCompleted || _disposed) return;

    final orderId = _lastOrderId;
    if (orderId == null) {
      _complete(error: _unknownPaymentStatusError());
      return;
    }

    await _run3DSReconcile(
      orderId: orderId,
      startMessage:
          '3DS OTP submitted — starting reconcile flow for order: $orderId',
      delays: _postOtpReconcileDelays,
      // Post-OTP exhaustion is a pending outcome, not a failure: build a
      // KashierPaymentPending from the last non-terminal reconcile response.
      exhaustedPendingBuilder: (last) =>
          _buildPendingFromReconcile(orderId: orderId, last: last),
    );
  }

  /// Reconcile safety net for 3DS cancellation / error.
  ///
  /// When the 3DS flow closes before OTP submission delivers a terminal
  /// result, the payment may still complete server-side. This keeps the
  /// existing cancel semantics intact.
  Future<void> reconcileAfter3DSCancel() async {
    if (_paymentCompleted || _disposed) return;

    final orderId = _lastOrderId;
    if (orderId == null) {
      _complete(
        error: KashierPaymentError.fromCode(KashierErrorCode.userCancelled),
      );
      return;
    }

    await _run3DSReconcile(
      orderId: orderId,
      startMessage:
          '3DS cancelled — starting reconcile safety net for order: $orderId',
      delays: _cancelReconcileDelays,
      exhaustedPendingError: KashierPaymentError.fromCode(
        KashierErrorCode.userCancelled,
      ),
    );
  }

  /// Deletes a saved card.
  ///
  /// Throws [KashierPaymentError] with [cardDeletionFailed] on failure.
  Future<void> deleteSavedCard(String cardToken) async {
    final session = _currentSession;
    if (session == null) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.cardDeletionFailed,
        message: 'No active session. Call startPayment() first.',
      );
    }


    await _api.deleteSavedCard(session: session, cardToken: cardToken);

  }

  /// Completes the 3DS flow after the WebView redirects.
  ///
  /// Called by the UI when the WebView intercepts a redirect to
  /// `session.merchantRedirect`. Parses the query parameters to
  /// determine the payment outcome and fires onSuccess or onFailure.
  ///
  /// Expected query params: `paymentStatus`, `orderId`, `transactionId`,
  /// `merchantOrderId`, `cardDataToken`, `maskedCard`, `cardBrand`.
  void complete3DS(Map<String, String> queryParams) {
    if (_paymentCompleted || _disposed) return;

    final paymentStatus = queryParams['paymentStatus'] ?? '';
    final orderId = queryParams['orderId'];
    final transactionId = queryParams['transactionId'];


    if (paymentStatus == 'SUCCESS' || paymentStatus == 'CAPTURED') {
      // Build a result from the redirect query params.
      final result = KashierPaymentResult(
        sessionId: _currentSession?.sessionId ?? '',
        status: paymentStatus,
        orderId: orderId,
        orderReference: queryParams['merchantOrderId'],
        transactionId: transactionId,
        card: KashierCardInfo(
          brand: queryParams['cardBrand'],
          maskedNumber: queryParams['maskedCard'],
        ),
      );
      _complete(result: result);
    } else if (paymentStatus == 'INITIATED') {
      // Verify page was stuck (FEP SPA failed to complete 3DS).
      // Fall back to reconcile to check the actual payment status.
      reconcileAfter3DSCancel();
    } else {
      // 3DS failed or was cancelled.
      _complete(
        error: KashierPaymentError.fromCode(
          KashierErrorCode.authenticationFailed,
          message: queryParams['message'] ?? '3DS authentication failed.',
        ),
      );
    }
  }

  /// Completes the payment with a successful [CardPaymentResponse].
  ///
  /// Called by the UI when [CardPaymentResponse.isSuccess] is true
  /// (direct capture without 3DS). Builds a [KashierPaymentResult]
  /// from the response and fires onSuccess.
  void completeWithSuccess(CardPaymentResponse response) {
    if (_paymentCompleted || _disposed) return;

    final result = KashierPaymentResult.fromApiResponse(
      response.rawBody,
      sessionId: _currentSession?.sessionId ?? '',
    );
    _complete(result: result);
  }

  /// Completes the payment with a failure.
  ///
  /// Called by the UI when the user cancels or a non-recoverable error occurs.
  void completeWithFailure(KashierPaymentError error) {
    if (_paymentCompleted || _disposed) return;
    _complete(error: error);
  }

  /// Resets the handler's completion state so a new payment attempt can
  /// fire onSuccess/onFailure again.
  ///
  /// Used by the UI for the "Try Again" flow after a non-recoverable
  /// failure (e.g., 3DS authentication failed). The session and callbacks
  /// are preserved — only the single-shot completion guard is cleared.
  void resetForRetry() {
    if (_disposed) return;
    _paymentCompleted = false;
    _reconcileInFlight = false;
  }

  void _complete({KashierPaymentResult? result, KashierPaymentError? error}) {
    if (_paymentCompleted) return;
    _paymentCompleted = true;

    if (result != null) {
      _onSuccess?.call(result);
    } else if (error != null) {
      _onFailure?.call(error);
    }
  }

  /// Completes the payment as pending — terminal for card.
  ///
  /// Single-shot (shares the [_paymentCompleted] guard with [_complete]) so any
  /// later 3DS redirect or in-flight reconcile cannot emit a success/failure
  /// after pending. Fires [_onPending]; never [_onSuccess]/[_onFailure].
  void _completePending(KashierPaymentPending pending) {
    if (_paymentCompleted) return;
    _paymentCompleted = true;

    _onPending?.call(pending);
  }

  /// Builds a [KashierPaymentPending] from the last non-terminal reconcile
  /// response after the post-OTP poll exhausts.
  ///
  /// For card pending, [orderId] is the authoritative reference; the reconcile
  /// response carries no `transactionId` on pending/404, so it falls back to an
  /// empty string. Localized messages fall back to the SDK pending body copy.
  KashierPaymentPending _buildPendingFromReconcile({
    required String orderId,
    required WalletReconcileResponse last,
  }) {
    const fallbackEn =
        "We're still confirming your payment. You'll be notified once it's "
        'complete — please check your payment history shortly.';
    const fallbackAr =
        'ما زلنا نؤكد عملية الدفع. سيتم إخطارك عند اكتمالها — يرجى مراجعة سجل '
        'المدفوعات بعد قليل.';

    final messageEn = last.messageEn.isNotEmpty ? last.messageEn : fallbackEn;
    final messageAr = last.messageAr.isNotEmpty ? last.messageAr : fallbackAr;
    final isArabic = KashierSDK.language == KashierLanguage.ar;

    return KashierPaymentPending(
      orderId: orderId,
      transactionId: last.transactionId ?? '',
      message: isArabic ? messageAr : messageEn,
      messageEn: messageEn,
      messageAr: messageAr,
    );
  }

  Future<void> _run3DSReconcile({
    required String orderId,
    required String startMessage,
    required List<Duration> delays,
    KashierPaymentError? exhaustedPendingError,
    KashierPaymentPending Function(WalletReconcileResponse last)?
        exhaustedPendingBuilder,
  }) async {
    assert(
      exhaustedPendingError != null || exhaustedPendingBuilder != null,
      'Exactly one exhaustion outcome must be provided',
    );
    if (_reconcileInFlight || _paymentCompleted || _disposed) return;

    _reconcileInFlight = true;

    // Last response that was neither success nor failure (PENDING, NOT_FOUND,
    // AUTHENTICATION_INITIATED, INITIATED, unknown). Thrown attempts do not
    // update it — exhaustion needs a real server response to claim pending.
    WalletReconcileResponse? lastNonTerminal;

    try {
      for (var i = 0; i < delays.length; i++) {
        final delay = delays[i];
        if (delay > Duration.zero) await Future.delayed(delay);
        if (_paymentCompleted || _disposed) return;

        try {
          final response = await _api.reconcileCardPayment(orderId: orderId);
          if (_paymentCompleted || _disposed) return;

          if (_isCardReconcileSuccess(response)) {
            _complete(
              result: KashierPaymentResult.fromApiResponse(
                response.rawBody,
                sessionId: _currentSession?.sessionId ?? '',
              ),
            );
            return;
          }
          if (_isCardReconcileFailure(response)) {
            _complete(
              error: KashierPaymentError.fromApiResponse(
                response.rawBody,
                statusCode: 200,
              ),
            );
            return;
          }
          lastNonTerminal = response;
        } catch (_) {
          // Attempt failed — retry on the next poll tick.
        }
      }

      if (_paymentCompleted || _disposed) return;

      if (lastNonTerminal == null) {
        // Every attempt threw — never claim pending without a server response.
        _complete(error: _unknownPaymentStatusError());
        return;
      }

      if (exhaustedPendingBuilder != null) {
        _completePending(exhaustedPendingBuilder(lastNonTerminal));
        return;
      }

      _complete(error: exhaustedPendingError!);
    } finally {
      if (!_paymentCompleted) {
        _reconcileInFlight = false;
      }
    }
  }

  KashierPaymentError _unknownPaymentStatusError() {
    return KashierPaymentError.fromCode(
      KashierErrorCode.unknownError,
      message:
          'Payment status could not be verified. Please check your payment history.',
      messageAr: 'تعذر التحقق من حالة الدفع. يرجى مراجعة سجل مدفوعاتك.',
    );
  }

  bool _isCardReconcileSuccess(WalletReconcileResponse response) {
    return response.isSuccess ||
        response.status == 'CAPTURED' ||
        response.status == 'SUCCESS';
  }

  bool _isCardReconcileFailure(WalletReconcileResponse response) {
    return response.isFailure ||
        response.status == 'FAILED' ||
        response.status == 'FAILURE' ||
        response.status == 'DECLINED' ||
        response.status == 'EXPIRED' ||
        response.status == 'VOIDED';
  }

  /// Validates a [KashierCardInput] before sending to the API.
  ///
  /// Throws [KashierPaymentError] with [invalidCardDetails] if any field
  /// fails validation.
  void _validateCardInput(KashierCardInput card) {
    if (!CardValidator.validateCardNumber(card.cardNumber)) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'Invalid card number.',
      );
    }

    if (!CardValidator.validateExpiry(card.expiryMonth, card.expiryYear)) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'Card has expired.',
      );
    }

    final brand = CardValidator.detectBrand(card.cardNumber);
    if (!CardValidator.validateCvv(card.cvv, brand)) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'Invalid CVV.',
      );
    }

    if (!CardValidator.validateName(card.nameOnCard)) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.invalidCardDetails,
        message: 'Invalid name on card.',
      );
    }
  }

  /// Disposes the handler, clearing all references.
  void dispose() {
    _disposed = true;
    _onSuccess = null;
    _onFailure = null;
    _onPending = null;
    _currentSession = null;
    _lastOrderId = null;
  }
}
