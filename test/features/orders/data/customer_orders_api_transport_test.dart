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

  test('cancels only through the fixed owned-order route', () async {
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
                  'order': <String, dynamic>{
                    'id': 101,
                    'number': '101',
                    'status': 'cancelled',
                    'status_name': 'Cancelled',
                    'total_display': 'EGP 100',
                    'item_count': 0,
                    'items': <dynamic>[],
                    'can_cancel': false,
                  },
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

    await transport.cancelOrder(101);

    expect(
      captured?.uri.path,
      '/store/wp-json/woo-mobile/v1/customer/orders/101/cancel',
    );
    expect(captured?.uri.hasQuery, isFalse);
    expect(captured?.headers['X-Kidia-Session'], 'safe-session-token');
    expect(captured?.method, 'POST');
  });
}
