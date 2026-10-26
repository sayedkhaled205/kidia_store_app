import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:kashier_flutter_sdk/src/ui/card/inline_card_form.dart'
    show kashierInlineAmountMatches;
import 'package:mobishop_store_app/features/checkout/data/network/native_payment_client92.dart';

void main() {
  test('provider totals compare exact decimal money, not rounded floats', () {
    expect(kashierInlineAmountMatches('70.00', '70'), true);
    expect(kashierInlineAmountMatches('70.10', '70.1'), true);
    expect(kashierInlineAmountMatches('70.001', '70.00'), false);
    for (final value in ['NaN', '7e1', '-70', ' 70', '70.0000001', '070']) {
      expect(kashierInlineAmountMatches('70.00', value), false);
    }
  });

  for (final mismatch in ['amount', 'currency', 'mode', 'session', 'buyer']) {
    test('$mismatch mismatch cannot submit inline card', () async {
      var token = 'buyer';
      final requests = <String>[];
      final card = _Card();
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              requests.add(r.method);
              if (mismatch == 'buyer') token = 'different-buyer';
              final data = _session();
              if (mismatch == 'amount') data['amount'] = '71.00';
              if (mismatch == 'currency') data['currency'] = 'USD';
              if (mismatch == 'mode') data['mode'] = 'unknown';
              if (mismatch == 'session') {
                data['session_id'] = 'https://untrusted.example';
              }
              h.resolve(
                Response(requestOptions: r, statusCode: 200, data: data),
              );
            },
          ),
        );
      final client = NativePaymentClient92(
        store: Uri.parse('https://merchant.example'),
        token: () => token,
        dio: dio,
            wait: (_) async {},
      );
      await expectLater(
        client.payInline(
          15,
          card: card,
          arabic: true,
          amount: '70.00',
          currency: 'EGP',
        ),
        throwsStateError,
      );
      expect(card.calls, 0);
      expect(requests, ['POST']);
    });
  }

  for (final sdkFails in [false, true]) {
    for (final paid in [false, true]) {
      test(
        'SDK failure=$sdkFails server paid=$paid: one submit, authoritative result',
        () async {
          final requests = <RequestOptions>[];
          final card = _Card()..fails = sdkFails;
          final dio = Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (r, h) {
                  requests.add(r);
                  h.resolve(
                    Response(
                      requestOptions: r,
                      statusCode: 200,
                      data: r.method == 'POST'
                          ? _session()
                          : {
                              'order_id': 15,
                              'paid': paid,
                              'status': paid ? 'processing' : 'pending',
                            },
                    ),
                  );
                },
              ),
            );
          final client = NativePaymentClient92(
            store: Uri.parse('https://merchant.example'),
            token: () => 'buyer',
            dio: dio,
            wait: (_) async {},
          );
          expect(
            await client.payInline(
              15,
              card: card,
              arabic: true,
              amount: '70.00',
              currency: 'EGP',
            ),
            paid,
          );
          expect(card.calls, 1);
          expect(card.parameters, (
            '123456789012345678901234',
            KashierMode.test,
            KashierLanguage.ar,
            '70.00',
            'EGP',
            true,
          ));
          expect(requests.map((r) => r.method), ['POST', ...List.filled(paid ? 1 : 6, 'GET')]);
          expect(
            requests.every((r) => r.data == null && !r.followRedirects),
            true,
          );
        },
      );
    }
  }
}

Map<String, Object> _session() => {
  'order_id': 15,
  'adapter': 'kashier',
  'session_id': '123456789012345678901234',
  'mode': 'test',
  'amount': '70.00',
  'currency': 'EGP',
};

class _Card extends KashierInlineCardController {
  int calls = 0;
  bool fails = false;
  Object? parameters;
  @override
  Future<void> pay({
    required String sessionId,
    required KashierMode mode,
    required KashierLanguage language,
    required String expectedAmount,
    required String expectedCurrency,
    required bool Function() canContinue,
  }) async {
    calls++;
    parameters = (
      sessionId,
      mode,
      language,
      expectedAmount,
      expectedCurrency,
      canContinue(),
    );
    if (fails) throw StateError('Simulated bank cancellation or SDK failure');
  }
}
