import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';

enum CartApiMethod { get, post }

abstract interface class CartApiTransport {
  Future<StoreApiResponse> request(
    CartApiMethod method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  });
}

class CartApiTransportException implements Exception {
  const CartApiTransportException({
    required this.message,
    this.statusCode,
    this.data,
    this.headers = const <String, List<String>>{},
    this.cause,
  });

  final String message;
  final int? statusCode;
  final dynamic data;
  final Map<String, List<String>> headers;
  final Object? cause;

  String? header(String name) {
    final List<String>? values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }

  @override
  String toString() => message;
}

/// Same-origin transport for Store API cart requests that need a Cart-Token.
///
/// The shared [StoreApiClient] remains the bootstrap/read-only client. This
/// transport only fills its current mutation/header gap and deliberately
/// accepts relative WooCommerce Store API paths—never arbitrary URLs.
class StoreApiCartTransport implements CartApiTransport {
  StoreApiCartTransport({required Uri storeUri, Dio? dio})
    : _storeUri = _normalizeAndValidateStoreUri(storeUri),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );

  factory StoreApiCartTransport.forConfiguredStore({Dio? dio}) {
    AppConfig.validateStoreConnection();
    return StoreApiCartTransport(
      storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
      dio: dio,
    );
  }

  final Uri _storeUri;
  final Dio _dio;

  @override
  Future<StoreApiResponse> request(
    CartApiMethod method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final Uri requestUri = _buildRequestUri(path, queryParameters);
    final Map<String, dynamic> requestHeaders = <String, dynamic>{
      'Accept': 'application/json',
      if (method == CartApiMethod.post) 'Content-Type': 'application/json',
      ...?headers,
    };

    try {
      final Response<dynamic> response = await _dio.requestUri<dynamic>(
        requestUri,
        data: body,
        options: Options(
          method: method == CartApiMethod.get ? 'GET' : 'POST',
          responseType: ResponseType.json,
          followRedirects: false,
          headers: requestHeaders,
        ),
      );

      _assertSameOrigin(response.realUri);
      return StoreApiResponse(
        data: _normalizeJson(response.data),
        statusCode: response.statusCode,
        headers: _headers(response.headers),
      );
    } on CartApiTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      final Response<dynamic>? response = error.response;
      if (response != null) {
        _assertSameOrigin(response.realUri);
        Error.throwWithStackTrace(
          CartApiTransportException(
            message: 'The Store API rejected the cart request.',
            statusCode: response.statusCode,
            data: _normalizeErrorData(response.data),
            headers: _headers(response.headers),
            cause: error,
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(_mapDioException(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StoreApiException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'The Store API returned invalid cart JSON.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Uri _buildRequestUri(String path, Map<String, dynamic>? queryParameters) {
    final String trimmedPath = path.trim();
    final Uri? parsedPath = Uri.tryParse(trimmedPath);
    if (trimmedPath.isEmpty ||
        parsedPath == null ||
        parsedPath.hasScheme ||
        parsedPath.hasAuthority ||
        parsedPath.hasQuery ||
        parsedPath.hasFragment ||
        parsedPath.pathSegments.contains('..')) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
        message: 'Cart API paths must be safe relative paths.',
      );
    }

    final String relativePath = parsedPath.path.startsWith('/')
        ? parsedPath.path.substring(1)
        : parsedPath.path;
    final bool isCartPath = RegExp(
      r'^wp-json/wc/store/v[0-9]+/cart(?:/[a-z0-9-]+)?/?$',
    ).hasMatch(relativePath);
    if (!isCartPath) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
        message: 'Only WooCommerce Store API cart paths are allowed.',
      );
    }

    final String installPath = _storeUri.path == '/'
        ? ''
        : _storeUri.path.replaceFirst(RegExp(r'/$'), '');
    return _storeUri.replace(
      path: '$installPath/$relativePath',
      queryParameters: _cleanQueryParameters(queryParameters),
    );
  }

  Map<String, dynamic>? _cleanQueryParameters(
    Map<String, dynamic>? parameters,
  ) {
    if (parameters == null || parameters.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      for (final MapEntry<String, dynamic> entry in parameters.entries)
        if (entry.value != null && entry.value.toString().trim().isNotEmpty)
          entry.key: entry.value,
    };
  }

  dynamic _normalizeJson(dynamic data) {
    if (data is String) {
      final String value = data.trim();
      if (value.isEmpty) {
        throw const FormatException('The cart response body is empty.');
      }
      return jsonDecode(value);
    }
    if (data is Map || data is List) {
      return data;
    }
    throw const FormatException('The cart response must be a JSON object.');
  }

  dynamic _normalizeErrorData(dynamic data) {
    try {
      return _normalizeJson(data);
    } on FormatException {
      return null;
    }
  }

  Map<String, List<String>> _headers(Headers headers) {
    return <String, List<String>>{
      for (final MapEntry<String, List<String>> entry in headers.map.entries)
        entry.key.toLowerCase(): List<String>.unmodifiable(entry.value),
    };
  }

  void _assertSameOrigin(Uri responseUri) {
    if (!_hasSameOrigin(responseUri, _storeUri)) {
      throw const CartApiTransportException(
        message: 'The Store API cart response came from an unexpected origin.',
      );
    }
  }

  StoreApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return StoreApiException(
          kind: StoreApiFailureKind.timeout,
          message: 'The Store API cart request timed out.',
          cause: error,
        );
      case DioExceptionType.connectionError:
        return StoreApiException(
          kind: StoreApiFailureKind.connection,
          message: 'Could not connect to the configured store.',
          cause: error,
        );
      case DioExceptionType.cancel:
        return StoreApiException(
          kind: StoreApiFailureKind.cancelled,
          message: 'The Store API cart request was cancelled.',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return StoreApiException(
          kind: StoreApiFailureKind.certificate,
          message: 'The configured store has an invalid certificate.',
          cause: error,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return StoreApiException(
          kind: StoreApiFailureKind.unknown,
          message: 'The Store API cart request failed.',
          cause: error,
        );
    }
  }

  static Uri _normalizeAndValidateStoreUri(Uri uri) {
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
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
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
      return uri.scheme == 'https' ? 443 : 80;
    }

    return left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
        left.host.toLowerCase() == right.host.toLowerCase() &&
        effectivePort(left) == effectivePort(right);
  }
}
