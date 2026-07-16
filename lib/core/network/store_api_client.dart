import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';

class StoreApiResponse {
  const StoreApiResponse({
    required this.data,
    this.statusCode,
    this.headers = const <String, List<String>>{},
  });

  final dynamic data;
  final int? statusCode;
  final Map<String, List<String>> headers;

  String? header(String name) {
    final List<String>? values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }
}

abstract interface class StoreApiClient {
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  });
}

/// Read-only client for WooCommerce's public Store API and the companion
/// Woo Mobile CMS bridge.
///
/// Only relative, same-origin public API paths are accepted. This keeps the
/// catalog layer tied to the configured store and prevents a response or a
/// caller from turning the client into an arbitrary URL fetcher.
class DioStoreApiClient implements StoreApiClient {
  DioStoreApiClient({required Uri storeUri, Dio? dio})
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

  factory DioStoreApiClient.forConfiguredStore({Dio? dio}) {
    AppConfig.validateStoreConnection();

    return DioStoreApiClient(
      storeUri: Uri.parse(AppConfig.apiBaseUrl.trim()),
      dio: dio,
    );
  }

  final Uri _storeUri;
  final Dio _dio;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final Uri requestUri = _buildRequestUri(path, queryParameters);

    try {
      final Response<dynamic> response = await _dio.getUri<dynamic>(
        requestUri,
        options: Options(
          responseType: ResponseType.json,
          followRedirects: false,
          headers: const <String, dynamic>{'Accept': 'application/json'},
        ),
      );

      if (!_hasSameOrigin(response.realUri, _storeUri)) {
        throw const StoreApiException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'The Store API response came from an unexpected origin.',
        );
      }

      return StoreApiResponse(
        data: _normalizeJson(response.data),
        statusCode: response.statusCode,
        headers: <String, List<String>>{
          for (final MapEntry<String, List<String>> entry
              in response.headers.map.entries)
            entry.key.toLowerCase(): List<String>.unmodifiable(entry.value),
        },
      );
    } on StoreApiException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(_mapDioException(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StoreApiException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'The Store API returned invalid JSON.',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StoreApiException(
          kind: StoreApiFailureKind.unknown,
          message: 'The Store API request failed unexpectedly.',
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
        message: 'Store API paths must be safe relative paths.',
      );
    }

    final String relativePath = parsedPath.path.startsWith('/')
        ? parsedPath.path.substring(1)
        : parsedPath.path;

    final bool isWooStoreApi = relativePath.startsWith('wp-json/wc/store/');
    final bool isMobileCmsApi = relativePath.startsWith(
      'wp-json/woo-mobile/v1/',
    );
    if (!isWooStoreApi && !isMobileCmsApi) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
        message: 'Only approved WooCommerce mobile API paths are allowed.',
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

    final Map<String, dynamic> clean = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in parameters.entries) {
      final dynamic value = entry.value;

      if (value == null) {
        continue;
      }

      if (value is Iterable) {
        final List<String> values = value
            .map((dynamic item) => item?.toString().trim() ?? '')
            .where((String item) => item.isNotEmpty)
            .toList(growable: false);

        if (values.isNotEmpty) {
          clean[entry.key] = values;
        }

        continue;
      }

      final String stringValue = value.toString().trim();
      if (stringValue.isNotEmpty) {
        clean[entry.key] = stringValue;
      }
    }

    return clean.isEmpty ? null : clean;
  }

  dynamic _normalizeJson(dynamic data) {
    if (data is String) {
      final String source = data.trim();
      if (source.isEmpty) {
        throw const FormatException('The Store API returned an empty body.');
      }
      return jsonDecode(source);
    }

    if (data is Map || data is List) {
      return data;
    }

    throw const FormatException(
      'The Store API response must contain a JSON object or array.',
    );
  }

  StoreApiException _mapDioException(DioException error) {
    final int? statusCode = error.response?.statusCode;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return StoreApiException(
          kind: StoreApiFailureKind.timeout,
          message: 'The Store API request timed out.',
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
          message: 'The Store API request was cancelled.',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return StoreApiException(
          kind: StoreApiFailureKind.certificate,
          message: 'The configured store has an invalid certificate.',
          cause: error,
        );
      case DioExceptionType.badResponse:
        return StoreApiException(
          kind: _failureKindForStatus(statusCode),
          message: 'The Store API returned HTTP ${statusCode ?? 'unknown'}.',
          statusCode: statusCode,
          cause: error,
        );
      case DioExceptionType.unknown:
        return StoreApiException(
          kind: StoreApiFailureKind.unknown,
          message: 'The Store API request failed.',
          statusCode: statusCode,
          cause: error,
        );
    }
  }

  StoreApiFailureKind _failureKindForStatus(int? statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return StoreApiFailureKind.unauthorized;
    }
    if (statusCode == 404) {
      return StoreApiFailureKind.notFound;
    }
    if (statusCode != null && statusCode >= 500) {
      return StoreApiFailureKind.server;
    }
    return StoreApiFailureKind.invalidResponse;
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
        : '/${uri.pathSegments.where((String segment) => segment.isNotEmpty).join('/')}';

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
