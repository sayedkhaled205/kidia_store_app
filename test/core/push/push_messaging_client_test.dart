import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
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
  late FirebasePlatform? original;
  late FakeFirebaseCore firebase;
  setUp(() {
    original = Firebase.delegatePackingProperty;
    firebase = FakeFirebaseCore();
    Firebase.delegatePackingProperty = firebase;
  });
  tearDown(() => Firebase.delegatePackingProperty = original);

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
