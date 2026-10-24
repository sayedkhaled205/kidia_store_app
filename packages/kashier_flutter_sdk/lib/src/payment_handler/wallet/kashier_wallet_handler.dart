import 'dart:async';

import 'wallet_polling_state.dart';
export 'wallet_polling_state.dart';

import '../../kashier_sdk.dart';
import '../../../models/kashier_language.dart';
import '../../../models/kashier_payment_error.dart';
import '../../../models/kashier_payment_pending.dart';
import '../../../models/kashier_payment_result.dart';
import '../../models/kashier_session.dart';
import '../../kashier_api.dart';
import '../../models/wallet_initiate_response.dart';
import '../kashier_payment_handler.dart';

/// Wallet payment handler.
///
/// Orchestrates the wallet payment flow:
/// 1. Receive phone number from UI
/// 2. Call INITIATE_R2P endpoint
/// 3. Poll RECONCILE on a fixed two-phase schedule:
///    - Phase 1: 12 attempts, 10s apart (120s total)
///    - Phase 2: increasing intervals (30s, 45s, 60s, …) until the 5-minute
///      total cap is reached
/// 4. Fire onSuccess / onFailure on a terminal reconcile result
/// 5. On exhaustion (5 min, still pending): emit [WalletPollingState.pendingExhausted]
///    so the UI shows an "I have paid" button. Tapping it calls
///    [confirmPaidAtExhaustion], which fires the terminal onPending callback.
class KashierWalletHandler extends KashierPaymentHandler {
  /// Phase 1: 12 fixed 10s intervals = 120s.
  static const _defaultPhase1Delays = [
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
    Duration(seconds: 10),
  ];

  /// Phase 2: increasing intervals after Phase 1. The 5-minute total cap
  /// truncates this in practice — given Phase 1 ends at 120s, only the first
  /// three intervals (30/45/60 → fires at 150/195/255s) fit before 300s; the
  /// later entries are defined for completeness but are unreachable under the
  /// default cap.
  static const _defaultPhase2Delays = [
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(seconds: 60),
    Duration(seconds: 90),
    Duration(seconds: 120),
    Duration(seconds: 180),
  ];

  /// Hard ceiling for total polling, measured from poll start. No reconcile
  /// request is dispatched once this boundary would be crossed.
  static const _defaultMaxTotalPollDuration = Duration(minutes: 5);

  final KashierApi _api;

  /// Fixed delay schedules (injectable for tests; production defaults above).
  final List<Duration> _phase1Delays;
  final List<Duration> _phase2Delays;

  /// Clock source (injectable for tests; defaults to [DateTime.now]).
  final DateTime Function() _now;
  final Duration _maxTotal;

  /// The two phases concatenated into a single ordered list, walked one-shot.
  late List<Duration> _combinedDelays;

  /// Index of the next delay to arm in [_combinedDelays].
  int _scheduleIndex = 0;

  Timer? _pollingTimer;
  DateTime? _pollingStartTime;
  bool _disposed = false;
  bool _paymentCompleted = false;

  /// True once polling has exhausted on pending. Guards
  /// [confirmPaidAtExhaustion] so onPending cannot fire during active polling.
  bool _pendingExhausted = false;

  /// Last non-terminal reconcile response (i.e. not success/failure). Used to
  /// populate the pending payload at exhaustion. Reset in [_startPolling] and
  /// [dispose]; deliberately NOT cleared in [_stopPolling] so it survives from
  /// exhaustion until the customer taps "I have paid".
  WalletReconcileResponse? _lastNonTerminal;

  /// Monotonically-increasing generation counter. Incremented on every
  /// abort/cancel/resend/dispose/paid-confirmation so that late HTTP responses
  /// from a prior attempt can be safely discarded by comparing the captured
  /// generation with the current one.
  int _gen = 0;

  /// Current order ID being polled (changes on resend).
  String? _currentOrderId;

  /// Phone number used for the current payment.
  String? _currentPhoneNumber;

  /// Current session reference.
  KashierSession? _currentSession;

