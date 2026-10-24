import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/hosted_commerce_destination297.dart';

void main() {
  final odoo = CommerceConnection(
    platform: CommercePlatform.odoo,
    storeOrigin: Uri.parse('https://odoo.example'),
  );
  final shopify = CommerceConnection(
    platform: CommercePlatform.shopify,
    storeOrigin: Uri.parse('https://customer.myshopify.com'),
  );
  final woo = CommerceConnection(
    platform: CommercePlatform.wooCommerce,
    storeOrigin: Uri.parse('https://woo.example'),
  );

  test('platform customer destinations remain on their own store', () {
    for (final entry in {
      '/auth': '/account/login',
      '/account': '/account',
      '/profile': '/account',
      '/orders/14': '/account',
      '/addresses': '/account/addresses',
    }.entries) {
      expect(
        HostedCommerceDestination297.forRoute(shopify, entry.key).toString(),
        'https://customer.myshopify.com${entry.value}',
      );
    }
    expect(
      HostedCommerceDestination297.forRoute(odoo, '/cart'),
      isNull,
    );
    expect(
      HostedCommerceDestination297.forRoute(odoo, '/checkout'),
      isNull,
    );
    expect(
      HostedCommerceDestination297.forRoute(odoo, '/account-help').toString(),
      'https://odoo.example/web/login',
    );
  });
  test('Woo and supported native routes remain native', () {
    for (final path in ['/auth', '/account', '/cart', '/checkout']) {
      expect(HostedCommerceDestination297.forRoute(woo, path), isNull);
    }
    expect(HostedCommerceDestination297.forRoute(odoo, '/account'), isNull);
    expect(HostedCommerceDestination297.forRoute(shopify, '/cart'), isNull);
    expect(
      HostedCommerceDestination297.forRoute(shopify, 'https://evil.example'),
      isNull,
    );
  });
  test(
    'product handoff rejects foreign, credential, HTTP, port and admin URLs',
    () {
      for (final url in [
        'https://other.example/shop/a',
        'http://odoo.example/shop/a',
        'https://u:p@odoo.example/shop/a',
        'https://odoo.example:9443/shop/a',
        'https://odoo.example/web/login',
      ]) {
        expect(
          HostedCommerceDestination297.product(odoo, Uri.parse(url)),
          isNull,
        );
      }
      final link = Uri.parse('https://odoo.example/shop/blue-shirt-42');
      expect(HostedCommerceDestination297.product(odoo, link), link);
      expect(HostedCommerceDestination297.product(woo, link), isNull);
    },
  );
}
