import 'package:flutter/material.dart';

import '../../../models/kashier_payment_error.dart';
import '../../../models/kashier_payment_result.dart';
import '../kashier_branding.dart';
import '../kashier_colors.dart';
import '../kashier_drag_handle.dart';
import '../kashier_localizations.dart';

/// Premium result bottom sheet shown after every payment attempt.
///
/// Replaces ad-hoc alerts across all payment methods with a single,
/// animated success/failure screen.
///
/// - Success: animated green checkmark, transaction details, "Done" button.
/// - Failure: animated red X, error message, "Try Again" + "Cancel" buttons.
class PaymentResultSheet extends StatefulWidget {
  /// Whether the payment succeeded.
  final bool isSuccess;

  /// Success result. Required when [isSuccess] is true.
  final KashierPaymentResult? result;

  /// Failure error. Required when [isSuccess] is false.
  final KashierPaymentError? error;

  /// Amount from the session for display.
  final double amount;

  /// Currency from the session for display.
  final String currency;

  /// Optional merchant brand color hex string for button theming.
  final String? brandColor;

  /// Called when the user taps "Done" on the success state.
  final VoidCallback? onDone;

  /// Called when the user taps "Try Again" on the failure state.
  final VoidCallback? onTryAgain;

  /// Called when the user taps "Cancel" on the failure state.
  final VoidCallback? onCancel;

  const PaymentResultSheet({
    super.key,
    required this.isSuccess,
    this.result,
    this.error,
    required this.amount,
    required this.currency,
    this.brandColor,
    this.onDone,
    this.onTryAgain,
    this.onCancel,
  }) : assert(
          (isSuccess && result != null) || (!isSuccess && error != null),
          'PaymentResultSheet requires result for success or error for failure',
        );

  @override
  State<PaymentResultSheet> createState() => _PaymentResultSheetState();
}

class _PaymentResultSheetState extends State<PaymentResultSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _amountStr {
    if (widget.amount % 1 == 0) return widget.amount.toInt().toString();
    return widget.amount.toStringAsFixed(2);
  }

  String _errorMessage(BuildContext context) {
    final error = widget.error!;
    if (KashierLocalizations.isArabic(context) &&
        error.messageAr != null &&
        error.messageAr!.isNotEmpty) {
      return error.messageAr!;
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    final primary = KashierColors.resolvedPrimary(widget.brandColor);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KashierDragHandle(),
              const SizedBox(height: 24),
              _buildAnimatedIcon(),
              const SizedBox(height: 20),
              _buildTitle(context),
              const SizedBox(height: 16),
              if (widget.isSuccess)
                _buildSuccessDetails(context)
              else
                _buildErrorMessage(context),
              const SizedBox(height: 24),
              _buildActionButtons(context, primary),
              const KashierBranding(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    final color = widget.isSuccess
        ? KashierColors.feedbackSuccess
        : KashierColors.feedbackError;
    final lightColor = widget.isSuccess
        ? KashierColors.feedbackSuccessLight
        : KashierColors.feedbackErrorLight;
    final icon = widget.isSuccess ? Icons.check_rounded : Icons.close_rounded;

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: lightColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, size: 50, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      widget.isSuccess
          ? KashierLocalizations.paymentSuccessful(context)
          : KashierLocalizations.paymentFailed(context),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: KashierColors.contentPrimary,
        height: 1.2,
      ),
    );
  }

  Widget _buildSuccessDetails(BuildContext context) {
    final result = widget.result!;
    final rows = <_DetailRow>[
      _DetailRow(
        label: KashierLocalizations.amount(context),
        value:
            '$_amountStr ${KashierLocalizations.currencyDisplay(context, widget.currency)}',
      ),
    ];

    if (result.transactionId != null && result.transactionId!.isNotEmpty) {
      rows.add(_DetailRow(
        label: KashierLocalizations.transactionId(context),
        value: result.transactionId!,
      ));
    }

    final isWalletPayment =
        result.card?.wallet != null && result.card!.wallet!.isNotEmpty;
    final maskedCard = result.card?.maskedNumber;
    if (!isWalletPayment && maskedCard != null && maskedCard.isNotEmpty) {
      rows.add(_DetailRow(
        label: KashierLocalizations.card(context),
        value: maskedCard,
        forceLtr: true,
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KashierColors.surfaceInput,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: KashierColors.strokeInput,
                ),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: KashierColors.feedbackErrorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 18,
              color: KashierColors.feedbackError,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage(context),
              style: const TextStyle(
                fontSize: 13,
                color: KashierColors.feedbackError,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primary) {
    if (widget.isSuccess) {
      return SizedBox(
        height: 50,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: Text(
            KashierLocalizations.done(context),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onTryAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              KashierLocalizations.tryAgain(context),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            KashierLocalizations.cancel(context),
            style: const TextStyle(
              fontSize: 14,
              color: KashierColors.contentSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool forceLtr;

  const _DetailRow({
    required this.label,
    required this.value,
    this.forceLtr = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: KashierColors.contentSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: forceLtr
              ? Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KashierColors.contentPrimary,
                    ),
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KashierColors.contentPrimary,
                  ),
                ),
        ),
      ],
    );
  }
}
