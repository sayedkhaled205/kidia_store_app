import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/data/repositories/cms_preview_catalog_repository.dart';
import 'package:mobishop_store_app/features/cart/data/repositories/cms_preview_cart_repository.dart';

void main() {
  test(
    'preview basket keeps real catalog identity, quantities and totals across reads',
    () async {
      final catalog = CmsPreviewCatalogRepository(
        live: false,
        catalog: () async => {
          'categories': [],
          'products': [
            {
              'id': 42,
              'name': 'Gift set',
              'price_minor': '44000',
              'currency_code': 'EGP',
              'in_stock': true,
            },
          ],
        },
      );
      final basket = CmsPreviewCartRepository(catalog);
      expect((await basket.getCart()).itemsCount, 0);
      final added = await basket.addItem(productId: 42);
      expect(added.itemsCount, 1);
      expect(added.items.single.name, 'Gift set');
      expect((await basket.getCart()).items.single.productId, 42);
      final twice = await basket.addItem(productId: 42);
      expect(twice.itemsCount, 2);
      expect(twice.items.length, 1);
      expect(
        (await basket.updateItem(
          key: twice.items.single.key,
          quantity: 3,
        )).itemsCount,
        3,
      );
      expect((await basket.removeItem(twice.items.single.key)).isEmpty, true);
    },
  );
  test(
    'selected live variation remains available when added to preview basket',
    () async {
      final parent = {
        'id': 10,
        'name': 'Shirt',
        'type': 'variable',
        'is_in_stock': true,
        'is_purchasable': true,
        'prices': {
          'price': '1000',
          'currency_code': 'EGP',
          'currency_minor_unit': 2,
        },
        'variations': [
          {
            'id': 11,
            'attributes': [
              {'name': 'Size', 'value': 'M'},
            ],
          },
        ],
      };
      final variant = {
        'id': 11,
        'parent': 10,
        'name': 'Shirt - M',
        'type': 'variation',
        'is_in_stock': true,
        'is_purchasable': true,
        'prices': {
          'price': '1200',
          'currency_code': 'EGP',
          'currency_minor_unit': 2,
        },
      };
      final catalog = CmsPreviewCatalogRepository(
        live: true,
        revision: () => 1,
        changes: const Stream.empty(),
        catalog: () async => {'categories': []},
        fetchPage: (query) async => {
          'products': query['type'] == 'variation'
              ? [
                  {'store_api_product': variant},
                ]
              : query['include'] == '10'
              ? [
                  {'store_api_product': parent},
                ]
              : [],
        },
      );
      expect((await catalog.getVariations(10)).single.id, 11);
      final basket = CmsPreviewCartRepository(catalog);
      final added = await basket.addItem(productId: 11);
      expect(added.items.single.productId, 11);
      expect(added.items.single.name, 'Shirt - M');
      expect(added.totals.priceMinor, '1200');
    },
  );
}
