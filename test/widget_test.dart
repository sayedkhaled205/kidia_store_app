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
import 'package:kidia_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStartupProvider.overrideWith((ref) async {}),
        catalogRepositoryProvider.overrideWithValue(
          const _RouterCatalogRepository(),
        ),
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
