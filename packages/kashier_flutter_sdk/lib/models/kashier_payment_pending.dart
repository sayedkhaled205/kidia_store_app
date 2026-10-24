/// Represents a payment that has entered the pending state.
///
/// Delivered via the `onPending` callback when reconcile polling exhausts while
/// the payment is still settling — **terminal** in both cases (no final
/// onSuccess/onFailure follows):
/// - **Wallet** — the 5-minute poll exhausted still pending and the customer
///   tapped "I have paid".
/// - **Card** — reconcile polling exhausted after 3DS while the payment was
///   still settling.
///
/// For both, [orderId] is the authoritative reference and [transactionId] may
/// be empty.
class KashierPaymentPending {
  /// The Kashier order ID for this payment. Authoritative reference for card
  /// pending.
  final String orderId;

  /// The transaction ID (e.g., "TX-35524544764"). May be empty for card
  /// pending, where the reconcile response carries no transaction ID yet.
  final String transactionId;

  /// A human-readable status message (EN or AR based on API response).
  final String message;

  /// The localized message in English.
  final String? messageEn;

  /// The localized message in Arabic.
  final String? messageAr;

  const KashierPaymentPending({
    required this.orderId,
    required this.transactionId,
    required this.message,
    this.messageEn,
    this.messageAr,
  });

  @override
  String toString() =>
      'KashierPaymentPending(orderId: $orderId, transactionId: $transactionId)';
}
