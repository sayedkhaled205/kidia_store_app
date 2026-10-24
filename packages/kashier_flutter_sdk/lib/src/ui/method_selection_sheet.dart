import 'package:flutter/material.dart';

import '../payment_handler/apple_pay/kashier_apple_pay_button.dart';
import 'kashier_branding.dart';
import 'kashier_colors.dart';
import 'kashier_drag_handle.dart';
import 'kashier_localizations.dart';

/// Bottom sheet for selecting a payment method.
///
/// Shows available methods based on the session's allowedMethods
/// and device capabilities.
class MethodSelectionSheet extends StatelessWidget {
  /// Whether Apple Pay is available on this device.
  final bool applePayAvailable;

  /// Whether wallet is in the allowed methods list.
  final bool walletAvailable;

  /// Called when the user selects Apple Pay.
  final VoidCallback? onApplePaySelected;

  /// Called when the user selects Wallet.
  final VoidCallback? onWalletSelected;

  /// Called when the user taps back. If null, no back button is shown.
  final VoidCallback? onBack;

  const MethodSelectionSheet({
    super.key,
    required this.applePayAvailable,
    required this.walletAvailable,
    this.onApplePaySelected,
    this.onWalletSelected,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KashierDragHandle(),
            const SizedBox(height: 20),

            // Title row with optional back button
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: KashierColors.contentSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    KashierLocalizations.choosePaymentMethod(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: KashierColors.contentPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 24),

            // Apple Pay option
            if (applePayAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: KashierApplePayButton(
                  onPressed: onApplePaySelected,
                ),
              ),

            // Wallet option
            if (walletAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WalletOptionTile(
                  onTap: onWalletSelected,
                ),
              ),

            // More methods placeholder
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                KashierLocalizations.moreMethodsSoon(context),
                style: const TextStyle(
                  fontSize: 13,
                  color: KashierColors.contentHint,
                ),
                textAlign: TextAlign.center,
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

class _WalletOptionTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _WalletOptionTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: KashierColors.strokeInput),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KashierColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: KashierColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      KashierLocalizations.wallet(context),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: KashierColors.contentPrimary,
                      ),
                    ),
                    Text(
                      KashierLocalizations.walletSubtitle(context),
                      style: const TextStyle(
                        fontSize: 12,
                        color: KashierColors.contentSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: KashierColors.contentDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
