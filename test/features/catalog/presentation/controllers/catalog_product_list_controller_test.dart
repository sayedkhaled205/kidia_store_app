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
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

void main() {
  group('CatalogProductListController', () {
    test(
      'loads the first page then appends a deduplicated next page',
      () async {
        final _FakeCatalogRepository repository = _FakeCatalogRepository(
          products: (CatalogProductQuery query) async {
            if (query.page == 1) {
              return _page(
                query,
                items: <CatalogProduct>[_product(1), _product(2)],
                totalItems: 3,
                totalPages: 2,
              );
            }
            return _page(
              query,
              items: <CatalogProduct>[_product(2), _product(3)],
              totalItems: 3,
              totalPages: 2,
            );
          },
        );
        final CatalogProductListController controller =
            CatalogProductListController(
              repository,
              request: const CatalogProductListRequest(categoryId: 7),
            );

        final Future<void> initialLoad = controller.loadInitial();
        expect(controller.state.isInitialLoading, isTrue);
        await initialLoad;
        expect(
          controller.state.items.map((CatalogProduct item) => item.id),
          <int>[1, 2],
        );
        expect(repository.productQueries.single.categoryIds, <int>[7]);

        await controller.loadMore();

        expect(
          controller.state.items.map((CatalogProduct item) => item.id),
          <int>[1, 2, 3],
        );
        expect(repository.productQueries.last.page, 2);
        controller.dispose();
      },
    );

    test('does not request the full catalog for an empty search', () async {
      final _FakeCatalogRepository repository = _FakeCatalogRepository();
      final CatalogProductListController controller =
          CatalogProductListController(
            repository,
            request: const CatalogProductListRequest(searchOnly: true),
          );

      await controller.loadInitial();
      expect(controller.isAwaitingSearch, isTrue);
      expect(repository.productQueries, isEmpty);

      await controller.submitSearch(' jacket ');
      expect(controller.isAwaitingSearch, isFalse);
      expect(repository.productQueries.single.search, 'jacket');
      controller.dispose();
    });

    test('rebuilds the query when sort and filters change', () async {
      final _FakeCatalogRepository repository = _FakeCatalogRepository();
      final CatalogProductListController controller =
          CatalogProductListController(
            repository,
            request: const CatalogProductListRequest(),
          );

      await controller.loadInitial();
      await controller.changeSort(CatalogSort.priceLowToHigh);
      await controller.applyFilters(
        const CatalogProductFilters(
          inStockOnly: true,
          onSaleOnly: true,
          minimumPriceMinor: '1000',
          maximumPriceMinor: '9000',
        ),
      );

      final CatalogProductQuery query = repository.productQueries.last;
      expect(query.sort, CatalogSort.priceLowToHigh);
      expect(query.stock, <CatalogStockFilter>[CatalogStockFilter.inStock]);
      expect(query.onSale, isTrue);
      expect(query.minimumPriceMinor, '1000');
      expect(query.maximumPriceMinor, '9000');
      controller.dispose();
    });

    test(
      'discovers sizes and sends the selected size to WooCommerce',
      () async {
        final _FakeCatalogRepository repository = _FakeCatalogRepository(
          products: (CatalogProductQuery query) async => _page(
            query,
            items: <CatalogProduct>[_product(1, withSizes: true)],
            totalItems: 1,
            totalPages: 1,
          ),
        );
        final CatalogProductListController controller =
            CatalogProductListController(
              repository,
              request: const CatalogProductListRequest(),
            );

        await controller.loadInitial();
        expect(
          controller.state.availableSizes.map(
            (CatalogSizeOption item) => item.label,
          ),
          <String>['Medium', 'Small'],
        );

        await controller.applySize(controller.state.availableSizes.last);

        final CatalogAttributeFilter selected =
            repository.productQueries.last.attributes.single;
        expect(selected.taxonomy, 'pa_size');
        expect(selected.terms, <String>['s']);
        expect(controller.state.filters.hasSize, isTrue);
        controller.dispose();
      },
    );
  });
}

CatalogPage<CatalogProduct> _page(
  CatalogProductQuery query, {
  List<CatalogProduct> items = const <CatalogProduct>[],
  int totalItems = 0,
  int totalPages = 0,
}) {
  return CatalogPage<CatalogProduct>(
    items: items,
    page: query.page,
    perPage: query.perPage,
    totalItems: totalItems,
    totalPages: totalPages,
  );
}

CatalogProduct _product(int id, {bool withSizes = false}) {
  return CatalogProduct(
    id: id,
    name: 'Product $id',
    slug: 'product-$id',
    type: 'simple',
    prices: const CatalogMoney(
      currencyCode: 'USD',
      currencySymbol: r'$',
      currencyMinorUnit: 2,
      priceMinor: '2500',
    ),
    isInStock: true,
    attributes: withSizes
        ? const <CatalogProductAttribute>[
            CatalogProductAttribute(
              id: 1,
              name: 'Size',
              taxonomy: 'pa_size',
              hasVariations: true,
              terms: <CatalogAttributeTerm>[
                CatalogAttributeTerm(id: 1, name: 'Small', slug: 's'),
                CatalogAttributeTerm(id: 2, name: 'Medium', slug: 'm'),
              ],
            ),
          ]
        : const <CatalogProductAttribute>[],
  );
}

typedef _ProductsHandler =
    Future<CatalogPage<CatalogProduct>> Function(CatalogProductQuery query);

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository({_ProductsHandler? products})
    : _products =
          products ?? ((CatalogProductQuery query) async => _page(query));

  final _ProductsHandler _products;
  final List<CatalogProductQuery> productQueries = <CatalogProductQuery>[];

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) {
    productQueries.add(query);
    return _products(query);
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    return const CatalogFilterData(
      minimumPriceMinor: '100',
      maximumPriceMinor: '10000',
    );
  }

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
  Future<CatalogProduct> getProduct(int productId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) async {
    return const <CatalogVariation>[];
  }
}
