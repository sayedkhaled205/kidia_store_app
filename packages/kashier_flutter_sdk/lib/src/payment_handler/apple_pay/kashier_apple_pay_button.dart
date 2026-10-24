import 'package:flutter/material.dart';

import '../../kashier_sdk.dart';
import '../../../models/kashier_language.dart';

/// A styled button that mimics the Apple Pay button appearance.
///
/// This is a Flutter widget (not a native PKPaymentButton) for v1 simplicity.
/// It triggers [onPressed] when tapped — the actual payment is started
/// via [KashierSDK.startPayment()].
///
/// Example:
/// ```dart
/// KashierApplePayButton(
///   onPressed: () {
///     KashierSDK.startPayment(
///       sessionId: 'sess_123',
///       onSuccess: (result) { /* handle success */ },
///       onFailure: (error) { /* handle failure */ },
///     );
///   },
/// )
/// ```
class KashierApplePayButton extends StatelessWidget {
  /// Called when the button is pressed.
  final VoidCallback? onPressed;

  /// The height of the button. Defaults to 50 to match the main pay button.
  final double height;

  /// The corner radius of the button. Defaults to 10 to match the main pay button.
  final double cornerRadius;

  const KashierApplePayButton({
    super.key,
    this.onPressed,
    this.height = 50,
    this.cornerRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = KashierSDK.language == KashierLanguage.ar;
    final leadLabel = isAr ? 'ادفع مع ' : 'Pay with ';
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              leadLabel,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
              ),
            ),
            // Apple logo approximation using SF-style text
            const Text(
              '\u{F8FF} Pay', // Apple logo Unicode (renders on Apple devices)
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
