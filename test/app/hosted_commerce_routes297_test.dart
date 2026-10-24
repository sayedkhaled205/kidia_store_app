import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_button.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_appearance.dart';
import 'package:mobishop_store_app/features/wishlist/data/shared_preferences_wishlist_repository.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/app/hosted_commerce_screen297.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';

void main() {
  final platform = AppConfig.commercePlatform;
  if (platform != CommercePlatform.wooCommerce) {
    testWidgets('foreign product favorites remain local without Woo sign-in', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith(
              (ref) => throw StateError('Woo auth must not initialize'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProductWishlistButton(
                productId: 42,
                appearance: ProductWishlistAppearance(enabled: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-card-wishlist-42')));
      await tester.pumpAndSettle();
      expect(
        await SharedPreferencesWishlistRepository.forConfiguredStore()
            .loadProductIds(),
        [42],
      );
      expect(tester.takeException(), isNull);
    });
  }
  final hostedRoutes = platform == CommercePlatform.shopify
      ? ['/account', '/auth', '/orders', '/orders/23', '/profile', '/addresses']
      : <String>[];
  for (final route in hostedRoutes) {
    testWidgets(
      '$route opens own platform website and never initializes Woo auth/cart',
      (tester) async {
        final opened = <Uri>[];
        final router = createAppRouter(initialLocation: route);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWith(
                (ref) => throw StateError('Woo auth must not initialize'),
              ),
              cartRepositoryProvider.overrideWith(
                (ref) => throw StateError('Woo cart must not initialize'),
              ),
              hostedCommerceLauncher297Provider.overrideWithValue((uri) async {
                opened.add(uri);
                return true;
              }),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hosted-commerce-screen')), findsOneWidget);
        expect(opened, hasLength(1));
        expect(
          opened.single.host,
          AppConfig.commerceConnection.storeOrigin.host,
        );
        expect(opened.single.path, isNot(contains('wp-json')));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('website handoff failure provides retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostedCommerceLauncher297Provider.overrideWithValue((uri) async {
            attempts++;
            return attempts > 1;
          }),
        ],
        child: MaterialApp(
          home: HostedCommerceScreen297(
            destination: Uri.parse('https://shop.example/account'),
            route: '/account',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to open the store. Please retry.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue on store'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Unable to open the store. Please retry.'), findsNothing);
  });
}
