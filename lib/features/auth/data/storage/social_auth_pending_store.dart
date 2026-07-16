import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';

abstract interface class SocialAuthPendingStore {
  Future<SocialAuthPending?> read();

  Future<void> write(SocialAuthPending pending);

  Future<void> clear();
}

class SecureSocialAuthPendingStore implements SocialAuthPendingStore {
  SecureSocialAuthPendingStore({
    required String storeUrl,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? FlutterSecureStorage(),
       _key = _storageKey(storeUrl);

  factory SecureSocialAuthPendingStore.forConfiguredStore({
    FlutterSecureStorage? storage,
  }) {
    AppConfig.validateStoreConnection();
    return SecureSocialAuthPendingStore(
      storeUrl: AppConfig.apiBaseUrl,
      storage: storage,
    );
  }

  final FlutterSecureStorage _storage;
  final String _key;

  @override
  Future<SocialAuthPending?> read() async {
    final String? value = await _storage.read(key: _key);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      final dynamic json = jsonDecode(value);
      if (json is! Map) {
        throw const FormatException('Pending social auth must be an object.');
      }
      final SocialAuthPending pending = SocialAuthPending.fromJson(
        Map<String, dynamic>.from(json),
      );
      if (pending.isExpired) {
        await clear();
        return null;
      }
      return pending;
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SocialAuthPending pending) {
    return _storage.write(key: _key, value: jsonEncode(pending.toJson()));
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
    return 'kidia_social_auth_pending_$encoded';
  }
}

class MemorySocialAuthPendingStore implements SocialAuthPendingStore {
  SocialAuthPending? value;

  @override
  Future<SocialAuthPending?> read() async => value;

  @override
  Future<void> write(SocialAuthPending pending) async {
    value = pending;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
