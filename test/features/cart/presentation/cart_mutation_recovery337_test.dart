import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_model.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';

import '../data/cart_test_fixture.dart';

void main() {
  for (final kind in [
    CartFailureKind.timeout,
    CartFailureKind.connection,
    CartFailureKind.cancelled,
    CartFailureKind.server,
    CartFailureKind.invalidResponse,
    CartFailureKind.unknown,
  ]) {
    test(
      'Lost add response $kind reads actual basket without replay',
      () async {
        final repository = _Repository(kind: kind);
        final container = _container(repository);
        await container.read(cartControllerProvider.future);
        final result = await container
            .read(cartControllerProvider.notifier)
            .addSelection(ProductPurchaseSelection(productId: 38));
        expect(result.succeeded, false);
        expect(result.message, contains('refreshed cart'));
        expect(repository.writes, 1);
        expect(repository.reads, 2);
        expect(container.read(cartBadgeCountProvider), 2);
      },
    );
  }

  test(
    'Reconciliation holds mutation lock until authoritative read completes',
    () async {
      final repository = _Repository();
      final container = _container(repository);
      await container.read(cartControllerProvider.future);
      repository.readGate = Completer<Cart>();
      final controller = container.read(cartControllerProvider.notifier);
      final first = controller.addSelection(
        ProductPurchaseSelection(productId: 38),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(cartControllerProvider).requireValue.hasPendingMutation,
        true,
      );
      expect(
        (await controller.addSelection(
          ProductPurchaseSelection(productId: 38),
        )).succeeded,
        false,
      );
      expect(repository.writes, 1);
      repository.readGate!.complete(repository.current);
      await first;
      expect(container.read(cartBadgeCountProvider), 2);
    },
  );

  test(
    'Failed reconciliation blocks writes until explicit successful retry',
    () async {
      final repository = _Repository();
      final container = _container(repository);
      await container.read(cartControllerProvider.future);
      repository.failRead = true;
      final controller = container.read(cartControllerProvider.notifier);
      await controller.addSelection(ProductPurchaseSelection(productId: 38));
      expect(container.read(cartControllerProvider).hasError, true);
      expect(
        (await controller.addSelection(
          ProductPurchaseSelection(productId: 38),
        )).succeeded,
        false,
      );
      expect(repository.writes, 1);
      repository.failRead = false;
      await controller.retry();
      expect(container.read(cartBadgeCountProvider), 2);
      repository.failWrite = false;
      expect(
        (await controller.addSelection(
          ProductPurchaseSelection(productId: 38),
        )).succeeded,
        true,
      );
      expect(repository.writes, 2);
      expect(container.read(cartBadgeCountProvider), 3);
    },
  );

  for (final action in ['update', 'remove', 'apply_coupon', 'remove_coupon']) {
    test('Lost $action acknowledgement reconciles without replay', () async {
      final repository = _Repository();
      if (action == 'remove_coupon') {
        repository.current = _cart(1, coupon: 'TEST');
      }
      final container = _container(repository);
      final initial = await container.read(cartControllerProvider.future);
      final controller = container.read(cartControllerProvider.notifier);
      switch (action) {
        case 'update':
          await controller.updateQuantity(initial.cart.items.single, 2);
        case 'remove':
          await controller.removeItem(initial.cart.items.single.key);
        case 'apply_coupon':
          await controller.applyCoupon('TEST');
        case 'remove_coupon':
          await controller.removeCoupon('TEST');
      }
      expect(repository.writes, 1);
      expect(repository.reads, 2);
      expect(
        container.read(cartControllerProvider).requireValue.cart,
        same(repository.current),
      );
    });
  }

  test(
    'Definitive validation rejection remains retryable without extra read',
    () async {
      final repository = _Repository(
        kind: CartFailureKind.invalidInput,
        applyBeforeFailure: false,
      );
      final container = _container(repository);
      await container.read(cartControllerProvider.future);
      await container
          .read(cartControllerProvider.notifier)
          .addSelection(ProductPurchaseSelection(productId: 38));
      expect(repository.reads, 1);
      expect(container.read(cartBadgeCountProvider), 1);
      expect(container.read(cartControllerProvider).hasError, false);
    },
  );
}

ProviderContainer _container(_Repository repository) {
  final container = ProviderContainer(
    overrides: [cartRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  container.listen(cartControllerProvider, (_, _) {});
  return container;
}

class _Repository implements CartRepository {
  _Repository({
    this.kind = CartFailureKind.timeout,
    this.applyBeforeFailure = true,
  });
  final CartFailureKind kind;
  final bool applyBeforeFailure;
  Cart current = _cart(1);
  int reads = 0;
  int writes = 0;
  bool failRead = false;
  bool failWrite = true;
  Completer<Cart>? readGate;
  @override
  Future<Cart> getCart() async {
    reads++;
    if (failRead) {
      throw const CartRepositoryException(
        kind: CartFailureKind.connection,
        message: 'Offline',
      );
    }
    return readGate == null ? current : await readGate!.future;
  }

  Future<Cart> _write(Cart next) async {
    writes++;
    if (applyBeforeFailure) current = next;
    if (failWrite) {
      throw CartRepositoryException(
        kind: kind,
        message: 'Write response unavailable',
      );
    }
    return current;
  }

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const [],
  }) => _write(_cart(current.itemsCount + quantity));
  @override
  Future<Cart> updateItem({required String key, required int quantity}) =>
      _write(_cart(quantity));
  @override
  Future<Cart> removeItem(String key) => _write(_cart(0));
  @override
  Future<Cart> applyCoupon(String code) =>
      _write(_cart(current.itemsCount, coupon: code));
  @override
  Future<Cart> removeCoupon(String code) => _write(_cart(current.itemsCount));
}

Cart _cart(int quantity, {String? coupon}) {
  final json = cartJsonFixture(itemsCount: quantity);
  if (quantity == 0) {
    json['items'] = <dynamic>[];
  } else {
    (json['items'] as List).single['quantity'] = quantity;
    (json['items'] as List).single['images'] = <dynamic>[];
  }
  if (coupon == null) {
    json['coupons'] = <dynamic>[];
  } else {
    (json['coupons'] as List).single['code'] = coupon;
  }
  return CartModel.fromJson(json).toEntity();
}
