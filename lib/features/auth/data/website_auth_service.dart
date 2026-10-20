import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';

typedef WebsiteAuthBrowser = Future<String> Function(Uri uri);

/// The store owns OTP, email, Google and verified account selection. Only a
/// one-use code returns from its browser; the session stays on HTTPS/storage.
class WebsiteAuthService {
  WebsiteAuthService({
    required this.store,
    required this.dio,
    required this.sessions,
    WebsiteAuthBrowser? browser,
  }) : browser = browser ?? ((uri) => _openBrowser(uri, schemeFor(store))) {
    if (store.scheme != 'https' ||
        store.host.isEmpty ||
        store.userInfo.isNotEmpty ||
        store.hasQuery ||
        store.hasFragment) {
      throw const FormatException('Invalid store login origin.');
    }
  }

  final Uri store;
  final Dio dio;
  final AuthSessionStore sessions;
  final WebsiteAuthBrowser browser;
  bool _active = false;

  static String schemeFor(Uri store) =>
      'mobishop-login-${sha256.convert(utf8.encode(store.host.toLowerCase())).toString().substring(0, 16)}';

  static Future<String> _openBrowser(Uri uri, String scheme) =>
      FlutterWebAuth2.authenticate(
        url: uri.toString(),
        callbackUrlScheme: scheme,
        options: const FlutterWebAuth2Options(useWebview: false),
      );

  Future<bool> enabled() async {
    final response = await _request(
      'config',
      method: 'GET',
      allowMissing: true,
    );
    return response['enabled'] == true && response['version'] == 1;
  }

  Future<AuthSession> signIn() async {
    if (_active) throw StateError('Sign-in already in progress.');
    _active = true;
    try {
      final state = _random();
      final verifier = _random();
      final started = DateTime.now();
      final start = await _request(
        'start',
        body: {
          'state': state,
          'challenge': sha256.convert(utf8.encode(verifier)).toString(),
        },
      );
      final uri = Uri.tryParse(start['authorize_url']?.toString() ?? '');
      if (uri == null ||
          uri.origin != store.origin ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          !RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(uri.queryParameters['mobishop_login'] ?? '')) {
        throw const FormatException('Invalid store login URL.');
      }
      final result = Uri.parse(await browser(uri));
      if (DateTime.now().difference(started) > const Duration(minutes: 10) ||
          result.scheme != schemeFor(store) ||
          result.host != 'auth' ||
          result.path != '/complete' ||
          result.userInfo.isNotEmpty ||
          result.hasPort ||
          result.hasFragment ||
          result.queryParametersAll['state']?.length != 1 ||
          result.queryParametersAll['code']?.length != 1 ||
          result.queryParameters['state'] != state ||
          !RegExp(
            r'^[a-f0-9]{64}\.[a-f0-9]{64}$',
          ).hasMatch(result.queryParameters['code'] ?? '')) {
        throw const FormatException('Invalid or expired sign-in callback.');
      }
      final session = AuthSession.fromJson(
        await _request(
          'exchange',
          body: {
            'code': result.queryParameters['code'],
            'state': state,
            'verifier': verifier,
          },
        ),
      );
      if (session.isExpired) throw const FormatException('Expired session.');
      await sessions.write(session);
      return session;
    } finally {
      _active = false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    String method = 'POST',
    Map<String, dynamic>? body,
    bool allowMissing = false,
  }) async {
    final path = store.path.replaceFirst(RegExp(r'/+$'), '');
    final response = await dio.requestUri<Object?>(
      store.replace(path: '$path/wp-json/mobishop/v1/auth/website/$action'),
      data: body,
      options: Options(
        method: method,
        followRedirects: false,
        maxRedirects: 0,
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
      ),
    );
    if (allowMissing && response.statusCode == 404) return {'enabled': false};
    if (response.statusCode != 200 || response.data is! Map) {
      throw const FormatException('Unable to complete store sign-in.');
    }
    return Map<String, dynamic>.from(response.data! as Map);
  }

  static String _random() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
