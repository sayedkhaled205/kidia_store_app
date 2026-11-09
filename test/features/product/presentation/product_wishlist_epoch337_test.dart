import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import '../support/product_test_data.dart';

Widget app({
  required ProductFakeCatalogRepository repo,
  required Object owner,
  required Future<bool> Function(int) lookup,
  required ProductWishlistToggleCallback toggle,
}) => ProviderScope(
  overrides: [
    cmsPageLayoutProvider(
      'product',
    ).overrideWithValue(AsyncData(CmsPageLayout.fallback('product'))),
  ],
  child: MaterialApp(
    home: ProductDetailScreen(
      productId: repo.product.id,
      repository: repo,
      wishlistIdentity: owner,
      isWishlisted: lookup,
      onWishlistToggle: toggle,
    ),
  ),
);
void surface(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final oldCompletesFirst in [true, false]) {
    testWidgets(
      'owner switch retains newer mutation when old completes first $oldCompletesFirst',
      (tester) async {
        surface(tester);
        final repo = ProductFakeCatalogRepository();
        final oldToggle = Completer<bool>();
        final newToggle = Completer<bool>();
        var bSaved = false;
        var bToggles = 0;
        await tester.pumpWidget(
          app(
            repo: repo,
            owner: 'A',
            lookup: (_) async => false,
            toggle: (_) => oldToggle.future,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('product-wishlist-button')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          app(
            repo: repo,
            owner: 'B',
            lookup: (_) async => bSaved,
            toggle: (_) {
              bToggles++;
              return newToggle.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.favorite_rounded), findsNothing);
        await tester.tap(find.byKey(const Key('product-wishlist-button')));
        await tester.pumpAndSettle();
        if (oldCompletesFirst) {
          oldToggle.complete(false);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('product-wishlist-button')));
          await tester.pumpAndSettle();
          expect(
            bToggles,
            1,
            reason: 'Old finally must not unlock the current owner mutation.',
          );
        }
        bSaved = true;
        newToggle.complete(true);
        await tester.pumpAndSettle();
        if (!oldCompletesFirst) {
          oldToggle.complete(false);
          await tester.pumpAndSettle();
        }
        expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
        expect(bToggles, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'old product lookup and toggle cannot mutate a replacement product',
    (tester) async {
      surface(tester);
      final lookupA = Completer<bool>();
      final toggleA = Completer<bool>();
      final repoA = ProductFakeCatalogRepository();
      final repoB = ProductFakeCatalogRepository(
        product: variableProduct,
        variations: testVariations,
      );
      await tester.pumpWidget(
        app(
          repo: repoA,
          owner: 'same',
          lookup: (_) => lookupA.future,
          toggle: (_) => toggleA.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-wishlist-button')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          repo: repoB,
          owner: 'same',
          lookup: (_) async => false,
          toggle: (_) async => true,
        ),
      );
      await tester.pumpAndSettle();
      lookupA.complete(true);
      toggleA.complete(true);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
