import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/data/network/native_payment_client92.dart';

void main() {
  for (final outcome in ['delayed', 'pending', 'failed', 'changed-buyer']) {
    test('settlement confirmation: $outcome, read-only and bounded', () async {
      var token = 'buyer';
      var reads = 0;
      final delays = <Duration>[];
      final dio = Dio()..interceptors.add(InterceptorsWrapper(onRequest: (r,h) {
        expect(r.method, 'GET');
        expect(r.path, endsWith('/15/native-payment/status'));
        reads++;
        final paid = outcome == 'delayed' && reads == 3;
        h.resolve(Response(requestOptions: r, statusCode: 200, data: {
          'order_id': 15, 'paid': paid,
          'status': paid ? 'processing' : outcome == 'failed' ? 'failed' : 'pending',
        }));
      }));
      final client = NativePaymentClient92(store: Uri.parse('https://merchant.example'),
        token: () => token, dio: dio, wait: (delay) async {
          delays.add(delay);
          if (outcome == 'changed-buyer') token = 'other';
        });
      if (outcome == 'changed-buyer') {
        await expectLater(client.confirmPayment(15), throwsStateError);
        expect(reads, 1);
      } else {
        expect(await client.confirmPayment(15), outcome == 'delayed');
        expect(reads, outcome == 'delayed' ? 3 : outcome == 'failed' ? 1 : 6);
        expect(delays.length, reads - 1);
      }
    });
  }

  test(
    'a failed SDK flow reconciles the same order without retrying a payment',
    () async {
      final methods = <String>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              methods.add(r.method);
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: 200,
                  data: r.method == 'POST'
                      ? {
                          'order_id': 15,
                          'adapter': 'kashier',
                          'session_id': '123456789012345678901234',
                          'mode': 'test',
                        }
                      : {'order_id': 15, 'paid': false, 'status': 'pending'},
                ),
              );
            },
          ),
        );
      final client = NativePaymentClient92(
        store: Uri.parse('https://merchant.example'),
        token: () => 'buyer',
        dio: dio,
        presentSession: (_, _, _) async => throw StateError('SDK failed'),
      );
      await expectLater(client.present(15, arabic: true), throwsStateError);
      expect(methods, ['POST', 'GET']);
    },
  );
  for (final store in [
    'https://merchant-one.example',
    'https://merchant-two.example/shop',
  ]) {
    test(
      'native session and reconciliation stay at $store for the same buyer',
      () async {
        final requests = <RequestOptions>[];
        var presented = false;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (r, h) {
                requests.add(r);
                expect(r.followRedirects, false);
                expect(r.headers['X-MobiShop-Channel'], 'mobile');
                expect(r.headers['X-MobiShop-Session'], 'buyer-token');
                h.resolve(
                  Response(
                    requestOptions: r,
                    statusCode: 200,
                    data: r.method == 'POST'
                        ? {
                            'order_id': 15,
                            'adapter': 'kashier',
                            'session_id': '123456789012345678901234',
                            'mode': 'test',
                          }
                        : {'order_id': 15, 'paid': false, 'status': 'pending'},
                  ),
                );
              },
            ),
          );
        final client = NativePaymentClient92(
          store: Uri.parse(store),
          token: () => 'buyer-token',
          dio: dio,
          presentSession: (session, mode, arabic) async {
            expect(session, '123456789012345678901234');
            expect(mode, 'test');
            expect(arabic, true);
            presented = true;
          },
        );
        await client.present(15, arabic: true);
        expect(presented, true);
        expect(requests.map((r) => r.uri.toString()), [
          '$store/wp-json/mobishop/v1/customer/orders/15/native-payment',
          '$store/wp-json/mobishop/v1/customer/orders/15/native-payment/status',
        ]);
        // Successful SDK completion still performs a server read; it cannot set paid.
        expect(requests.map((r) => r.method), ['POST', 'GET']);
      },
    );
  }
  for (final mismatch in [
    'order',
    'customer',
    'adapter',
    'session',
    'redirect',
  ]) {
    test('$mismatch mismatch never opens card entry', () async {
      var token = 'buyer';
      var shown = false;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              if (mismatch == 'customer') token = 'another-buyer';
              h.resolve(
                Response(
                  requestOptions: r,
                  statusCode: mismatch == 'redirect' ? 302 : 200,
                  data: {
                    'order_id': mismatch == 'order' ? 16 : 15,
                    'adapter': mismatch == 'adapter' ? 'website' : 'kashier',
                    'session_id': mismatch == 'session'
                        ? 'https://elsewhere.example'
                        : '123456789012345678901234',
                    'mode': 'live',
                  },
                ),
              );
            },
          ),
        );
      final client = NativePaymentClient92(
        store: Uri.parse('https://merchant.example'),
        token: () => token,
        dio: dio,
        presentSession: (_, _, _) async {
          shown = true;
        },
      );
      await expectLater(client.present(15, arabic: false), throwsStateError);
      expect(shown, false);
    });
  }
}
