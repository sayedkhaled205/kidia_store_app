import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';

abstract interface class AuthApiTransport {
  Future<AuthIdentity> identify(String email);

  Future<AuthSession> signIn({
    required String email,
    required String password,
  });

  Future<AuthSession> register({
    required String email,
    required String password,
  });

  Future<AuthUser> currentUser(String token);

  Future<void> signOut(String token);
}

class AuthApiException implements Exception {
  const AuthApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final AuthFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

/// Same-origin transport for the companion plugin's customer auth contract.
///
/// It accepts only fixed Woo Mobile endpoints and never logs credentials or
/// follows redirects, so a store response cannot forward a password or bearer
/// session to another origin.
class DioAuthApiTransport implements AuthApiTransport {
  DioAuthApiTransport({required Uri storeUri, Dio? dio})
    : _storeUri = _normalizeStoreUri(storeUri),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );

  factory DioAuthApiTransport.forConfiguredStore({Dio? dio}) {
    AppConfig.validateStoreConnection();
    return DioAuthApiTransport(
      storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
      dio: dio,
    );
  }

  final Uri _storeUri;
  final Dio _dio;

  @override
  Future<AuthIdentity> identify(String email) async {
    final Map<String, dynamic> json = await _request(
      'identify',
      body: <String, dynamic>{'email': email.trim()},
    );
    final String normalizedEmail = json['email']?.toString().trim() ?? '';
    final String next = json['next']?.toString().trim() ?? '';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail) ||
        (next != 'password' && next != 'create_password')) {
      throw const AuthApiException(
        kind: AuthFailureKind.invalidResponse,
        message: 'The store returned an invalid sign-in step.',
      );
    }
    return AuthIdentity(
      email: normalizedEmail,
      isRegistered: next == 'password',
    );
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    return AuthSession.fromJson(
      await _request(
        'login',
        body: <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      ),
    );
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    return AuthSession.fromJson(
      await _request(
        'register',
        body: <String, dynamic>{
          'email': email.trim(),
          'password': password,
        },
      ),
    );
  }

  @override
  Future<AuthUser> currentUser(String token) async {
    final Map<String, dynamic> json = await _request(
      'me',
      method: 'GET',
      token: token,
    );
    final dynamic rawUser = json['user'];
    if (rawUser is! Map) {
      throw const AuthApiException(
        kind: AuthFailureKind.invalidResponse,
        message: 'The store returned an invalid customer profile.',
      );
    }
    return AuthUser.fromJson(Map<String, dynamic>.from(rawUser));
  }

  @override
  Future<void> signOut(String token) async {
    await _request('logout', token: token, allowEmpty: true);
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? token,
    bool allowEmpty = false,
  }) async {
    final String sessionToken = token?.trim() ?? '';
    if (sessionToken.isNotEmpty && !_safeHeaderValue(sessionToken)) {
      throw const AuthApiException(
        kind: AuthFailureKind.configuration,
        message: 'The stored customer session is invalid.',
      );
    }

    try {
      final Response<dynamic> response = await _dio.requestUri<dynamic>(
        _endpointUri(endpoint),
        data: body,
        options: Options(
          method: method,
          responseType: ResponseType.json,
          followRedirects: false,
          headers: <String, String>{
            'Accept': 'application/json',
            if (method != 'GET') 'Content-Type': 'application/json',
            if (sessionToken.isNotEmpty) 'X-Kidia-Session': sessionToken,
          },
        ),
      );
      _assertSameOrigin(response.realUri);
      if (allowEmpty && response.data == null) {
        return const <String, dynamic>{};
      }
      return _jsonObject(response.data);
    } on AuthApiException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        final Map<String, dynamic>? errorJson = _optionalJsonObject(
          response.data,
        );
        final String code = errorJson?['code']?.toString().trim() ?? '';
        final String message = errorJson?['message']?.toString().trim() ?? '';
        Error.throwWithStackTrace(
          AuthApiException(
            kind: _statusFailure(response.statusCode),
            message: message.isEmpty
                ? 'The store rejected the customer authentication request.'
                : message,
            statusCode: response.statusCode,
            code: code.isEmpty ? null : code,
            cause: error,
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(_networkFailure(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthApiException(
          kind: AuthFailureKind.invalidResponse,
          message: 'The store returned invalid authentication data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Uri _endpointUri(String endpoint) {
    if (!<String>{
      'identify',
      'login',
      'register',
      'me',
      'logout',
    }.contains(endpoint)) {
      throw const AuthApiException(
        kind: AuthFailureKind.configuration,
        message: 'The authentication endpoint is not approved.',
      );
    }
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/wp-json/woo-mobile/v1/auth/$endpoint',
      query: null,
      fragment: null,
    );
  }

  Map<String, dynamic> _jsonObject(dynamic data) {
    dynamic value = data;
    if (value is String) {
      final String source = value.trim();
      if (source.isEmpty) {
        throw const FormatException('The authentication response is empty.');
      }
      value = jsonDecode(source);
    }
    if (value is! Map) {
      throw const FormatException(
        'The authentication response must be an object.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  Map<String, dynamic>? _optionalJsonObject(dynamic data) {
    try {
      return _jsonObject(data);
    } on FormatException {
      return null;
    }
  }

  void _assertSameOrigin(Uri responseUri) {
    if (!_hasSameOrigin(responseUri, _storeUri)) {
      throw const AuthApiException(
        kind: AuthFailureKind.invalidResponse,
        message: 'The authentication response came from an unexpected store.',
      );
    }
  }

  AuthApiException _networkFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return AuthApiException(
          kind: AuthFailureKind.timeout,
          message: 'The customer authentication request timed out.',
          cause: error,
        );
      case DioExceptionType.connectionError:
        return AuthApiException(
          kind: AuthFailureKind.connection,
          message: 'Could not connect to the configured store.',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return AuthApiException(
          kind: AuthFailureKind.certificate,
          message: 'The configured store has an invalid certificate.',
          cause: error,
        );
      case DioExceptionType.cancel:
        return AuthApiException(
          kind: AuthFailureKind.unknown,
          message: 'The customer authentication request was cancelled.',
          cause: error,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return AuthApiException(
          kind: AuthFailureKind.unknown,
          message: 'Customer authentication failed unexpectedly.',
          cause: error,
        );
    }
  }

  AuthFailureKind _statusFailure(int? statusCode) {
    if (statusCode == 400 || statusCode == 422) {
      return AuthFailureKind.invalidInput;
    }
    if (statusCode == 401 || statusCode == 403) {
      return AuthFailureKind.unauthorized;
    }
    if (statusCode == 409) {
      return AuthFailureKind.conflict;
    }
    if (statusCode == 429) {
      return AuthFailureKind.rateLimited;
    }
    if (statusCode != null && statusCode >= 500) {
      return AuthFailureKind.server;
    }
    return AuthFailureKind.invalidResponse;
  }

  bool _safeHeaderValue(String value) {
    return value.length <= 512 &&
        !value.codeUnits.any((int unit) => unit < 0x20 || unit == 0x7f);
  }

  static Uri _normalizeStoreUri(Uri uri) {
    final bool isHttps = uri.scheme.toLowerCase() == 'https';
    final bool isLocalDebugHttp =
        kDebugMode &&
        uri.scheme.toLowerCase() == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        (!isHttps && !isLocalDebugHttp) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const AuthApiException(
        kind: AuthFailureKind.configuration,
        message: 'The configured store must be a valid HTTPS origin.',
      );
    }
    final String normalizedPath = uri.path.isEmpty
        ? '/'
        : '/${uri.pathSegments.where((String part) => part.isNotEmpty).join('/')}';
    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      path: normalizedPath,
      query: null,
      fragment: null,
    );
  }

  static bool _hasSameOrigin(Uri left, Uri right) {
    int effectivePort(Uri uri) {
      if (uri.hasPort) {
        return uri.port;
      }
      return uri.scheme.toLowerCase() == 'https' ? 443 : 80;
    }

    return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
        left.host.toLowerCase() == right.host.toLowerCase() &&
        effectivePort(left) == effectivePort(right);
  }
}
