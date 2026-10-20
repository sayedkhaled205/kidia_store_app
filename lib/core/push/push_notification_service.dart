import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'push_bootstrap_config.dart';
import 'push_messaging_client.dart';
import 'foreground_push_notice.dart';

final class PushNotificationService with WidgetsBindingObserver {
  static const Duration _networkTimeout = Duration(seconds: 12);

  PushNotificationService._()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: _networkTimeout,
          receiveTimeout: _networkTimeout,
          sendTimeout: _networkTimeout,
          followRedirects: false,
        ),
      ),
      _messaging = FirebasePushMessagingClient(),
      _configUrl = AppConfig.pushConfigUrl.trim(),
      _platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
      _enabled =
          !kIsWeb &&
          !AppConfig.isCmsPreview &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS),
      _observeLifecycle = true,
      _retryBase = const Duration(seconds: 5);

  @visibleForTesting
  PushNotificationService.forTesting({
    required Dio dio,
    required PushMessagingClient messaging,
    required String configUrl,
    String platform = 'android',
    Duration retryBase = const Duration(seconds: 5),
    // Retain readable public names for the dependency-injection seam.
    // ignore: prefer_initializing_formals
  }) : _dio = dio,
       // ignore: prefer_initializing_formals
       _messaging = messaging,
       // ignore: prefer_initializing_formals
       _configUrl = configUrl,
       // ignore: prefer_initializing_formals
       _platform = platform,
       _enabled = true,
       _observeLifecycle = false,
       // ignore: prefer_initializing_formals
       _retryBase = retryBase;

  static final PushNotificationService instance = PushNotificationService._();

  final Dio _dio;
  final PushMessagingClient _messaging;
  final String _configUrl;
  final String _platform;
  final bool _enabled;
  final bool _observeLifecycle;
  final Duration _retryBase;
  final _storeChangeHints = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get storeChangeHints => _storeChangeHints.stream;
  final _openedActions = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get openedActions => _openedActions.stream;
  final _foregroundNotices = StreamController<ForegroundPushNotice>.broadcast();
  Stream<ForegroundPushNotice> get foregroundNotices =>
      _foregroundNotices.stream;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Map<String, dynamic>? _pendingOpenedAction;
  Uri? _registrationUrl;
  Uri? _eventsUrl;
  Timer? _retryTimer;
  Future<void>? _initializing;
  Future<String>? _clientId;
  String? _pendingToken;
  int _retryAttempt = 0;
  bool _ready = false;
  bool _listening = false;
  bool _observing = false;
  bool _permissionDenied = false;
  bool _active = true;
  bool _disposed = false;

  Map<String, dynamic>? takePendingOpenedAction() {
    final action = _pendingOpenedAction;
    _pendingOpenedAction = null;
    return action;
  }

  Future<void> initialize() {
    if (_disposed || !_enabled || _configUrl.isEmpty || _ready || !_active) {
      return Future<void>.value();
    }
    final running = _initializing;
    if (running != null) return running;
    if (_observeLifecycle && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _retryTimer?.cancel();
    return _initializing = _initialize().whenComplete(() {
      _initializing = null;
      if (!_ready && !_permissionDenied) _scheduleRetry();
    });
  }

  Future<void> _initialize() async {
    try {
      final uri = Uri.parse(_configUrl);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        _permissionDenied = true;
        return;
      }
      final response = await _dio.getUri<dynamic>(
        uri.replace(
          queryParameters: {...uri.queryParameters, 'platform': _platform},
        ),
      );
      if (_disposed || response.data is! Map<String, dynamic>) return;
      final config = PushBootstrapConfig.fromJson(response.data);
      final options = config.firebase;
      if (!config.canRegister ||
          options == null ||
          !options.supportsPlatform(_platform)) {
        return;
      }

      await _messaging.configure(options);
      if (_disposed) return;
      _registrationUrl = config.registrationUrl;
      _eventsUrl = config.eventsUrl;
      _permissionDenied = !await _messaging.requestPermission();
      if (_disposed || _permissionDenied) return;
      _listen();
      final token = _pendingToken ?? await _messaging.getToken(_platform);
      if (_disposed || token == null || token.isEmpty) return;
      await _registerToken(token);
      if (_disposed) return;
      if (_pendingToken == token) _pendingToken = null;
      _ready = _pendingToken == null;
      if (_ready) _retryAttempt = 0;
    } catch (_) {
      // Requests can contain device tokens: never log them on failure.
      debugPrint('MobiShop push is waiting to reconnect.');
    }
  }

  void _scheduleRetry() {
    if (_disposed || !_active || _retryTimer?.isActive == true) return;
    final multiplier = 1 << min(_retryAttempt++, 6);
    final milliseconds = min(_retryBase.inMilliseconds * multiplier, 60000);
    _retryTimer = Timer(Duration(milliseconds: milliseconds), () {
      unawaited(initialize());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _retryTimer?.cancel();
      return;
    }
    _permissionDenied = false;
    _ready = false;
    _retryAttempt = 0;
    unawaited(initialize());
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _subscriptions.add(
      _messaging.tokenRefreshes.listen(
        (token) {
          _pendingToken = token;
          _ready = false;
          unawaited(initialize());
        },
        onError: (Object _) {
          _ready = false;
          _scheduleRetry();
        },
      ),
    );
    _subscriptions.add(
      _messaging.messages.listen((message) {
        _publishStoreChangeHint(message);
        _publishForegroundNotice(message);
        unawaited(_recordEvent(message, 'delivered'));
      }, onError: (Object _) {}),
    );
    _subscriptions.add(
      _messaging.openedMessages.listen((message) {
        _publishStoreChangeHint(message);
        _publishOpenedAction(message);
        unawaited(_recordEvent(message, 'opened'));
      }, onError: (Object _) {}),
    );
    unawaited(_readInitialMessage());
  }

  Future<void> _readInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (_disposed || message == null) return;
      _publishStoreChangeHint(message);
      _publishOpenedAction(message);
      await _recordEvent(message, 'opened');
    } catch (_) {
      debugPrint('MobiShop push could not read the initial notification.');
    }
  }

  void _publishStoreChangeHint(RemoteMessage message) {
    if (!_disposed && message.data['type'] == 'mobishop_store_change') {
      _storeChangeHints.add(Map<String, dynamic>.unmodifiable(message.data));
    }
  }

  void _publishOpenedAction(RemoteMessage message) {
    if (_disposed || message.data['type'] == 'mobishop_store_change') return;
    final action = Map<String, dynamic>.unmodifiable(message.data);
    if (_openedActions.hasListener) {
      _openedActions.add(action);
    } else {
      _pendingOpenedAction = action;
    }
  }

  void _publishForegroundNotice(RemoteMessage message) {
    // iOS uses its native foreground presentation configured by the SDK adapter.
    if (_disposed ||
        _platform != 'android' ||
        message.data['type'] == 'mobishop_store_change') {
      return;
    }
    final title =
        (message.notification?.title ?? message.data['title']?.toString() ?? '')
            .trim();
    final body =
        (message.notification?.body ?? message.data['body']?.toString() ?? '')
            .trim();
    if (title.isEmpty && body.isEmpty) return;
    _foregroundNotices.add(
      ForegroundPushNotice(title: title, body: body, data: message.data),
    );
  }

  Future<void> recordForegroundOpened(Map<String, dynamic> data) =>
      _recordEvent(RemoteMessage(data: data), 'opened');

  Future<String> _getClientId() =>
      _clientId ??= _loadClientId().catchError((Object error) {
        _clientId = null;
        throw error;
      });

  Future<String> _loadClientId() async {
    final preferences = await SharedPreferences.getInstance();
    var clientId = preferences.getString('mobishop_push_client_id') ?? '';
    if (clientId.isEmpty) {
      final random = Random.secure().nextInt(1 << 32);
      clientId = 'device_${DateTime.now().microsecondsSinceEpoch}_$random';
      await preferences.setString('mobishop_push_client_id', clientId);
    }
    return clientId;
  }

  Future<void> _registerToken(String token) async {
    final url = _registrationUrl;
    if (_disposed || url == null) return;
    final clientId = await _getClientId();
    if (_disposed) return;
    await _dio.postUri<dynamic>(
      url,
      data: <String, dynamic>{
        'token': token,
        'platform': _platform,
        'client_id': clientId,
        'locale': AppConfig.storeLocale,
        'test': AppConfig.isTestBuild,
      },
    );
  }

  Future<void> _recordEvent(RemoteMessage message, String event) async {
    final url = _eventsUrl;
    final notificationId = message.data['notification_id']?.toString() ?? '';
    if (_disposed || url == null || notificationId.isEmpty) return;
    try {
      final clientId = await _getClientId();
      if (_disposed) return;
      await _dio.postUri<dynamic>(
        url,
        data: <String, dynamic>{
          'notification_id': notificationId,
          'event': event,
          'client_id': clientId,
        },
      );
    } catch (_) {
      // Optional analytics must not break notification navigation or the app.
      debugPrint('MobiShop push event could not be recorded.');
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _storeChangeHints.close();
    await _openedActions.close();
    await _foregroundNotices.close();
  }
}
