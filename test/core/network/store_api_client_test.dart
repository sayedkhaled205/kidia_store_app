import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';

void main() {
  group('DioStoreApiClient', () {
    test(
      'keeps requests on the configured store and WordPress subdirectory',
      () async {
        RequestOptions? capturedRequest;
        final Dio dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (RequestOptions options, handler) {
              capturedRequest = options;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: const <dynamic>[],
                  statusCode: 200,
                  headers: Headers.fromMap(<String, List<String>>{
                    'X-WP-Total': <String>['0'],
                  }),
                ),
              );
            },
          ),
        );
        final DioStoreApiClient client = DioStoreApiClient(
          storeUri: Uri.parse('https://shop.example.com/store/'),
          dio: dio,
        );

        final StoreApiResponse response = await client.get(
          '/wp-json/wc/store/v1/products',
          queryParameters: <String, dynamic>{
            'page': 2,
            'stock_status[]': <String>['instock', 'onbackorder'],
          },
        );

        expect(
          capturedRequest?.uri.path,
          '/store/wp-json/wc/store/v1/products',
        );
        expect(capturedRequest?.uri.queryParameters['page'], '2');
        expect(
          capturedRequest?.uri.queryParametersAll['stock_status[]'],
          <String>['instock', 'onbackorder'],
        );
        expect(response.header('x-wp-total'), '0');
      },
    );

    test('rejects absolute and non Store API paths', () async {
      final DioStoreApiClient client = DioStoreApiClient(
        storeUri: Uri.parse('https://shop.example.com'),
        dio: Dio(),
      );

      await expectLater(
        client.get('https://attacker.example/products'),
        throwsA(
          isA<StoreApiException>().having(
            (StoreApiException error) => error.kind,
            'kind',
            StoreApiFailureKind.configuration,
          ),
        ),
      );
      await expectLater(
        client.get('/wp-json/wp/v2/users'),
        throwsA(isA<StoreApiException>()),
      );
    });

    test('rejects non-HTTPS public store origins', () {
      expect(
        () => DioStoreApiClient(
          storeUri: Uri.parse('http://shop.example.com'),
          dio: Dio(),
        ),
        throwsA(isA<StoreApiException>()),
      );
    });
  });
}
