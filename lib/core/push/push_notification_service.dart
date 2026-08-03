import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'push_bootstrap_config.dart';

final class PushNotificationService {
  PushNotificationService._({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 12),
              ),
            );

  static final PushNotificationService instance = PushNotificationService._();

  final Dio _dio;
  Uri? _registrationUrl;
  Uri? _eventsUrl;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _started = false;

  Future<void> initialize() async {
    if (_started || kIsWeb || AppConfig.isCmsPreview) {
      return;
    }
    _started = true;

    final String configUrl = AppConfig.pushConfigUrl.trim();
    final TargetPlatform platform = defaultTargetPlatform;
    if (configUrl.isEmpty || platform != TargetPlatform.android) {
      return;
    }

    try {
      final Response<dynamic> response = await _dio.get<dynamic>(configUrl);
      final Object? raw = response.data;
      if (raw is! Map<String, dynamic>) {
        return;
      }
      final PushBootstrapConfig config = PushBootstrapConfig.fromJson(raw);
      final FirebaseClientOptions? options = config.firebase;
      if (!config.canRegister || options == null || !options.isComplete) {
        return;
      }

      _registrationUrl = config.registrationUrl;
      _eventsUrl = config.eventsUrl;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: options.apiKey,
            appId: options.appId,
            messagingSenderId: options.messagingSenderId,
            projectId: options.projectId,
            storageBucket: options.storageBucket,
          ),
        );
      }

      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final NotificationSettings permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final String? token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (String refreshedToken) => unawaited(_registerToken(refreshedToken)),
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) => unawaited(_recordEvent(message, 'delivered')),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) => unawaited(_recordEvent(message, 'opened')),
      );
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await _recordEvent(initialMessage, 'opened');
      }
    } catch (error, stackTrace) {
      debugPrint('WooMobile Push initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _registerToken(String token) async {
    final Uri? url = _registrationUrl;
    if (url == null) {
      return;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    String clientId = preferences.getString('woomobile_push_client_id') ?? '';
    if (clientId.isEmpty) {
      final int random = Random.secure().nextInt(1 << 32);
      clientId = 'device_${DateTime.now().microsecondsSinceEpoch}_$random';
      await preferences.setString('woomobile_push_client_id', clientId);
    }
    await _dio.postUri<dynamic>(
      url,
      data: <String, dynamic>{
        'token': token,
        'platform': 'android',
        'client_id': clientId,
        'locale': AppConfig.storeLocale,
        'test': false,
      },
    );
  }

  Future<void> _recordEvent(RemoteMessage message, String event) async {
    final Uri? url = _eventsUrl;
    final String notificationId = message.data['notification_id'] ?? '';
    if (url == null || notificationId.isEmpty) {
      return;
    }
    await _dio.postUri<dynamic>(
      url,
      data: <String, dynamic>{
        'notification_id': notificationId,
        'event': event,
      },
    );
  }
}
