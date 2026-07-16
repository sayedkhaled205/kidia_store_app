import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_field_definition.dart';

class CheckoutState {
  CheckoutState({
    required this.cart,
    List<CheckoutFieldDefinition> fieldDefinitions =
        const <CheckoutFieldDefinition>[],
  }) : fieldDefinitions = List<CheckoutFieldDefinition>.unmodifiable(
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
  final List<String> paymentMethodIds;
  final List<CheckoutFieldDefinition> fieldDefinitions;

  bool get needsPayment => cart.needsPayment;
  bool get needsShipping => cart.needsShipping;
  bool get hasDynamicFields => fieldDefinitions.isNotEmpty;
}