  // Callbacks stored for polling lifecycle.
  void Function(KashierPaymentResult result)? _onSuccess;
  void Function(KashierPaymentError error)? _onFailure;
  void Function(KashierPaymentPending pending)? _onPending;

  /// Listener for UI state changes during polling.
  void Function(WalletPollingState state)? onPollingStateChanged;

  KashierWalletHandler({
    required KashierApi api,
    List<Duration>? phase1Delays,
    List<Duration>? phase2Delays,
    Duration? maxTotalPollDuration,
    DateTime Function()? now,
  })  : _api = api,
        _phase1Delays = phase1Delays ?? _defaultPhase1Delays,
        _phase2Delays = phase2Delays ?? _defaultPhase2Delays,
        _maxTotal = maxTotalPollDuration ?? _defaultMaxTotalPollDuration,
        _now = now ?? DateTime.now;

  /// Phone number used for the most recent initiate attempt. Surfaced so the
  /// UI can pre-fill the input when the user navigates back from the
  /// waiting screen to correct a typo.
  String? get currentPhoneNumber => _currentPhoneNumber;

  @override
  Future<bool> isAvailable() async {
    // Wallet payments are always available (Dart-only, no native dependency).
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
    _currentPhoneNumber = null;
    _currentOrderId = null;
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _onPending = onPending;
    _paymentCompleted = false;
  }

