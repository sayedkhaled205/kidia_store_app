import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_api_transport.dart';

import 'cart_test_fixture.dart';

void main() {
  group('StoreApiCartTransport', () {
    test('keeps tokenized mutations on the configured store', () async {
      RequestOptions? captured;
      final Dio dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (RequestOptions options, handler) {
            captured = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: cartJsonFixture(),
                statusCode: 200,
                headers: Headers.fromMap(<String, List<String>>{
                  'Cart-Token': <String>['rotated-token'],
                }),
              ),
            );
          },
        ),
      );
      final StoreApiCartTransport transport = StoreApiCartTransport(
        storeUri: Uri.parse('https://shop.example.com/store/'),
        dio: dio,
      );

      final response = await transport.request(
        CartApiMethod.post,
        '/wp-json/wc/store/v1/cart/add-item',
        body: <String, dynamic>{'id': 42, 'quantity': 1},
        headers: const <String, String>{'Cart-Token': 'session-token'},
      );

      expect(captured?.uri.path, '/store/wp-json/wc/store/v1/cart/add-item');
      expect(captured?.method, 'POST');
      expect(captured?.headers['Cart-Token'], 'session-token');
      expect(captured?.data, <String, dynamic>{'id': 42, 'quantity': 1});
      expect(response.header('cart-token'), 'rotated-token');
    });

    test('rejects absolute URLs and non-cart Store API paths', () async {
      final StoreApiCartTransport transport = StoreApiCartTransport(
        storeUri: Uri.parse('https://shop.example.com'),
        dio: Dio(),
      );

      await expectLater(
        transport.request(
          CartApiMethod.get,
          'https://attacker.example/wp-json/wc/store/v1/cart',
        ),
        throwsA(isA<StoreApiException>()),
      );
      await expectLater(
        transport.request(
          CartApiMethod.get,
          '/wp-json/wc/store/v1/products/cart',
        ),
        throwsA(isA<StoreApiException>()),
      );
    });

    test('rejects non-HTTPS public stores', () {
      expect(
        () => StoreApiCartTransport(
          storeUri: Uri.parse('http://shop.example.com'),
          dio: Dio(),
        ),
        throwsA(isA<StoreApiException>()),
      );
    });
  });
}
