import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

void main() {
  group('CatalogProductListController', () {
    test(
      'child selection retains filters and sort across paging and reset',
      () async {
        final repository = _FakeCatalogRepository(
          products: (q) async => _page(
            q,
            items: [_product(q.categoryIds.single * 10 + q.page)],
            totalItems: 3,
            totalPages: 3,
          ),
        );
        final controller = CatalogProductListController(
          repository,
          request: const CatalogProductListRequest(categoryId: 7, pageSize: 1),
        );
        addTearDown(controller.dispose);
        await controller.applyFilters(
          const CatalogProductFilters(onSaleOnly: true),
        );
        await controller.changeSort(CatalogSort.priceLowToHigh);
        await controller.selectChildCategory(8);
        expect(controller.state.selectedChildCategoryId, 8);
        expect(controller.state.page, 1);
        expect(repository.productQueries.last.categoryIds, [8]);
        expect(repository.productQueries.last.onSale, true);
        expect(repository.productQueries.last.sort, CatalogSort.priceLowToHigh);
        await controller.loadMore();
        expect(controller.state.items.map((p) => p.id), [81, 82]);
        await controller.selectChildCategory(9);
        expect(controller.state.items.map((p) => p.id), [91]);
        expect(controller.state.page, 1);
        await controller.selectChildCategory(null);
        expect(controller.state.selectedChildCategoryId, isNull);
        expect(controller.state.items.map((p) => p.id), [71]);
        expect(controller.state.filters.onSaleOnly, true);
      },
    );
    test(
      'rapid child changes ignore older responses and allow retry',
      () async {
        final pending = <int, Completer<CatalogPage<CatalogProduct>>>{};
        final repository = _FakeCatalogRepository(
          products: (q) => (pending[q.categoryIds.single] = Completer()).future,
        );
        final controller = CatalogProductListController(
          repository,
          request: const CatalogProductListRequest(categoryId: 7),
        );
        addTearDown(controller.dispose);
        final first = controller.selectChildCategory(8);
        final second = controller.selectChildCategory(9);
        pending[9]!.completeError(StateError('temporary failure'));
        await second;
        expect(controller.state.error, isNotNull);
        final retry = controller.loadInitial();
        pending[9]!.complete(
          _page(
            repository.productQueries.last,
            items: [_product(9)],
            totalItems: 1,
            totalPages: 1,
          ),
        );
        await retry;
        pending[8]!.complete(
          _page(
            repository.productQueries.first,
            items: [_product(8)],
            totalItems: 1,
            totalPages: 1,
          ),
        );
        await first;
        expect(controller.state.selectedChildCategoryId, 9);
        expect(controller.state.items.single.id, 9);
        expect(controller.state.error, isNull);
      },
    );
    test('tag filters retain the category and attribute selections', () async {
      final repository = _FakeCatalogRepository(
        products: (query) async =>
            _page(query, items: [_product(1)], totalItems: 1, totalPages: 1),
      );
      final controller = CatalogProductListController(
        repository,
        request: const CatalogProductListRequest(categoryId: 7),
      );
      addTearDown(controller.dispose);
      await controller.applyFilters(
        const CatalogProductFilters(
          tags: [CatalogTagOption(id: 124, label: 'Trousers')],
          sizes: [
            CatalogSizeOption(taxonomy: 'pa_size', term: '4y', label: '4Y'),
          ],
          minimumPriceMinor: '1000',
        ),
      );
      final query = repository.productQueries.last;
      expect(query.toStoreApiQuery()['tag'], '124');
      expect(query.categoryIds, [7]);
      expect(query.attributes.single.terms, ['4y']);
      expect(query.minimumPriceMinor, '1000');
      await controller.applyColors(const [
        CatalogSizeOption(taxonomy: 'pa_color', term: 'blue', label: 'Blue'),
      ]);
      expect(repository.productQueries.last.tagIds, [124]);
      expect(repository.productQueries.last.attributes.length, 2);
      // Optional metadata is not fabricated or sent to unsupported transports.
      expect((await controller.loadFilterOptions()).tags, isEmpty);
    });
    test(
      'notification offers destination requests only sale products',
      () async {
        final repository = _FakeCatalogRepository(
          products: (query) async =>
              _page(query, items: [_product(1)], totalItems: 1, totalPages: 1),
        );
        final controller = CatalogProductListController(
          repository,
          request: const CatalogProductListRequest(collection: 'sale'),
        );
        await controller.loadInitial();
        expect(repository.productQueries.single.onSale, isTrue);
        expect(controller.state.items.single.id, 1);
        controller.dispose();
      },
    );

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

    test('loads any selected numbered page directly', () async {
      final _FakeCatalogRepository repository = _FakeCatalogRepository(
        products: (CatalogProductQuery query) async => _page(
          query,
          items: <CatalogProduct>[_product(query.page)],
          totalItems: 5,
          totalPages: 5,
        ),
      );
      final CatalogProductListController controller =
          CatalogProductListController(
            repository,
            request: const CatalogProductListRequest(),
          );

      await controller.loadInitial();
      await controller.loadPage(4);

      expect(repository.productQueries.last.page, 4);
      expect(controller.state.page, 4);
      expect(controller.state.items.single.id, 4);
      controller.dispose();
    });

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
          onSaleOnly: true,
          minimumPriceMinor: '1000',
          maximumPriceMinor: '9000',
          brandId: 18,
          brandLabel: 'Bonjor',
        ),
      );

      final CatalogProductQuery query = repository.productQueries.last;
      expect(query.sort, CatalogSort.priceLowToHigh);
      expect(query.stock, isEmpty);
      expect(query.brandIds, <int>[18]);
      expect(query.onSale, isTrue);
      expect(query.minimumPriceMinor, '1000');
      expect(query.maximumPriceMinor, '9000');
      controller.dispose();
    });

    test(
      'multiple sizes and colors use OR terms with AND across groups',
      () async {
        final repository = _FakeCatalogRepository();
        final controller = CatalogProductListController(
          repository,
          request: const CatalogProductListRequest(categoryId: 7),
        );
        await controller.loadInitial();
        const small = CatalogSizeOption(
          taxonomy: 'pa_size',
          term: 's',
          label: 'Small',
        );
        const medium = CatalogSizeOption(
          taxonomy: 'pa_size',
          term: 'm',
          label: 'Medium',
        );
        const red = CatalogSizeOption(
          taxonomy: 'pa_color',
          term: 'red',
          label: 'Red',
        );
        const blue = CatalogSizeOption(
          taxonomy: 'pa_color',
          term: 'blue',
          label: 'Blue',
        );
        await controller.applyFilters(
          const CatalogProductFilters(
            onSaleOnly: true,
            minimumPriceMinor: '1000',
            sizes: [small, medium],
            colors: [red, blue],
          ),
        );
        final query = repository.productQueries.last;
        expect(query.categoryIds, [7]);
        expect(query.attributes.first.terms, ['m', 's']);
        expect(query.attributes.last.terms, ['blue', 'red']);
        expect(query.toStoreApiQuery()['attribute_relation'], 'and');
        expect(query.toStoreApiQuery()['attributes[0][operator]'], 'in');
        expect(query.toStoreApiQuery()['attributes[1][slug]'], 'blue,red');
        expect(controller.state.filters.activeCount, 6);
        final before = repository.productQueries.length;
        await controller.applySizes([medium, small, small]);
        expect(repository.productQueries.length, before);
        await controller.applyColors([blue]);
        expect(repository.productQueries.last.attributes.last.terms, ['blue']);
        expect(controller.state.filters.sizes.length, 2);
        await controller.applySizes([]);
        expect(
          repository.productQueries.last.attributes.single.taxonomy,
          'pa_color',
        );
        expect(repository.productQueries.last.minimumPriceMinor, '1000');
        expect(repository.productQueries.last.onSale, true);
        controller.dispose();
      },
    );
    test(
      'color combines with size and preserves other filters when cleared',
      () async {
        final repository = _FakeCatalogRepository(
          products: (query) async => _page(
            query,
            items: [_product(1, withSizes: true)],
            totalItems: 1,
            totalPages: 1,
          ),
        );
        final controller = CatalogProductListController(
          repository,
          request: const CatalogProductListRequest(),
        );
        await controller.loadInitial();
        expect(controller.state.availableColors.single.term, 'blue');
        await controller.applyFilters(
          const CatalogProductFilters(
            onSaleOnly: true,
            minimumPriceMinor: '1000',
            maximumPriceMinor: '9000',
            brandId: 18,
          ),
        );
        await controller.applyColor(controller.state.availableColors.single);
        await controller.applySize(controller.state.availableSizes.last);
        var query = repository.productQueries.last;
        expect(query.attributes.map((a) => a.taxonomy), [
          'pa_size',
          'pa_color',
        ]);
        expect(query.attributes.last.terms, ['blue']);
        expect(query.brandIds, [18]);
        expect(query.onSale, true);
        expect(query.minimumPriceMinor, '1000');
        expect(query.maximumPriceMinor, '9000');
        expect(controller.state.filters.hasColor, true);
        await controller.applyColor(null);
        query = repository.productQueries.last;
        expect(query.attributes.single.taxonomy, 'pa_size');
        expect(controller.state.filters.hasColor, false);
        expect(query.brandIds, [18]);
        expect(query.onSale, true);
        controller.dispose();
      },
    );

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
              id: 2,
              name: 'Color',
              taxonomy: 'pa_color',
              hasVariations: true,
              terms: [CatalogAttributeTerm(id: 3, name: 'Blue', slug: 'blue')],
            ),
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
