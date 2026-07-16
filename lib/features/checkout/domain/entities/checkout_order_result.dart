class CheckoutOrderResult {
  const CheckoutOrderResult({
    required this.orderId,
    required this.status,
    required this.paymentStatus,
    this.redirectUri,
  });

  final int orderId;
  final String status;
  final String paymentStatus;
  final Uri? redirectUri;

  bool get requiresRedirect => redirectUri != null;
}
