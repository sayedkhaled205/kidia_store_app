import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mobishop_store_app/features/home/data/datasources/mock_home_layout_json.dart';

abstract interface class HomeRemoteDataSource {
  Future<Map<String, dynamic>> fetchHomeLayout({
    required String locale,
  });
}

class DioHomeRemoteDataSource implements HomeRemoteDataSource {
  DioHomeRemoteDataSource({
    required this._dio,
    required this._endpoint,
  });

  final Dio _dio;
  final String _endpoint;

  @override
  Future<Map<String, dynamic>> fetchHomeLayout({
    required String locale,
  }) async {
    final List<String> endpoints = _compatibleEndpoints();
    late Response<dynamic> response;

    for (var index = 0; index < endpoints.length; index += 1) {
      try {
        response = await _fetch(endpoints[index], locale);
        break;
      } on DioException catch (error) {
        final bool canTryLegacyRoute =
            error.response?.statusCode == 404 && index < endpoints.length - 1;
        if (!canTryLegacyRoute) {
          rethrow;
        }
      }
    }

    final Map<String, dynamic> responseJson = _normalizeJsonObject(
      response.data,
    );

    return _unwrapLayoutResponse(responseJson);
  }

  Future<Response<dynamic>> _fetch(String endpoint, String locale) =>
      _dio.get<dynamic>(
        endpoint,
        queryParameters: <String, dynamic>{
          'locale': locale,
          '_mobile_cache_buster': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: const <String, dynamic>{
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );

  List<String> _compatibleEndpoints() {
    const List<String> paths = <String>[
      '/wp-json/mobishop/v1/home-layout',
      '/wp-json/mobishop/v1/home-layout',
      '/wp-json/mobishop/v1/home-layout',
    ];
    String? matchedPath;
    for (final String path in paths) {
      if (_endpoint.contains(path)) {
        matchedPath = path;
        break;
      }
    }
    if (matchedPath == null) {
      return <String>[_endpoint];
    }

    return <String>[
      _endpoint,
      for (final String path in paths)
        if (path != matchedPath) _endpoint.replaceFirst(matchedPath, path),
    ];
  }

  Map<String, dynamic> _normalizeJsonObject(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is String) {
      final String normalizedData = data.trim();

      if (normalizedData.isEmpty) {
        throw const FormatException(
          'Home layout API returned an empty response.',
        );
      }

      final dynamic decoded = jsonDecode(normalizedData);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }

    throw const FormatException(
      'Home layout API returned an invalid JSON object.',
    );
  }

  Map<String, dynamic> _unwrapLayoutResponse(
      Map<String, dynamic> responseJson,
      ) {
    final bool isDirectLayout =
        responseJson.containsKey('version') &&
            responseJson.containsKey('page') &&
            responseJson.containsKey('blocks');

    if (isDirectLayout) {
      return responseJson;
    }

    final dynamic wrappedData = responseJson['data'];

    if (wrappedData is Map<String, dynamic>) {
      return wrappedData;
    }

    if (wrappedData is Map) {
      return Map<String, dynamic>.from(wrappedData);
    }

    throw const FormatException(
      'Home layout API response does not contain a valid layout.',
    );
  }
}

class MockHomeRemoteDataSource implements HomeRemoteDataSource {
  const MockHomeRemoteDataSource();

  @override
  Future<Map<String, dynamic>> fetchHomeLayout({
    required String locale,
  }) async {
    final dynamic decoded = jsonDecode(mockHomeLayoutJson);

    if (decoded is! Map) {
      throw const FormatException(
        'Mock home layout JSON must contain a root object.',
      );
    }

    final Map<String, dynamic> json =
    Map<String, dynamic>.from(decoded);

    return <String, dynamic>{
      ...json,
      'locale': locale,
    };
  }
}
