import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_safety.dart';

/// A read-only outcome check for the exact persisted buyer/attempt scope.
/// Implementations must not submit, replay, or infer rejection from an empty cart.
abstract interface class CheckoutRecoveryRepository {
  Future<CheckoutAttemptRecovery> recoverPendingOrder();
}
