import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import '../support/product_test_data.dart';

class MemoryWishlist implements WishlistRepository {
  MemoryWishlist(this.ids);
  List<int> ids;
  int writes = 0;
  @override
  Future<List<int>> loadProductIds() async => List.of(ids);
  @override
  Future<void> saveProductIds(List<int> value) async {
    ids = List.of(value);
    writes++;
  }
}

GoRoute productRoute(List<RouteBase> routes) {
  for (final route in routes) {
    if (route is GoRoute && route.path == 'product/:productId') return route;
    final children = route is StatefulShellRoute
        ? route.branches.expand((branch) => branch.routes).toList()
        : route is ShellRoute
        ? route.routes
        : route is GoRoute
        ? route.routes
        : <RouteBase>[];
    try {
      return productRoute(children);
    } on StateError {
      /* next sibling */
    }
  }
  throw StateError('Product route not found');
}

void main() {
  for (final scenario in ['cancel', 'add', 'already-saved', 'owner-change']) {
    testWidgets('actual product route wishlist $scenario', (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final guest = MemoryWishlist([]);
      final customer = MemoryWishlist(
        scenario == 'already-saved' ? [simpleProduct.id] : [],
      );
      MemoryWishlist owner = guest;
      var access = const WishlistAccess(requiresSignIn: true);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          wishlistRepositoryProvider.overrideWith((ref) => owner),
          wishlistAccessProvider.overrideWith((ref) {
            ref.watch(wishlistRepositoryProvider);
            return access;
          }),
          catalogRepositoryProvider.overrideWithValue(
            ProductFakeCatalogRepository(),
          ),
          cmsPageLayoutProvider(
            'product',
          ).overrideWithValue(AsyncData(CmsPageLayout.fallback('product'))),
        ],
      );
      final original = createAppRouter();
      final builder = productRoute(original.configuration.routes).builder!;
      final router = GoRouter(
        initialLocation: '/product/${simpleProduct.id}',
        routes: [
          GoRoute(path: '/product/:productId', builder: builder),
          GoRoute(
            path: '/auth',
            builder: (context, state) => Scaffold(
              body: TextButton(
                key: const Key('fixture-auth-result'),
                onPressed: () {
                  if (scenario != 'cancel') {
                    owner = customer;
                    access = const WishlistAccess(
                      requiresSignIn: true,
                      authenticated: true,
                    );
                    container.invalidate(wishlistRepositoryProvider);
                  }
                  context.pop(scenario != 'cancel');
                },
                child: const Text('Auth result'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(original.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario == 'owner-change') {
        expect(find.byIcon(Icons.favorite_rounded), findsNothing);
        customer.ids = [simpleProduct.id];
        owner = customer;
        access = const WishlistAccess(
          requiresSignIn: true,
          authenticated: true,
        );
        container.invalidate(wishlistRepositoryProvider);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
      } else {
        await tester.tap(find.byKey(const Key('product-wishlist-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fixture-auth-result')), findsOneWidget);
        await tester.tap(find.byKey(const Key('fixture-auth-result')));
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsOneWidget);
        expect(guest.writes, 0);
        if (scenario == 'cancel') {
          expect(customer.writes, 0);
          expect(find.byIcon(Icons.favorite_rounded), findsNothing);
        } else {
          expect(customer.ids, [simpleProduct.id]);
          expect(customer.writes, scenario == 'already-saved' ? 0 : 1);
          expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });
  }
}
