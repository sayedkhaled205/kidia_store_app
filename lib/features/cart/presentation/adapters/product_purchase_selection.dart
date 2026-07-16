import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';

/// Store-agnostic selection produced by a product-details experience.
///
/// The product feature can construct this value without depending on the cart
/// data layer. Variation values intentionally use the same attribute/value
/// contract required by the official WooCommerce Store API.
class ProductPurchaseSelection {
  ProductPurchaseSelection({
    required this.productId,
    this.quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  }) : variation = List<CartItemVariation>.unmodifiable(variation);

  final int productId;
  final int quantity;
  final List<CartItemVariation> variation;
}

typedef AddProductPurchaseSelection =
    Future<CartActionResult> Function(ProductPurchaseSelection selection);

/// Result returned to product and cart UIs without exposing repository errors.
class CartActionResult {
  const CartActionResult._({required this.succeeded, this.message});

  const CartActionResult.success() : this._(succeeded: true);

  const CartActionResult.failure(String message)
    : this._(succeeded: false, message: message);

  final bool succeeded;
  final String? message;
}
