import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:kidia_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:kidia_store_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';

import '../data/cart_test_fixture.dart';

void main() {
  test(
    'loads cart, exposes badge count, and keeps pending item state',
    () async {
      final _FakeCartRepository repository = _FakeCartRepository();
      final ProviderContainer container = _container(repository);
      addTearDown(container.dispose);

      final CartViewState initial = await container.read(
        cartControllerProvider.future,
      );
      expect(initial.cart.itemsCount, 1);
      expect(container.read(cartBadgeCountProvider), 1);

      repository.updateCompleter = Completer<Cart>();
      final Future<CartActionResult> operation = container
          .read(cartControllerProvider.notifier)
          .updateQuantity(initial.cart.items.single, 2);
      await Future<void>.delayed(Duration.zero);

      expect(
        container
            .read(cartControllerProvider)
            .requireValue
            .pendingItemKeys
            .single,
        'cart-key-1',
      );

      repository.updateCompleter!.complete(_fixtureCart(quantity: 2));
      expect((await operation).succeeded, isTrue);
      expect(container.read(cartBadgeCountProvider), 2);
      expect(
        container
            .read(cartControllerProvider)
            .requireValue
            .cart
            .items
            .single
            .quantity,
        2,
      );
    },
  );

  test('uses server-authoritative cart after a conflict', () async {
    final Cart serverCart = _fixtureCart(quantity: 3);
    final _FakeCartRepository repository = _FakeCartRepository(
      updateError: CartRepositoryException(
        kind: CartFailureKind.conflict,
        message: 'The item changed in the store.',
        statusCode: 409,
        serverCart: serverCart,
      ),
    );
    final ProviderContainer container = _container(repository);
    addTearDown(container.dispose);
    final CartViewState initial = await container.read(
      cartControllerProvider.future,
    );

    final CartActionResult result = await container
        .read(cartControllerProvider.notifier)
        .updateQuantity(initial.cart.items.single, 2);

    expect(result.succeeded, isFalse);
    expect(result.message, 'The item changed in the store.');
    expect(
      container
          .read(cartControllerProvider)
          .requireValue
          .cart
          .items
          .single
          .quantity,
      3,
    );
  });

  test('product purchase adapter forwards a variation selection', () async {
    final _FakeCartRepository repository = _FakeCartRepository();
    final ProviderContainer container = _container(repository);
    addTearDown(container.dispose);
    await container.read(cartControllerProvider.future);

    final AddProductPurchaseSelection addSelection = container.read(
      addProductPurchaseSelectionProvider,
    );
    final CartActionResult result = await addSelection(
      ProductPurchaseSelection(
        productId: 88,
        quantity: 2,
        variation: const <CartItemVariation>[
          CartItemVariation(attribute: 'pa_size', value: 'large'),
        ],
      ),
    );

    expect(result.succeeded, isTrue);
    expect(repository.lastAddedProductId, 88);
    expect(repository.lastAddedQuantity, 2);
    expect(repository.lastVariation.single.attribute, 'pa_size');
    expect(repository.lastVariation.single.value, 'large');
  });
}

ProviderContainer _container(CartRepository repository) {
  return ProviderContainer(
    overrides: [cartRepositoryProvider.overrideWithValue(repository)],
  );
}

class _FakeCartRepository implements CartRepository {
  _FakeCartRepository({this.updateError}) : current = _fixtureCart();

  Cart current;
  final CartRepositoryException? updateError;
  Completer<Cart>? updateCompleter;
  int? lastAddedProductId;
  int? lastAddedQuantity;
  List<CartItemVariation> lastVariation = const <CartItemVariation>[];

  @override
  Future<Cart> getCart() async => current;

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  }) async {
    lastAddedProductId = productId;
    lastAddedQuantity = quantity;
    lastVariation = variation;
    return current;
  }

  @override
  Future<Cart> updateItem({required String key, required int quantity}) async {
    if (updateError != null) {
      throw updateError!;
    }
    if (updateCompleter != null) {
      current = await updateCompleter!.future;
      return current;
    }
    current = _fixtureCart(quantity: quantity);
    return current;
  }

  @override
  Future<Cart> removeItem(String key) async {
    current = _fixtureCart(empty: true);
    return current;
  }

  @override
  Future<Cart> applyCoupon(String code) async {
    current = _fixtureCart(couponCode: code);
    return current;
  }

  @override
  Future<Cart> removeCoupon(String code) async {
    current = _fixtureCart(includeCoupon: false);
    return current;
  }
}

Cart _fixtureCart({
  int quantity = 1,
  bool empty = false,
  bool includeCoupon = true,
  String couponCode = 'save10',
}) {
  final Map<String, dynamic> json = cartJsonFixture(
    itemsCount: empty ? 0 : quantity,
  );
  if (empty) {
    json['items'] = <dynamic>[];
    json['coupons'] = <dynamic>[];
  } else {
    final Map<String, dynamic> item =
        (json['items'] as List<dynamic>).single as Map<String, dynamic>;
    item['quantity'] = quantity;
    item['images'] = <dynamic>[];
    if (!includeCoupon) {
      json['coupons'] = <dynamic>[];
    } else {
      final Map<String, dynamic> coupon =
          (json['coupons'] as List<dynamic>).single as Map<String, dynamic>;
      coupon['code'] = couponCode;
    }
  }
  return CartModel.fromJson(json).toEntity();
}
