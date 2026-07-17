import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';

typedef CustomerAccountAuthTokenReader = String? Function();

abstract interface class CustomerAccountApiTransport {
  Future<Map<String, dynamic>> fetchAccount();

  Future<Map<String, dynamic>> fetchAddressConfig();

  Future<Map<String, dynamic>> updateProfile(Map<String, String> values);

  Future<Map<String, dynamic>> updateAddress(
    CustomerAddressType type,
    Map<String, String> values,
  );
}

enum CustomerAccountTransportFailureKind {
  configuration,
  invalidInput,
  unauthorized,
  conflict,
  timeout,
  connection,
  certificate,
  server,
  invalidResponse,
  unknown,
}

class CustomerAccountTransportException implements Exception {
  const CustomerAccountTransportException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final CustomerAccountTransportFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

class DioCustomerAccountApiTransport implements CustomerAccountApiTransport {
  DioCustomerAccountApiTransport({
    required Uri storeUri,
    required this.authTokenReader,
    Dio? dio,
  }) : _storeUri = _normalizeStoreUri(storeUri),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 25),
             ),
           );

  factory DioCustomerAccountApiTransport.forConfiguredStore({
    required CustomerAccountAuthTokenReader authTokenReader,
    Dio? dio,
  }) {
    AppConfig.validateStoreConnection();
    return DioCustomerAccountApiTransport(
      storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
      authTokenReader: authTokenReader,
      dio: dio,
    );
  }

  final Uri _storeUri;
  final CustomerAccountAuthTokenReader authTokenReader;
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> fetchAccount() {
    return _request('customer/account', method: 'GET', authenticated: true);
  }

  @override
  Future<Map<String, dynamic>> fetchAddressConfig() {
    return _request('checkout-config', method: 'GET', authenticated: false);
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, String> values) {
    return _request(
      'customer/account/profile',
      method: 'POST',
      authenticated: true,
      body: values,
    );
  }

  @override
  Future<Map<String, dynamic>> updateAddress(
    CustomerAddressType type,
    Map<String, String> values,
  ) {
    final String typeName = type == CustomerAddressType.billing
        ? 'billing'
        : 'shipping';
    return _request(
      'customer/account/address/$typeName',
      method: 'POST',
      authenticated: true,
      body: values,
    );
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    required String method,
    required bool authenticated,
    Map<String, String>? body,
  }) async {
    final String token = authenticated
        ? authTokenReader()?.trim() ?? ''
        : '';
    if (authenticated && token.isEmpty) {
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.unauthorized,
        message: 'Customer account data requires a signed-in session.',
        statusCode: 401,
      );
    }
    if (token.isNotEmpty && !_safeHeaderValue(token)) {
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.configuration,
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
            if (token.isNotEmpty) 'X-Kidia-Session': token,
          },
        ),
      );
      _assertSameOrigin(response.realUri);
      return _jsonObject(response.data);
    } on CustomerAccountTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        final Map<String, dynamic>? json = _optionalJsonObject(response.data);
        final String code = json?['code']?.toString().trim() ?? '';
        final String message = json?['message']?.toString().trim() ?? '';
        Error.throwWithStackTrace(
          CustomerAccountTransportException(
            kind: _failureForStatus(response.statusCode),
            message: message.isEmpty
                ? 'The store rejected the customer account request.'
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
        CustomerAccountTransportException(
          kind: CustomerAccountTransportFailureKind.invalidResponse,
          message: 'The store returned invalid customer account data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Uri _endpointUri(String endpoint) {
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/wp-json/woo-mobile/v1/$endpoint',
      query: null,
      fragment: null,
    );
  }

  Map<String, dynamic> _jsonObject(dynamic data) {
    dynamic value = data;
    if (value is String) {
      final String source = value.trim();
      if (source.isEmpty) {
        throw const FormatException('The customer account response is empty.');
      }
      value = jsonDecode(source);
    }
    if (value is! Map) {
      throw const FormatException(
        'The customer account response must be an object.',
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
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.invalidResponse,
        message: 'The customer account response came from another store.',
      );
    }
  }

  CustomerAccountTransportException _networkFailure(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.timeout,
        message: 'The customer account request timed out.',
        cause: error,
      ),
      DioExceptionType.connectionError => CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.connection,
        message: 'Could not connect to the configured store.',
        cause: error,
      ),
      DioExceptionType.badCertificate => CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.certificate,
        message: 'The configured store has an invalid certificate.',
        cause: error,
      ),
      DioExceptionType.badResponse => CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.server,
        message: 'The customer account request failed.',
        statusCode: error.response?.statusCode,
        cause: error,
      ),
      DioExceptionType.cancel || DioExceptionType.unknown =>
        CustomerAccountTransportException(
          kind: CustomerAccountTransportFailureKind.unknown,
          message: 'The customer account request failed unexpectedly.',
          cause: error,
        ),
    };
  }

  CustomerAccountTransportFailureKind _failureForStatus(int? statusCode) {
    if (statusCode == 400 || statusCode == 422) {
      return CustomerAccountTransportFailureKind.invalidInput;
    }
    if (statusCode == 401 || statusCode == 403) {
      return CustomerAccountTransportFailureKind.unauthorized;
    }
    if (statusCode == 409) {
      return CustomerAccountTransportFailureKind.conflict;
    }
    if (statusCode != null && statusCode >= 500) {
      return CustomerAccountTransportFailureKind.server;
    }
    return CustomerAccountTransportFailureKind.invalidResponse;
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
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.configuration,
        message: 'The configured store must be a valid HTTPS origin.',
      );
    }
    final String normalizedPath = uri.path.isEmpty
        ? '/'
        : '/${uri.pathSegments.where((String value) => value.isNotEmpty).join('/')}';
    return uri.replace(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      path: normalizedPath,
      query: null,
      fragment: null,
    );
  }

  static bool _hasSameOrigin(Uri left, Uri right) {
    int port(Uri uri) => uri.hasPort
        ? uri.port
        : uri.scheme.toLowerCase() == 'https'
        ? 443
        : 80;
    return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
        left.host.toLowerCase() == right.host.toLowerCase() &&
        port(left) == port(right);
  }
}
