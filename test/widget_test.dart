import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/app/app.dart';
import 'package:kidia_store_app/app/app_router.dart';
import 'package:kidia_store_app/app/app_startup_provider.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
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
    expect(find.byKey(const Key('cms-bottom-navigation')), findsOneWidget);

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
    expect(categoryIcon.color, KidiaColors.primaryDark);

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
}

Future<void> _pumpStartedApp(
  WidgetTester tester, {
  required GoRouter router,
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
      ],
      child: KidiaApp(router: router),
    ),
  );
  for (int index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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
