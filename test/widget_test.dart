import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/app/app.dart';
import 'package:kidia_store_app/app/app_router.dart';
import 'package:kidia_store_app/app/app_startup_provider.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';
import 'package:kidia_store_app/features/brands/presentation/brands_screen.dart';
import 'package:kidia_store_app/features/brands/presentation/providers/brands_providers.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/adapters/product_purchase_selection.dart' as cart_selection;
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

import 'features/product/support/product_test_data.dart';

void main() {
  testWidgets('app shows its startup splash safely', (tester) async {
    final Completer<void> startupCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith((ref) => startupCompleter.future),
        ],
        child: const KidiaApp(),
      ),
    );

    expect(find.text(AppConfig.storeName), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('product CMS action opens the real product details screen', (
    tester,
  ) async {
    final GoRouter router = createAppRouter(initialLocation: '/product/42');

    await _pumpStartedApp(tester, router: router);

    expect(find.byType(ProductDetailScreen), findsOneWidget);
	expect(find.byKey(const Key('cms-bottom-navigation')), findsNothing);
	expect(find.byKey(const Key('add-to-cart-button')), findsOneWidget);

    await _disposeApp(tester, router);
  });

  testWidgets('real product route opens options and adds selected variation', (
    tester,
  ) async {
    cart_selection.ProductPurchaseSelection? captured;
    final GoRouter router = createAppRouter(initialLocation: '/product/42');

    await _pumpStartedApp(
      tester,
      router: router,
      catalogRepository: ProductFakeCatalogRepository(
        product: variableProduct,
        variations: testVariations,
      ),
      addSelection: (selection) async {
        captured = selection;
        return const cart_selection.CartActionResult.success();
      },
    );

    final FilledButton initial = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(initial.onPressed, isNotNull);
    expect(
      initial.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF2F806E).withValues(alpha: 0.48),
    );
    expect(find.text('اختر خيارات المنتج أولًا.'), findsNothing);
    await tester.tap(find.byKey(const Key('add-to-cart-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-options-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-option-pa_color-blue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('product-option-pa_size-m')));
    await tester.pumpAndSettle();
    final FilledButton selected = tester.widget<FilledButton>(
      find.byKey(const Key('add-to-cart-button')),
    );
    expect(
      selected.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFF2F806E),
    );
    await tester.tap(find.byKey(const Key('product-options-sheet-add')));
    await tester.pumpAndSettle();

    expect(captured?.productId, 103);
    expect(find.byKey(const Key('product-options-sheet')), findsNothing);
    await _disposeApp(tester, router);
  });

  testWidgets('category route keeps and selects bottom navigation', (
    tester,
  ) async {
    final GoRouter router = createAppRouter(initialLocation: '/categories/17');

    await _pumpStartedApp(tester, router: router);

    final CatalogProductListScreen screen = tester.widget(
      find.byType(CatalogProductListScreen),
    );
    expect(screen.request.categoryId, 17);

    final Icon categoryIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('cms-bottom-nav-categories')),
        matching: find.byType(Icon),
      ),
    );
    expect(categoryIcon.color, const Color(0xFF1F6F61));

    await _disposeApp(tester, router);
  });

  testWidgets('collection and brand CMS routes are registered', (tester) async {
    final GoRouter router = createAppRouter(
      initialLocation: '/collection/summer',
    );

    await _pumpStartedApp(tester, router: router);

    CatalogProductListScreen screen = tester.widget(
      find.byType(CatalogProductListScreen),
    );
    expect(screen.request.collection, 'summer');

    router.go('/brand/9');
    await tester.pumpAndSettle();

    screen = tester.widget(find.byType(CatalogProductListScreen));
    expect(screen.request.brandId, 9);

    router.go('/brands');
    await tester.pumpAndSettle();

    expect(find.byType(BrandsScreen), findsOneWidget);

    await _disposeApp(tester, router);
  });

  testWidgets('search action passes its query to the search field', (
    tester,
  ) async {
    final GoRouter router = createAppRouter(
      initialLocation: '/search?q=dresses',
    );

    await _pumpStartedApp(tester, router: router);

    final TextField textField = tester.widget<TextField>(
      find.byType(TextField),
    );
    expect(textField.controller?.text, 'dresses');

    expect(find.byType(NavigationBar), findsNothing);

    await _disposeApp(tester, router);
  });

  testWidgets('bottom navigation exposes wishlist instead of search and cart', (
    tester,
  ) async {
    final GoRouter router = createAppRouter();

    await _pumpStartedApp(tester, router: router);

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الأقسام'), findsOneWidget);
    expect(find.text('المفضلة'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
    expect(find.text('البحث'), findsNothing);
    expect(find.text('السلة'), findsNothing);

    await _disposeApp(tester, router);
  });

  testWidgets(
    'all pages use Category footer sizing while keeping Arabic page labels',
    (tester) async {
      final GoRouter router = createAppRouter();
      final CmsPageLayout homeLayout = _navigationLayout(
        'home',
        height: 92,
        iconSize: 36,
        iconLabelGap: 9,
        items: const <String>['home', 'wishlist'],
      );
      final CmsPageLayout categoryLayout = _navigationLayout(
        'category',
        height: 64,
        iconSize: 24,
      );

      await _pumpStartedApp(
        tester,
        router: router,
        homeLayout: homeLayout,
        categoryLayout: categoryLayout,
      );

      final SizedBox footerSize = tester.widget<SizedBox>(
        find.byKey(const Key('cms-bottom-navigation-size')),
      );
      final Icon homeIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('cms-bottom-nav-home')),
          matching: find.byType(Icon),
        ),
      );

      expect(footerSize.height, 64);
      expect(homeIcon.size, 24);
      final SizedBox homeIconBox = tester.widget<SizedBox>(
        find.byKey(const Key('cms-bottom-nav-icon-box-home')),
      );
      final SizedBox wishlistIconBox = tester.widget<SizedBox>(
        find.byKey(const Key('cms-bottom-nav-icon-box-wishlist')),
      );
      expect(homeIconBox.width, 32);
      expect(homeIconBox.height, 32);
      expect(wishlistIconBox.width, homeIconBox.width);
      expect(wishlistIconBox.height, homeIconBox.height);
      expect(
        tester
            .widget<SizedBox>(
              find.byKey(
                const Key('cms-bottom-nav-icon-label-gap-home'),
              ),
            )
            .height,
        9,
      );
      expect(
        tester
            .getCenter(find.byKey(const Key('cms-bottom-nav-icon-box-home')))
            .dy,
        tester
            .getCenter(
              find.byKey(const Key('cms-bottom-nav-icon-box-wishlist')),
            )
            .dy,
      );
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('المفضلة'), findsOneWidget);
      expect(find.text('الأقسام'), findsNothing);
      expect(find.text('حسابي'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Categories'), findsNothing);

      await _disposeApp(tester, router);
    },
  );
}

