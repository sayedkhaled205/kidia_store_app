import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/product/application/product_detail_controller.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

import '../support/product_test_data.dart';

void main() {
  for (final customLabel in [false, true]) {
    testWidgets('disabled reviews hide their navigation target (custom: $customLabel)', (tester) async {
      _useTallSurface(tester);
      final base = CmsPageLayout.fallback('product');
      for (final enabled in [true, false, true]) {
        final layout = CmsPageLayout(page: base.page, header: base.header, footer: base.footer,
          elements: base.elements.map((element) => CmsPageComponent(
            id: element.id, type: element.type,
            enabled: element.id == 'reviews' ? enabled : element.enabled,
            settings: {...element.settings,
              if (customLabel && element.id == 'product_tabs') 'tabs_json': [
                {'label': 'Overview', 'target': 'overview'},
                {'label': 'Customer opinions', 'target': 'reviews'},
              ],
            },
          )).toList());
        await tester.pumpWidget(_testApp(ProductDetailScreen(
          productId: simpleProduct.id, repository: ProductFakeCatalogRepository()), productLayout: layout));
        await tester.pumpAndSettle();
        expect(find.text(customLabel ? 'Customer opinions' : 'Reviews'), enabled ? findsWidgets : findsNothing);
        expect(find.text('Overview'), findsOneWidget);
        if (enabled) {
          await tester.tap(find.text(customLabel ? 'Customer opinions' : 'Reviews').first);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('Recommend reaches an unvisited section after a long description on first tap', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final product = CatalogProduct(
      id: 404, name: 'Long description product', slug: 'long-product',
      type: 'simple', prices: testMoney, isInStock: true, isPurchasable: true,
      description: List.filled(80, 'Detailed product information.').join(' '),
    );
    final repository = ProductFakeCatalogRepository(product: product)
      ..relatedProducts = <CatalogProduct>[variableProduct];
    await tester.pumpWidget(_testApp(ProductDetailScreen(
      productId: product.id, repository: repository,
    )));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byKey(const Key('product-detail-scroll')),
      matching: find.byType(Scrollable),
    ).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    // On a physical Android surface the gallery can exceed the viewport.
    // Reveal only the tabs; the related-products target remains unvisited.
    await tester.scrollUntilVisible(
      find.text('Recommend'), 200, scrollable: scrollable,
    );
    await tester.tap(find.text('Recommend'));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(1000));
    final target = tester.getRect(find.byKey(const Key('related-products-button')));
    final viewport = tester.getRect(find.byKey(const Key('product-detail-scroll')));
    expect(target.top, greaterThanOrEqualTo(viewport.top));
    expect(target.bottom, lessThan(viewport.bottom));
    expect(repository.relatedQueries, hasLength(1));
  });

  testWidgets('related products use the repository even in CMS preview', (tester) async {
    _useTallSurface(tester);
    final repository = ProductFakeCatalogRepository()
      ..relatedProducts = <CatalogProduct>[variableProduct];
    await tester.pumpWidget(_testApp(ProductDetailScreen(
      productId: simpleProduct.id,
      repository: repository,
    )));
    await tester.pumpAndSettle();
    expect(repository.relatedQueries, hasLength(1));
    expect(repository.relatedQueries.single.excludeIds, <int>[simpleProduct.id]);
    expect(repository.relatedQueries.single.perPage, 4);
    expect(tester.widget<CatalogProductCard>(find.byType(CatalogProductCard)).product.id,
      variableProduct.id);
    expect(find.text('MobiShop everyday set'), findsNothing);
  });

  testWidgets('failed related products can retry without fabricated fallback', (tester) async {
    _useTallSurface(tester);
    final repository = ProductFakeCatalogRepository()
      ..relatedError = StateError('Catalog unavailable');
    await tester.pumpWidget(_testApp(ProductDetailScreen(
      productId: simpleProduct.id,
      repository: repository,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('related-products-retry')), findsOneWidget);
    expect(find.byType(CatalogProductCard), findsNothing);
    repository.relatedError = null;
    repository.relatedProducts = <CatalogProduct>[variableProduct];
    await tester.ensureVisible(find.byKey(const Key('related-products-retry')));
    await tester.tap(find.byKey(const Key('related-products-retry')));
    await tester.pumpAndSettle();
    expect(repository.relatedQueries, hasLength(2));
    expect(find.byType(CatalogProductCard), findsOneWidget);
  });

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
    for (final Key key in const <Key>[
      Key('share-copy-link'),
      Key('share-more'),
    ]) {
      final CircleAvatar action = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byKey(const Key('share-action-circle')),
        ),
      );
      expect(action.backgroundColor, const Color(0xFFF1F2F3));
    }
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
    expect(find.text('MobiShop'), findsOneWidget);
    expect(find.text('Product'), findsNothing);
	expect(find.byKey(const Key('commerce-app-bar-title')), findsNothing);
    expect(find.byType(CmsPageAppBar), findsOneWidget);
    expect(find.text('In stock'), findsNothing);
	expect(find.byKey(const Key('product-tabs')), findsOneWidget);
	expect(find.byKey(const Key('product-reviews-button')), findsOneWidget);
	expect(find.byKey(const Key('related-products-button')), findsOneWidget);
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
        productLayout: _productLayoutWithQuantity(),
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
      const Color(0xFF1D1D1D).withValues(alpha: 0.48),
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
      const Color(0xFF1D1D1D),
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
    expect(find.text('Size   Medium'), findsOneWidget);
    expect(find.text('Color   Blue'), findsWidgets);
    expect(find.text('Color   blue'), findsNothing);
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
    expect(addToCartSize.width, closeTo(footerSize.width / 3 - 8, 0.1));
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
    expect(shareBox.width, 28);
    expect(shareBox.height, 28);
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

  for (final locale in ['ar', 'en']) {
    for (final width in [320.0, 390.0]) {
      testWidgets('footer honors equal columns and inset at $width in $locale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_testApp(ProductDetailScreen(
          productId: simpleProduct.id, repository: ProductFakeCatalogRepository(),
          onAddToCart: (_) async {},
        ), locale: Locale(locale), productLayout: _liveStyleProductLayout(
          layoutJson: {'rows': [{'columns': [
            {'width': 33.33, 'items': ['share']},
            {'width': 33.33, 'items': ['like']},
            {'width': 33.34, 'items': ['add_to_cart']},
          ]}]}, footerSettings: {'icon_label_gap': 2, 'show_button_icon': true},
        )));
        await tester.pumpAndSettle();
        final share = tester.getRect(find.byKey(const Key('product-footer-column-share')));
        final like = tester.getRect(find.byKey(const Key('product-footer-column-like')));
        final buy = tester.getRect(find.byKey(const Key('product-footer-column-add_to_cart')));
        final button = tester.getRect(find.byKey(const Key('product-add-to-cart-size')));
        expect(share.width, closeTo(like.width, .1));
        expect(share.width, closeTo(buy.width, .1));
        expect(button.left - buy.left, closeTo(4, .1));
        expect(buy.right - button.right, closeTo(4, .1));
        expect(button.center.dy, closeTo(buy.center.dy, .1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('product footer keeps two rows and an empty column without losing purchase action', (tester) async {
    _useTallSurface(tester);
    ProductPurchaseSelection? captured;
    await tester.pumpWidget(_testApp(ProductDetailScreen(
      productId:simpleProduct.id, repository:ProductFakeCatalogRepository(),
      onAddToCart:(selection) async { captured=selection; },
    ),productLayout:_liveStyleProductLayout(layoutJson:{'rows':[
      {'columns':[{'width':25,'items':[]},{'width':75,'items':['share','like']}]},
      {'columns':[{'width':100,'items':['add_to_cart']}]},
    ]})));
    await tester.pumpAndSettle();
    final share=tester.getRect(find.byKey(const Key('product-footer-column-share')));
    final like=tester.getRect(find.byKey(const Key('product-footer-column-like')));
    final buy=tester.getRect(find.byKey(const Key('product-footer-column-add_to_cart')));
    expect(share.top,like.top);
    expect(buy.top,greaterThanOrEqualTo(share.bottom));
    expect(share.width/buy.width,closeTo(.375,.01));
    final button=tester.getRect(find.byKey(const Key('product-add-to-cart-size')));
    expect(button.width/buy.width,closeTo(.60,.01));
    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();
    expect(captured?.quantity,1);
    expect(tester.takeException(),isNull);
  });

  testWidgets('product purchase button is vertically centered without adding footer height', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_testApp(ProductDetailScreen(
      productId: simpleProduct.id, repository: ProductFakeCatalogRepository(),
      onAddToCart: (selection) async {},
    ), productLayout: _liveStyleProductLayout(footerSettings: {
      'height': 50, 'button_height': 45.59, 'icon_size': 22,
      'font_size': 11, 'icon_label_gap': 0,
    })));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('product-footer-size'));
    final footer = find.ancestor(of: row, matching: find.byType(Material)).first;
    final button = find.byKey(const Key('product-add-to-cart-size'));
    expect(tester.getSize(footer).height, tester.getSize(row).height + 6);
    expect(tester.getCenter(button).dy, closeTo(tester.getCenter(footer).dy, .01));
    expect(tester.takeException(), isNull);
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
  testWidgets('variable product preserves outline and soft button styles', (tester) async {
    _useTallSurface(tester);
    for (final style in ['outline', 'soft']) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_testApp(
        ProductDetailScreen(
          key: ValueKey(style),
          productId: variableProduct.id,
          repository: ProductFakeCatalogRepository(
            product: variableProduct, variations: testVariations,
          ),
          onAddToCart: (selection) async {},
        ),
        productLayout: _liveStyleProductLayout(footerSettings: {
          'button_style': style,
          'button_color': '#123456',
        }),
      ));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.byKey(const Key('add-to-cart-button')));
      final color = button.style!.backgroundColor!.resolve({})!;
      expect(color.a, closeTo(style == 'outline' ? 0 : 0.14 * 0.48, 0.01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('footer quantity changes the actual purchase selection', (tester) async {
    _useTallSurface(tester);
    ProductPurchaseSelection? purchased;
    await tester.pumpWidget(_testApp(
      ProductDetailScreen(
        productId: simpleProduct.id,
        repository: ProductFakeCatalogRepository(),
        onAddToCart: (selection) async { purchased = selection; },
      ),
      productLayout: _liveStyleProductLayout(footerSettings: {
        'show_price': true,
        'show_quantity': true,
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-footer-price')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quantity-increment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();
    expect(purchased?.quantity, 2);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(
  Widget home, {
  Locale? locale,
  CmsPageLayout? productLayout,
}) {
  return ProviderScope(
    overrides: [
      // Keep screen tests independent of live store appearance on Android.
      cmsPageLayoutProvider('product').overrideWithValue(
        AsyncData(productLayout ?? CmsPageLayout.fallback('product')),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(useMaterial3: true),
      home: home,
    ),
  );
}

CmsPageLayout _liveStyleProductLayout({Map<String, dynamic>? layoutJson, Map<String, dynamic> footerSettings = const {}}) {
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
        'style': 'product_action',
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
        ...footerSettings,
      },
    ),
  );
}

CmsPageLayout _productLayoutWithQuantity() {
  final CmsPageLayout fallback = CmsPageLayout.fallback('product');
  return CmsPageLayout(
    page: fallback.page,
    header: fallback.header,
    elements: fallback.elements
        .map(
          (CmsPageComponent element) => element.id == 'purchase_bar'
              ? CmsPageComponent(
                  id: element.id,
                  type: element.type,
                  enabled: true,
                  settings: <String, dynamic>{
                    ...element.settings,
                    'show_quantity': true,
                  },
                )
              : element,
        )
        .toList(growable: false),
    footer: fallback.footer,
  );
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
