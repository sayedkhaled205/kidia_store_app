import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';

class CheckoutState {
  CheckoutState({required this.cart})
    : paymentMethodIds = List<String>.unmodifiable(
        cart.paymentMethods
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toSet(),
      );

  final Cart cart;
  final List<String> paymentMethodIds;

  bool get needsPayment => cart.needsPayment;
  bool get needsShipping => cart.needsShipping;
}
