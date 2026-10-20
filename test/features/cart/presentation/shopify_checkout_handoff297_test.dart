import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_model.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/presentation/cart_screen.dart';
import 'package:mobishop_store_app/features/cart/presentation/controllers/cart_controller.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/compact_family_provider.dart';
import '../data/cart_test_fixture.dart';

class _DomainReader implements ShopifyStorefrontCartTransport {
  int reads = 0;
  @override
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    reads++;
    expect(document, contains('shop { primaryDomain { url } }'));
    return {
      'shop': {
        'primaryDomain': {'url': 'https://store.example'},
      },
    };
  }

  @override
  Future<Map<String, dynamic>> cartMutation(
    String document, {
    Map<String, dynamic> variables = const {},
  }) => throw StateError('No write');
}

class _CartController extends CartController {
  _CartController(this.cart);
  final Cart cart;
  @override
  Future<CartViewState> build() async => CartViewState(cart: cart);
}

Cart _cart(String checkout) {
  final json = cartJsonFixture();
  (json['items'] as List).single['images'] = <dynamic>[];
  final cart = CartModel.fromJson(json).toEntity();
  return Cart(
    items: cart.items,
    coupons: cart.coupons,
    totals: cart.totals,
    shippingAddress: cart.shippingAddress,
    billingAddress: cart.billingAddress,
    itemsCount: cart.itemsCount,
    itemsWeight: cart.itemsWeight,
    needsPayment: cart.needsPayment,
    needsShipping: cart.needsShipping,
    hasCalculatedShipping: cart.hasCalculatedShipping,
    paymentMethods: cart.paymentMethods,
    errors: cart.errors,
    checkoutUrl: Uri.parse(checkout),
  );
}

void main() {
  if (AppConfig.commercePlatform != CommercePlatform.shopify) return;
  for (final accepted in [true, false]) {
    testWidgets('Shopify checkout exact domain allowed=$accepted', (
      tester,
    ) async {
      final checkout = accepted
          ? 'https://store.example/cart/c/test?key=buyer-secret'
          : 'https://untrusted.example/cart/c/test?key=buyer-secret';
      final opened = <Uri>[];
      final reader = _DomainReader();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartControllerProvider.overrideWith(
              () => _CartController(_cart(checkout)),
            ),
            compactFamilyProvider.overrideWithValue(false),
            shopifyCartTransportProvider.overrideWithValue(reader),
            shopifyCheckoutLauncher297Provider.overrideWithValue((uri) async {
              opened.add(uri);
              return true;
            }),
          ],
          child: const MaterialApp(home: CartScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      await tester.tap(find.byKey(const Key('checkout-button')));
      await tester.pumpAndSettle();
      expect(reader.reads, 1);
      expect(opened, accepted ? [Uri.parse(checkout)] : isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
