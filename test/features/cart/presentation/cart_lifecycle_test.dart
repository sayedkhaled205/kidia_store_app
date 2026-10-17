import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/product/presentation/widgets/product_quick_add.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

import '../data/cart_test_fixture.dart';
import '../../product/support/product_test_data.dart';

void main() {
  test(
    'a saved product callback survives route disposal and cart invalidation',
    () async {
      final api = _CartApi();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final add = container.read(addProductPurchaseSelectionProvider);
      await container.pump(); // No cart screen or badge is watching.
      var result = await add(
        ProductPurchaseSelection(productId: 41, quantity: 1),
      );
      expect(result.succeeded, isTrue, reason: result.message);
      expect(api.addCalls, 1);
      container.invalidate(cartControllerProvider); // Checkout / route refresh.
      await container.pump();
      result = await add(ProductPurchaseSelection(productId: 41, quantity: 1));
      expect(result.succeeded, isTrue, reason: result.message);
      expect(api.addCalls, 2);
      expect(
        container.read(cartControllerProvider).requireValue.cart.itemsCount,
        2,
      );
    },
  );

  testWidgets(
    'quick add survives slow bootstrap, closing and reopening the sheet',
    (tester) async {
      final api = _CartApi()..bootstrap = Completer<StoreApiResponse>();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ProductQuickAddButton(productId: 41)),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('quick-add-product-41')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-quick-add-submit')));
      await tester.pump(const Duration(seconds: 2));
      expect(api.addCalls, 0);
      api.bootstrap!.complete(api.response());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.addCalls, 1);
      expect(find.byKey(const Key('product-quick-add-sheet')), findsNothing);
      await tester.tap(find.byKey(const Key('quick-add-product-41')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-quick-add-submit')));
      await tester.pumpAndSettle();
      expect(api.addCalls, 2);
      expect(
        container.read(cartControllerProvider).requireValue.cart.itemsCount,
        2,
      );
      expect(find.textContaining('session changed'), findsNothing);
    },
  );

  testWidgets(
    'the full product page can use its captured callback after several frames',
    (tester) async {
      final api = _CartApi();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final add = container.read(addProductPurchaseSelectionProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ProductDetailScreen(
              productId: 41,
              repository: container.read(catalogRepositoryProvider),
              onAddToCart: (selection) async {
                final result = await add(
                  ProductPurchaseSelection(
                    productId: selection.productId,
                    quantity: selection.quantity,
                  ),
                );
                if (!result.succeeded) throw StateError(result.message!);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('add-to-cart-button')));
      await tester.pumpAndSettle();
      expect(api.addCalls, 1);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('disposed'), findsNothing);
      expect(
        container.read(cartControllerProvider).requireValue.cart.itemsCount,
        1,
      );
    },
  );

  test(
    'changing customer during add rejects the stale result and clears their token',
    () async {
      final api = _CartApi();
      final container = _container(api);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final auth = container.read(authControllerProvider.notifier) as _Auth;
      auth.setOwner(1);
      await container.pump();
      await container.read(cartControllerProvider.future);
      api.pendingAdd = Completer<StoreApiResponse>();
      final pending = container.read(addProductPurchaseSelectionProvider)(
        ProductPurchaseSelection(productId: 41, quantity: 1),
      );
      await Future<void>.delayed(Duration.zero);
      auth.setOwner(2);
      await container.pump();
      expect(container.read(cartTokenStoreProvider).read(), isNot('cart-1'));
      api.pendingAdd!.complete(api.response(token: 'old-customer-cart'));
      expect((await pending).succeeded, isFalse);
      expect(
        container.read(cartTokenStoreProvider).read(),
        isNot('old-customer-cart'),
      );
    },
  );
}

ProviderContainer _container(_CartApi api) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_Auth.new),
    cartStoreApiClientProvider.overrideWithValue(api),
    cartApiTransportProvider.overrideWithValue(api),
    catalogRepositoryProvider.overrideWithValue(ProductFakeCatalogRepository()),
    cmsPageLayoutProvider(
      'product',
    ).overrideWith((ref) async => CmsPageLayout.fallback('product')),
  ],
);

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
  void setOwner(int id) => state = AsyncData(
    AuthSession(
      token: 'customer-$id',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      user: AuthUser(id: id, email: 'customer$id@example.test'),
    ),
  );
}

class _CartApi implements StoreApiClient, CartApiTransport {
  Completer<StoreApiResponse>? bootstrap;
  Completer<StoreApiResponse>? pendingAdd;
  int addCalls = 0;
  StoreApiResponse response({String token = 'cart-1'}) {
    final json = cartJsonFixture(itemsCount: addCalls);
    if (addCalls == 0) json['items'] = <dynamic>[];
    return StoreApiResponse(
      data: json,
      headers: {
        'cart-token': [token],
      },
    );
  }

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => bootstrap == null ? response() : await bootstrap!.future;
  @override
  Future<StoreApiResponse> request(
    CartApiMethod method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (path.endsWith('/add-item')) {
      addCalls++;
      if (pendingAdd != null) return pendingAdd!.future;
    }
    return response();
  }
}
