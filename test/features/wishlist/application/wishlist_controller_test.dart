import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/wishlist/application/wishlist_controller.dart';

import '../support/wishlist_test_data.dart';

void main() {
  group('WishlistController', () {
    test(
      'hydrates include ids and preserves the locally saved order',
      () async {
        final FakeWishlistRepository wishlist = FakeWishlistRepository(
          ids: <int>[3, 1, 2, 1, -5],
        );
        final FakeWishlistCatalogRepository catalog =
            FakeWishlistCatalogRepository(
              products: const <CatalogProduct>[
                wishlistProductOne,
                wishlistProductTwo,
                wishlistProductThree,
              ],
            );
        final WishlistController controller = WishlistController(
          repository: wishlist,
          catalogRepository: catalog,
        );
        addTearDown(controller.dispose);

        await controller.load();

        expect(controller.status, WishlistStatus.ready);
        expect(controller.productIds, <int>[3, 1, 2]);
        expect(controller.products.map((CatalogProduct item) => item.id), <int>[
          3,
          1,
          2,
        ]);
        expect(catalog.productQueries, hasLength(1));
        expect(catalog.productQueries.single.includeIds, <int>[3, 1, 2]);
        expect(catalog.productQueries.single.perPage, 3);
      },
    );

    test('ignores a stale hydration response after a newer refresh', () async {
      final Completer<CatalogPage<CatalogProduct>> stale =
          Completer<CatalogPage<CatalogProduct>>();
      final Completer<CatalogPage<CatalogProduct>> fresh =
          Completer<CatalogPage<CatalogProduct>>();
      int request = 0;
      final FakeWishlistRepository wishlist = FakeWishlistRepository(
        ids: <int>[1],
      );
      final FakeWishlistCatalogRepository catalog =
          FakeWishlistCatalogRepository(
            onGetProducts: (_) => request++ == 0 ? stale.future : fresh.future,
          );
      final WishlistController controller = WishlistController(
        repository: wishlist,
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);

      final Future<void> firstLoad = controller.load();
      await _waitFor(() => catalog.productQueries.length == 1);
      wishlist.ids = <int>[2];
      final Future<void> secondLoad = controller.refresh();
      await _waitFor(() => catalog.productQueries.length == 2);

      fresh.complete(catalogPage(<CatalogProduct>[wishlistProductTwo]));
      await secondLoad;
      stale.complete(catalogPage(<CatalogProduct>[wishlistProductOne]));
      await firstLoad;

      expect(controller.productIds, <int>[2]);
      expect(controller.products.single.name, 'Classic Shirt');
    });

    test('adds, removes and toggles with persisted newest-first ids', () async {
      final FakeWishlistRepository wishlist = FakeWishlistRepository();
      final FakeWishlistCatalogRepository catalog =
          FakeWishlistCatalogRepository(
            products: const <CatalogProduct>[
              wishlistProductOne,
              wishlistProductTwo,
            ],
          );
      final WishlistController controller = WishlistController(
        repository: wishlist,
        catalogRepository: catalog,
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(await controller.add(1, product: wishlistProductOne), isTrue);
      expect(await controller.add(2), isTrue);
      expect(catalog.productDetailCalls, 1);
      expect(controller.productIds, <int>[2, 1]);
      expect(wishlist.ids, <int>[2, 1]);

      expect(await controller.toggle(2), isTrue);
      expect(controller.productIds, <int>[1]);
      expect(await controller.toggle(2, product: wishlistProductTwo), isTrue);
      expect(controller.productIds, <int>[2, 1]);
      expect(await controller.remove(1), isTrue);
      expect(controller.productIds, <int>[2]);
    });

    test(
      'rolls back a failed local removal and exposes a safe error',
      () async {
        final FakeWishlistRepository wishlist = FakeWishlistRepository(
          ids: <int>[1],
        );
        final FakeWishlistCatalogRepository catalog =
            FakeWishlistCatalogRepository(
              products: const <CatalogProduct>[wishlistProductOne],
            );
        final WishlistController controller = WishlistController(
          repository: wishlist,
          catalogRepository: catalog,
        );
        addTearDown(controller.dispose);
        await controller.load();
        wishlist.onSave = (_) async => throw StateError('disk full');

        expect(await controller.remove(1), isFalse);
        expect(controller.contains(1), isTrue);
        expect(controller.products, hasLength(1));
        expect(controller.mutationError, isNotEmpty);
      },
    );

    test('prunes ids for products that no longer exist in the store', () async {
      final FakeWishlistRepository wishlist = FakeWishlistRepository(
        ids: <int>[1, 999],
      );
      final WishlistController controller = WishlistController(
        repository: wishlist,
        catalogRepository: FakeWishlistCatalogRepository(
          products: const <CatalogProduct>[wishlistProductOne],
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();
      await controller.add(1, product: wishlistProductOne);

      expect(controller.productIds, <int>[1]);
      expect(wishlist.ids, <int>[1]);
    });

    test('uses empty and failure states without leaking invalid ids', () async {
      final FakeWishlistRepository wishlist = FakeWishlistRepository(
        ids: <int>[-1, 0],
      );
      final WishlistController controller = WishlistController(
        repository: wishlist,
        catalogRepository: FakeWishlistCatalogRepository(),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.status, WishlistStatus.empty);

      wishlist.onLoad = () async => throw StateError('read failed');
      await controller.load();
      expect(controller.status, WishlistStatus.failure);
      expect(controller.loadError, isNotEmpty);
    });
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (int attempt = 0; attempt < 50; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for an asynchronous test condition.');
}
