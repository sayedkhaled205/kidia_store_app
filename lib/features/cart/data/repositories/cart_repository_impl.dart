import 'dart:async';

import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  CartRepositoryImpl(this._remoteDataSource);

  final CartRemoteDataSource _remoteDataSource;

  /// Cart mutations are serialized. Add-item is not automatically retried
  /// because replaying it is not idempotent; the server response remains the
  /// source of truth after every operation.
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<Cart> getCart() {
    return _enqueue(() => _remoteDataSource.fetchCart());
  }

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  }) {
    return _enqueue(() {
      if (productId <= 0) {
        throw _invalidInput('A product id must be positive.');
      }
      if (quantity <= 0) {
        throw _invalidInput('Cart quantity must be positive.');
      }
      for (final CartItemVariation value in variation) {
        if (value.attribute.trim().isEmpty || value.value.trim().isEmpty) {
          throw _invalidInput(
            'Variation attributes and values must not be empty.',
          );
        }
      }
      return _remoteDataSource.addItem(
        productId: productId,
        quantity: quantity,
        variation: List<CartItemVariation>.unmodifiable(variation),
      );
    });
  }

  @override
  Future<Cart> updateItem({required String key, required int quantity}) {
    return _enqueue(() {
      final String itemKey = key.trim();
      if (itemKey.isEmpty) {
        throw _invalidInput('A cart item key is required.');
      }
      if (quantity <= 0) {
        throw _invalidInput(
          'Use removeItem when the requested quantity is zero.',
        );
      }
      return _remoteDataSource.updateItem(key: itemKey, quantity: quantity);
    });
  }

  @override
  Future<Cart> removeItem(String key) {
    return _enqueue(() {
      final String itemKey = key.trim();
      if (itemKey.isEmpty) {
        throw _invalidInput('A cart item key is required.');
      }
      return _remoteDataSource.removeItem(itemKey);
    });
  }

  @override
  Future<Cart> applyCoupon(String code) {
    return _enqueue(() {
      final String coupon = code.trim();
      if (coupon.isEmpty) {
        throw _invalidInput('A coupon code is required.');
      }
      return _remoteDataSource.applyCoupon(coupon);
    });
  }

  @override
  Future<Cart> removeCoupon(String code) {
    return _enqueue(() {
      final String coupon = code.trim();
      if (coupon.isEmpty) {
        throw _invalidInput('A coupon code is required.');
      }
      return _remoteDataSource.removeCoupon(coupon);
    });
  }

  Future<Cart> _enqueue(Future<CartModel> Function() operation) {
    final Completer<Cart> result = Completer<Cart>();
    _operationTail = _operationTail.then<void>((_) async {
      try {
        result.complete((await operation()).toEntity());
      } on CartRepositoryException catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } on CartRemoteException catch (error, stackTrace) {
        result.completeError(
          CartRepositoryException(
            kind: error.kind,
            message: error.message,
            statusCode: error.statusCode,
            apiError: error.apiError?.toEntity(),
            serverCart: error.serverCart?.toEntity(),
            cause: error.cause ?? error,
          ),
          stackTrace,
        );
      } on StoreApiException catch (error, stackTrace) {
        result.completeError(
          CartRepositoryException(
            kind: cartFailureKindFromStoreApi(error.kind),
            message: error.message,
            statusCode: error.statusCode,
            cause: error,
          ),
          stackTrace,
        );
      } on FormatException catch (error, stackTrace) {
        result.completeError(
          CartRepositoryException(
            kind: CartFailureKind.invalidResponse,
            message: 'The store returned invalid cart data.',
            cause: error,
          ),
          stackTrace,
        );
      } catch (error, stackTrace) {
        result.completeError(
          CartRepositoryException(
            kind: CartFailureKind.unknown,
            message: 'The cart request failed unexpectedly.',
            cause: error,
          ),
          stackTrace,
        );
      }
    });
    return result.future;
  }

  CartRepositoryException _invalidInput(String message) {
    return CartRepositoryException(
      kind: CartFailureKind.invalidInput,
      message: message,
    );
  }
}
