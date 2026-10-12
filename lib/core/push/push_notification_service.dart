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
  static const Duration _networkTimeout = Duration(seconds: 12);

  PushNotificationService._({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _networkTimeout,
              receiveTimeout: _networkTimeout,
              sendTimeout: _networkTimeout,
            ),
          );

  static final PushNotificationService instance = PushNotificationService._();

  final Dio _dio;
  final _storeChangeHints = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get storeChangeHints => _storeChangeHints.stream;
  final _openedActions = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get openedActions => _openedActions.stream;
  Map<String, dynamic>? _pendingOpenedAction;
  Map<String, dynamic>? takePendingOpenedAction() {
    final action = _pendingOpenedAction;
    _pendingOpenedAction = null;
    return action;
  }

  void _publishOpenedAction(RemoteMessage message) {
    if (message.data['type'] == 'mobishop_store_change') return;
    final action = Map<String, dynamic>.unmodifiable(message.data);
    if (_openedActions.hasListener) {
      _openedActions.add(action);
    } else {
      _pendingOpenedAction = action;
    }
  }

  Uri? _registrationUrl;
  Uri? _eventsUrl;
  bool _started = false;
  bool _listening = false;
  String _platform = 'android';

  Future<void> initialize() async {
    if (_started || kIsWeb || AppConfig.isCmsPreview) {
      return;
    }
    final String configUrl = AppConfig.pushConfigUrl.trim();
    final TargetPlatform platform = defaultTargetPlatform;
    if (configUrl.isEmpty ||
        (platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS)) {
      return;
    }
    _started = true;
    _platform = platform == TargetPlatform.iOS ? 'ios' : 'android';

    try {
      final Uri uri = Uri.parse(configUrl);
      final Response<dynamic> response = await _dio.getUri<dynamic>(
        uri.replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'platform': _platform,
          },
        ),
      );
      final Object? raw = response.data;
      if (raw is! Map<String, dynamic>) {
        return;
      }
      final PushBootstrapConfig config = PushBootstrapConfig.fromJson(raw);
      final FirebaseClientOptions? options = config.firebase;
      if (!config.canRegister ||
          options == null ||
          !options.supportsPlatform(_platform)) {
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
            iosBundleId: options.iosBundleId,
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

      // Apple must issue an APNs token before Firebase can request an FCM token.
      if (platform == TargetPlatform.iOS) {
        String? apnsToken;
        for (int attempt = 0; attempt < 30; attempt++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            break;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null || apnsToken.isEmpty) {
          return;
        }
      }

      final String? token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
      messaging.onTokenRefresh.listen(
        (String refreshedToken) => unawaited(_registerToken(refreshedToken)),
      );
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _publishStoreChangeHint(message);
        unawaited(_recordEvent(message, 'delivered'));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _publishStoreChangeHint(message);
        _publishOpenedAction(message);
        unawaited(_recordEvent(message, 'opened'));
      });
      _listening = true;
      final RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _publishStoreChangeHint(initialMessage);
        _publishOpenedAction(initialMessage);
        await _recordEvent(initialMessage, 'opened');
      }
    } catch (error, stackTrace) {
      debugPrint('MobiShop Push initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _started = _listening;
    }
  }

  void _publishStoreChangeHint(RemoteMessage message) {
    if (message.data['type'] == 'mobishop_store_change') {
      _storeChangeHints.add(Map<String, dynamic>.unmodifiable(message.data));
    }
  }

  Future<void> _registerToken(String token) async {
    final Uri? url = _registrationUrl;
    if (url == null) {
      return;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    String clientId = preferences.getString('mobishop_push_client_id') ?? '';
    if (clientId.isEmpty) {
      final int random = Random.secure().nextInt(1 << 32);
      clientId = 'device_${DateTime.now().microsecondsSinceEpoch}_$random';
      await preferences.setString('mobishop_push_client_id', clientId);
    }
    await _dio.postUri<dynamic>(
      url,
      data: <String, dynamic>{
        'token': token,
        'platform': _platform,
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
