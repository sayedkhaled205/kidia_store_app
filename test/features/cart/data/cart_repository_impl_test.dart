import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_error_model.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';

import 'cart_test_fixture.dart';

void main() {
  group('CartRepositoryImpl', () {
    test('rejects unsafe requests before calling the remote source', () async {
      final _FakeCartRemoteDataSource remote = _FakeCartRemoteDataSource();
      final CartRepositoryImpl repository = CartRepositoryImpl(remote);

      await expectLater(
        repository.addItem(productId: 0),
        throwsA(
          isA<CartRepositoryException>().having(
            (CartRepositoryException error) => error.kind,
            'kind',
            CartFailureKind.invalidInput,
          ),
        ),
      );
      await expectLater(
        repository.updateItem(key: 'item', quantity: 0),
        throwsA(isA<CartRepositoryException>()),
      );
      await expectLater(
        repository.applyCoupon('   '),
        throwsA(isA<CartRepositoryException>()),
      );

      expect(remote.calls, isEmpty);
    });

    test('serializes mutations to avoid stale optimistic responses', () async {
      final _FakeCartRemoteDataSource remote = _FakeCartRemoteDataSource(
        operationDelay: const Duration(milliseconds: 10),
      );
      final CartRepositoryImpl repository = CartRepositoryImpl(remote);

      final Future<dynamic> first = repository.updateItem(
        key: 'item',
        quantity: 2,
      );
      final Future<dynamic> second = repository.updateItem(
        key: 'item',
        quantity: 3,
      );
      await Future.wait(<Future<dynamic>>[first, second]);

      expect(remote.maxConcurrentOperations, 1);
      expect(remote.calls, <String>['update:item:2', 'update:item:3']);
    });

    test('maps conflict details and its server-authoritative cart', () async {
      final CartModel current = CartModel.fromJson(
        cartJsonFixture(totalPrice: '9100'),
      );
      final _FakeCartRemoteDataSource remote = _FakeCartRemoteDataSource(
        updateError: CartRemoteException(
          kind: CartFailureKind.conflict,
          message: 'Item changed on the server.',
          statusCode: 409,
          apiError: const CartErrorModel(
            code: 'woocommerce_rest_cart_invalid_key',
            message: 'Item changed on the server.',
            statusCode: 409,
          ),
          serverCart: current,
        ),
      );
      final CartRepositoryImpl repository = CartRepositoryImpl(remote);

      try {
        await repository.updateItem(key: 'stale', quantity: 2);
        fail('Expected a repository conflict.');
      } on CartRepositoryException catch (error) {
        expect(error.kind, CartFailureKind.conflict);
        expect(error.statusCode, 409);
        expect(error.apiError?.code, 'woocommerce_rest_cart_invalid_key');
        expect(error.serverCart?.totals.priceMinor, '9100');
      }
    });

    test('passes variation data without changing attribute case', () async {
      final _FakeCartRemoteDataSource remote = _FakeCartRemoteDataSource();
      final CartRepositoryImpl repository = CartRepositoryImpl(remote);

      await repository.addItem(
        productId: 13,
        quantity: 1,
        variation: const <CartItemVariation>[
          CartItemVariation(attribute: 'Logo', value: 'Yes'),
        ],
      );

      expect(remote.lastVariation.single.attribute, 'Logo');
      expect(remote.lastVariation.single.value, 'Yes');
    });
  });
}

class _FakeCartRemoteDataSource implements CartRemoteDataSource {
  _FakeCartRemoteDataSource({
    this.operationDelay = Duration.zero,
    this.updateError,
  });

  final Duration operationDelay;
  final CartRemoteException? updateError;
  final List<String> calls = <String>[];
  List<CartItemVariation> lastVariation = const <CartItemVariation>[];
  int _activeOperations = 0;
  int maxConcurrentOperations = 0;

  CartModel get _cart => CartModel.fromJson(cartJsonFixture());

  Future<CartModel> _run(String call, {CartRemoteException? error}) async {
    calls.add(call);
    _activeOperations++;
    if (_activeOperations > maxConcurrentOperations) {
      maxConcurrentOperations = _activeOperations;
    }
    if (operationDelay > Duration.zero) {
      await Future<void>.delayed(operationDelay);
    }
    _activeOperations--;
    if (error != null) {
      throw error;
    }
    return _cart;
  }

  @override
  Future<CartModel> fetchCart() => _run('get');

  @override
  Future<CartModel> addItem({
    required int productId,
    required int quantity,
    required List<CartItemVariation> variation,
  }) {
    lastVariation = List<CartItemVariation>.from(variation);
    return _run('add:$productId:$quantity');
  }

  @override
  Future<CartModel> updateItem({required String key, required int quantity}) {
    return _run('update:$key:$quantity', error: updateError);
  }

  @override
  Future<CartModel> removeItem(String key) => _run('remove:$key');

  @override
  Future<CartModel> applyCoupon(String code) => _run('apply:$code');

  @override
  Future<CartModel> removeCoupon(String code) => _run('remove-coupon:$code');
}
