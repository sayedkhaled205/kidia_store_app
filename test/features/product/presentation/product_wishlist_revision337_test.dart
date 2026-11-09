import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import '../support/product_test_data.dart';

void main() {
  testWidgets(
    'late initial wishlist read must not overwrite a successful toggle',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final lookup = Completer<bool>();
      var toggles = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cmsPageLayoutProvider(
              'product',
            ).overrideWithValue(AsyncData(CmsPageLayout.fallback('product'))),
          ],
          child: MaterialApp(
            home: ProductDetailScreen(
              productId: simpleProduct.id,
              repository: ProductFakeCatalogRepository(),
              isWishlisted: (_) => lookup.future,
              onWishlistToggle: (_) async {
                toggles++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-wishlist-button')));
      await tester.pumpAndSettle();
      expect(toggles, 1);
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
      lookup.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.favorite_rounded),
        findsWidgets,
        reason:
            'The earlier GET snapshot must not revert a later successful mutation.',
      );
    },
  );
  testWidgets('changed wishlist owner callbacks reload heart for same product', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ProductFakeCatalogRepository();
    Future<bool> lookupA(int _) async => false;
    var lookupBCalls = 0;
    Future<bool> lookupB(int _) async {
      lookupBCalls++;
      return true;
    }

    Widget app(Future<bool> Function(int) lookup) => ProviderScope(
      overrides: [
        cmsPageLayoutProvider(
          'product',
        ).overrideWithValue(AsyncData(CmsPageLayout.fallback('product'))),
      ],
      child: MaterialApp(
        home: ProductDetailScreen(
          productId: simpleProduct.id,
          repository: repository,
          isWishlisted: lookup,
          onWishlistToggle: (_) async => true,
        ),
      ),
    );
    await tester.pumpWidget(app(lookupA));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    await tester.pumpWidget(app(lookupB));
    await tester.pumpAndSettle();
    expect(
      lookupBCalls,
      1,
      reason:
          'A changed owner callback must be consulted even when product and catalog are unchanged.',
    );
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
  });
}
