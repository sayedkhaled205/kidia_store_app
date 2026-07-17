import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/core/config/app_config.dart';

class CustomerOrdersApiResponse {
  const CustomerOrdersApiResponse({required this.data, this.statusCode});

  final dynamic data;
  final int? statusCode;
}

typedef CustomerOrdersAuthTokenReader = String? Function();

abstract interface class CustomerOrdersApiTransport {
  Future<CustomerOrdersApiResponse> fetchOrders({
    required int page,
    required int perPage,
  });
}

abstract interface class CustomerOrderCancellationTransport {
  Future<CustomerOrdersApiResponse> cancelOrder(int orderId);
}

enum CustomerOrdersTransportFailureKind {
  configuration,
  unauthorized,
  timeout,
  connection,
  certificate,
  server,
  invalidResponse,
  unknown,
}

class CustomerOrdersTransportException implements Exception {
  const CustomerOrdersTransportException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final CustomerOrdersTransportFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

/// Same-origin client for the signed-in WooCommerce customer's order history.
class DioCustomerOrdersApiTransport
    implements
        CustomerOrdersApiTransport,
        CustomerOrderCancellationTransport {
  DioCustomerOrdersApiTransport({
    required Uri storeUri,
    required this.authTokenReader,
    Dio? dio,
  }) : _storeUri = _normalizeStoreUri(storeUri),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 25),
             ),
           );

  factory DioCustomerOrdersApiTransport.forConfiguredStore({
    required CustomerOrdersAuthTokenReader authTokenReader,
    Dio? dio,
  }) {
    AppConfig.validateStoreConnection();
    return DioCustomerOrdersApiTransport(
      storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
      authTokenReader: authTokenReader,
      dio: dio,
    );
  }

  final Uri _storeUri;
  final CustomerOrdersAuthTokenReader authTokenReader;
  final Dio _dio;

  @override
  Future<CustomerOrdersApiResponse> fetchOrders({
    required int page,
    required int perPage,
  }) async {
    final int safePage = page < 1 ? 1 : page;
    final int safePerPage = perPage.clamp(1, 20);
    return _request(
      _ordersUri(page: safePage, perPage: safePerPage),
      method: 'GET',
    );
  }

  @override
  Future<CustomerOrdersApiResponse> cancelOrder(int orderId) {
    if (orderId <= 0) {
      throw const CustomerOrdersTransportException(
        kind: CustomerOrdersTransportFailureKind.configuration,
        message: 'A valid customer order is required.',
      );
    }
    return _request(_cancelOrderUri(orderId), method: 'POST');
  }

  Future<CustomerOrdersApiResponse> _request(
    Uri uri, {
    required String method,
  }) async {
    final String token = authTokenReader()?.trim() ?? '';
    if (token.isEmpty) {
      throw const CustomerOrdersTransportException(
        kind: CustomerOrdersTransportFailureKind.unauthorized,
        message: 'Customer order history requires a signed-in session.',
        statusCode: 401,
      );
    }
    if (!_safeHeaderValue(token)) {
      throw const CustomerOrdersTransportException(
        kind: CustomerOrdersTransportFailureKind.configuration,
        message: 'The stored customer session is invalid.',
      );
    }

    try {
      final Response<dynamic> response = await _dio.requestUri<dynamic>(
        uri,
        options: Options(
          method: method,
          responseType: ResponseType.json,
          followRedirects: false,
          headers: <String, String>{
            'Accept': 'application/json',
            if (method != 'GET') 'Content-Type': 'application/json',
            'X-Kidia-Session': token,
          },
        ),
      );
      _assertSameOrigin(response.realUri);
      return CustomerOrdersApiResponse(
        data: _jsonObject(response.data),
        statusCode: response.statusCode,
      );
    } on CustomerOrdersTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        final Map<String, dynamic>? body = _optionalJsonObject(response.data);
        final String code = body?['code']?.toString().trim() ?? '';
        final String message = body?['message']?.toString().trim() ?? '';
        Error.throwWithStackTrace(
          CustomerOrdersTransportException(
            kind: _failureForStatus(response.statusCode),
            message: message.isEmpty
                ? 'The store rejected the customer orders request.'
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
        CustomerOrdersTransportException(
          kind: CustomerOrdersTransportFailureKind.invalidResponse,
          message: 'The store returned invalid customer order data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Uri _ordersUri({required int page, required int perPage}) {
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/wp-json/woo-mobile/v1/customer/orders',
      queryParameters: <String, String>{
        'page': '$page',
        'per_page': '$perPage',
      },
      fragment: null,
    );
  }

  Uri _cancelOrderUri(int orderId) {
    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path:
          '$installPath/wp-json/woo-mobile/v1/customer/orders/$orderId/cancel',
      query: null,
      fragment: null,
    );
  }

  Map<String, dynamic> _jsonObject(dynamic data) {
    dynamic value = data;
    if (value is String) {
      final String source = value.trim();
      if (source.isEmpty) {
        throw const FormatException('The customer orders response is empty.');
      }
      value = jsonDecode(source);
    }
    if (value is! Map) {
      throw const FormatException(
        'The customer orders response must be an object.',
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
      throw const CustomerOrdersTransportException(
        kind: CustomerOrdersTransportFailureKind.invalidResponse,
        message: 'The customer orders response came from another store.',
      );
    }
  }

  CustomerOrdersTransportException _networkFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return CustomerOrdersTransportException(
          kind: CustomerOrdersTransportFailureKind.timeout,
          message: 'The customer orders request timed out.',
          cause: error,
        );
      case DioExceptionType.connectionError:
        return CustomerOrdersTransportException(
          kind: CustomerOrdersTransportFailureKind.connection,
          message: 'Could not connect to the configured store.',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return CustomerOrdersTransportException(
          kind: CustomerOrdersTransportFailureKind.certificate,
          message: 'The configured store has an invalid certificate.',
          cause: error,
        );
      case DioExceptionType.badResponse:
        return CustomerOrdersTransportException(
          kind: CustomerOrdersTransportFailureKind.server,
          message: 'The customer orders request failed.',
          statusCode: error.response?.statusCode,
          cause: error,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return CustomerOrdersTransportException(
          kind: CustomerOrdersTransportFailureKind.unknown,
          message: 'The customer orders request failed unexpectedly.',
          cause: error,
        );
    }
  }

  CustomerOrdersTransportFailureKind _failureForStatus(int? statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return CustomerOrdersTransportFailureKind.unauthorized;
    }
    if (statusCode != null && statusCode >= 500) {
      return CustomerOrdersTransportFailureKind.server;
    }
    return CustomerOrdersTransportFailureKind.invalidResponse;
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
      throw const CustomerOrdersTransportException(
        kind: CustomerOrdersTransportFailureKind.configuration,
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
