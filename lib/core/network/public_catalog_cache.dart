import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'store_api_client.dart';
import 'store_api_exception.dart';

/// Stale-while-revalidate for public browsing only. Cart, customer and checkout
/// requests never pass through this cache. Entries are isolated by store/query,
/// bounded on disk and refreshed without replacing a readable page with errors.
class PublicCatalogCache implements StoreApiClient {
  PublicCatalogCache(
    this.network, {
    required String store,
    DateTime Function()? now,
  }) : _key = 'public_catalog_v1:${Uri.encodeComponent(store)}',
       _now = now ?? DateTime.now;

  final StoreApiClient network;
  final String _key;
  final DateTime Function() _now;
  final _entries = <String, Map<String, dynamic>>{};
  final _invalidated = <String>{};
  void invalidate() => _invalidated.addAll(_entries.keys);
  final _pending = <String, Future<StoreApiResponse>>{};
  final _checked = <String, DateTime>{};
  Future<void>? _loaded;
  Future<void> _writing = Future.value();
  static const maxAge = Duration(days: 7);
  static const refreshInterval = Duration(minutes: 1);
  static const maxBytes = 8 * 1024 * 1024;

  static bool supports(String path) => RegExp(
    r'^/wp-json/(wc/store/v1/products(?:/\d+|/categories|/collection-data|/attributes(?:/\d+/terms)?)?|mobishop/v1/(?:category-page|products/\d+/variations))$',
  ).hasMatch(path);

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.length > maxBytes) return;
      final values = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in values.entries.take(96)) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        if (value['saved'] is int &&
            value['headers'] is Map &&
            value.containsKey('data')) {
          _entries[entry.key] = value;
        }
      }
    } catch (_) {
      /* A corrupt/full cache must never break catalog reads. */
    }
  }

  void _discard(String key) {
    _entries.remove(key);
    _checked.remove(key);
    _invalidated.remove(key);
  }

  Future<void> _save() {
    _writing = _writing.then((_) async {
      try {
        var raw = jsonEncode(_entries);
        while (raw.length > maxBytes && _entries.isNotEmpty) {
          _discard(_entries.keys.first);
          raw = jsonEncode(_entries);
        }
        await (await SharedPreferences.getInstance()).setString(_key, raw);
      } catch (_) {
        /* Browsing remains available if local storage is full. */
      }
    });
    return _writing;
  }

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (!supports(path)) {
      return network.get(path, queryParameters: queryParameters);
    }
    await (_loaded ??= _load());
    final key =
        '$path?${jsonEncode(SplayTreeMap<String, dynamic>.from({...?queryParameters}..remove('_mobile_cache_bust')))}';
    final saved = _entries[key];
    if (saved != null &&
        _now().difference(
              DateTime.fromMillisecondsSinceEpoch(saved['saved'] as int),
            ) <
            maxAge) {
      try {
        final response = StoreApiResponse(
          data: saved['data'],
          statusCode: 200,
          headers: (saved['headers'] as Map).map(
            (k, v) => MapEntry('$k', (v as List).cast<String>()),
          ),
        );
        if (_invalidated.remove(key)) {
          try {
            return await _refresh(key, path, queryParameters);
          } on StoreApiException catch (error) {
            if (!{
              StoreApiFailureKind.connection,
              StoreApiFailureKind.timeout,
              StoreApiFailureKind.server,
            }.contains(error.kind)) {
              rethrow;
            }
            return response;
          }
        }
        final checked = _checked[key];
        if (checked == null || _now().difference(checked) >= refreshInterval) {
          unawaited(
            _refresh(
              key,
              path,
              queryParameters,
            ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
        return response;
      } on StoreApiException {
        rethrow;
      } catch (_) {
        _entries.remove(key);
      }
    }
    return _refresh(key, path, queryParameters);
  }

  Future<StoreApiResponse> _refresh(
    String key,
    String path,
    Map<String, dynamic>? query,
  ) {
    return _pending[key] ??= (() async {
      _checked[key] = _now();
      while (_checked.length > 192) {
        _checked.remove(_checked.keys.first);
      }
      try {
        final response = await network.get(path, queryParameters: query);
        if (response.statusCode != null && response.statusCode != 200) {
          return response;
        }
        final value = <String, dynamic>{
          'saved': _now().millisecondsSinceEpoch,
          'data': response.data,
          'headers': response.headers,
        };
        if (jsonEncode(value).length <= 512 * 1024) {
          _entries.remove(key);
          _entries[key] = value;
          while (_entries.length > 96) {
            _discard(_entries.keys.first);
          }
          await _save();
        }
        return response;
      } on StoreApiException catch (error) {
        if (!{
          StoreApiFailureKind.connection,
          StoreApiFailureKind.timeout,
          StoreApiFailureKind.server,
        }.contains(error.kind)) {
          _entries.remove(key);
          await _save();
        }
        rethrow;
      } finally {
        _pending.remove(key);
      }
    })();
  }
}
