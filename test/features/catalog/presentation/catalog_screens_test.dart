import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:kidia_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';
import 'package:kidia_store_app/features/categories/presentation/categories_screen.dart';
import 'package:kidia_store_app/features/search/presentation/search_screen.dart';

void main() {
  testWidgets('empty search waits for a customer query', (
    WidgetTester tester,
  ) async {
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(_app(repository, const SearchScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a product name to start searching'),
      findsOneWidget,
    );
    expect(repository.productQueries, isEmpty);

    await tester.enterText(find.byType(TextField), 'shirt');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.productQueries.single.search, 'shirt');
    expect(find.text('Shirt'), findsOneWidget);
  });

  testWidgets('categories preserve their parent-child hierarchy', (
    WidgetTester tester,
  ) async {
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(_app(repository, const CategoriesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Dresses'), findsNothing);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Dresses'), findsOneWidget);
    expect(find.text('8 products'), findsNothing);
    expect(find.text('5 products'), findsNothing);
    expect(find.byType(SafeArea), findsWidgets);
  });

  testWidgets('product list uses three controls without a duplicate search', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _ScreenCatalogRepository repository = _ScreenCatalogRepository();
    await tester.pumpWidget(
      _app(
        repository,
        const CatalogProductListScreen(
          request: CatalogProductListRequest(title: 'Shoes'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('1 product'), findsNothing);
    expect(find.byKey(const Key('catalog-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('catalog-size-button')), findsOneWidget);
    expect(find.byKey(const Key('catalog-sort-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catalog-size-button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a size'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(CatalogRepository repository, Widget home) {
  return ProviderScope(
    overrides: [catalogRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(locale: const Locale('en'), home: home),
  );
}

class _ScreenCatalogRepository implements CatalogRepository {
  final List<CatalogProductQuery> productQueries = <CatalogProductQuery>[];

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    productQueries.add(query);
    final List<CatalogProduct> products = <CatalogProduct>[
      const CatalogProduct(
        id: 10,
        name: 'Shirt',
        slug: 'shirt',
        type: 'simple',
        isInStock: true,
        prices: CatalogMoney(
          currencyCode: 'USD',
          currencySymbol: r'$',
          currencyMinorUnit: 2,
          priceMinor: '1999',
        ),
        attributes: <CatalogProductAttribute>[
          CatalogProductAttribute(
            id: 1,
            name: 'Size',
            taxonomy: 'pa_size',
            hasVariations: true,
            terms: <CatalogAttributeTerm>[
              CatalogAttributeTerm(id: 1, name: 'Small', slug: 's'),
            ],
          ),
        ],
      ),
    ];
    return CatalogPage<CatalogProduct>(
      items: products,
      page: query.page,
      perPage: query.perPage,
      totalItems: products.length,
      totalPages: products.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) async {
    return CatalogPage<CatalogCategory>(
      items: const <CatalogCategory>[
        CatalogCategory(id: 1, name: 'Women', slug: 'women', count: 8),
        CatalogCategory(
          id: 2,
          name: 'Dresses',
          slug: 'dresses',
          parentId: 1,
          count: 5,
        ),
      ],
      page: query.page,
      perPage: query.perPage,
      totalItems: 2,
      totalPages: 1,
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
  Future<CatalogProduct> getProduct(int productId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    return const <CatalogVariation>[];
  }
}
