import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'saved_checkout_address92.dart';

class CheckoutState {
  CheckoutState({
    required this.cart,
    this.hasUnresolvedSubmission = false,
    this.serverSafetyRequired = false,
    this.serverSafetyEnforced = false,
    this.allowDifferentShippingAddress = true,
    this.savedAddresses = const [],
    this.nativePaymentAdapters = const {},
    Map<String, String> paymentMethodLabels = const <String, String>{},
    List<CheckoutFieldDefinition> fieldDefinitions =
        const <CheckoutFieldDefinition>[],
  }) : paymentMethodLabels = Map<String, String>.unmodifiable(
         paymentMethodLabels,
       ),
       fieldDefinitions = List<CheckoutFieldDefinition>.unmodifiable(
         fieldDefinitions.toList()..sort(
           (CheckoutFieldDefinition first, CheckoutFieldDefinition second) =>
               first.priority.compareTo(second.priority),
         ),
       ),
       paymentMethodIds = List<String>.unmodifiable(
         cart.paymentMethods
             .map((String value) => value.trim())
             .where((String value) => value.isNotEmpty)
             .toSet(),
       );

  final Cart cart;

  /// Production repositories supply the merchant's current shipping policy.
  final bool allowDifferentShippingAddress;
  final List<SavedCheckoutAddress92> savedAddresses;
  final Map<String, String> nativePaymentAdapters;

  /// Persisted dispatch without an authoritative order/rejection response.
  /// An empty or freshly fetched basket does not resolve this state.
  final bool hasUnresolvedSubmission;

  /// False means unverified/unavailable, never legacy protection inferred from
  /// merely sending an Idempotency-Key header. Submission rechecks the server.
  final bool serverSafetyRequired;
  final bool serverSafetyEnforced;
  final List<String> paymentMethodIds;
  final Map<String, String> paymentMethodLabels;

  String? paymentMethodLabel(String id) =>
      paymentMethodIds.contains(id) ? paymentMethodLabels[id] : null;
  final List<CheckoutFieldDefinition> fieldDefinitions;

  bool get needsPayment => cart.needsPayment;
  bool get needsShipping => cart.needsShipping;
  bool get hasDynamicFields => fieldDefinitions.isNotEmpty;
}
