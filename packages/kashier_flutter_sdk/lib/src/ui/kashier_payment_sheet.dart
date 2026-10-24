import 'package:flutter/material.dart';

import '../kashier_sdk.dart';
import '../../models/kashier_payment_error.dart';
import '../../models/kashier_payment_pending.dart';
import '../../models/kashier_payment_result.dart';
import '../models/card_payment_response.dart';
import '../models/kashier_card.dart';
import '../models/kashier_session.dart';
import '../payment_handler/apple_pay/kashier_apple_pay_handler.dart';
import '../payment_handler/card/kashier_card_handler.dart';
import '../payment_handler/wallet/kashier_wallet_handler.dart';
import 'card/card_form_sheet.dart';
import 'card/three_ds_status_view.dart';
import 'card/three_ds_webview_sheet.dart';
import 'kashier_payment_overlay.dart';
import 'kashier_payment_provider.dart';
import 'payment_landing_sheet.dart';
import 'result/payment_result_sheet.dart';
import 'wallet_phone_input_sheet.dart';
import 'wallet_waiting_sheet.dart';

/// Shows the payment UI on the SDK's own overlay and handles the full
/// payment flow.
///
/// This is the internal entry point called by [KashierSDK.startPayment].
/// It does NOT depend on the merchant's navigator or BuildContext.
///
/// Flow:
/// - Consolidated landing: store name, amount, Apple Pay + method tiles
/// - User selects a method → method-specific screens
void showKashierPaymentSheet({
  required KashierSession session,
  required List<String> availableMethods,
  required void Function(KashierPaymentResult result) onSuccess,
  required void Function(KashierPaymentError error) onFailure,
  void Function(KashierPaymentPending pending)? onPending,
}) {
  final provider = KashierPaymentProviderState.instance;
  if (provider == null) {
    onFailure(
      KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message: 'KashierPaymentProvider not found. '
            'Wrap your app with KashierPaymentProvider.',
      ),
    );
    return;
  }

  // Guard against double-firing callbacks.
  var completed = false;

  void completeWithSuccess(KashierPaymentResult result) {
    if (completed) return;
    completed = true;
    provider.dismissPaymentSheet();
    onSuccess(result);
  }

  void completeWithFailure(KashierPaymentError error) {
    if (completed) return;
    completed = true;
    provider.dismissPaymentSheet();
    onFailure(error);
  }

  // Pending marks the flow resolved at the sheet level (shares the `completed`
  // guard) but does NOT dismiss — the pending modal must stay visible until the
  // customer taps Done. For card, pending is terminal: no later success/failure.
  void completePending(KashierPaymentPending pending) {
    if (completed) return;
    completed = true;
    onPending?.call(pending);
  }

  provider.showPaymentSheet(
    _PaymentFlowOverlay(
      session: session,
      availableMethods: availableMethods,
      onSuccess: completeWithSuccess,
      onFailure: completeWithFailure,
      onPending: completePending,
      onDismiss: () {
        completeWithFailure(
          KashierPaymentError.fromCode(KashierErrorCode.userCancelled),
        );
      },
      // Teardown only — fires no merchant callback. Used by the pending modal's
      // Done button so dismissal never emits userCancelled.
      onComplete: () => provider.dismissPaymentSheet(),
    ),
  );
}

/// The full payment flow rendered on the SDK overlay.
class _PaymentFlowOverlay extends StatefulWidget {
  final KashierSession session;
  final List<String> availableMethods;
  final void Function(KashierPaymentResult result) onSuccess;
  final void Function(KashierPaymentError error) onFailure;
  final void Function(KashierPaymentPending pending)? onPending;
  final VoidCallback onDismiss;

  /// Tears down the overlay without firing any merchant callback. Used by the
  /// pending modal's Done button (pending already fired via [onPending]).
  final VoidCallback onComplete;

  const _PaymentFlowOverlay({
    required this.session,
    required this.availableMethods,
    required this.onSuccess,
    required this.onFailure,
    this.onPending,
    required this.onDismiss,
    required this.onComplete,
  });

  @override
  State<_PaymentFlowOverlay> createState() => _PaymentFlowOverlayState();
}

enum _PaymentScreen {
  landing,
  walletPhoneInput,
  walletWaiting,
  cardNewForm,
  threeDSWebView,
  threeDSTimeout,
  resultSuccess,
  resultFailure,
  resultPending,
}

