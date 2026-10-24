import 'package:flutter/material.dart';

import '../../models/kashier_payment_error.dart';
import '../payment_handler/wallet/kashier_wallet_handler.dart';
import 'kashier_branding.dart';
import 'kashier_colors.dart';
import 'kashier_drag_handle.dart';
import 'kashier_localizations.dart';

/// Bottom sheet displayed while waiting for wallet payment completion.
///
/// Shows a 3-step progress indicator and provides Reload/Resend actions.
class WalletWaitingSheet extends StatefulWidget {
  /// The wallet handler managing the payment flow.
  final KashierWalletHandler handler;

  /// Status message from the initiate API response.
  final String statusMessage;

  /// Called when the sheet should be dismissed (on success/failure/cancel).
  final VoidCallback onDismiss;

  /// Called when the user taps Cancel on the waiting screen and the flow
  /// should return to the phone input screen (rather than end the payment
  /// session). When null, Cancel falls back to the old behavior of calling
  /// [KashierWalletHandler.cancelPayment] + [onDismiss].
  final VoidCallback? onBackToPhoneInput;

  /// Called when the customer taps "I have paid" at pending exhaustion. Tears
  /// down the overlay **without** firing any merchant failure callback (the
  /// terminal onPending has already fired via
  /// [KashierWalletHandler.confirmPaidAtExhaustion]).
  final VoidCallback onPaidConfirmed;

  const WalletWaitingSheet({
    super.key,
    required this.handler,
    required this.statusMessage,
    required this.onDismiss,
    required this.onPaidConfirmed,
    this.onBackToPhoneInput,
  });

  @override
  State<WalletWaitingSheet> createState() => _WalletWaitingSheetState();
}

