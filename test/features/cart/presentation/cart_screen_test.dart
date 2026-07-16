import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:kidia_store_app/features/cart/presentation/cart_screen.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_providers.dart';

import '../data/cart_test_fixture.dart';

void main() {
  testWidgets('renders loading then the localized empty RTL state', (
    WidgetTester tester,
  ) async {
    final Completer<Cart> cartCompleter = Completer<Cart>();
    final _WidgetCartRepository repository = _WidgetCartRepository(
      getCompleter: cartCompleter,
    );

    await _pumpCart(tester, repository, locale: const Locale('ar'));
    expect(find.byKey(const Key('cart-loading')), findsOneWidget);

    cartCompleter.complete(_cart(empty: true));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('سلتك فارغة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(CartScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('shows an initial error and retries successfully', (
    WidgetTester tester,
  ) async {
    final _WidgetCartRepository repository = _WidgetCartRepository(
      remainingGetFailures: 1,
      current: _cart(empty: true),
    );
    await _pumpCart(tester, repository);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('The store could not load your cart.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cart-retry-button')));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(repository.getCalls, 2);
  });

  testWidgets('updates quantity and confirms removal before deleting', (
    WidgetTester tester,
  ) async {
    final _WidgetCartRepository repository = _WidgetCartRepository();
    await _pumpCart(tester, repository);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Test product'), findsOneWidget);
    expect(find.text('1.530 د.ك'), findsOneWidget);

    await tester.tap(find.byKey(const Key('increase-cart-key-1')));
    await tester.pumpAndSettle();
    expect(repository.updatedQuantities, <int>[2]);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-cart-key-1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this item?'), findsOneWidget);
    expect(repository.removeCalls, isEmpty);

    await tester.tap(find.byKey(const Key('confirm-remove-button')));
    await tester.pumpAndSettle();
    expect(repository.removeCalls, <String>['cart-key-1']);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('applies a coupon and delegates checkout to the shell', (
    WidgetTester tester,
  ) async {
    final _WidgetCartRepository repository = _WidgetCartRepository();
    int checkoutCalls = 0;
    await _pumpCart(
      tester,
      repository,
      onCheckout: (BuildContext context, Cart cart) {
        checkoutCalls++;
      },
    );
    await tester.pumpAndSettle();
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('coupon-field')));
    await tester.enterText(find.byKey(const Key('coupon-field')), 'WELCOME');
    await tester.tap(find.byKey(const Key('apply-coupon-button')));
    await tester.pumpAndSettle();
    expect(repository.appliedCoupons, <String>['WELCOME']);
    expect(find.byKey(const Key('coupon-WELCOME')), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkout-button')));
    await tester.pump();
    expect(checkoutCalls, 1);
  });
}

Future<void> _pumpCart(
  WidgetTester tester,
  CartRepository repository, {
  Locale locale = const Locale('en'),
  CartCheckoutCallback? onCheckout,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(useMaterial3: true),
        home: CartScreen(onCheckout: onCheckout),
      ),
    ),
  );
}

class _WidgetCartRepository implements CartRepository {
  _WidgetCartRepository({
    this.getCompleter,
    this.remainingGetFailures = 0,
    Cart? current,
  }) : current = current ?? _cart();

  final Completer<Cart>? getCompleter;
  int remainingGetFailures;
  Cart current;
  int getCalls = 0;
  final List<int> updatedQuantities = <int>[];
  final List<String> removeCalls = <String>[];
  final List<String> appliedCoupons = <String>[];

  @override
  Future<Cart> getCart() async {
    getCalls++;
    if (remainingGetFailures > 0) {
      remainingGetFailures--;
      throw const CartRepositoryException(
        kind: CartFailureKind.connection,
        message: 'Offline',
      );
    }
    if (getCompleter != null) {
      return getCompleter!.future;
    }
    return current;
  }

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const <CartItemVariation>[],
  }) async {
    return current;
  }

  @override
  Future<Cart> updateItem({required String key, required int quantity}) async {
    updatedQuantities.add(quantity);
    current = _cart(quantity: quantity);
    return current;
  }

  @override
  Future<Cart> removeItem(String key) async {
    removeCalls.add(key);
    current = _cart(empty: true);
    return current;
  }

  @override
  Future<Cart> applyCoupon(String code) async {
    appliedCoupons.add(code);
    current = _cart(couponCode: code);
    return current;
  }

  @override
  Future<Cart> removeCoupon(String code) async {
    current = _cart(includeCoupon: false);
    return current;
  }
}

Cart _cart({
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