  /// Initiates a wallet payment with the given phone number.
  ///
  /// Called by the UI after the user enters their phone number and taps Pay.
  Future<WalletInitiateResponse> initiatePayment({
    required String phoneNumber,
  }) async {
    final session = _currentSession;
    if (session == null) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.walletInitFailed,
        message: 'No active session. Call startPayment() first.',
      );
    }

    _currentPhoneNumber = phoneNumber;


    final response = await _api.initiateWalletPayment(
      session: session,
      phoneNumber: phoneNumber,
    );

    _currentOrderId = response.orderId;

    // onPending is terminal for wallet — it fires only at pending exhaustion
    // (via [confirmPaidAtExhaustion]), never at initiation.

    // Start polling.
    _startPolling();

    return response;
  }

  /// Resends the wallet payment request (same phone, new orderId).
  ///
  /// Stops current polling, calls INITIATE_R2P again, and restarts polling.
  /// If the backend returns "Session already paid", falls back to a reconcile
  /// check which will detect the successful payment.
  Future<WalletInitiateResponse?> resendPayment() async {
    final phoneNumber = _currentPhoneNumber;
    final session = _currentSession;
    if (phoneNumber == null || session == null) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.walletInitFailed,
        message: 'No active payment to resend.',
      );
    }


    // Bump generation so any in-flight reconcile from the previous attempt
    // is discarded when it eventually returns.
    _gen++;
    _stopPolling();

    try {
      final response = await _api.initiateWalletPayment(
        session: session,
        phoneNumber: phoneNumber,
      );

      _currentOrderId = response.orderId;
      _paymentCompleted = false;

      // onPending is terminal for wallet — it fires only at the FINAL pending
      // exhaustion (via [confirmPaidAtExhaustion]), never per-resend. A resend
      // restarts the full schedule below.

      // Restart polling with new orderId.
      _startPolling();

      return response;
    } on KashierPaymentError {
      // "Session already paid" means the original payment succeeded.
      // Fall back to a reconcile check to confirm and complete the flow.
      await checkPaymentStatus();
      return null;
    }
  }

  /// Triggers an immediate reconcile check (user taps "Reload Payment Status").
  ///
  /// Works while polling is active — the user can check the real payment status
  /// from the backend on demand. Throws on network/backend errors so the UI can
  /// surface them inline instead of silently swallowing. Becomes a no-op once
  /// the payment has completed (e.g. after the "I have paid" button is tapped).
  Future<void> checkPaymentStatus() async {
    if (_paymentCompleted || _disposed) return;

    final orderId = _currentOrderId;
    if (orderId == null) return;

    final gen = _gen;

    final response = await _api.reconcilePayment(orderId: orderId);

    // If the user aborted/cancelled or the handler was disposed while the
    // request was in flight, drop the response.
    if (_disposed || gen != _gen || _paymentCompleted) return;

    if (response.isSuccess) {
      _stopPolling();
      onPollingStateChanged?.call(WalletPollingState.success);
      _complete(
        result: KashierPaymentResult.fromApiResponse(
          response.rawBody,
          sessionId: _currentSession?.sessionId ?? '',
        ),
      );
    } else if (response.isFailure) {
      _stopPolling();
      onPollingStateChanged?.call(WalletPollingState.failed);
      _complete(
        error: KashierPaymentError.fromApiResponse(
          response.rawBody,
          statusCode: 200,
        ),
      );
    } else {
      _lastNonTerminal = response;
    }
  }

  /// Aborts the current wallet payment attempt **without** firing a failure
  /// callback.
  ///
  /// Use this when the user backs out of the waiting screen to return to the
  /// phone input — the outer payment session is still open, and we only
  /// want to cancel this R2P attempt (stop polling, drop any in-flight
  /// reconcile response). The handler is left in a state where a new
  /// [initiatePayment] can be called immediately.
  void abortPayment() {
    if (_paymentCompleted) return;

    _gen++;
    _stopPolling();
    _currentOrderId = null;
    _paymentCompleted = false;
  }

  /// Cancels the current wallet payment flow and fires the failure callback
  /// with [KashierErrorCode.userCancelled]. Ends the payment session.
  void cancelPayment() {
    if (_paymentCompleted) return;

    _gen++;
    _stopPolling();
    _complete(
      error: KashierPaymentError.fromCode(KashierErrorCode.userCancelled),
    );
  }

  /// Customer asserts they paid after polling exhausted. Terminal: stops the
  /// flow, hands off to the integrator via [onPending] (if provided), and lets
  /// the UI tear down. Safe no-op if already completed or if invoked before
  /// polling has exhausted on pending.
  void confirmPaidAtExhaustion() {
    if (_paymentCompleted) return; // primary guard, blocks late results
    // Defense in depth: this method is only valid once polling has exhausted on
    // pending. Refuse to fire onPending if invoked during active polling via a
    // bug or UI race. assert() in debug; silent no-op in release.
    assert(
      _pendingExhausted,
      'confirmPaidAtExhaustion called before pendingExhausted',
    );
    if (!_pendingExhausted) return;

    _paymentCompleted = true; // single-shot guard, blocks late results
    _gen++; // discard any in-flight reconcile/reload
    _stopPolling();

    _onPending?.call(_buildPendingFromReconcile(_lastNonTerminal));
  }

  void _startPolling() {
    _stopPolling();
    _pollingStartTime = _now();
    _paymentCompleted = false;
    _pendingExhausted = false;
    _lastNonTerminal = null;
    _combinedDelays = [..._phase1Delays, ..._phase2Delays];
    _scheduleIndex = 0;

    onPollingStateChanged?.call(WalletPollingState.polling);


    _scheduleNext();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingStartTime = null;
    // NOTE: _lastNonTerminal is intentionally NOT cleared here — it must
    // survive from exhaustion until the customer taps "I have paid". It is
    // reset in _startPolling and dispose.
  }

  /// Arms a one-shot timer for the next scheduled reconcile attempt, enforcing
  /// the 5-minute total cap. Recurses after each poll completes — no
  /// Timer.periodic, so no request is ever armed past exhaustion.
  void _scheduleNext() {
    if (_disposed || _paymentCompleted) return;

    final startTime = _pollingStartTime;
    if (startTime == null) return;

    // No more scheduled delays → exhaustion.
    if (_scheduleIndex >= _combinedDelays.length) {
      _onPendingExhaustion();
      return;
    }

    final delay = _combinedDelays[_scheduleIndex];

    // Enforce the 5-minute boundary: never arm a timer that would fire past it.
    if (_elapsed() + delay > _maxTotal) {
      _onPendingExhaustion();
      return;
    }

    _pollingTimer = Timer(delay, () {
      _scheduleIndex++;
      _onPollTick();
    });
  }

  Future<void> _onPollTick() async {
    if (_disposed || _paymentCompleted) {
      _stopPolling();
      return;
    }

    final orderId = _currentOrderId;
    if (orderId == null) {
      _stopPolling();
      return;
    }

    await _pollOnce(orderId);

    // Arm the next attempt (if any) once this one resolves.
    _scheduleNext();
  }

  Future<void> _pollOnce(String orderId) async {
    if (_paymentCompleted || _disposed) return;

    final gen = _gen;

    try {
      final response = await _api.reconcilePayment(orderId: orderId);

      // Discard if the attempt was aborted/cancelled/resent mid-flight.
      if (gen != _gen || _paymentCompleted || _disposed) return;

      if (response.isSuccess) {
        _stopPolling();
        onPollingStateChanged?.call(WalletPollingState.success);
        _complete(
          result: KashierPaymentResult.fromApiResponse(
            response.rawBody,
            sessionId: _currentSession?.sessionId ?? '',
          ),
        );
      } else if (response.isFailure) {
        _stopPolling();
        onPollingStateChanged?.call(WalletPollingState.failed);
        _complete(
          error: KashierPaymentError.fromApiResponse(
            response.rawBody,
            statusCode: 200,
          ),
        );
      } else {
        // Non-terminal (pending or any unexpected result) — keep the latest for
        // the pending payload and continue polling.
        _lastNonTerminal = response;
      }
    } catch (_) {
      // Errors during polling should not stop the flow.
      // Only stop on definitive success/failure.
    }
  }

  /// Called when the schedule is exhausted with the payment still pending.
  /// Stops polling and signals the UI to show the "I have paid" button. Does
  /// NOT fire onPending — that happens on the button tap via
  /// [confirmPaidAtExhaustion].
  void _onPendingExhaustion() {
    _stopPolling();
    if (_paymentCompleted) return;

    _pendingExhausted = true;
    onPollingStateChanged?.call(WalletPollingState.pendingExhausted);
  }

  /// Builds the terminal pending payload from the last non-terminal reconcile
  /// response. [orderId] is the authoritative reference; the reconcile response
  /// carries no `transactionId` on pending, so it falls back to an empty
  /// string. Localized messages fall back to the SDK pending body copy.
  KashierPaymentPending _buildPendingFromReconcile(
    WalletReconcileResponse? last,
  ) {
    const fallbackEn =
        "We're still confirming your payment. You'll be notified once it's "
        'complete — please check your payment history shortly.';
    const fallbackAr =
        'ما زلنا نؤكد عملية الدفع. سيتم إخطارك عند اكتمالها — يرجى مراجعة سجل '
        'المدفوعات بعد قليل.';

    final messageEn =
        (last?.messageEn.isNotEmpty ?? false) ? last!.messageEn : fallbackEn;
    final messageAr =
        (last?.messageAr.isNotEmpty ?? false) ? last!.messageAr : fallbackAr;
    final isArabic = KashierSDK.language == KashierLanguage.ar;

    return KashierPaymentPending(
      orderId: _currentOrderId ?? '',
      transactionId: last?.transactionId ?? '',
      message: isArabic ? messageAr : messageEn,
      messageEn: messageEn,
      messageAr: messageAr,
    );
  }

  Duration _elapsed() => _now().difference(_pollingStartTime!);

  void _complete({KashierPaymentResult? result, KashierPaymentError? error}) {
    if (_paymentCompleted) return;
    _paymentCompleted = true;

    if (result != null) {
      _onSuccess?.call(result);
    } else if (error != null) {
      _onFailure?.call(error);
    }
  }

  /// Disposes the handler, cancelling any active polling.
  void dispose() {
    _disposed = true;
    _gen++;
    _stopPolling();
    _lastNonTerminal = null;
    _pendingExhausted = false;
    _onSuccess = null;
    _onFailure = null;
    _onPending = null;
    onPollingStateChanged = null;
  }
}
