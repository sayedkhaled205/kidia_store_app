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
        api.finalizeIdentityDeletion(
          receipt: 'test-receipt',
          expectedSession: 'confirmed-session',
          appleRevoked: false,
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
        api.finalizeIdentityDeletion(
          receipt: 'test-receipt',
          expectedSession: 'confirmed-session',
          appleRevoked: true,
        ),
        throwsA(unauthorized),
      );
    },
  );

  test(
    'identity protocol sends only scoped JSON and captured merchant session',
    () async {
      final captured = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              captured.add(o);
              h.resolve(Response(requestOptions: o, data: {'approved': true}));
            },
          ),
        );
      final api = DioCustomerAccountApiTransport(
        storeUri: Uri.parse('https://store.example/substore/'),
        authTokenReader: () => 'confirmed-session',
        dio: dio,
      );
      await api.prepareIdentityDeletion(
        receipt: 'private-receipt',
        expectedSession: 'confirmed-session',
      );
      await api.validateAppleDeletion(
        receipt: 'private-receipt',
        expectedSession: 'confirmed-session',
        idToken: 'fresh-fixture-proof',
      );
      await api.finalizeIdentityDeletion(
        receipt: 'private-receipt',
        expectedSession: 'confirmed-session',
        appleRevoked: true,
      );
      expect(captured.map((o) => o.uri.path), [
        '/substore/wp-json/mobishop/v1/customer/account/deletion/prepare',
        '/substore/wp-json/mobishop/v1/customer/account/deletion/apple-proof',
        '/substore/wp-json/mobishop/v1/customer/account/deletion/finalize',
      ]);
      expect(captured.map((o) => o.data), [
        {'receipt': 'private-receipt'},
        {
          'receipt': 'private-receipt',
          'id_token': 'fresh-fixture-proof',
          'platform': 'ios',
        },
        {
          'receipt': 'private-receipt',
          'confirmation': 'delete-my-account',
          'apple_revoked': true,
        },
      ]);
      for (final o in captured) {
        expect(o.method, 'POST');
        expect(o.uri.hasQuery, false);
        expect(o.headers['X-MobiShop-Session'], 'confirmed-session');
        expect(o.headers.containsKey('Authorization'), false);
        expect(o.followRedirects, false);
      }
    },
  );

  for (final step in ['prepare', 'proof']) {
    for (final during in [false, true]) {
      test(
        'replacement session blocks $step ${during ? 'response' : 'dispatch'}',
        () async {
          var token = during ? 'original' : 'replacement';
          var calls = 0;
          final dio = Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (o, h) {
                  calls++;
                  token = 'replacement';
                  h.resolve(
                    Response(requestOptions: o, data: {'approved': true}),
                  );
                },
              ),
            );
          final api = DioCustomerAccountApiTransport(
            storeUri: Uri.parse('https://store.example'),
            authTokenReader: () => token,
            dio: dio,
          );
          await expectLater(
            step == 'prepare'
                ? api.prepareIdentityDeletion(
                    receipt: 'private-receipt',
                    expectedSession: 'original',
                  )
                : api.validateAppleDeletion(
                    receipt: 'private-receipt',
                    expectedSession: 'original',
                    idToken: 'fresh-fixture-proof',
                  ),
            throwsA(unauthorized),
          );
          expect(calls, during ? 1 : 0);
        },
      );
    }
  }
}
