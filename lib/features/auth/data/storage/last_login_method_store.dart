import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';

enum LastLoginMethod { google, facebook, phone, email, apple }

/// A local display hint only: never an identifier, credential or proof.
class LastLoginMethodStore {
  LastLoginMethodStore(Uri store)
    : _key =
          'mobishop_last_login_${sha256.convert(utf8.encode(store.replace(query: null, fragment: null).toString().replaceFirst(RegExp(r'/+$'), '')))}';
  final String _key;

  Future<LastLoginMethod?> read() async {
    if (AppConfig.isCmsPreview) return null;
    try {
      final value = (await SharedPreferences.getInstance()).getString(_key);
      for (final method in LastLoginMethod.values) {
        if (method.name == value) return method;
      }
    } catch (_) {
      /* A display hint must never block sign-in. */
    }
    return null;
  }

  Future<void> save(LastLoginMethod method) async {
    if (AppConfig.isCmsPreview) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key,
        method.name,
      );
    } catch (_) {
      /* A display hint must never fail a committed session. */
    }
  }
}
