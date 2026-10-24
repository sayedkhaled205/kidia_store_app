/// Represents the current state of wallet payment polling.
enum WalletPollingState {
  /// Polling is active, waiting for payment completion.
  polling,

  /// Payment completed successfully.
  success,

  /// Payment failed.
  failed,

  /// Reconcile polling exhausted after the 5-minute schedule with the payment
  /// still pending. The customer is offered an "I have paid" button which,
  /// when tapped, fires the terminal [onPending] callback.
  pendingExhausted,
}