class _PaymentFlowOverlayState extends State<_PaymentFlowOverlay> {
  _PaymentScreen _currentScreen = _PaymentScreen.landing;

  // ── Wallet state ──
  KashierWalletHandler? _walletHandler;
  String _walletStatusMessage = '';

  // ── Card state ──
  KashierCardHandler? _cardHandler;
  List<KashierCard> _savedCards = [];
  KashierCard? _selectedCard;
  String? _redirectUrl;

  /// True while the saved-cards fetch is in progress (accordion skeleton).
  bool _savedCardsLoading = false;

  /// Single source of truth for "the card handler was created AND
  /// startPayment() succeeded" — only then is the card section (saved cards
  /// + Add New Card) safe to use. Distinct from [_savedCards] being empty:
  /// an empty fetch with a ready handler is a valid "Add New Card only"
  /// state, whereas a non-ready handler disables the card section.
  bool _cardHandlerReady = false;

  /// Covers both the fetch and off-fetch bootstrap paths so the landing can
  /// tell "still bootstrapping" from "bootstrap failed".
  bool _cardBootstrapInProgress = false;

  // ── Result sheet state ──
  KashierPaymentResult? _paymentResult;
  KashierPaymentError? _paymentError;

  /// Screen to return to when the user taps "Try Again" on a failure result.
  /// Set before starting each payment method's handler.
  _PaymentScreen _resultReturnScreen = _PaymentScreen.landing;

  bool get _applePayAvailable => widget.availableMethods.contains('applePay');
  bool get _walletAvailable => widget.availableMethods.contains('wallet');
  bool get _cardAvailable => widget.availableMethods.contains('card');

  /// True when the session is configured to retrieve saved cards and has a
  /// customer reference to query against.
  bool get _shouldFetchSavedCards {
    final session = widget.session;
    return _cardAvailable &&
        session.retrieveSavedCard == true &&
        session.customer?.reference != null &&
        session.customer!.reference!.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // If card payments are allowed at all, pre-create the card handler so
    // the landing can charge a saved card inline without navigating away.
    // Flags are set synchronously, before the first build, so the accordion
    // (not the plain tile) renders from frame 1 — no flicker.
    if (_cardAvailable) {
      _cardBootstrapInProgress = true;
      if (_shouldFetchSavedCards) {
        _savedCardsLoading = true;
      }
      _bootstrapCardHandler();
    }
  }

