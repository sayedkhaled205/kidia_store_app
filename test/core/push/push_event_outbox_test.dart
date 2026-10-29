import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/push/push_event_outbox.dart';
import 'package:mobishop_store_app/core/push/push_checkout_attribution.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final endpoint = Uri.parse(
    'https://store.test/wp-json/mobishop/v1/push/events',
  );
  const event = {
    'notification_id': 'campaign-123',
    'event': 'opened',
    'client_id': 'device-123',
  };
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'offline event survives a new service and drains exactly once',
    () async {
      var fail = true;
      final sent = <dynamic>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (fail) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.connectionError,
                  ),
                );
              } else {
                sent.add(request.data);
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: {'recorded': true},
                  ),
                );
              }
            },
          ),
        );
      expect(await PushEventOutbox(dio, endpoint).enqueue(event), isTrue);
      fail = false;
      expect(await PushEventOutbox(dio, endpoint).flush(), isFalse);
      expect(sent, [event]);
      await PushEventOutbox(dio, endpoint).flush();
      expect(sent, hasLength(1));
    },
  );

  test(
    'queued duplicate is coalesced; tenants never share queued events',
    () async {
      var fail = true;
      final sent = <dynamic>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (r, h) {
              if (fail) {
                h.reject(DioException(requestOptions: r));
              } else {
                sent.add(r.data);
                h.resolve(Response(requestOptions: r, statusCode: 200));
              }
            },
          ),
        );
      final box = PushEventOutbox(dio, endpoint);
      await Future.wait([box.enqueue(event), box.enqueue(event)]);
      fail = false;
      await PushEventOutbox(
        dio,
        Uri.parse('https://other.test/push/events'),
      ).flush();
      expect(sent, isEmpty);
      await box.flush();
      expect(sent, [event]);
    },
  );

  for (final status in [404, 422, 429, 503]) {
    test(
      '$status discards invalid evidence or retains retryable evidence',
      () async {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (r, h) => h.reject(
                DioException(
                  requestOptions: r,
                  response: Response(requestOptions: r, statusCode: status),
                ),
              ),
            ),
          );
        expect(
          await PushEventOutbox(dio, endpoint).enqueue(event),
          [429, 503].contains(status),
        );
      },
    );
  }

  test(
    'checkout attribution is recent, same-origin and pseudonymous',
    () async {
      SharedPreferences.setMockInitialValues({
        'mobishop_push_client_id': 'device-123',
      });
      expect(await PushCheckoutAttribution.headers(endpoint), isEmpty);
      await PushCheckoutAttribution.opened(endpoint);
      expect(
        await PushCheckoutAttribution.headers(
          Uri.parse('https://store.test/wc/store/v1/checkout'),
        ),
        {'X-MobiShop-Push-Client': 'device-123'},
      );
      expect(
        await PushCheckoutAttribution.headers(
          Uri.parse('https://other.test/checkout'),
        ),
        isEmpty,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'mobishop_push_click_https://store.test',
        DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
      );
      expect(await PushCheckoutAttribution.headers(endpoint), isEmpty);
    },
  );

  test('malformed client cannot enter an HTTP header', () async {
    SharedPreferences.setMockInitialValues({
      'mobishop_push_client_id': 'device\r\nInjected: yes',
    });
    await PushCheckoutAttribution.opened(endpoint);
    expect(await PushCheckoutAttribution.headers(endpoint), isEmpty);
  });
}
