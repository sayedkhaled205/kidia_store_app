import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:kashier_flutter_sdk/src/kashier_connectivity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
  });
  tearDown(() async {
    await KashierConnectivity.instance.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  for (final outcome in [
    'captured',
    'declined',
    'wrong-total',
    'changed-buyer',
  ]) {
    testWidgets('inline SDK dispatch and clearing: $outcome', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = KashierInlineCardController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: KashierInlineCardForm(controller: controller)),
        ),
      );
      for (final entry in {
        'number': '4111111111111111',
        'expiry': '12/39',
        'cvv': '123',
        'name': 'Test Customer',
      }.entries) {
        await tester.enterText(
          find.byKey(Key('inline-card-${entry.key}')),
          entry.value,
        );
      }
      expect(controller.validate(), true);
      final requests = <http.Request>[];
      Object? error;
      // All requests are intercepted in-process. No dummy card leaves this test.
      await tester.runAsync(
        () => http.runWithClient(
          () async {
            try {
              await controller.pay(
                sessionId: '123456789012345678901234',
                mode: KashierMode.test,
                language: KashierLanguage.en,
                expectedAmount: '70.00',
                expectedCurrency: 'EGP',
                canContinue: () => outcome != 'changed-buyer',
              );
            } catch (e) {
              error = e;
            }
          },
          () => MockClient((request) async {
            requests.add(request);
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'data': {
                    '_id': '123456789012345678901234',
                    'merchantId': 'test-merchant',
                    'status': 'ACTIVE',
                    'paymentParams': {
                      'amount': outcome == 'wrong-total' ? 71 : 70,
                      'currency': 'EGP',
                      'order': 'test-order',
                      'hash': 'test-hash',
                      'allowedMethods': 'card',
                      'enable3DS': true,
                    },
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'response': {
                  'status': outcome == 'captured' ? 'CAPTURED' : 'FAILURE',
                  'orderId': 'test-provider-order',
                  'transactionId': 'test-transaction',
                },
              }),
              200,
            );
          }),
        ),
      );
      await tester.pumpAndSettle();
      final submitted = outcome == 'captured' || outcome == 'declined';
      expect(
        requests.map((r) => r.method),
        submitted ? ['GET', 'POST'] : ['GET'],
      );
      expect(error, outcome == 'captured' ? isNull : isNotNull);
      if (submitted) {
        final pay = requests.last;
        expect(pay.url.host, 'test-fep.kashier.io');
        final body = jsonDecode(pay.body) as Map;
        expect(body['order']['amount'], 70);
        expect(body['order']['currency'], 'EGP');
        expect(body['paymentMethod']['card']['save'], false);
        expect(body['paymentMethod']['card']['enable3DS'], true);
        expect(body['paymentMethod']['card']['number'], '4111111111111111');
      }
      for (final id in ['number', 'expiry', 'cvv', 'name']) {
        expect(
          tester
              .widget<TextFormField>(find.byKey(Key('inline-card-$id')))
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
