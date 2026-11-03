import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';

void main() {
  final unauthorized = isA<CustomerAccountTransportException>().having(
    (e) => e.kind,
    'kind',
    CustomerAccountTransportFailureKind.unauthorized,
  );

  test(
    'account replacement prevents deletion before network dispatch',
    () async {
      var calls = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              calls++;
              h.resolve(
                Response(requestOptions: o, data: {'status': 'pending'}),
              );
            },
          ),
        );
      final api = DioCustomerAccountApiTransport(
        storeUri: Uri.parse('https://store.example/'),
        authTokenReader: () => 'replacement-session',
        dio: dio,
      );
      await expectLater(
        api.requestDeletion(
          receipt: 'test-receipt',
          expectedSession: 'confirmed-session',
        ),
        throwsA(unauthorized),
      );
      expect(calls, 0);
    },
  );

  test('receipt status is sent in JSON without any customer session', () async {
    RequestOptions? captured;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            captured = o;
            h.resolve(
              Response(requestOptions: o, data: {'status': 'completed'}),
            );
          },
        ),
      );
    final api = DioCustomerAccountApiTransport(
      storeUri: Uri.parse('https://store.example/substore/'),
      authTokenReader: () => 'another-customer-session',
      dio: dio,
    );
    expect(await api.deletionStatus('private-receipt'), {
      'status': 'completed',
    });
    expect(
      captured?.uri.path,
      '/substore/wp-json/mobishop/v1/customer/account/deletion/status',
    );
    expect(captured?.uri.hasQuery, false);
    expect(captured?.headers.containsKey('X-MobiShop-Session'), false);
    expect(captured?.data, {'receipt': 'private-receipt'});
    expect(captured?.method, 'POST');
    expect(captured?.followRedirects, false);
  });

  test(
    'replacement session cannot receive the previous deletion result',
    () async {
      var token = 'confirmed-session';
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              token = 'replacement-session';
              h.resolve(
                Response(
                  requestOptions: o,
                  data: {'status': 'pending', 'user_id': 7},
                ),
              );
            },
          ),
        );
      final api = DioCustomerAccountApiTransport(
        storeUri: Uri.parse('https://store.example/'),
        authTokenReader: () => token,
        dio: dio,
      );
      await expectLater(
        api.requestDeletion(
          receipt: 'test-receipt',
          expectedSession: 'confirmed-session',
        ),
        throwsA(unauthorized),
      );
    },
  );
}
