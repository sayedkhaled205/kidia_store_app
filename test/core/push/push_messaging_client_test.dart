import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/push/push_bootstrap_config.dart';
import 'package:mobishop_store_app/core/push/push_messaging_client.dart';

const pushOptions = FirebaseClientOptions(
  apiKey: 'public-push-key',
  appId: '1:123:android:push',
  messagingSenderId: '123',
  projectId: 'managed-push-project',
);

const nativePushOptions = FirebaseOptions(
  apiKey: 'public-push-key',
  appId: '1:123:android:push',
  messagingSenderId: '123',
  projectId: 'managed-push-project',
);

const merchantOptions = FirebaseOptions(
  apiKey: 'public-merchant-key',
  appId: '1:456:android:auth',
  messagingSenderId: '456',
  projectId: 'merchant-auth-project',
);

class FakeFirebaseCore extends FirebasePlatform {
  final registry = <String, FirebaseAppPlatform>{};
  int initializations = 0;

  @override
  List<FirebaseAppPlatform> get apps => registry.values.toList();

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      registry[name] ?? (throw StateError('Firebase app is missing: $name'));

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    initializations++;
    final key = name ?? defaultFirebaseAppName;
    if (registry.containsKey(key)) throw StateError('Duplicate Firebase app');
    return registry[key] = FirebaseAppPlatform(key, options!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebasePlatform? original;
  late FakeFirebaseCore firebase;
  setUp(() {
    original = Firebase.delegatePackingProperty;
    firebase = FakeFirebaseCore();
    Firebase.delegatePackingProperty = firebase;
  });
  tearDown(() => Firebase.delegatePackingProperty = original);

  group('notification permission decisions', () {
    const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
    late AuthorizationStatus status;
    late AuthorizationStatus response;
    late int requests;
    late bool requestFails;

    Map<String, Object?> settings(AuthorizationStatus value) => {
      'authorizationStatus': switch (value) {
        AuthorizationStatus.notDetermined => -1,
        AuthorizationStatus.denied => 0,
        AuthorizationStatus.authorized => 1,
        AuthorizationStatus.provisional => 2,
        AuthorizationStatus.deniedPermanently => 3,
      },
      for (final key in [
        'alert',
        'announcement',
        'badge',
        'carPlay',
        'lockScreen',
        'notificationCenter',
        'timeSensitive',
        'criticalAlert',
        'sound',
        'providesAppNotificationSettings',
      ])
        key: -1,
      'showPreviews': -1,
    };

    setUp(() async {
      await FirebasePushMessagingClient().configure(pushOptions);
      status = AuthorizationStatus.notDetermined;
      response = AuthorizationStatus.denied;
      requests = 0;
      requestFails = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'Messaging#getNotificationSettings') {
              return settings(status);
            }
            if (call.method == 'Messaging#requestPermission') {
              requests++;
              if (requestFails) throw PlatformException(code: 'unavailable');
              status = response;
              return settings(status);
            }
            throw StateError('Unexpected messaging call: ${call.method}');
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('first launch prompts once; denial survives a new client', () async {
      expect(await FirebasePushMessagingClient().requestPermission(), isFalse);
      expect(requests, 1);
      // A new service/client after backgrounding or process restart must not
      // ask again. The installed SDK persists whether Android already asked.
      expect(await FirebasePushMessagingClient().requestPermission(), isFalse);
      expect(requests, 1);
    });

    for (final denied in [
      AuthorizationStatus.denied,
      AuthorizationStatus.deniedPermanently,
    ]) {
      test('existing $denied is respected without prompting', () async {
        status = denied;
        expect(
          await FirebasePushMessagingClient().requestPermission(),
          isFalse,
        );
        expect(requests, 0);
      });
    }

    test(
      'permission granted in Settings recovers without another prompt',
      () async {
        expect(
          await FirebasePushMessagingClient().requestPermission(),
          isFalse,
        );
        status = AuthorizationStatus.authorized;
        expect(await FirebasePushMessagingClient().requestPermission(), isTrue);
        expect(requests, 1);
        status = AuthorizationStatus.denied;
        expect(
          await FirebasePushMessagingClient().requestPermission(),
          isFalse,
        );
        expect(requests, 1);
      },
    );

    for (final granted in [
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ]) {
      test(
        'existing $granted never prompts, even after Settings revocation',
        () async {
          status = granted;
          expect(
            await FirebasePushMessagingClient().requestPermission(),
            isTrue,
          );
          status = AuthorizationStatus.denied;
          expect(
            await FirebasePushMessagingClient().requestPermission(),
            isFalse,
          );
          expect(requests, 0);
        },
      );
    }

    test('first grant is retained without repeating the prompt', () async {
      response = AuthorizationStatus.authorized;
      expect(await FirebasePushMessagingClient().requestPermission(), isTrue);
      expect(await FirebasePushMessagingClient().requestPermission(), isTrue);
      expect(requests, 1);
    });

    test(
      'SDK request failure is retryable and is not treated as a denial',
      () async {
        requestFails = true;
        await expectLater(
          FirebasePushMessagingClient().requestPermission(),
          throwsA(isA<FirebaseException>()),
        );
        requestFails = false;
        response = AuthorizationStatus.authorized;
        expect(await FirebasePushMessagingClient().requestPermission(), isTrue);
        expect(requests, 2);
      },
    );
  });

  test(
    'push starts after merchant auth initialized its secondary project',
    () async {
      const secondaryName = 'mobishop-merchant-auth-test';
      final secondary = FirebaseAppPlatform(secondaryName, merchantOptions);
      firebase.registry[secondaryName] = secondary;

      await FirebasePushMessagingClient().configure(pushOptions);

      expect(firebase.initializations, 1);
      expect(Firebase.app().options.projectId, 'managed-push-project');
      expect(firebase.registry[secondaryName], same(secondary));
      expect(
        Firebase.app(secondaryName).options.projectId,
        'merchant-auth-project',
      );
      expect(firebase.registry.length, 2);
    },
  );

  test(
    'matching default push project is reused without duplicate initialization',
    () async {
      final existing = FirebaseAppPlatform(
        defaultFirebaseAppName,
        nativePushOptions,
      );
      firebase.registry[defaultFirebaseAppName] = existing;
      firebase.registry['merchant-auth'] = FirebaseAppPlatform(
        'merchant-auth',
        merchantOptions,
      );

      await FirebasePushMessagingClient().configure(pushOptions);

      expect(firebase.initializations, 0);
      expect(firebase.registry[defaultFirebaseAppName], same(existing));
    },
  );

  test(
    'wrong default project is rejected even when a secondary matches push',
    () async {
      final foreign = FirebaseAppPlatform(
        defaultFirebaseAppName,
        merchantOptions,
      );
      firebase.registry[defaultFirebaseAppName] = foreign;
      firebase.registry['secondary-push'] = FirebaseAppPlatform(
        'secondary-push',
        nativePushOptions,
      );

      await expectLater(
        FirebasePushMessagingClient().configure(pushOptions),
        throwsStateError,
      );

      expect(firebase.initializations, 0);
      expect(firebase.registry[defaultFirebaseAppName], same(foreign));
    },
  );
}
