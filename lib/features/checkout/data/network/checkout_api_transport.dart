import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/core/config/app_config.dart';

class CheckoutApiResponse {
  const CheckoutApiResponse({required this.data, this.statusCode});

  final dynamic data;
  final int? statusCode;
}

typedef CheckoutAuthTokenReader = String? Function();

abstract interface class CheckoutApiTransport {
  Future<CheckoutApiResponse> loadConfiguration();

  Future<CheckoutApiResponse> updateCustomer({
    required String cartToken,
    required Map<String, dynamic> body,
  });

  Future<CheckoutApiResponse> placeOrder({
    required String cartToken,
    required String idempotencyKey,
    required Map<String, dynamic> body,
  });
}

enum CheckoutTransportFailureKind {
  configuration,
  timeout,
  connection,
  cancelled,
  certificate,
  rejected,
  invalidResponse,
  unknown,
}

class CheckoutApiTransportException implements Exception {
  const CheckoutApiTransportException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.data,
    this.cause,
  });

  final CheckoutTransportFailureKind kind;
  final String message;
  final int? statusCode;
  final dynamic data;
  final Object? cause;

  @override
  String toString() => message;
}

/// Same-origin transport for the official WooCommerce Store API checkout.
///
/// It accepts one fixed endpoint and sends only the in-memory Cart-Token. No
/// payment credentials are persisted or logged here.
class StoreApiCheckoutTransport implements CheckoutApiTransport {
  StoreApiCheckoutTransport({
    required Uri storeUri,
    Dio? dio,
    this._authTokenReader,
  })
    : _storeUri = _normalizeStoreUri(storeUri),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 35),
            ),
          );

  factory StoreApiCheckoutTransport.forConfiguredStore({
    Dio? dio,
    CheckoutAuthTokenReader? authTokenReader,
  }) {
    AppConfig.validateStoreConnection();
    return StoreApiCheckoutTransport(
      storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
      dio: dio,
      authTokenReader: authTokenReader,
    );
  }

  @override
  Future<CheckoutApiResponse> updateCustomer({
    required String cartToken,
    required Map<String, dynamic> body,
  }) async {
    final String token = cartToken.trim();
    if (!_safeHeaderValue(token, maxLength: 4096)) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'Updating checkout requires a safe cart token.',
      );
    }

    try {
      final Response<dynamic> response = await _dio.postUri<dynamic>(
        _updateCustomerUri(),
        data: body,
        options: Options(
          responseType: ResponseType.json,
          followRedirects: false,
          headers: _headers(<String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Cart-Token': token,
          }),
        ),
      );
      _assertSameOrigin(response.realUri);
      return CheckoutApiResponse(
        data: _normalizeJson(response.data),
        statusCode: response.statusCode,
      );
    } on CheckoutApiTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        Error.throwWithStackTrace(
          CheckoutApiTransportException(
            kind: CheckoutTransportFailureKind.rejected,
            message: 'The store rejected the customer address update.',
            statusCode: response.statusCode,
            data: _normalizeErrorData(response.data),
            cause: error,
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(_mapDioError(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.invalidResponse,
          message:
              'The store returned invalid cart data after the address update.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  final Uri _storeUri;
  final Dio _dio;
  final CheckoutAuthTokenReader? _authTokenReader;

  @override
  Future<CheckoutApiResponse> loadConfiguration() async {
    try {
      final Response<dynamic> response = await _dio.getUri<dynamic>(
        _checkoutConfigurationUri(),
        options: Options(
          responseType: ResponseType.json,
          followRedirects: false,
          headers: _headers(const <String, String>{
            'Accept': 'application/json',
          }),
        ),
      );
      _assertSameOrigin(response.realUri);
      return CheckoutApiResponse(
        data: _normalizeJson(response.data),
        statusCode: response.statusCode,
      );
    } on CheckoutApiTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        Error.throwWithStackTrace(
          CheckoutApiTransportException(
            kind: CheckoutTransportFailureKind.rejected,
            message: 'The store rejected the checkout configuration request.',
            statusCode: response.statusCode,
            data: _normalizeErrorData(response.data),
            cause: error,
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(_mapDioError(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.invalidResponse,
          message: 'The store returned invalid checkout configuration.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CheckoutApiResponse> placeOrder({
    required String cartToken,
    required String idempotencyKey,
    required Map<String, dynamic> body,
  }) async {
    final String token = cartToken.trim();
    final String requestKey = idempotencyKey.trim();
    if (!_safeHeaderValue(token, maxLength: 4096) ||
        !RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(requestKey)) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'Checkout requires safe cart and idempotency tokens.',
      );
    }

    final Uri requestUri = _checkoutUri();
    try {
      final Response<dynamic> response = await _dio.postUri<dynamic>(
        requestUri,
        data: body,
        options: Options(
          responseType: ResponseType.json,
          followRedirects: false,
          headers: _headers(<String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Cart-Token': token,
            'Idempotency-Key': requestKey,
          }),
        ),
      );
      _assertSameOrigin(response.realUri);
      return CheckoutApiResponse(
        data: _normalizeJson(response.data),
        statusCode: response.statusCode,
      );
    } on CheckoutApiTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        Error.throwWithStackTrace(
          CheckoutApiTransportException(
            kind: CheckoutTransportFailureKind.rejected,
            message: 'The store rejected the checkout request.',
            statusCode: response.statusCode,
            data: _normalizeErrorData(response.data),
            cause: error,
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(_mapDioError(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.invalidResponse,
          message: 'The store returned invalid checkout data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Uri _checkoutUri() {
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/wp-json/wc/store/v1/checkout',
      query: null,
      fragment: null,
    );
  }

  Uri _updateCustomerUri() {
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/wp-json/wc/store/v1/cart/update-customer',
      query: null,
      fragment: null,
    );
  }

  Uri _checkoutConfigurationUri() {
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/wp-json/woo-mobile/v1/checkout-config',
      query: null,
      fragment: null,
    );
  }

  Map<String, String> _headers(Map<String, String> base) {
    final String token = _authTokenReader?.call()?.trim() ?? '';
    if (token.isNotEmpty && !_safeHeaderValue(token, maxLength: 512)) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'The stored customer session is invalid.',
      );
    }
    return <String, String>{
      ...base,
      if (token.isNotEmpty) 'X-Kidia-Session': token,
    };
  }

  dynamic _normalizeJson(dynamic data) {
    if (data is String) {
      final String source = data.trim();
      if (source.isEmpty) {
        throw const FormatException('The checkout response is empty.');
      }
      return jsonDecode(source);
    }
    if (data is Map) {
      return data;
    }
    throw const FormatException('The checkout response must be an object.');
  }

  dynamic _normalizeErrorData(dynamic data) {
    try {
      return _normalizeJson(data);
    } on FormatException {
      return null;
    }
  }

  CheckoutApiTransportException _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.timeout,
          message: 'The checkout request timed out.',
          cause: error,
        );
      case DioExceptionType.connectionError:
        return CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.connection,
          message: 'Could not connect to the configured store.',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.certificate,
          message: 'The configured store has an invalid certificate.',
          cause: error,
        );
      case DioExceptionType.cancel:
        return CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.cancelled,
          message: 'The checkout request was cancelled.',
          cause: error,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.unknown,
          message: 'The checkout request failed.',
          cause: error,
        );
    }
  }

  void _assertSameOrigin(Uri responseUri) {
    if (!_sameOrigin(responseUri, _storeUri)) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.invalidResponse,
        message: 'The checkout response came from an unexpected origin.',
      );
    }
  }

  static Uri _normalizeStoreUri(Uri uri) {
    final String scheme = uri.scheme.toLowerCase();
    final bool isHttps = scheme == 'https';
    final bool isLocalDebug =
        kDebugMode &&
        scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        (!isHttps && !isLocalDebug) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'Checkout requires a valid HTTPS store origin.',
      );
    }
    final String path = uri.path.isEmpty
        ? '/'
        : '/${uri.pathSegments.where((String value) => value.isNotEmpty).join('/')}';
    return uri.replace(
      scheme: scheme,
      host: uri.host.toLowerCase(),
      path: path,
      query: null,
      fragment: null,
    );
  }

  static bool _sameOrigin(Uri left, Uri right) {
    int port(Uri value) {
      if (value.hasPort) {
        return value.port;
      }
      return value.scheme.toLowerCase() == 'https' ? 443 : 80;
    }

    return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
        left.host.toLowerCase() == right.host.toLowerCase() &&
        port(left) == port(right);
  }

  static bool _safeHeaderValue(String value, {required int maxLength}) {
    return value.isNotEmpty &&
        value.length <= maxLength &&
        !value.contains('\r') &&
        !value.contains('\n');
  }
}
