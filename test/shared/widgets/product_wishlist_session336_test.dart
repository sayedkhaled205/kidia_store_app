import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_button.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_appearance.dart';

class _Repo implements WishlistRepository {
  _Repo(this.ids);
  List<int> ids;
  Future<List<int>>? pendingLoad;
  Completer<void>? pendingSave;
  @override
  Future<List<int>> loadProductIds() async => pendingLoad ?? List.of(ids);
  @override
  Future<void> saveProductIds(List<int> next) async {
    await pendingSave?.future;
    ids = List.of(next);
  }
}

void main() {
  for (final result in [
    'success',
    'already-saved',
    'cancel',
    'changed-product',
  ]) {
    testWidgets('guest wishlist intent after sign-in $result', (tester) async {
      final guest = _Repo([]);
      final customer = _Repo(result == 'already-saved' ? [7] : []);
      final product = ValueNotifier(7);
      addTearDown(product.dispose);
      final container = ProviderContainer(
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(guest),
          wishlistAccessProvider.overrideWithValue(
            const WishlistAccess(requiresSignIn: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: ValueListenableBuilder<int>(
                valueListenable: product,
                builder: (_, id, _) => ProductWishlistButton(
                  productId: id,
                  appearance: const ProductWishlistAppearance(enabled: true),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (result == 'cancel') {
                    context.pop(false);
                    return;
                  }
                  container.updateOverrides([
                    wishlistRepositoryProvider.overrideWithValue(customer),
                    wishlistAccessProvider.overrideWithValue(
                      const WishlistAccess(
                        requiresSignIn: true,
                        authenticated: true,
                      ),
                    ),
                  ]);
                  context.pop(true);
                },
                child: const Text('Complete fixture sign-in'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-card-wishlist-7')));
      await tester.pumpAndSettle();
      if (result == 'changed-product') {
        product.value = 8;
        await tester.pump();
      }
      await tester.tap(find.text('Complete fixture sign-in'));
      await tester.pumpAndSettle();
      expect(guest.ids, isEmpty);
      expect(
        customer.ids,
        ['success', 'already-saved'].contains(result) ? [7] : isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final lateOperation in ['none', 'load', 'save']) {
    testWidgets('mounted heart follows new repository after $lateOperation', (
      tester,
    ) async {
      final old = _Repo([]);
      final next = _Repo([7]);
      final load = Completer<List<int>>();
      if (lateOperation == 'load') old.pendingLoad = load.future;
      final container = ProviderContainer(
        overrides: [
          wishlistRepositoryProvider.overrideWithValue(old),
          wishlistAccessProvider.overrideWithValue(
            const WishlistAccess(requiresSignIn: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ProductWishlistButton(
                productId: 7,
                appearance: ProductWishlistAppearance(enabled: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      if (lateOperation == 'save') {
        old.pendingSave = Completer<void>();
        await tester.tap(find.byKey(const Key('product-card-wishlist-7')));
        await tester.pump();
      }
      container.updateOverrides([
        wishlistRepositoryProvider.overrideWithValue(next),
        wishlistAccessProvider.overrideWithValue(
          const WishlistAccess(requiresSignIn: false),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      if (lateOperation == 'load') load.complete([]);
      if (lateOperation == 'save') old.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('product-card-wishlist-7')));
      await tester.pumpAndSettle();
      expect(next.ids, isEmpty);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
