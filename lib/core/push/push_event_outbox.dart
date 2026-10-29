import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bounded, store-scoped evidence queue. The server deduplicates each receipt.
final class PushEventOutbox {
  PushEventOutbox(this.dio, this.endpoint);
  final Dio dio;
  final Uri endpoint;
  Future<void> _serial = Future<void>.value();
  String get _key =>
      'mobishop_push_events_${base64Url.encode(utf8.encode('$endpoint'))}';
  static const _maxAge = Duration(days: 7);

  Future<bool> enqueue(Map<String, dynamic> event) => _run(event);
  Future<bool> flush() => _run(null);

  Future<bool> _run(Map<String, dynamic>? event) {
    var pending = false;
    final next = _serial.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      List<Map<String, dynamic>> queue;
      try {
        final raw = jsonDecode(prefs.getString(_key) ?? '[]');
        queue = raw is List
            ? raw
                  .whereType<Map>()
                  .map((v) => Map<String, dynamic>.from(v))
                  .toList()
            : [];
      } catch (_) {
        queue = [];
      }
      queue.removeWhere(
        (item) =>
            item['queued_at'] is! int ||
            now - (item['queued_at'] as int) > _maxAge.inMilliseconds ||
            item['queued_at'] > now,
      );
      if (event != null &&
          !queue.any(
            (item) =>
                item['notification_id'] == event['notification_id'] &&
                item['event'] == event['event'] &&
                item['client_id'] == event['client_id'],
          )) {
        queue.add({...event, 'queued_at': now});
      }
      if (queue.length > 100) queue = queue.sublist(queue.length - 100);
      await prefs.setString(_key, jsonEncode(queue));
      while (queue.isNotEmpty) {
        final body = Map<String, dynamic>.from(queue.first)
          ..remove('queued_at');
        try {
          await dio.postUri<dynamic>(endpoint, data: body);
        } on DioException catch (error) {
          final status = error.response?.statusCode ?? 0;
          // Invalid/stale audience evidence cannot become valid on a retry.
          if (![400, 401, 403, 404, 410, 422].contains(status)) break;
        } catch (_) {
          break;
        }
        queue.removeAt(0);
        await prefs.setString(_key, jsonEncode(queue));
      }
      pending = queue.isNotEmpty;
    });
    _serial = next.catchError((Object _) {});
    return next.then((_) => pending, onError: (Object _) => true);
  }
}
