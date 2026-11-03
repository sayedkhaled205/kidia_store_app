import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

/// Used after server-side revocation without clearing a replacement account.
abstract interface class ConditionalAuthSessionStore {
  Future<bool> clearIfToken(String token);
}

class SecureAuthSessionStore
    implements AuthSessionStore, ConditionalAuthSessionStore {
  SecureAuthSessionStore({
    required String storeUrl,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? FlutterSecureStorage(),
       _key = _storageKey(storeUrl);

  factory SecureAuthSessionStore.forConfiguredStore({
    FlutterSecureStorage? storage,
  }) {
    AppConfig.validateStoreConnection();
    return SecureAuthSessionStore(
      storeUrl: AppConfig.apiBaseUrl,
      storage: storage,
    );
  }

  final FlutterSecureStorage _storage;
  final String _key;
  static final Map<String, Future<void>> _pending = {};

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = (_pending[_key] ?? Future<void>.value()).then(
      (_) => action(),
    );
    final settled = result.then<void>((_) {}, onError: (Object _) {});
    _pending[_key] = settled;
    settled.whenComplete(() {
      if (identical(_pending[_key], settled)) _pending.remove(_key);
    });
    return result;
  }

  @override
  Future<AuthSession?> read() => _exclusive(_read);

  Future<AuthSession?> _read() async {
    final String? value = await _storage.read(key: _key);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic json = jsonDecode(value);
      if (json is! Map) {
        throw const FormatException('Stored session must be an object.');
      }
      return AuthSession.fromJson(Map<String, dynamic>.from(json));
    } on FormatException {
      await _storage.delete(key: _key);
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    return _exclusive(
      () => _storage.write(key: _key, value: jsonEncode(session.toJson())),
    );
  }

  @override
  Future<void> clear() => _exclusive(() => _storage.delete(key: _key));

  @override
  Future<bool> clearIfToken(String token) => _exclusive(() async {
    if ((await _read())?.token != token) return false;
    await _storage.delete(key: _key);
    return true;
  });

  static String _storageKey(String storeUrl) {
    final Uri? uri = Uri.tryParse(storeUrl.trim());
    final String scope = uri == null
        ? storeUrl.trim().toLowerCase()
        : uri
              .replace(
                scheme: uri.scheme.toLowerCase(),
                host: uri.host.toLowerCase(),
                query: null,
                fragment: null,
              )
              .toString()
              .replaceFirst(RegExp(r'/$'), '');
    final String encoded = base64Url
        .encode(utf8.encode(scope))
        .replaceAll('=', '');
    return 'mobishop_auth_session_$encoded';
  }
}

class MemoryAuthSessionStore
    implements AuthSessionStore, ConditionalAuthSessionStore {
  AuthSession? value;

  @override
  Future<AuthSession?> read() async => value;

  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<bool> clearIfToken(String token) async {
    if (value?.token != token) return false;
    value = null;
    return true;
  }
}
