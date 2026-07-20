import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/product/application/product_detail_controller.dart';
import 'package:kidia_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

import '../support/product_test_data.dart';

void main() {
  testWidgets('product share opens the real product link actions', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    final CatalogProduct shareProduct = CatalogProduct(
      id: 88,
      name: 'Share Dress',
      slug: 'share-dress',
      type: 'simple',
      permalink: Uri.parse('https://shop.example.com/product/share-dress'),
      prices: testMoney,
      isPurchasable: true,
      isInStock: true,
    );
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: shareProduct.id,
          repository: ProductFakeCatalogRepository(product: shareProduct),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('product-footer-icon-box-share')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product-share-sheet')), findsOneWidget);
    expect(find.text('Share Dress'), findsWidgets);
    expect(find.byKey(const Key('share-facebook')), findsOneWidget);
    expect(find.byKey(const Key('share-whatsapp')), findsOneWidget);
    expect(find.byKey(const Key('share-messenger')), findsOneWidget);
    expect(find.byKey(const Key('share-copy-link')), findsOneWidget);
    expect(find.byKey(const Key('share-more')), findsOneWidget);
  });

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
	expect(find.byKey(const Key('commerce-app-bar-title')), findsNothing);
    expect(find.byType(CmsPageAppBar), findsOneWidget);
    expect(find.text('In stock'), findsOneWidget);
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
    expect(find.text('Added to cart'), findsNothing);
    expect(find.text('تمت الإضافة إلى السلة'), findsNothing);
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

    expect(
      find.byKey(const Key('add-to-cart-disabled-reason')),
      findsNothing,
    );
    final FilledButton initialButton = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(initialButton.onPressed, isNotNull);
    expect(
      initialButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF2F806E).withValues(alpha: 0.48),
    );
    expect(find.text('Choose the product options first.'), findsNothing);
    expect(find.text('اختر خيارات المنتج أولًا.'), findsNothing);

    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();

    final Finder optionsSheet = find.byKey(const Key('product-options-sheet'));
    expect(optionsSheet, findsOneWidget);
    expect(find.text('Choose product options'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: optionsSheet,
        matching: find.byKey(const Key('product-option-pa_color-blue')),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: optionsSheet,
        matching: find.byKey(const Key('product-option-pa_size-m')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$69.99'), findsOneWidget);
    final FilledButton selectedButton = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(
      selectedButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF2F806E),
    );
    expect(find.byKey(const Key('add-to-cart-disabled-reason')), findsNothing);
    expect(find.byKey(const Key('add-to-cart-error')), findsNothing);
    final FilledButton sheetButton = tester.widget<FilledButton>(
      find.byKey(const Key('product-options-sheet-add')),
    );
    expect(sheetButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('product-options-sheet-add')));
    await tester.pumpAndSettle();
    expect(optionsSheet, findsNothing);
    expect(captured?.variationId, 103);
  });

  testWidgets('adds directly when product options were already selected', (
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

    await tester.tap(find.byKey(const Key('product-option-pa_color-blue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('product-option-pa_size-m')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product-options-sheet')), findsNothing);
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
    final Finder heart = find.byKey(const Key('product-wishlist-button'));
	expect(heart, findsOneWidget);
	expect(tester.widget<IconButton>(heart).onPressed, isNotNull);
  });

  testWidgets('shows product footer action text in Arabic', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: simpleProduct.id,
          repository: ProductFakeCatalogRepository(),
          onAddToCart: (ProductPurchaseSelection selection) async {},
          onShareRequested: (_) {},
          onWishlistToggle: (_) async => true,
        ),
        locale: const Locale('ar'),
        productLayout: _liveStyleProductLayout(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مشاركة'), findsOneWidget);
    expect(find.text('المفضلة'), findsOneWidget);
    expect(find.text('أضف إلى السلة'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Like'), findsNothing);
    expect(find.text('Add to bag'), findsNothing);
    expect(
      tester.widget<SizedBox>(find.byKey(const Key('product-footer-size'))).height,
      84,
    );
    final Size footerSize = tester.getSize(
      find.byKey(const Key('product-footer-size')),
    );
    final Size addToCartSize = tester.getSize(
      find.byKey(const Key('product-add-to-cart-size')),
    );
    expect(addToCartSize.height, 48);
    expect(addToCartSize.width / footerSize.width, closeTo(0.60, 0.01));
    final FilledButton addToCartButton = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(
      addToCartButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    final OutlinedBorder? addToCartShape = addToCartButton.style?.shape?.resolve(
      <WidgetState>{},
    );
    expect(addToCartShape, isA<RoundedRectangleBorder>());
    expect(
      (addToCartShape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(24),
    );
    final SizedBox shareBox = tester.widget<SizedBox>(
      find.byKey(const Key('product-footer-icon-box-share')),
    );
    final SizedBox likeBox = tester.widget<SizedBox>(
      find.byKey(const Key('product-footer-icon-box-like')),
    );
    expect(shareBox.width, 32);
    expect(shareBox.height, 32);
    expect(likeBox.width, shareBox.width);
    expect(likeBox.height, shareBox.height);
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(
              const Key('product-footer-icon-label-gap-share'),
            ),
          )
          .height,
      9,
    );
    expect(
      tester
          .getCenter(find.byKey(const Key('product-footer-icon-box-share')))
          .dy,
      tester
          .getCenter(find.byKey(const Key('product-footer-icon-box-like')))
          .dy,
    );
  });

  testWidgets('centers the configured button width inside its footer column', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(
        ProductDetailScreen(
          productId: simpleProduct.id,
          repository: ProductFakeCatalogRepository(),
          onAddToCart: (ProductPurchaseSelection selection) async {},
        ),
        productLayout: _liveStyleProductLayout(
          layoutJson: <String, dynamic>{
            'rows': <Map<String, dynamic>>[
              <String, dynamic>{
                'columns': <Map<String, dynamic>>[
                  <String, dynamic>{
				    'width': 30,
                    'items': <String>['share', 'like'],
                  },
                  <String, dynamic>{
				    'width': 70,
                    'items': <String>['add_to_cart'],
                  },
                ],
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Size footerSize = tester.getSize(
      find.byKey(const Key('product-footer-size')),
    );
    final Size addToCartColumn = tester.getSize(
      find.byKey(const Key('product-footer-column-add_to_cart')),
    );
    final Size addToCartButton = tester.getSize(
      find.byKey(const Key('product-add-to-cart-size')),
    );

    expect(addToCartColumn.width / footerSize.width, closeTo(0.70, 0.01));
    expect(addToCartButton.width / footerSize.width, closeTo(0.60, 0.01));
    expect(
      tester.getCenter(find.byKey(const Key('product-add-to-cart-size'))).dx,
      closeTo(
        tester
            .getCenter(
              find.byKey(const Key('product-footer-column-add_to_cart')),
            )
            .dx,
        0.5,
      ),
    );
  });
}

Widget _testApp(
  Widget home, {
  Locale? locale,
  CmsPageLayout? productLayout,
}) {
  return ProviderScope(
    overrides: [
      if (productLayout != null)
        cmsPageLayoutProvider(
          'product',
        ).overrideWith((ref) async => productLayout),
    ],
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(useMaterial3: true),
      home: home,
    ),
  );
}

CmsPageLayout _liveStyleProductLayout({Map<String, dynamic>? layoutJson}) {
  final CmsPageLayout fallback = CmsPageLayout.fallback('product');
  return CmsPageLayout(
    page: fallback.page,
    header: fallback.header,
    elements: fallback.elements,
    footer: CmsPageComponent(
      id: fallback.footer.id,
      type: fallback.footer.type,
      enabled: true,
      settings: <String, dynamic>{
        ...fallback.footer.settings,
        'style': 'navigation',
        'share_label': 'Share',
        'like_label': 'Like',
        'add_to_cart_label': 'Add to bag',
        'button_width_percent': 60,
        'button_height': 48,
        'button_style': 'outline',
        'button_shape': 'pill',
        'button_border_color': '#2F806E',
        'button_border_width': 2,
        'icon_label_gap': 9,
        'layout_json': ?layoutJson,
      },
    ),
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
