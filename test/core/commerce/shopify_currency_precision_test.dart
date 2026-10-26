import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/currency_minor_units.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/features/catalog/data/shopify/shopify_catalog_gateway.dart';

class _Reader implements ShopifyStorefrontReader {
  _Reader(this.currency, this.amount);
  final String currency, amount;
  @override
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async => {
    'product': {
      'id': 'gid://shopify/Product/1',
      'title': 'Price test',
      'handle': 'price-test',
      'description': '',
      'descriptionHtml': '',
      'onlineStoreUrl': null,
      'requiresSellingPlan': false,
      'options': [],
      'priceRange': {
        'minVariantPrice': {'currencyCode': currency, 'amount': amount},
        'maxVariantPrice': {'currencyCode': currency, 'amount': amount},
      },
      'availableForSale': true,
      'selectedOrFirstAvailableVariant': {
        'id': 'gid://shopify/ProductVariant/2',
      },
    },
  };
}

void main() {
  for (final entry in {
    'INR': (2, '12.34'),
    'SEK': (2, '12.34'),
    'ZAR': (2, '12.34'),
    'CLP': (0, '1234'),
    'VND': (0, '1234'),
    'TND': (3, '1.234'),
    'JOD': (3, '1.234'),
  }.entries) {
    test('Shopify catalog preserves exact ${entry.key} prices', () async {
      final product = await ShopifyCatalogGateway(
        client: _Reader(entry.key, entry.value.$2),
        currencyMinorUnits: commerceCurrencyMinorUnits,
      ).getProduct(1);
      expect(product.product.prices.currencyMinorUnit, entry.value.$1);
      expect(product.product.prices.priceMinor, '1234');
    });
  }
  for (final entry in {
    'XXX': '12.34',
    'ZZZ': '12.34',
    'INR': '12.345',
    'VND': '12.3',
  }.entries) {
    test(
      'unknown or overprecise ${entry.key} prices are never guessed',
      () async {
        final gateway = ShopifyCatalogGateway(
          client: _Reader(entry.key, entry.value),
          currencyMinorUnits: commerceCurrencyMinorUnits,
        );
        await expectLater(gateway.getProduct(1), throwsFormatException);
      },
    );
  }
}