Future<void> _pumpStartedApp(
  WidgetTester tester, {
  required GoRouter router,
  CmsPageLayout? homeLayout,
  CmsPageLayout? categoryLayout,
  CatalogRepository catalogRepository = const _RouterCatalogRepository(),
  cart_selection.AddProductPurchaseSelection? addSelection,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStartupProvider.overrideWith((ref) async {}),
        catalogRepositoryProvider.overrideWithValue(catalogRepository),
        if (addSelection != null)
          addProductPurchaseSelectionProvider.overrideWithValue(addSelection),
        brandsRepositoryProvider.overrideWithValue(
          const _RouterBrandsRepository(),
        ),
        if (homeLayout != null)
          cmsPageLayoutProvider('home').overrideWith((ref) async => homeLayout),
        if (categoryLayout != null)
          cmsPageLayoutProvider(
            'category',
          ).overrideWith((ref) async => categoryLayout),
      ],
      child: KidiaApp(router: router),
    ),
  );
  for (int index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

CmsPageLayout _navigationLayout(
  String page, {
  required double height,
  required double iconSize,
  double iconLabelGap = 3,
  List<String> items = const <String>[
    'home',
    'categories',
    'wishlist',
    'account',
  ],
}) {
  final CmsPageLayout fallback = CmsPageLayout.fallback(page);
  return CmsPageLayout(
    page: page,
    header: fallback.header,
    elements: fallback.elements,
    footer: CmsPageComponent(
      id: fallback.footer.id,
      type: fallback.footer.type,
      enabled: true,
      settings: <String, dynamic>{
        ...fallback.footer.settings,
        'layout_json': <String, dynamic>{
          'rows': <Map<String, dynamic>>[
            <String, dynamic>{
              'columns': items
                  .map(
                    (String item) => <String, dynamic>{
                      'width': 100 / items.length,
                      'align': 'center',
                      'items': <String>[item],
                    },
                  )
                  .toList(growable: false),
            },
          ],
        },
        'height': height,
        'icon_size': iconSize,
        'icon_label_gap': iconLabelGap,
        'home_label': 'Home',
        'categories_label': 'Categories',
        'wishlist_label': 'Wishlist',
        'account_label': 'Account',
      },
    ),
  );
}

Future<void> _disposeApp(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
}

class _RouterBrandsRepository implements BrandsRepository {
  const _RouterBrandsRepository();

  @override
  Future<StoreBrandPage> getBrands({
    required int page,
    required int perPage,
    required String search,
  }) async {
    return StoreBrandPage(
      items: const <StoreBrand>[
        StoreBrand(id: 9, name: 'Test Brand', slug: 'test-brand'),
      ],
      page: page,
      perPage: perPage,
      totalItems: 1,
      totalPages: 1,
    );
  }
}

class _RouterCatalogRepository implements CatalogRepository {
  const _RouterCatalogRepository();

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    return CatalogPage<CatalogCategory>(
      items: const <CatalogCategory>[],
      page: query.page,
      perPage: query.perPage,
      totalItems: 0,
      totalPages: 0,
    );
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    return const CatalogFilterData();
  }

  @override
  Future<CatalogProduct> getProduct(int productId) async {
    return _product(productId);
  }

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    return CatalogPage<CatalogProduct>(
      items: <CatalogProduct>[_product(42)],
      page: query.page,
      perPage: query.perPage,
      totalItems: 1,
      totalPages: 1,
    );
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    return const <CatalogVariation>[];
  }

  static CatalogProduct _product(int id) {
    return CatalogProduct(
      id: id,
      name: 'Test Product $id',
      slug: 'test-product-$id',
      type: 'simple',
      isInStock: true,
      isPurchasable: true,
      prices: const CatalogMoney(
        currencyCode: 'USD',
        currencySymbol: r'$',
        currencyMinorUnit: 2,
        priceMinor: '1999',
      ),
    );
  }
}
