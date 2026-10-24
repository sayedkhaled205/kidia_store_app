import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';

import '../app_design/app_design_fixture58.dart';

void main() {
  test('saved Woo design stays bound to its installation folder', () {
    for (final path in ['/shop', '/store-b', '/%D9%85%D8%AA%D8%AC%D8%B1']) {
      final store = 'https://merchant.example.invalid$path';
      final fixture = appDesignFixture58()
        ..['platform'] = 'woocommerce'
        ..['store_origin'] = store;
      final encoded = appDesignRawEncoded58(fixture);
      AppDesignBundle58 parse(String address) => AppDesignBundle58.fromEncoded(
        encoded,
        platform: CommercePlatform.wooCommerce,
        storeOrigin: Uri.parse(address),
      );
      expect(parse('$store/').storeOrigin.toString(), store);
      expect(
        () => parse('https://merchant.example.invalid'),
        throwsFormatException,
      );
      expect(
        () => parse('https://merchant.example.invalid/other'),
        throwsFormatException,
      );
    }
  });
  test('Woo preserves installations in different folders on the same host', () {
    final a = CommerceConnection(
      platform: CommercePlatform.wooCommerce,
      storeOrigin: Uri.parse('https://merchant.example.invalid/store-a/'),
    );
    final b = CommerceConnection(
      platform: CommercePlatform.wooCommerce,
      storeOrigin: Uri.parse('https://merchant.example.invalid/store-b'),
    );
    expect(
      a.storeOrigin.toString(),
      'https://merchant.example.invalid/store-a',
    );
    expect(
      b.storeOrigin.toString(),
      'https://merchant.example.invalid/store-b',
    );
    expect(a.storeOrigin, isNot(b.storeOrigin));
  });

  test('Woo root origins keep their established normalized identity', () {
    final connection = CommerceConnection(
      platform: CommercePlatform.wooCommerce,
      storeOrigin: Uri.parse('https://merchant.example.invalid/'),
    );
    expect(
      connection.storeOrigin.toString(),
      'https://merchant.example.invalid',
    );
  });

  for (final platform in [CommercePlatform.odoo, CommercePlatform.shopify]) {
    test('$platform still requires its own root origin', () {
      expect(
        () => CommerceConnection(
          platform: platform,
          storeOrigin: Uri.parse(
            platform == CommercePlatform.shopify
                ? 'https://merchant.myshopify.com/shop'
                : 'https://merchant.example.invalid/shop',
          ),
        ),
        throwsFormatException,
      );
    });
  }

  for (final uri in [
    'http://merchant.example.invalid/shop',
    'https://buyer:secret@merchant.example.invalid/shop',
    'https://merchant.example.invalid:9443/shop',
    'https://merchant.example.invalid/shop?store=other',
    'https://merchant.example.invalid/shop#other',
    'https://merchant.example.invalid/shop//other',
    'https://merchant.example.invalid/shop//',
    'https://merchant.example.invalid/shop%2fother',
    'https://merchant.example.invalid/shop%5cother',
    'https://merchant.example.invalid/shop%0aother',
    'https://merchant.example.invalid/shop%252fother',
  ]) {
    test('rejects ambiguous store authority or installation path $uri', () {
      expect(
        () => CommerceConnection(
          platform: CommercePlatform.wooCommerce,
          storeOrigin: Uri.parse(uri),
        ),
        throwsFormatException,
      );
    });
  }
}
