import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
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

  @override
  Future<AuthSession?> read() async {
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
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);

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
    final String encoded = base64Url.encode(utf8.encode(scope)).replaceAll(
      '=',
      '',
    );
    return 'kidia_auth_session_$encoded';
  }
}

class MemoryAuthSessionStore implements AuthSessionStore {
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
}
