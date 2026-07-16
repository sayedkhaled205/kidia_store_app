import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';

abstract interface class CartRepository {
  Future<Cart> getCart();

  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  });

  Future<Cart> updateItem({required String key, required int quantity});

  Future<Cart> removeItem(String key);

  Future<Cart> applyCoupon(String code);

  Future<Cart> removeCoupon(String code);
}

/// Repository failures can include the server-authoritative cart returned by a
/// WooCommerce 409 response. Callers should replace any optimistic UI state
/// with [serverCart] before showing the error.
class CartRepositoryException implements Exception {
  const CartRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.apiError,
    this.serverCart,
    this.cause,
  });

  final CartFailureKind kind;
  final String message;
  final int? statusCode;
  final CartError? apiError;
  final Cart? serverCart;
  final Object? cause;

  @override
  String toString() => message;
}
