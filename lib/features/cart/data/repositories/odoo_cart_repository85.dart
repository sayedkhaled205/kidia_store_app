import 'dart:async';

import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/features/cart/data/odoo/odoo_cart85.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';

/// Native direct Odoo quote, using the same SID/CSRF as the portal customer.
/// No Woo transport, merchant relay or local-price/cart fallback is available.
class OdooCartRepository85 implements CartRepository {
  OdooCartRepository85({required this.client, required this.isCurrentSession});
  final OdooCustomerClient51 client;
  final bool Function() isCurrentSession;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  void dispose() => _disposed = true;

  @override
  Future<Cart> getCart() => _run(() => client.cart85());

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const [],
  }) {
    if (variation.any(
      (value) =>
          value.attribute.isEmpty ||
          value.value.isEmpty ||
          value.attribute.length > 240 ||
          value.value.length > 240,
    )) {
      return Future.error(
        const CartRepositoryException(
          kind: CartFailureKind.invalidInput,
          message:
              'Choose valid attributes for the actual Odoo product variant.',
        ),
      );
    }
    return _run(
      () => client.addCartItem85(productId: productId, quantity: quantity),
    );
  }

  @override
  Future<Cart> updateItem({required String key, required int quantity}) => _run(
    () => client.updateCartItem85(lineId: _lineId(key), quantity: quantity),
  );

  @override
  Future<Cart> removeItem(String key) =>
      _run(() => client.updateCartItem85(lineId: _lineId(key), quantity: 0));

  @override
  Future<Cart> applyCoupon(String code) => _unsupportedCoupon();
  @override
  Future<Cart> removeCoupon(String code) => _unsupportedCoupon();
  Future<Cart> _unsupportedCoupon() => Future.error(
    const CartRepositoryException(
      kind: CartFailureKind.configuration,
      message:
          'This Odoo website has not enabled a verified mobile coupon contract.',
    ),
  );

  int _lineId(String key) {
    if (!RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(key)) {
      throw const FormatException('Invalid Odoo cart line.');
    }
    return int.parse(key);
  }

  Future<Cart> _run(Future<Map<String, dynamic>> Function() request) {
    final ownerEpoch = client.sessionEpoch85;
    final customerId = client.customer?.id;
    final result = _tail.then((_) async {
      void checkOwner() {
        if (_disposed ||
            !isCurrentSession() ||
            ownerEpoch != client.sessionEpoch85 ||
            client.customer?.id != customerId) {
          throw const CartRepositoryException(
            kind: CartFailureKind.unauthorized,
            message: 'The Odoo customer session changed.',
          );
        }
      }

      try {
        checkOwner();
        final response = await request();
        checkOwner();
        return OdooCart85.fromResponse(
          response,
          customerId: customerId,
          origin: client.origin,
        ).cart;
      } on CartRepositoryException {
        rethrow;
      } on FormatException catch (error) {
        throw CartRepositoryException(
          kind: CartFailureKind.invalidResponse,
          message: 'Odoo returned an unverified cart response.',
          cause: error,
        );
      } on OdooCustomerException51 catch (error) {
        throw CartRepositoryException(
          kind: switch (error.code) {
            'customer_request_timeout' => CartFailureKind.timeout,
            'customer_connection_failed' => CartFailureKind.connection,
            'customer_session_changed' ||
            'customer_session_required' => CartFailureKind.unauthorized,
            'cart_contract_unavailable' => CartFailureKind.configuration,
            'invalid_cart_quantity' => CartFailureKind.invalidInput,
            _ =>
              error.statusCode == 409
                  ? CartFailureKind.conflict
                  : CartFailureKind.server,
          },
          message: 'Odoo could not complete the cart request (${error.code}).',
          statusCode: error.statusCode,
          cause: error,
        );
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
