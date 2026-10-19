import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_bootstrap_config.dart';

/// SDK boundary for startup recovery without a real FCM device in unit tests.
abstract interface class PushMessagingClient {
  Future<void> configure(FirebaseClientOptions options);
  Future<bool> requestPermission();
  Future<String?> getToken(String platform);
  Stream<String> get tokenRefreshes;
  Stream<RemoteMessage> get messages;
  Stream<RemoteMessage> get openedMessages;
  Future<RemoteMessage?> getInitialMessage();
}

final class FirebasePushMessagingClient implements PushMessagingClient {
  @override
  Future<void> configure(FirebaseClientOptions options) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: options.apiKey,
          appId: options.appId,
          messagingSenderId: options.messagingSenderId,
          projectId: options.projectId,
          storageBucket: options.storageBucket,
          iosBundleId: options.iosBundleId,
        ),
      );
    }
    final current = Firebase.app().options;
    if (current.projectId != options.projectId ||
        current.appId != options.appId ||
        current.messagingSenderId != options.messagingSenderId) {
      throw StateError(
        'The installed app and push configuration do not match.',
      );
    }
    if (options.supportsPlatform('ios')) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  @override
  Future<bool> requestPermission() async {
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken(String platform) async {
    if (platform == 'ios') {
      // APNs can be unavailable at first launch. The service retries later.
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null || apns.isEmpty) return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Stream<String> get tokenRefreshes =>
      FirebaseMessaging.instance.onTokenRefresh;
  @override
  Stream<RemoteMessage> get messages => FirebaseMessaging.onMessage;
  @override
  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;
  @override
  Future<RemoteMessage?> getInitialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
}
