import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/wishlist/presentation/wishlist_screen.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

import '../support/wishlist_test_data.dart';

void main() {
  testWidgets('shows an empty wishlist without the local-only banner', (
    WidgetTester tester,
  ) async {
    bool continued = false;
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: FakeWishlistRepository(),
          catalogRepository: FakeWishlistCatalogRepository(),
          onContinueShopping: () => continued = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-local-only-notice')), findsNothing);
    expect(
      find.text('Saved on this device for this store only.'),
      findsNothing,
    );
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
    expect(find.text('Your wishlist is empty'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wishlist-continue-shopping')));
    expect(continued, isTrue);
  });

  testWidgets('hydrates products, opens one, and removes it locally', (
    WidgetTester tester,
  ) async {
    CatalogProduct? opened;
    final FakeWishlistRepository wishlist = FakeWishlistRepository(
      ids: <int>[1],
    );
    await tester.pumpWidget(
      _testApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: WishlistScreen(
            repository: wishlist,
            catalogRepository: FakeWishlistCatalogRepository(
              products: const <CatalogProduct>[wishlistProductOne],
            ),
            onProductTap: (CatalogProduct product) => opened = product,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-grid')), findsOneWidget);
    expect(find.text('Everyday Jacket'), findsOneWidget);
    expect(find.text(r'$85.00'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('1 item'), findsNothing);
    expect(find.byType(CmsPageAppBar), findsOneWidget);
    final double logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester
          .getCenter(find.byKey(const Key('commerce-app-bar-title')))
          .dx,
      closeTo(logicalWidth / 2, 0.5),
    );

    await tester.tap(find.byKey(const Key('wishlist-product-1')));
    expect(opened?.id, 1);
    await tester.tap(find.byKey(const Key('wishlist-remove-1')));
    await tester.pumpAndSettle();

    expect(wishlist.ids, isEmpty);
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
    expect(find.text('Removed from wishlist'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Removed from wishlist'), findsNothing);
  });

  testWidgets('renders a responsive RTL grid', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: WishlistScreen(
            repository: FakeWishlistRepository(ids: <int>[1, 2, 3]),
            catalogRepository: FakeWishlistCatalogRepository(
              products: const <CatalogProduct>[
                wishlistProductOne,
                wishlistProductTwo,
                wishlistProductThree,
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext gridContext = tester.element(
      find.byKey(const Key('wishlist-grid')),
    );
    expect(Directionality.of(gridContext), TextDirection.rtl);
    final GridView grid = tester.widget<GridView>(
      find.byKey(const Key('wishlist-grid')),
    );
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(grid.padding?.resolve(TextDirection.rtl).top, 24);
  });

  testWidgets('shows a retryable load error', (WidgetTester tester) async {
    final FakeWishlistRepository wishlist = FakeWishlistRepository(
      onLoad: () async => throw StateError('read failed'),
    );
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: wishlist,
          catalogRepository: FakeWishlistCatalogRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-load-error')), findsOneWidget);
    wishlist.onLoad = null;
    await tester.tap(find.byKey(const Key('wishlist-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
  });

  testWidgets('keeps the item visible when local removal fails', (
    WidgetTester tester,
  ) async {
    final FakeWishlistRepository wishlist = FakeWishlistRepository(
      ids: <int>[1],
      onSave: (_) async => throw StateError('disk full'),
    );
    await tester.pumpWidget(
      _testApp(
        WishlistScreen(
          repository: wishlist,
          catalogRepository: FakeWishlistCatalogRepository(
            products: const <CatalogProduct>[wishlistProductOne],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wishlist-remove-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wishlist-product-1')), findsOneWidget);
    expect(find.byKey(const Key('wishlist-mutation-error')), findsOneWidget);
  });
}

Widget _testApp(Widget home) {
  return ProviderScope(
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}
