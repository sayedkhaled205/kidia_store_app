import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

import '../support/product_test_data.dart';

void main() {
  testWidgets('renders product content and explains a disconnected cart', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: simpleProduct.id,
          repository: ProductFakeCatalogRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Everyday Dress'), findsWidgets);
    expect(find.byKey(const Key('product-current-price')), findsOneWidget);
    expect(find.text(r'$79.99'), findsOneWidget);
    expect(find.text('Soft & comfortable.'), findsNothing);
    expect(find.byKey(const Key('product-brand-section')), findsOneWidget);
    expect(find.text('Kidia'), findsOneWidget);
    expect(find.text('Product'), findsNothing);
    expect(find.byKey(const Key('commerce-app-bar-title')), findsOneWidget);
    expect(find.byType(CmsPageAppBar), findsOneWidget);
    expect(find.text('In stock'), findsNothing);
    expect(find.byKey(const Key('add-to-cart-button')), findsOneWidget);
    expect(
      find.text('Cart connection is not available in this build yet.'),
      findsOneWidget,
    );

    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('wishlist heart reflects add and remove state', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    bool saved = false;
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: simpleProduct.id,
          repository: ProductFakeCatalogRepository(),
          isWishlisted: (int productId) async => saved,
          onWishlistToggle: (_) async {
            saved = !saved;
            return saved;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-wishlist-button')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    final IconButton added = tester.widget<IconButton>(
      find.byKey(const Key('product-wishlist-button')),
    );
    expect(added.color, Colors.red);

    await tester.tap(find.byKey(const Key('product-wishlist-button')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('passes quantity to the add-to-cart integration callback', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    ProductPurchaseSelection? captured;
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: simpleProduct.id,
          repository: ProductFakeCatalogRepository(),
          onAddToCart: (ProductPurchaseSelection selection) async {
            captured = selection;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quantity-increment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();

    expect(captured?.productId, simpleProduct.id);
    expect(captured?.variationId, isNull);
    expect(captured?.quantity, 2);
    expect(find.text('Added to cart'), findsOneWidget);
  });

  testWidgets('requires a valid variation then exposes its price to the UI', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    ProductPurchaseSelection? captured;
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: variableProduct.id,
          repository: ProductFakeCatalogRepository(
            product: variableProduct,
            variations: testVariations,
          ),
          onAddToCart: (ProductPurchaseSelection selection) async {
            captured = selection;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose the product options first.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-option-pa_color-blue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('product-option-pa_size-m')));
    await tester.pumpAndSettle();

    expect(find.text(r'$69.99'), findsOneWidget);
    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();
    expect(captured?.variationId, 103);
  });

  testWidgets('shows a retryable load error', (WidgetTester tester) async {
    _useTallSurface(tester);
    final ProductFakeCatalogRepository repository =
        ProductFakeCatalogRepository(
          productError: const CatalogRepositoryException(
            kind: StoreApiFailureKind.connection,
            message: 'Store is offline.',
          ),
        );
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: simpleProduct.id,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Store is offline.'), findsOneWidget);
    repository.productError = null;
    await tester.tap(find.byKey(const Key('product-retry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Everyday Dress'), findsWidgets);
  });

  testWidgets('keeps the product layout usable in RTL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: ProductDetailScreen(
            productId: simpleProduct.id,
            repository: ProductFakeCatalogRepository(),
            isWishlisted: (int productId) async => false,
            onWishlistToggle: (product) async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext productContext = tester.element(
      find.byKey(const Key('product-detail-scroll')),
    );
    expect(Directionality.of(productContext), TextDirection.rtl);
    expect(find.byKey(const Key('add-to-cart-button')), findsOneWidget);
    final Finder cart = find.byKey(const Key('product-cart-button'));
    final Finder heart = find.byKey(const Key('product-wishlist-button'));
    expect(tester.getCenter(cart).dx, lessThan(tester.getCenter(heart).dx));
    expect(tester.widget<IconButton>(cart).onPressed, isNotNull);
  });
}

Widget _testApp(Widget home) {
  return ProviderScope(
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
