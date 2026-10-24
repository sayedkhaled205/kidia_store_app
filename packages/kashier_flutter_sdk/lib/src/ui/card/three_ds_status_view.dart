import 'package:flutter/material.dart';

import '../kashier_branding.dart';
import '../kashier_colors.dart';
import '../kashier_localizations.dart';

enum ThreeDSStatusViewMode { verifying, timeout, pending }

class ThreeDSStatusView extends StatelessWidget {
  final ThreeDSStatusViewMode mode;
  final VoidCallback? onDone;

  const ThreeDSStatusView({super.key, required this.mode, this.onDone});

  /// Done button is shown for every mode except [verifying] (spinner only).
  bool get _showDoneButton => mode != ThreeDSStatusViewMode.verifying;

  Widget _buildIcon() {
    switch (mode) {
      case ThreeDSStatusViewMode.verifying:
        return const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: KashierColors.primary,
          ),
        );
      case ThreeDSStatusViewMode.timeout:
      case ThreeDSStatusViewMode.pending:
        return const Icon(
          Icons.hourglass_top_rounded,
          size: 40,
          color: KashierColors.primary,
        );
    }
  }

  String _title(BuildContext context) {
    switch (mode) {
      case ThreeDSStatusViewMode.verifying:
        return KashierLocalizations.verifyingPaymentTitle(context);
      case ThreeDSStatusViewMode.timeout:
        return KashierLocalizations.threeDSTimeoutTitle(context);
      case ThreeDSStatusViewMode.pending:
        return KashierLocalizations.paymentPendingTitle(context);
    }
  }

  String _body(BuildContext context) {
    switch (mode) {
      case ThreeDSStatusViewMode.verifying:
        return KashierLocalizations.verifyingPaymentBody(context);
      case ThreeDSStatusViewMode.timeout:
        return KashierLocalizations.threeDSTimeoutBody(context);
      case ThreeDSStatusViewMode.pending:
        return KashierLocalizations.paymentPendingBody(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KashierColors.surfaceSheet,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: KashierColors.surfaceInput,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIcon(),
                    const SizedBox(height: 20),
                    Text(
                      _title(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: KashierColors.primary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _body(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: KashierColors.contentSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showDoneButton) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KashierColors.primary,
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
                ),
              ],
              const Spacer(),
              const KashierBranding(),
            ],
          ),
        ),
      ),
    );
  }
}
