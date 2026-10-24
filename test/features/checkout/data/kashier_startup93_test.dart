import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
// Regression for the pinned runtime patch; no payment or issuer data is used.
// ignore: implementation_imports
import 'package:kashier_flutter_sdk/src/kashier_connectivity.dart';
import 'package:mobishop_store_app/features/checkout/data/network/native_payment_client92.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const events = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() async {
    await KashierConnectivity.instance.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test(
    'first request joins delayed initialization rather than assuming offline',
    () async {
      final platform = Completer<List<String>>();
      var checks = 0;
      messenger.setMockMethodCallHandler(channel, (_) {
        checks++;
        return platform.future;
      });
      messenger.setMockMethodCallHandler(events, (_) async => null);
      KashierSDK.initialize(mode: KashierMode.test);
      var completed = false;
      final first = KashierConnectivity.instance.hasInternet().then((result) {
        completed = true;
        return result;
      });
      final second = KashierConnectivity.instance.start();
      await Future<void>.delayed(Duration.zero);
      expect(completed, false);
      expect(checks, 1);
      platform.complete(['none']);
      expect(await first, false);
      await second;
    },
  );

  for (final code in [
    KashierErrorCode.networkError,
    KashierErrorCode.userCancelled,
    KashierErrorCode.paymentDeclined,
  ]) {
    test(
      '$code is surfaced once without silently completing or retrying payment',
      () async {
        var calls = 0;
        messenger.setMockMethodCallHandler(channel, (_) async => ['none']);
        messenger.setMockMethodCallHandler(events, (_) async => null);
        await expectLater(
          presentKashierSession92(
            'test-session',
            'test',
            true,
            runner:
                ({
                  required sessionId,
                  required onSuccess,
                  required onFailure,
                  onPending,
                }) async {
                  calls++;
                  onFailure(
                    KashierPaymentError.fromCode(
                      code,
                      details: 'private-payload',
                    ),
                  );
                },
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'safe error',
              'Native payment: ${code.name}',
            ),
          ),
        );
        expect(calls, 1);
      },
    );
  }
}