class _WalletWaitingSheetState extends State<WalletWaitingSheet> {
  WalletPollingState _pollingState = WalletPollingState.polling;
  bool _reloading = false;
  bool _resending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.handler.onPollingStateChanged = _onPollingStateChanged;
  }

  void _onPollingStateChanged(WalletPollingState state) {
    if (!mounted) return;

    // Reflect polling state in the progress steps UI. The orchestrator
    // routes the flow to the result sheet via the handler's success/failure
    // callbacks, so this widget no longer needs to dismiss itself.
    setState(() => _pollingState = state);
  }

  Future<void> _onReloadTapped() async {
    setState(() {
      _reloading = true;
      _errorMessage = null;
    });
    try {
      await widget.handler.checkPaymentStatus();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _messageOf(e));
    }
    if (mounted) setState(() => _reloading = false);
  }

  // ignore: unused_element
  Future<void> _onResendTapped() async {
    setState(() {
      _resending = true;
      _errorMessage = null;
      _pollingState = WalletPollingState.polling;
    });
    try {
      await widget.handler.resendPayment();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _messageOf(e));
    }
    if (mounted) setState(() => _resending = false);
  }

  void _onPaidTapped() {
    // Fires the terminal merchant onPending (if implemented), then tears down
    // the overlay with no failure callback.
    widget.handler.confirmPaidAtExhaustion();
    widget.onPaidConfirmed();
  }

  void _onCancelTapped() {
    // At pending exhaustion the flow is terminal — the choices are "I have
    // paid" or give up. Cancel here ends the flow as a user-cancelled failure
    // rather than returning to the phone-input screen.
    if (_pollingState == WalletPollingState.pendingExhausted) {
      widget.handler.cancelPayment();
      widget.onDismiss();
      return;
    }

    final backCallback = widget.onBackToPhoneInput;
    if (backCallback != null) {
      // Abort this attempt (stop polling, drop in-flight reconcile) and
      // bubble up so the orchestrator returns to the phone input screen.
      widget.handler.abortPayment();
      backCallback();
      return;
    }
    // Legacy behavior: fully cancel and close the sheet.
    widget.handler.cancelPayment();
    widget.onDismiss();
  }

  String _messageOf(Object e) =>
      e is KashierPaymentError ? e.message : e.toString();

  @override
  Widget build(BuildContext context) {
    final isExhausted = _pollingState == WalletPollingState.pendingExhausted;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KashierDragHandle(),
            const SizedBox(height: 24),

            // Title
            Text(
              isExhausted
                  ? KashierLocalizations.paymentPendingTitle(context)
                  : KashierLocalizations.completeYourPayment(context),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: KashierColors.contentPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Status message
            Text(
              isExhausted
                  ? KashierLocalizations.paymentPendingBody(context)
                  : KashierLocalizations.checkWalletApp(context),
              style: TextStyle(
                fontSize: 14,
                color: isExhausted
                    ? KashierColors.feedbackWarning
                    : KashierColors.contentSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // 3-step progress indicator
            _ProgressSteps(pollingState: _pollingState),
            const SizedBox(height: 28),

            // Inline error (e.g. network error on reload/resend).
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: KashierColors.feedbackError,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // "I have paid" button — only at pending exhaustion, above Cancel.
            if (isExhausted) ...[
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _onPaidTapped,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KashierColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(KashierLocalizations.iHavePaid(context)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Reload button — hidden once polling has exhausted.
            if (!isExhausted) ...[
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _reloading || _resending ? null : _onReloadTapped,
                  icon: _reloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(KashierLocalizations.reloadStatus(context)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KashierColors.primary,
                    side: const BorderSide(color: KashierColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Cancel button
            TextButton(
              onPressed: _onCancelTapped,
              child: Text(
                KashierLocalizations.cancel(context),
                style: const TextStyle(
                  color: KashierColors.contentSecondary,
                  fontSize: 14,
                ),
              ),
            ),

            // Branding
            const KashierBranding(),
          ],
        ),
      ),
    );
  }
}

/// Three-step progress indicator: Notifying -> Processing -> Successful Payment.
class _ProgressSteps extends StatelessWidget {
  final WalletPollingState pollingState;

  const _ProgressSteps({required this.pollingState});

  @override
  Widget build(BuildContext context) {
    int step1State;
    int step2State;
    int step3State;

    switch (pollingState) {
      case WalletPollingState.polling:
        step1State = 2; // done
        step2State = 1; // active
        step3State = 0; // pending
      case WalletPollingState.success:
        step1State = 2;
        step2State = 2;
        step3State = 2;
      case WalletPollingState.failed:
      case WalletPollingState.pendingExhausted:
        step1State = 2;
        step2State = 0;
        step3State = 0;
    }

    return Row(
      children: [
        _StepIndicator(
          label: KashierLocalizations.notifying(context),
          state: step1State,
        ),
        Expanded(child: _StepConnector(active: step1State == 2)),
        _StepIndicator(
          label: KashierLocalizations.processing(context),
          state: step2State,
        ),
        Expanded(child: _StepConnector(active: step2State == 2)),
        _StepIndicator(
          label: KashierLocalizations.successfulPayment(context),
          state: step3State,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final String label;
  final int state; // 0=pending, 1=active (pulsing), 2=done

  const _StepIndicator({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    Color circleColor;
    Widget circleChild;

    switch (state) {
      case 2:
        circleColor = KashierColors.feedbackSuccess;
        circleChild = const Icon(Icons.check, size: 14, color: Colors.white);
      case 1:
        circleColor = KashierColors.primary;
        circleChild = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        );
      default:
        circleColor = KashierColors.strokeInput;
        circleChild = const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(child: circleChild),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: state > 0 ? FontWeight.w600 : FontWeight.w400,
              color:
                  state > 0 ? KashierColors.primary : KashierColors.contentHint,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool active;

  const _StepConnector({required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        height: 2,
        color:
            active ? KashierColors.feedbackSuccess : KashierColors.strokeInput,
      ),
    );
  }
}