  /// Creates the card handler, starts the payment, and (if enabled) fetches
  /// saved cards before showing the landing. We run this once on overlay
  /// open so the saved cards are ready the first time the landing renders.
  ///
  /// Every exit path — createHandler returning null or throwing,
  /// startPayment() throwing, fetchSavedCards() throwing, or success —
  /// clears the loading flags and leaves [_cardHandlerReady] correctly set.
  Future<void> _bootstrapCardHandler() async {
    try {
      final handler = KashierSDK.createHandler<KashierCardHandler>('card');
      if (handler == null) return; // _cardHandlerReady stays false.
      _cardHandler = handler;

      await handler.startPayment(
        session: widget.session,
        onSuccess: _onHandlerSuccess,
        onFailure: _onHandlerFailure,
        onPending: _onHandlerPending,
      );
      _cardHandlerReady = true; // Startup succeeded → card section usable.

      if (_shouldFetchSavedCards && mounted) {
        // A fetch failure must NOT un-ready the handler — it degrades only
        // to "Add New Card only", never to the cardUnavailable() state.
        try {
          final cards = await handler.fetchSavedCards();
          if (!mounted) return;
          _savedCards = cards;
          _selectedCard = null; // No pre-selection.
        } catch (_) {
          _savedCards = const [];
        }
      }
    } catch (_) {
      // Only createHandler / startPayment failures reach here → the card
      // section renders the disabled cardUnavailable() state.
      _cardHandlerReady = false;
    } finally {
      // Single setState applies all mutations in one rebuild and never
      // touches _currentScreen — a fetch completing while the user is on
      // the new-card form updates data quietly in the background.
      if (mounted) {
        setState(() {
          _savedCardsLoading = false;
          _cardBootstrapInProgress = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _walletHandler?.dispose();
    _cardHandler?.dispose();
    super.dispose();
  }

  // ── Result routing (shared by all payment methods) ──

  /// Intercepts handler success and routes the flow to the result sheet.
  void _onHandlerSuccess(KashierPaymentResult result) {
    if (!mounted) return;
    setState(() {
      _paymentResult = result;
      _paymentError = null;
      _currentScreen = _PaymentScreen.resultSuccess;
    });
  }

  /// Intercepts handler failure and routes the flow to the result sheet,
  /// except for userCancelled (explicit cancellation) and paymentTimeout
  /// (wallet switches to slow polling, no final failure yet).
  void _onHandlerFailure(KashierPaymentError error) {
    if (error.code == KashierErrorCode.paymentTimeout) {
      if (!mounted || _currentScreen != _PaymentScreen.threeDSWebView) return;
      setState(() {
        _paymentError = error;
        _paymentResult = null;
        _currentScreen = _PaymentScreen.threeDSTimeout;
      });
      return;
    }
    if (error.code == KashierErrorCode.userCancelled) {
      widget.onFailure(error);
      return;
    }
    if (!mounted) {
      widget.onFailure(error);
      return;
    }
    setState(() {
      _paymentError = error;
      _paymentResult = null;
      _currentScreen = _PaymentScreen.resultFailure;
    });
  }

  /// Intercepts handler pending (card reconcile exhaustion or wallet pending)
  /// and shows the pending modal. Fires the sheet-level [onPending] first so
  /// the flow is marked resolved the instant pending occurs, then renders the
  /// modal. For card this is terminal — no later success/failure follows.
  void _onHandlerPending(KashierPaymentPending pending) {
    widget.onPending?.call(pending);
    if (!mounted) return;
    setState(() {
      _paymentResult = null;
      _paymentError = null;
      _currentScreen = _PaymentScreen.resultPending;
    });
  }

  void _onResultDone() {
    final result = _paymentResult;
    if (result != null) widget.onSuccess(result);
  }

  /// Pending modal Done — teardown only. [onPending] already fired in
  /// [_onHandlerPending]; this must NOT route through onDismiss (userCancelled).
  void _onPendingDone() {
    widget.onComplete();
  }

  void _onResultCancel() {
    final error = _paymentError ??
        KashierPaymentError.fromCode(KashierErrorCode.userCancelled);
    widget.onFailure(error);
  }

  void _onResultTryAgain() {
    final returnScreen = _resultReturnScreen;
    // Card retries reuse the same handler — reset its completion guard.
    // The landing can also host a saved-card charge, so we reset there too.
    if (returnScreen == _PaymentScreen.cardNewForm ||
        returnScreen == _PaymentScreen.landing) {
      _cardHandler?.resetForRetry();
    }
    setState(() {
      _paymentResult = null;
      _paymentError = null;
      _currentScreen = returnScreen;
    });
  }

  // ── Apple Pay ──

  void _onApplePaySelected() {
    final handler = KashierSDK.createHandler<KashierApplePayHandler>(
      'applePay',
    );
    if (handler == null) return;
    _resultReturnScreen = _PaymentScreen.landing;
    handler.startPayment(
      session: widget.session,
      onSuccess: _onHandlerSuccess,
      onFailure: _onApplePayFailure,
    );
  }

  /// Handles Apple Pay–specific failures.
  ///
  /// When the user merely closes/cancels the Apple Pay sheet
  /// ([KashierErrorCode.userCancelled]), we silently return to the landing
  /// screen so they can choose a different payment method.
  ///
  /// Any other error (e.g. validation failed, token processing failed) is
  /// forwarded to the shared [_onHandlerFailure] which shows the failure
  /// result sheet.
  void _onApplePayFailure(KashierPaymentError error) {
    if (error.code == KashierErrorCode.userCancelled) {
      // Apple Pay popup was closed — stay on the landing screen.
      if (mounted) setState(() => _currentScreen = _PaymentScreen.landing);
      return;
    }
    _onHandlerFailure(error);
  }

  // ── Card ──

  void _onCardPaymentResponse(CardPaymentResponse response) {
    // Capture the source screen so Try Again returns to the right form.
    _resultReturnScreen = _currentScreen;
    if (response.isSuccess) {
      _cardHandler?.completeWithSuccess(response);
    } else if (response.needs3DS) {
      setState(() {
        _redirectUrl = response.redirectUrl;
        _currentScreen = _PaymentScreen.threeDSWebView;
      });
    }
    // Failure/auth-failed errors are shown inline by CardFormSheet.
  }

  /// User tapped the "New card" / "Card" tile on the landing. The card
  /// handler is already created in [initState]; just navigate to the form.
  void _onCardSelected() {
    if (_cardHandler == null) return;
    _resultReturnScreen = _PaymentScreen.cardNewForm;
    setState(() => _currentScreen = _PaymentScreen.cardNewForm);
  }

  /// Called when the user taps a saved card row in the landing accordion.
  void _onSavedCardTapped(KashierCard card) {
    setState(() => _selectedCard = card);
  }

  /// Deletes a saved card from the accordion (swipe or trash, after the
  /// accordion's confirm dialog). Throws on server failure so the accordion
  /// keeps the row. Never auto-selects another card (C1).
  Future<void> _onDeleteSavedCard(KashierCard card) async {
    try {
      await _cardHandler!.deleteSavedCard(card.cardToken);
    } catch (_) {
      // Rethrow so the accordion's catch keeps the row and shows the
      // failure SnackBar. Never log the raw error — it can embed the token.
      rethrow;
    }
    if (!mounted) return;
    setState(() {
      _savedCards =
          _savedCards.where((c) => c.cardToken != card.cardToken).toList();
      if (_selectedCard?.cardToken == card.cardToken) {
        _selectedCard = null;
      }
    });
  }

  /// Called by the landing sheet when a saved-card charge returns a
  /// terminal response (success or 3DS). The handler is already wired.
  void _onSavedCardPaymentResponse(CardPaymentResponse response) {
    _resultReturnScreen = _PaymentScreen.landing;
    if (response.isSuccess) {
      _cardHandler?.completeWithSuccess(response);
    } else if (response.needs3DS) {
      setState(() {
        _redirectUrl = response.redirectUrl;
        _currentScreen = _PaymentScreen.threeDSWebView;
      });
    }
  }

  // ── 3DS ──

  void _on3DSComplete(Map<String, String> queryParams) {
    _cardHandler?.complete3DS(queryParams);
  }

  void _on3DSReconcileRequested() {
    _cardHandler?.start3DSReconcile();
  }

  void _on3DSCancel() {
    // Explicit user cancel (X button / system back). Finalize the payment
    // as userCancelled right away — skip the reconcile safety net so the
    // sheet closes without a network round-trip. The reconcile path is
    // still used from complete3DS for the INITIATED-fallback case.
    _cardHandler?.completeWithFailure(
      KashierPaymentError.fromCode(KashierErrorCode.userCancelled),
    );
  }

  void _on3DSTimeoutDone() {
    final error = _paymentError ??
        KashierPaymentError.fromCode(KashierErrorCode.paymentTimeout);
    widget.onFailure(error);
  }

  // ── Wallet ──

  void _onWalletSelected() {
    setState(() => _currentScreen = _PaymentScreen.walletPhoneInput);
  }

  void _onBackToLanding() {
    setState(() => _currentScreen = _PaymentScreen.landing);
  }

  Future<void> _onWalletPay(String phoneNumber) async {
    _walletHandler?.dispose();

    final handler = KashierSDK.createHandler<KashierWalletHandler>('wallet');
    if (handler == null) return;
    _walletHandler = handler;
    _resultReturnScreen = _PaymentScreen.walletPhoneInput;

    await handler.startPayment(
      session: widget.session,
      onSuccess: _onHandlerSuccess,
      onFailure: _onHandlerFailure,
      onPending: widget.onPending,
    );

    final response = await handler.initiatePayment(phoneNumber: phoneNumber);

    if (!mounted) return;

    _walletStatusMessage = response.messageEn;
    setState(() => _currentScreen = _PaymentScreen.walletWaiting);
  }

  void _onWaitingDismiss() {
    widget.onDismiss();
  }

  /// Called when the customer taps "I have paid" at wallet pending exhaustion.
  /// The handler has already fired the terminal onPending; here we only tear
  /// down the overlay, firing NO merchant failure callback.
  void _onWalletPaidConfirmed() {
    widget.onComplete();
  }

  /// Called when the user taps Cancel on the waiting screen. Aborts the
  /// current R2P attempt (stops polling, drops in-flight reconcile) and
  /// returns to the phone input screen so they can correct the number and
  /// retry — without tearing down the whole payment session.
  void _onWalletBackToPhoneInput() {
    _walletHandler?.abortPayment();
    if (!mounted) return;
    setState(() => _currentScreen = _PaymentScreen.walletPhoneInput);
  }

  @override
  Widget build(BuildContext context) {
    return KashierPaymentOverlay(
      onDismiss: widget.onDismiss,
      fullScreen: _currentScreen == _PaymentScreen.threeDSWebView ||
          _currentScreen == _PaymentScreen.threeDSTimeout ||
          _currentScreen == _PaymentScreen.resultPending,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_currentScreen) {
          _PaymentScreen.landing => PaymentLandingSheet(
              key: const ValueKey('landing'),
              storeName: widget.session.storeName,
              amount: widget.session.amount,
              currency: widget.session.currency,
              applePayAvailable: _applePayAvailable,
              walletAvailable: _walletAvailable,
              cardAvailable: _cardAvailable,
              savedCards: _savedCards,
              selectedCard: _selectedCard,
              useSavedCardsAccordion: _shouldFetchSavedCards,
              savedCardsLoading: _savedCardsLoading,
              cardHandlerReady: _cardHandlerReady,
              cardBootstrapFailed: _cardAvailable &&
                  !_cardBootstrapInProgress &&
                  !_cardHandlerReady,
              cardHandler: _cardHandler,
              onApplePaySelected: _onApplePaySelected,
              onCardSelected: _onCardSelected,
              onWalletSelected: _onWalletSelected,
              onSavedCardTapped: _onSavedCardTapped,
              onDeleteSavedCard: _onDeleteSavedCard,
              onSavedCardPaymentResponse: _onSavedCardPaymentResponse,
            ),
          _PaymentScreen.walletPhoneInput => WalletPhoneInputSheet(
              key: const ValueKey('phone_input'),
              amount: widget.session.amount,
              currency: widget.session.currency,
              initialPhoneNumber: _walletHandler?.currentPhoneNumber,
              onPay: _onWalletPay,
              onBack: _onBackToLanding,
            ),
          _PaymentScreen.walletWaiting => WalletWaitingSheet(
              key: const ValueKey('waiting'),
              handler: _walletHandler!,
              statusMessage: _walletStatusMessage,
              onDismiss: _onWaitingDismiss,
              onPaidConfirmed: _onWalletPaidConfirmed,
              onBackToPhoneInput: _onWalletBackToPhoneInput,
            ),
          _PaymentScreen.cardNewForm => CardFormSheet(
              key: const ValueKey('card_form'),
              session: widget.session,
              cardHandler: _cardHandler!,
              onBack: _onBackToLanding,
              onPaymentResponse: _onCardPaymentResponse,
            ),
          _PaymentScreen.threeDSWebView => ThreeDSWebViewSheet(
              key: const ValueKey('three_ds'),
              redirectUrl: _redirectUrl!,
              merchantRedirect: widget.session.merchantRedirect,
              onComplete: _on3DSComplete,
              onReconcileRequested: _on3DSReconcileRequested,
              onCancel: _on3DSCancel,
            ),
          _PaymentScreen.threeDSTimeout => ThreeDSStatusView(
              key: const ValueKey('three_ds_timeout'),
              mode: ThreeDSStatusViewMode.timeout,
              onDone: _on3DSTimeoutDone,
            ),
          _PaymentScreen.resultPending => ThreeDSStatusView(
              key: const ValueKey('result_pending'),
              mode: ThreeDSStatusViewMode.pending,
              onDone: _onPendingDone,
            ),
          _PaymentScreen.resultSuccess => PaymentResultSheet(
              key: const ValueKey('result_success'),
              isSuccess: true,
              result: _paymentResult,
              amount: widget.session.amount,
              currency: widget.session.currency,
              brandColor: widget.session.brandColor,
              onDone: _onResultDone,
            ),
          _PaymentScreen.resultFailure => PaymentResultSheet(
              key: const ValueKey('result_failure'),
              isSuccess: false,
              error: _paymentError,
              amount: widget.session.amount,
              currency: widget.session.currency,
              brandColor: widget.session.brandColor,
              onTryAgain: _onResultTryAgain,
              onCancel: _onResultCancel,
            ),
        },
      ),
    );
  }
}
