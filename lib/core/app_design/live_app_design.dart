import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../commerce/commerce_connection.dart';
import 'app_design_bundle58.dart';

/// Public declarative designs only. No scripts, credentials or executable code.
class PublishedAppDesign {
  PublishedAppDesign._(this.revision, this.digest, this.encoded, this.design);
  final int revision;
  final String digest;
  final String encoded;
  final AppDesignBundle58 design;

  static const maxResponseBytes = 1500000;
  factory PublishedAppDesign.parse(
    String raw,
    CommercePlatform platform,
    Uri origin,
  ) {
    if (utf8.encode(raw).length > maxResponseBytes) {
      throw const FormatException('Design too large');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['protocol'] != 1 ||
        value['revision'] is! int ||
        (value['revision'] as int) <= 0 ||
        value['bundle'] is! String ||
        value['sha256'] is! String) {
      throw const FormatException('Unsupported publication');
    }
    final encoded = value['bundle'] as String;
    final digest = sha256.convert(utf8.encode(encoded)).toString();
    if (digest != value['sha256']) {
      throw const FormatException('Incomplete publication');
    }
    final design = AppDesignBundle58.fromEncoded(
      encoded,
      platform: platform,
      storeOrigin: origin,
    );
    return PublishedAppDesign._(
      value['revision'] as int,
      digest,
      encoded,
      design,
    );
  }
  String get etag => '"$revision-$digest"';
  String encode() => jsonEncode({
    'protocol': 1,
    'revision': revision,
    'sha256': digest,
    'bundle': encoded,
  });
}

abstract interface class LiveDesignTransport {
  Future<String?> fetch(String? etag);
}

class DioLiveDesignTransport implements LiveDesignTransport {
  DioLiveDesignTransport(this.dio, this.endpoint) {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw const FormatException('Invalid design endpoint');
    }
  }
  final Dio dio;
  final Uri endpoint;
  @override
  Future<String?> fetch(String? etag) async {
    final response = await dio.get<ResponseBody>(
      endpoint.toString(),
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (status) =>
            status == 200 || status == 304 || status == 404,
        headers: {
          'Accept': 'application/json',
          'If-None-Match': ?etag,
        },
      ),
    );
    final body = response.data;
    if (body == null) return null;
    if (response.statusCode != 200) {
      await body.stream.listen((_) {}).cancel();
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in body.stream) {
      if (bytes.length + chunk.length > PublishedAppDesign.maxResponseBytes) {
        throw const FormatException('Design too large');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }
}

abstract interface class LiveDesignCache {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesLiveDesignCache implements LiveDesignCache {
  PreferencesLiveDesignCache(String scope)
    : key = 'published_design_v1_${sha256.convert(utf8.encode(scope))}';
  final String key;
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Design cache unavailable');
    }
  }
}

/// Downloads while browsing, but applies only on the Home route. Checkout,
/// authentication, product selections and dirty forms keep their current UI.
class LiveAppDesign extends ChangeNotifier {
  LiveAppDesign({
    required this.transport,
    required this.cache,
    required this.platform,
    required this.origin,
    this.interval = const Duration(seconds: 30),
  });
  final LiveDesignTransport transport;
  final LiveDesignCache cache;
  final CommercePlatform platform;
  final Uri origin;
  final Duration interval;
  PublishedAppDesign? _downloaded;
  PublishedAppDesign? _applied;
  Timer? _timer;
  Future<void>? _initializing;
  bool _active = false, _safe = false, _busy = false, _disposed = false;
  AppDesignBundle58? get design => _applied?.design;
  int? get revision => _applied?.revision;

  Future<void> initialize() => _initializing ??= _loadCache();
  Future<void> _loadCache() async {
    try {
      final raw = await cache.read();
      if (raw != null && !_disposed) {
        _downloaded = PublishedAppDesign.parse(raw, platform, origin);
        _apply();
      }
    } catch (_) {
      /* A bad cache never prevents the embedded design starting. */
    }
  }

  void configure({required bool active, required bool safeToApply}) {
    if (_disposed) return;
    final resumed = active && !_active;
    _active = active;
    _safe = safeToApply;
    _apply();
    if (!active) {
      _timer?.cancel();
      _timer = null;
    }
    if (resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed || !_active || _busy) return;
    _busy = true;
    _timer?.cancel();
    try {
      await initialize();
      if (_disposed || !_active) return;
      final raw = await transport.fetch(_downloaded?.etag);
      if (raw == null || _disposed) return;
      final next = PublishedAppDesign.parse(raw, platform, origin);
      if (_downloaded != null && next.revision <= _downloaded!.revision) return;
      _downloaded = next;
      // Cache the validated complete revision, not a partial response. The
      // embedded build is always available when local storage is unavailable.
      try {
        await cache.write(next.encode());
      } catch (_) {}
      if (!_disposed) _apply();
    } catch (_) {
      /* Offline, invalid and incompatible updates keep last good UI. */
    } finally {
      _busy = false;
      if (!_disposed && _active) _timer = Timer(interval, refresh);
    }
  }

  void _apply() {
    if (_disposed ||
        !_active ||
        !_safe ||
        _downloaded == null ||
        _downloaded!.revision == _applied?.revision) {
      return;
    }
    final changed = _downloaded!.digest != _applied?.digest;
    _applied = _downloaded;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
