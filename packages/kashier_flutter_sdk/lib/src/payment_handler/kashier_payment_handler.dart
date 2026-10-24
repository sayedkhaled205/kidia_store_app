import '../../models/kashier_payment_error.dart';
import '../../models/kashier_payment_pending.dart';
import '../../models/kashier_payment_result.dart';
import '../models/kashier_session.dart';

/// Abstract base class for payment method handlers.
///
/// Each payment method (Apple Pay, Wallet, Google Pay, Cards, BNPL, etc.)
/// implements this interface. The SDK selects the appropriate handler
/// based on the session's allowed methods and device capabilities.
abstract class KashierPaymentHandler {
  /// Checks whether this payment method is available on the current device.
  Future<bool> isAvailable();

  /// Starts the payment flow for this payment method.
  ///
  /// [session] contains the payment details fetched from the Kashier API.
  /// [onSuccess] is called when the payment completes successfully.
  /// [onFailure] is called when the payment fails or is cancelled.
  /// [onPending] is optionally called when reconcile polling exhausts while the
  /// payment is still settling — terminal for both card and wallet (no final
  /// result follows). For wallet, the customer must additionally tap "I have
  /// paid" at exhaustion.
  Future<void> startPayment({
    required KashierSession session,
    required void Function(KashierPaymentResult result) onSuccess,
    required void Function(KashierPaymentError error) onFailure,
    void Function(KashierPaymentPending pending)? onPending,
  });
}
