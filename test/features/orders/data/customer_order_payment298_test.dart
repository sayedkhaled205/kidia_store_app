import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/orders/data/network/customer_orders_api_transport.dart';
import 'package:mobishop_store_app/features/orders/data/repositories/customer_orders_repository_impl.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';

void main() {
  Map<String, dynamic> order([Map<String, dynamic> payment = const {}]) => {
    'id': 730,
    'number': '730',
    'status': 'pending',
    'status_name': 'Pending',
    'total_display': 'EGP 100',
    'item_count': 1,
    'items': [
      {'name': 'Test product', 'quantity': 1},
    ],
    ...payment,
  };
  test(
    'single-order payment facts use fixed authenticated no-cache GET',
    () async {
      RequestOptions? captured;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              captured = request;
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'order': order({
                      'is_paid': false,
                      'needs_payment': true,
                      'payment_method': 'card',
                      'payment_endpoint_path': '/checkout/order-pay/730/',
                      'payment_url':
                          'https://store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_abc',
                    }),
                  },
                ),
              );
            },
          ),
        );
      final repo = CustomerOrdersRepositoryImpl(
        DioCustomerOrdersApiTransport(
          storeUri: Uri.parse('https://store.example'),
          authTokenReader: () => 'customer-session',
          dio: dio,
        ),
      );
      final result = await repo.getOrder(730);
      expect(captured!.method, 'GET');
      expect(
        captured!.uri.toString(),
        'https://store.example/wp-json/mobishop/v1/customer/orders/730',
      );
      expect(captured!.followRedirects, isFalse);
      expect(captured!.headers['X-MobiShop-Session'], 'customer-session');
      expect(captured!.headers['Cache-Control'], 'no-store');
      expect(result.isPaid, isFalse);
      expect(result.needsPayment, isTrue);
      expect(result.paymentMethod, 'card');
      expect(result.paymentEndpointPath, '/checkout/order-pay/730/');
      expect(result.paymentUri?.queryParameters['key'], 'wc_order_abc');
    },
  );

  test(
    'older or string payment fields never become authoritative facts',
    () async {
      final transport = _Lookup(
        order({'is_paid': 'true', 'needs_payment': 'false'}),
      );
      final result = await CustomerOrdersRepositoryImpl(
        transport,
      ).getOrder(730);
      expect(result.isPaid, isNull);
      expect(result.needsPayment, isNull);
      expect(result.paymentUri, isNull);
      transport.value = order({
        'id': 731,
        'is_paid': true,
        'needs_payment': false,
      });
      await expectLater(
        CustomerOrdersRepositoryImpl(transport).getOrder(730),
        throwsA(isA<CustomerOrdersRepositoryException>()),
      );
    },
  );

  test(
    'identity changed while payment status loads discards response',
    () async {
      var token = 'customer-one';
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              token = 'customer-two';
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'order': order({'is_paid': true, 'needs_payment': false}),
                  },
                ),
              );
            },
          ),
        );
      final transport = DioCustomerOrdersApiTransport(
        storeUri: Uri.parse('https://store.example'),
        authTokenReader: () => token,
        dio: dio,
      );
      await expectLater(
        transport.fetchOrder(730),
        throwsA(
          isA<CustomerOrdersTransportException>().having(
            (e) => e.kind,
            'kind',
            CustomerOrdersTransportFailureKind.unauthorized,
          ),
        ),
      );
    },
  );
}

class _Lookup
    implements CustomerOrdersApiTransport, CustomerOrderLookupTransport {
  _Lookup(this.value);
  Map<String, dynamic> value;
  @override
  Future<CustomerOrdersApiResponse> fetchOrder(int orderId) async =>
      CustomerOrdersApiResponse(data: {'order': value}, statusCode: 200);
  @override
  Future<CustomerOrdersApiResponse> fetchOrders({
    required int page,
    required int perPage,
  }) => throw UnimplementedError();
}
