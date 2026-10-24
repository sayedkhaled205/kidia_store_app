import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_catalog_client.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_session_store51.dart';
import 'package:mobishop_store_app/core/commerce/shopify_storefront_client.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/cart/data/shopify/shopify_cart_session_store.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/wishlist/data/shared_preferences_wishlist_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HttpFixture implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final payload = {'merchant': options.uri.host};
    return ResponseBody.fromString(
      jsonEncode(
        options.uri.path.endsWith('graphql.json') ? {'data': payload} : payload,
      ),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (status == 302) 'location': ['https://other.example.invalid/'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CommerceConnection _connection(CommercePlatform platform, String merchant) =>
    CommerceConnection(
      platform: platform,
      storeOrigin: Uri.parse(
        platform == CommercePlatform.shopify
            ? 'https://matrix-$merchant.myshopify.com'
            : 'https://$merchant.example.invalid',
      ),
      shopifyPublicStorefrontToken: platform == CommercePlatform.shopify
          ? 'public-fixture-$merchant'
          : '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'Woo checkout fields and shipping calls stay with each merchant',
    () async {
      final fixture = _HttpFixture();
      final dio = Dio()..httpClientAdapter = fixture;
      addTearDown(dio.close);
      if (AppConfig.commercePlatform != CommercePlatform.wooCommerce) {
        expect(
          () => StoreApiCheckoutTransport(
            storeUri: Uri.parse('https://alpha.example.invalid/shop'),
            dio: dio,
          ),
          throwsA(isA<AppConfigurationException>()),
        );
        expect(fixture.requests, isEmpty);
        return;
      }
      for (final merchant in ['alpha', 'beta', 'alpha']) {
        // A WordPress installation in a subdirectory must keep that path too.
        final origin = Uri.parse('https://$merchant.example.invalid/shop');
        final transport = StoreApiCheckoutTransport(storeUri: origin, dio: dio);
        expect(
          (await transport.loadConfiguration()).data['merchant'],
          origin.host,
        );
        await transport.updateCustomer(
          cartToken: 'cart-$merchant',
          body: {
            'billing_address': {'country': merchant == 'alpha' ? 'EG' : 'US'},
          },
        );
        await transport.selectShippingRate(
          cartToken: 'cart-$merchant',
          packageId: 0,
          rateId: 'flat_rate:$merchant',
        );
        final requests = fixture.requests.sublist(fixture.requests.length - 3);
        expect(requests.map((r) => r.uri.host).toSet(), {origin.host});
        expect(requests.map((r) => r.uri.path), [
          '/shop/wp-json/mobishop/v1/checkout-config',
          '/shop/wp-json/wc/store/v1/cart/update-customer',
          '/shop/wp-json/wc/store/v1/cart/select-shipping-rate',
        ]);
        expect(requests.first.headers.containsKey('Cart-Token'), isFalse);
        expect(requests[1].headers['Cart-Token'], 'cart-$merchant');
        expect(requests[2].data, {
          'package_id': 0,
          'rate_id': 'flat_rate:$merchant',
        });
        expect(requests.every((r) => !r.followRedirects), isTrue);
      }
    },
  );

  test(
    'Shopify public tokens and responses never cross merchant origins',
    () async {
      final fixture = _HttpFixture();
      final clients = [
        for (final merchant in ['alpha', 'beta'])
          ShopifyStorefrontClient(
            connection: _connection(CommercePlatform.shopify, merchant),
            adapter: fixture,
          ),
      ];
      addTearDown(() {
        for (final client in clients) {
          client.close();
        }
      });
      for (final index in [0, 1, 0]) {
        final merchant = index == 0 ? 'alpha' : 'beta';
        final data = await clients[index].query('query { shop { name } }');
        final request = fixture.requests.last;
        expect(data['merchant'], 'matrix-$merchant.myshopify.com');
        expect(request.uri.path, '/api/2026-10/graphql.json');
        expect(
          request.headers['X-Shopify-Storefront-Access-Token'],
          'public-fixture-$merchant',
        );
        expect(request.headers.containsKey('Cookie'), isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.followRedirects, isFalse);
      }
      fixture.status = 302;
      await expectLater(
        clients.first.query('query { shop { name } }'),
        throwsA(isA<StoreApiException>()),
      );
      expect(fixture.requests, hasLength(4));
    },
  );

  test(
    'Odoo catalog uses its own origin and rejects Woo or customer paths',
    () async {
      final fixture = _HttpFixture();
      for (final merchant in ['alpha', 'beta']) {
        final client = OdooCatalogClient(
          connection: _connection(CommercePlatform.odoo, merchant),
          adapter: fixture,
        );
        addTearDown(client.close);
        final data = await client.get('/api/mobile/v1/catalog/products');
        expect(data.data['merchant'], '$merchant.example.invalid');
        final request = fixture.requests.last;
        expect(request.followRedirects, isFalse);
        expect(request.headers.containsKey('Cookie'), isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);
        final before = fixture.requests.length;
        for (final path in [
          '/wp-json/wc/store/v1/products',
          '/api/mobile/v1/customer/orders',
          'https://other.example.invalid/products',
        ]) {
          await expectLater(
            client.get(path),
            throwsA(isA<StoreApiException>()),
          );
        }
        expect(fixture.requests.length, before);
      }
    },
  );

  test('Woo catalog rejects absolute URLs before sending a request', () async {
    final fixture = _HttpFixture();
    final dio = Dio()..httpClientAdapter = fixture;
    addTearDown(dio.close);
    final client = DioStoreApiClient(
      storeUri: Uri.parse('https://alpha.example.invalid'),
      dio: dio,
    );
    await expectLater(
      client.get('https://beta.example.invalid/wp-json/wc/store/v1/products'),
      throwsA(isA<StoreApiException>()),
    );
    expect(fixture.requests, isEmpty);
  });

  test(
    'Shopify persisted carts remain separate after restart and clearing',
    () async {
      final a = SecureShopifyCartSessionStore(
        connection: _connection(CommercePlatform.shopify, 'alpha'),
      );
      final b = SecureShopifyCartSessionStore(
        connection: _connection(CommercePlatform.shopify, 'beta'),
      );
      await a.write(
        const ShopifyCartSessionRecord(cartId: 'fixture-cart-alpha'),
      );
      expect(await b.read(), isNull);
      await b.write(
        const ShopifyCartSessionRecord(cartId: 'fixture-cart-beta'),
      );
      final restarted = SecureShopifyCartSessionStore(
        connection: _connection(CommercePlatform.shopify, 'alpha'),
      );
      expect((await restarted.read())!.cartId, 'fixture-cart-alpha');
      await restarted.clear();
      expect(await a.read(), isNull);
      expect((await b.read())!.cartId, 'fixture-cart-beta');
    },
  );

  test(
    'Odoo persisted identities cannot be written to another merchant',
    () async {
      final connection = _connection(CommercePlatform.odoo, 'alpha');
      final a = SecureOdooCustomerSessionStore51(connection: connection);
      final b = SecureOdooCustomerSessionStore51(
        connection: _connection(CommercePlatform.odoo, 'beta'),
      );
      final record = OdooCustomerStoredSession51(
        origin: connection.storeOrigin,
        sessionId: 'fixture_session_alpha_123456',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        customerId: 7,
        partnerId: 11,
      );
      await a.write(record);
      expect(await b.read(), isNull);
      await expectLater(b.write(record), throwsFormatException);
      await b.clear();
      expect((await a.read())!.customerId, 7);
    },
  );

  test(
    'wishlists with identical product IDs remain independent per merchant',
    () async {
      final a = SharedPreferencesWishlistRepository(
        storeUrl: 'https://alpha.example.invalid',
      );
      final b = SharedPreferencesWishlistRepository(
        storeUrl: 'https://beta.example.invalid',
      );
      await a.saveProductIds([7, 11]);
      expect(await b.loadProductIds(), isEmpty);
      await b.saveProductIds([7, 19]);
      await a.saveProductIds([]);
      expect(await b.loadProductIds(), [7, 19]);
    },
  );
}
