import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_money_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_product_model.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';

void main() {
  group('CatalogProductModel', () {
    test(
      'parses a Store API product and tolerates malformed optional records',
      () {
        final CatalogProductModel product = CatalogProductModel.fromJson(
          <String, dynamic>{
            'id': 42,
            'name': 'Everyday Dress',
            'slug': 'everyday-dress',
            'type': 'variable',
            'permalink': 'https://shop.example.com/product/everyday-dress',
            'sku': 'DR-42',
            'short_description': '<p>Soft fabric</p>',
            'description': '<p>Full description</p>',
            'is_featured': 1,
            'on_sale': true,
            'is_purchasable': true,
            'is_in_stock': true,
            'average_rating': '4.75',
            'review_count': '12',
            'prices': <String, dynamic>{
              'currency_code': 'EGP',
              'currency_symbol': 'EGP',
              'currency_prefix': 'EGP ',
              'currency_minor_unit': 2,
              'price': '129950',
              'regular_price': '149950',
              'sale_price': '129950',
            },
            'images': <dynamic>[
              <String, dynamic>{
                'src': 'https://cdn.example.com/dress.jpg',
                'thumbnail': 'https://cdn.example.com/dress-300.jpg',
                'alt': 'Blue dress',
              },
              <String, dynamic>{'src': 'javascript:alert(1)'},
            ],
            'categories': <dynamic>[
              <String, dynamic>{'id': 3, 'name': 'Dresses', 'slug': 'dresses'},
              <String, dynamic>{'id': 0},
            ],
            'brands': <dynamic>[
              <String, dynamic>{
                'id': 7,
                'name': 'Sample Brand',
                'slug': 'sample-brand',
              },
            ],
            'attributes': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'name': 'Size',
                'taxonomy': 'pa_size',
                'has_variations': true,
                'terms': <dynamic>[
                  <String, dynamic>{'id': 11, 'name': 'M', 'slug': 'm'},
                ],
              },
            ],
            'variations': <dynamic>[
              <String, dynamic>{
                'id': 99,
                'attributes': <dynamic>[
                  <String, dynamic>{'name': 'Size', 'value': 'M'},
                ],
              },
              <String, dynamic>{'id': 'broken'},
            ],
          },
        );

        expect(product.id, 42);
        expect(product.name, 'Everyday Dress');
        expect(product.stockStatus, CatalogStockStatus.inStock);
        expect(product.averageRating, 4.75);
        expect(product.prices.priceMinor, '129950');
        expect(product.prices.isDiscounted, isTrue);
        expect(
          product.prices.displayAmount(product.prices.priceMinor),
          'EGP 1299.50',
        );
        expect(product.images, hasLength(1));
        expect(product.categories.single.name, 'Dresses');
        expect(product.brands.single.slug, 'sample-brand');
        expect(product.attributes.single.terms.single.slug, 'm');
        expect(product.variations.single.id, 99);
      },
    );

    test('requires only a valid product id and supplies safe fallbacks', () {
      final CatalogProductModel product = CatalogProductModel.fromJson(
        <String, dynamic>{'id': '5'},
      );

      expect(product.name, 'Product 5');
      expect(product.slug, '5');
      expect(product.type, 'simple');
      expect(product.prices.hasPrice, isFalse);
    });

    test('rejects an unusable product record', () {
      expect(
        () => CatalogProductModel.fromJson(<String, dynamic>{'id': 0}),
        throwsFormatException,
      );
    });
  });

  test('category parser ignores unsafe image URLs and normalizes counts', () {
    final CatalogCategoryModel category = CatalogCategoryModel.fromJson(
      <String, dynamic>{
        'id': 8,
        'name': 'Shoes',
        'slug': 'shoes',
        'count': -4,
        'image': <String, dynamic>{'src': 'file:///private/image.png'},
      },
    );

    expect(category.count, 0);
    expect(category.image, isNull);
  });

  test(
    'money preserves very large minor-unit amounts without precision loss',
    () {
      final CatalogMoneyModel money =
          CatalogMoneyModel.fromJson(<String, dynamic>{
            'currency_code': 'USD',
            'currency_symbol': r'$',
            'currency_minor_unit': 2,
            'price': '999999999999999999999999',
          });

      expect(
        money.decimalAmount(money.priceMinor),
        '9999999999999999999999.99',
      );
      expect(
        money.displayAmount(money.priceMinor),
        r'$9999999999999999999999.99',
      );
    },
  );
}
