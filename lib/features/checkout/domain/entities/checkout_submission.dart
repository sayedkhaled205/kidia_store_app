import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';

class CheckoutSubmission {
  const CheckoutSubmission({
    required this.billingAddress,
    required this.shippingAddress,
    required this.customerNote,
    required this.paymentMethodId,
    required this.idempotencyKey,
    this.customFields = const <String, String>{},
  });

  final CheckoutAddress billingAddress;
  final CheckoutAddress shippingAddress;
  final String customerNote;
  final String paymentMethodId;
  final Map<String, String> customFields;

  /// Client-generated key used to serialize and deduplicate this submission.
  /// The repository never automatically retries a request with an unknown
  /// server outcome.
  final String idempotencyKey;
}
