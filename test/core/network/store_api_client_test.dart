import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';

void main() {
  group('DioStoreApiClient', () {
    test('encodes Arabic catalog taxonomy exactly once on the wire', () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: <dynamic>[],
                statusCode: 200,
              ),
            );
          },
        ),
      );
      final client = DioStoreApiClient(
        storeUri: Uri.parse('https://shop.example.com'),
        dio: dio,
      );
      for (final taxonomy in [
        'pa_المقاس',
        'pa_%d8%a7%d9%84%d9%85%d9%82%d8%a7%d8%b3',
      ]) {
        await client.get(
          '/wp-json/wc/store/v1/products',
          queryParameters: CatalogProductQuery(
            search: 'Dino',
            attributes: [
              CatalogAttributeFilter(taxonomy: taxonomy, terms: ['24-25']),
            ],
          ).toStoreApiQuery(),
        );
      }
      for (final request in requests) {
        expect(
          request.uri.queryParameters['attributes[0][attribute]'],
          'pa_المقاس',
        );
        expect(request.uri.queryParameters['attributes[0][slug]'], '24-25');
        expect(request.uri.toString().toLowerCase(), isNot(contains('%25d8')));
      }
    });
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
        expect(capturedRequest?.headers['X-MobiShop-Channel'], 'mobile');
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

    test('allows the same-origin MobiShop bridge', () async {
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
              ),
            );
          },
        ),
      );
      final DioStoreApiClient client = DioStoreApiClient(
        storeUri: Uri.parse('https://shop.example.com/store/'),
        dio: dio,
      );

      await client.get('/wp-json/mobishop/v1/products/12/variations');

      expect(capturedRequest?.headers['X-MobiShop-Channel'], 'mobile');
      expect(
        capturedRequest?.uri.path,
        '/store/wp-json/mobishop/v1/products/12/variations',
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
