import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/cart/domain/entities/cart.dart';
import '../config/app_config.dart';

final mobileAnalyticsProvider = Provider<MobileAnalytics>((Ref ref) {
  return MobileAnalytics();
});

/// Sends first-party, decision-focused commerce events to the store itself.
///
/// Tracking never blocks a customer action. CMS previews, fixture builds and
/// unconfigured development builds deliberately do not emit events.
class MobileAnalytics {
  MobileAnalytics({Dio? dio, Future<SharedPreferences>? preferences})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              sendTimeout: const Duration(seconds: 4),
            ),
          ),
      // The public constructor parameter remains `preferences` for test injection.
      // ignore: prefer_initializing_formals
      _preferences = preferences;

  static const String _clientKey = 'mobishop_mobile_analytics_client_v1';
  static const String _queueKey = 'mobishop_mobile_analytics_queue_v1';
  static final String _sessionId = _randomIdentifier();

  final Dio _dio;
  Future<SharedPreferences>? _preferences;
  bool _flushing = false;
  Future<void> _pipeline = Future<void>.value();

  Future<void> track(
    String event, {
    int objectId = 0,
    String label = '',
    num value = 0,
    String currency = '',
    int orderId = 0,
    Map<String, Object?> properties = const <String, Object?>{},
    String authToken = '',
  }) async {
    if (!_enabled) return;
    try {
      final String stableEventId = orderId > 0 && event == 'purchase'
          ? 'mobile-purchase-$orderId'
          : orderId > 0 && event == 'purchase_item' && objectId > 0
          ? 'mobile-purchase-item-$orderId-$objectId'
          : 'mobile-event-${_randomIdentifier()}';
      final Future<void> operation = _pipeline.then((_) async {
        await _enqueue(<String, Object?>{
          'event_id': stableEventId,
          'event': event,
          'client_id': await _clientId(),
          'session_id': _sessionId,
          if (objectId > 0) 'object_id': objectId,
          if (label.trim().isNotEmpty) 'label': label.trim(),
          if (value > 0) 'value': value,
          if (currency.trim().isNotEmpty)
            'currency': currency.trim().toUpperCase(),
          if (orderId > 0) 'order_id': orderId,
          if (properties.isNotEmpty) 'properties': properties,
        });
        await _flush(authToken: authToken);
      });
      _pipeline = operation.catchError((Object _) {});
      await operation;
    } on Object {
      // Analytics must never interrupt shopping, authentication or checkout.
    }
  }

  Future<void> captureCart(Cart cart, {String authToken = ''}) async {
    if (!_enabled) return;
    try {
      await _dio.post<void>(
        _endpoint('/wp-json/mobishop/v1/analytics/cart'),
        data: <String, Object?>{
          'client_id': await _clientId(),
          'session_id': _sessionId,
          'items': cart.items
              .map(
                (item) => <String, Object?>{
                  'product_id': item.productId,
                  'name': item.name,
                  'quantity': item.quantity,
                },
              )
              .toList(growable: false),
          'total_minor': int.tryParse(cart.totals.priceMinor) ?? 0,
          'currency': cart.totals.currency.code,
          'currency_minor_unit': cart.totals.currency.minorUnit,
        },
        options: Options(
          headers: authToken.trim().isEmpty
              ? null
              : <String, String>{'X-MobiShop-Session': authToken.trim()},
        ),
      );
    } catch (_) {
      // Cart recovery data is best-effort and never blocks cart updates.
    }
  }

  void trackInBackground(
    String event, {
    int objectId = 0,
    String label = '',
    num value = 0,
    String currency = '',
    int orderId = 0,
    Map<String, Object?> properties = const <String, Object?>{},
    String authToken = '',
  }) {
    unawaited(
      track(
        event,
        objectId: objectId,
        label: label,
        value: value,
        currency: currency,
        orderId: orderId,
        properties: properties,
        authToken: authToken,
      ),
    );
  }

  void captureCartInBackground(Cart cart, {String authToken = ''}) {
    unawaited(captureCart(cart, authToken: authToken));
  }

  bool get _enabled =>
      !AppConfig.isCmsPreview &&
      !AppConfig.useMockHomeLayout &&
      AppConfig.hasConfiguredStore;

  String _endpoint(String path) {
    return '${AppConfig.apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}$path';
  }

  Future<String> _clientId() async {
    final SharedPreferences preferences = await (_preferences ??=
        SharedPreferences.getInstance());
    final String existing = preferences.getString(_clientKey)?.trim() ?? '';
    if (existing.length >= 8 && existing.length <= 64) {
      return existing;
    }
    final String created = _randomIdentifier();
    await preferences.setString(_clientKey, created);
    return created;
  }

  Future<void> _enqueue(Map<String, Object?> payload) async {
    final SharedPreferences preferences = await (_preferences ??=
        SharedPreferences.getInstance());
    final List<String> queue = List<String>.from(
      preferences.getStringList(_queueKey) ?? const <String>[],
    );
    queue.add(jsonEncode(payload));
    if (queue.length > 200) {
      queue.removeRange(0, queue.length - 200);
    }
    await preferences.setStringList(_queueKey, queue);
  }

  Future<void> _flush({String authToken = ''}) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final SharedPreferences preferences = await (_preferences ??=
          SharedPreferences.getInstance());
      final List<String> queue = List<String>.from(
        preferences.getStringList(_queueKey) ?? const <String>[],
      );
      while (queue.isNotEmpty) {
        Map<String, Object?> payload;
        try {
          payload = Map<String, Object?>.from(
            jsonDecode(queue.first) as Map,
          );
        } on Object {
          queue.removeAt(0);
          await preferences.setStringList(_queueKey, queue);
          continue;
        }
        try {
          await _dio.post<void>(
            _endpoint('/wp-json/mobishop/v1/analytics/event'),
            data: payload,
            options: Options(
              headers: authToken.trim().isEmpty
                  ? null
                  : <String, String>{'X-MobiShop-Session': authToken.trim()},
            ),
          );
        } on Object {
          // Keep this event and every later event for the next app activity.
          break;
        }
        queue.removeAt(0);
        await preferences.setStringList(_queueKey, queue);
      }
    } finally {
      _flushing = false;
    }
  }

  static String _randomIdentifier() {
    final Random random = Random.secure();
    final StringBuffer value = StringBuffer();
    for (int index = 0; index < 24; index += 1) {
      value.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return value.toString();
  }
}
