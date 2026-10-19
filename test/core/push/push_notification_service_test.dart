import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/push/push_bootstrap_config.dart';
import 'package:mobishop_store_app/core/push/push_messaging_client.dart';
import 'package:mobishop_store_app/core/push/push_notification_service.dart';
import 'package:mobishop_store_app/core/push/foreground_push_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Android foreground notice carries content; silent changes stay silent',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      final notices = <ForegroundPushNotice>[];
      final listener = h.service.foregroundNotices.listen(notices.add);
      addTearDown(listener.cancel);
      await _initialize(tester, h.service);
      h.messaging.foreground.add(
        const RemoteMessage(
          notification: RemoteNotification(
            title: 'New collection',
            body: 'Explore today',
          ),
          data: {
            'notification_id': 'n3',
            'destination': 'product',
            'destination_id': '42',
          },
        ),
      );
      h.messaging.foreground.add(
        const RemoteMessage(
          data: {'title': 'Hidden update', 'type': 'mobishop_store_change'},
        ),
      );
      h.messaging.foreground.add(
        const RemoteMessage(data: {'destination': 'home'}),
      );
      await _flush(tester);
      expect(notices, hasLength(1));
      expect(notices.single.title, 'New collection');
      expect(notices.single.body, 'Explore today');
      final recorded = h.service.recordForegroundOpened(notices.single.data);
      await _flush(tester);
      await recorded;
      expect(h.events.last.data['event'], 'opened');
      expect(
        h.events.last.data['client_id'],
        h.registrations.single.data['client_id'],
      );
    },
  );

  testWidgets(
    'iOS uses native foreground presentation without duplicate in-app banner',
    (tester) async {
      final h = _Harness(platform: 'ios');
      addTearDown(h.dispose);
      final notices = <ForegroundPushNotice>[];
      final listener = h.service.foregroundNotices.listen(notices.add);
      addTearDown(listener.cancel);
      await _initialize(tester, h.service);
      h.messaging.foreground.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'Offer'),
          data: {'notification_id': 'ios1'},
        ),
      );
      await _flush(tester);
      expect(notices, isEmpty);
      expect(h.events.single.data['event'], 'delivered');
    },
  );

  for (final entry in {
    'woocommerce': 'https://shop.example/wp-json/mobishop/v1/push',
    'shopify': 'https://api.example/v1/stores/shopify-store/push',
    'odoo': 'https://api.example/v1/stores/odoo-store/push',
  }.entries) {
    testWidgets(
      '${entry.key}: recovers automatically when provisioning finishes',
      (tester) async {
        final h = _Harness(base: entry.value)..ready = false;
        addTearDown(h.dispose);
        await _initialize(tester, h.service);
        expect(h.registrations, isEmpty);
        h.ready = true;
        await tester.pump(const Duration(seconds: 5));
        await _flush(tester);
        expect(h.registrations, hasLength(1));
        expect(h.registrations.single.uri.toString(), '${entry.value}/devices');
        expect(h.messaging.configureCalls, 1);
        await tester.pump(const Duration(minutes: 2));
        expect(h.configReads, 2);
      },
    );
  }

  testWidgets(
    'network and registration outages retry and preserve device identity',
    (tester) async {
      final h = _Harness()..configFailures = 1;
      addTearDown(h.dispose);
      await _initialize(tester, h.service);
      h.registrationFailures = 1;
      await tester.pump(const Duration(seconds: 5));
      await _flush(tester);
      expect(h.registrations, hasLength(1));
      await tester.pump(const Duration(seconds: 10));
      await _flush(tester);
      expect(h.registrations, hasLength(2));
      expect(
        h.registrations[0].data['client_id'],
        h.registrations[1].data['client_id'],
      );
      expect(h.registrations[1].data['token'], 'fcm-token');
    },
  );

  testWidgets(
    'token rotation recovers failed POST without duplicate listeners',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await _initialize(tester, h.service);
      h.registrationFailures = 1;
      h.messaging.tokens.add('rotated-token');
      await _flush(tester);
      await tester.pump(const Duration(seconds: 5));
      await _flush(tester);
      expect(h.registrations.map((r) => r.data['token']), [
        'fcm-token',
        'rotated-token',
        'rotated-token',
      ]);
      h.messaging.foreground.add(
        const RemoteMessage(data: {'notification_id': 'n1'}),
      );
      await _flush(tester);
      expect(h.events, hasLength(1));
      expect(h.messaging.initialReads, 1);
    },
  );

  testWidgets(
    'analytics uses registered client ID and failure does not block opening',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await _initialize(tester, h.service);
      h.eventFailures = 1;
      h.messaging.opened.add(
        const RemoteMessage(
          data: {
            'notification_id': 'n2',
            'action': 'product',
            'product_id': '23',
          },
        ),
      );
      await _flush(tester);
      expect(
        h.events.single.data['client_id'],
        h.registrations.single.data['client_id'],
      );
      expect(h.events.single.data['event'], 'opened');
      expect(h.service.takePendingOpenedAction()?['product_id'], '23');
    },
  );

  testWidgets('background pauses polling; foreground resumes immediately', (
    tester,
  ) async {
    final h = _Harness()..ready = false;
    addTearDown(h.dispose);
    await _initialize(tester, h.service);
    h.service.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(h.configReads, 1);
    h.ready = true;
    h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _flush(tester);
    expect(h.registrations, hasLength(1));
  });

  testWidgets(
    'denied permission does not poll and recovers after Settings return',
    (tester) async {
      final h = _Harness();
      h.messaging.permission = false;
      addTearDown(h.dispose);
      await _initialize(tester, h.service);
      await tester.pump(const Duration(minutes: 2));
      expect(h.configReads, 1);
      expect(h.registrations, isEmpty);
      h.messaging.permission = true;
      h.service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _flush(tester);
      expect(h.registrations, hasLength(1));
    },
  );

  testWidgets('iOS retries delayed APNs/FCM token and uses iOS configuration', (
    tester,
  ) async {
    final h = _Harness(platform: 'ios');
    h.messaging.token = null;
    addTearDown(h.dispose);
    await _initialize(tester, h.service);
    expect(h.registrations, isEmpty);
    h.messaging.token = 'ios-token';
    await tester.pump(const Duration(seconds: 5));
    await _flush(tester);
    expect(h.registrations.single.data['platform'], 'ios');
    expect(h.messaging.configured?.appId, '1:123:ios:app');
  });

  testWidgets(
    'rejects bootstrap for another platform before configuring Firebase',
    (tester) async {
      final h = _Harness(platform: 'ios')..optionPlatform = 'android';
      addTearDown(h.dispose);
      await _initialize(tester, h.service);
      await _dispose(tester, h.service);
      expect(h.messaging.configureCalls, 0);
      expect(h.registrations, isEmpty);
    },
  );

  testWidgets('concurrent initialization shares one request', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    final initialization = Future.wait([
      h.service.initialize(),
      h.service.initialize(),
      h.service.initialize(),
    ]);
    await _flush(tester);
    await initialization;
    expect(h.configReads, 1);
    expect(h.registrations, hasLength(1));
    expect(h.messaging.operations.take(2), ['configure', 'permission']);
    expect(h.messaging.operations.last, 'token');
  });

  testWidgets('dispose cancels pending recovery', (tester) async {
    final h = _Harness()..ready = false;
    await _initialize(tester, h.service);
    await _dispose(tester, h.service);
    await tester.pump(const Duration(minutes: 2));
    expect(h.configReads, 1);
  });
}

