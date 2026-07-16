import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';

void main() {
  group('CatalogProductQuery', () {
    test('normalizes pagination and serializes Store API filters', () {
      final CatalogProductQuery query = CatalogProductQuery(
        page: 0,
        perPage: 500,
        search: '  summer dress  ',
        sort: CatalogSort.priceLowToHigh,
        categoryIds: <int>[3, 3, -1],
        brandIds: <int>[9],
        stock: <CatalogStockFilter>[
          CatalogStockFilter.inStock,
          CatalogStockFilter.onBackorder,
        ],
        minimumPriceMinor: '1000',
        maximumPriceMinor: 'not-a-price',
        onSale: true,
        attributes: <CatalogAttributeFilter>[
          CatalogAttributeFilter(
            taxonomy: 'pa_size',
            terms: <String>['m', 'l', 'm'],
            operator: CatalogAttributeOperator.all,
          ),
        ],
      );

      final Map<String, dynamic> serialized = query.toStoreApiQuery();

      expect(serialized['page'], 1);
      expect(serialized['per_page'], 100);
      expect(serialized['search'], 'summer dress');
      expect(serialized['category'], '3');
      expect(serialized['brand'], '9');
      expect(serialized['orderby'], 'price');
      expect(serialized['order'], 'asc');
      expect(serialized['min_price'], '1000');
      expect(serialized.containsKey('max_price'), isFalse);
      expect(serialized['on_sale'], isTrue);
      expect(serialized['attributes[0][attribute]'], 'pa_size');
      expect(serialized['attributes[0][slug]'], 'm,l');
      expect(serialized['attributes[0][operator]'], 'and');
      expect(serialized['stock_status[]'], <String>['instock', 'onbackorder']);
    });

    test('serializes variation hydration queries using official filters', () {
      final Map<String, dynamic> serialized = CatalogProductQuery(
        includeIds: <int>[91, 92],
        parentIds: <int>[10],
        productType: CatalogProductType.variation,
        sort: CatalogSort.includeOrder,
      ).toStoreApiQuery();

      expect(serialized['include'], '91,92');
      expect(serialized['parent'], '10');
      expect(serialized['type'], 'variation');
      expect(serialized['orderby'], 'include');
    });

    test('falls back from relevance to newest without a search term', () {
      final Map<String, dynamic> serialized = CatalogProductQuery()
          .toStoreApiQuery();

      expect(serialized['orderby'], 'date');
      expect(serialized['order'], 'desc');
    });
  });

  test(
    'category query supports root categories and deterministic ordering',
    () {
      final Map<String, dynamic> serialized = CatalogCategoryQuery(
        parentId: 0,
        hideEmpty: false,
        sort: CatalogCategorySort.count,
      ).toStoreApiQuery();

      expect(serialized['parent'], 0);
      expect(serialized['hide_empty'], isFalse);
      expect(serialized['orderby'], 'count');
      expect(serialized['order'], 'desc');
    },
  );
}
