import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/orders/data/network/customer_orders_api_transport.dart';

void main() {
  test('loads only the fixed order route with the customer session', () async {
    RequestOptions? captured;
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (RequestOptions options, handler) {
            captured = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'orders': <dynamic>[],
                  'page': 1,
                  'per_page': 20,
                  'total': 0,
                  'total_pages': 0,
                },
              ),
            );
          },
        ),
      );
    final DioCustomerOrdersApiTransport transport =
        DioCustomerOrdersApiTransport(
          storeUri: Uri.parse('https://shop.example.com/store/'),
          authTokenReader: () => 'safe-session-token',
          dio: dio,
        );

    await transport.fetchOrders(page: 1, perPage: 20);

    expect(
      captured?.uri.path,
      '/store/wp-json/woo-mobile/v1/customer/orders',
    );
    expect(captured?.uri.queryParameters, <String, String>{
      'page': '1',
      'per_page': '20',
    });
    expect(captured?.headers['X-Kidia-Session'], 'safe-session-token');
    expect(captured?.method, 'GET');
  });

  test('does not send an order request without a session', () async {
    final DioCustomerOrdersApiTransport transport =
        DioCustomerOrdersApiTransport(
          storeUri: Uri.parse('https://shop.example.com'),
          authTokenReader: () => null,
        );

    await expectLater(
      transport.fetchOrders(page: 1, perPage: 20),
      throwsA(
        isA<CustomerOrdersTransportException>().having(
          (CustomerOrdersTransportException error) => error.kind,
          'kind',
          CustomerOrdersTransportFailureKind.unauthorized,
        ),
      ),
    );
  });
}