class _Harness {
  _Harness({
    this.base = 'https://store.example/push',
    this.platform = 'android',
  }) {
    optionPlatform = platform;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          var status = 200;
          Object payload = {'ok': true};
          if (request.method == 'GET') {
            configReads++;
            expectSync(request.uri.queryParameters['platform'], platform);
            if (configFailures > 0) {
              configFailures--;
              status = 503;
            }
            payload = {
              'enabled': true,
              'clientReady': ready,
              'registrationUrl': '$base/devices',
              'eventsUrl': '$base/events',
              'firebaseOptions': {
                'apiKey': 'public-key',
                'appId': '1:123:$optionPlatform:app',
                'projectId': 'store-fixture',
                'messagingSenderId': '123',
                'iosBundleId': 'app.example.store',
              },
            };
          } else if (request.uri.path.endsWith('/devices')) {
            registrations.add(request);
            if (registrationFailures > 0) {
              registrationFailures--;
              status = 503;
            }
          } else {
            events.add(request);
            if (eventFailures > 0) {
              eventFailures--;
              status = 503;
            }
          }
          if (status != 200) {
            handler.reject(
              DioException(
                requestOptions: request,
                response: Response(requestOptions: request, statusCode: status),
                type: DioExceptionType.badResponse,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: status,
                data: payload,
              ),
            );
          }
        },
      ),
    );
    service = PushNotificationService.forTesting(
      dio: dio,
      messaging: messaging,
      configUrl: '$base/config',
      platform: platform,
    );
  }
  final String base;
  final String platform;
  late String optionPlatform;
  final messaging = _Messaging();
  late final PushNotificationService service;
  bool ready = true;
  int configReads = 0;
  int configFailures = 0;
  int registrationFailures = 0;
  int eventFailures = 0;
  final registrations = <RequestOptions>[];
  final events = <RequestOptions>[];
  Future<void> dispose() async {
    await service.dispose();
    await messaging.dispose();
  }
}

class _Messaging implements PushMessagingClient {
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<RemoteMessage>.broadcast();
  final opened = StreamController<RemoteMessage>.broadcast();
  int configureCalls = 0;
  int initialReads = 0;
  bool permission = true;
  String? token = 'fcm-token';
  FirebaseClientOptions? configured;
  final operations = <String>[];
  @override
  Future<void> configure(FirebaseClientOptions options) async {
    operations.add('configure');
    configureCalls++;
    configured = options;
  }

  @override
  Future<bool> requestPermission() async {
    operations.add('permission');
    return permission;
  }

  @override
  Future<String?> getToken(String platform) async {
    operations.add('token');
    return token;
  }

  @override
  Stream<String> get tokenRefreshes => tokens.stream;
  @override
  Stream<RemoteMessage> get messages => foreground.stream;
  @override
  Stream<RemoteMessage> get openedMessages => opened.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialReads++;
    return null;
  }

  Future<void> dispose() async {
    await tokens.close();
    await foreground.close();
    await opened.close();
  }
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _initialize(
  WidgetTester tester,
  PushNotificationService service,
) async {
  var complete = false;
  final pending = service.initialize().whenComplete(() => complete = true);
  await _flush(tester);
  expect(
    complete,
    isTrue,
    reason: 'Initialization should finish without real network',
  );
  await pending;
}

Future<void> _dispose(
  WidgetTester tester,
  PushNotificationService service,
) async {
  final pending = service.dispose();
  await _flush(tester);
  await pending;
}
