import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kidia_store_app/features/home/data/datasources/mock_home_layout_json.dart';

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
    final Response<dynamic> response = await _dio.get<dynamic>(
      _endpoint,
      queryParameters: <String, dynamic>{
        'locale': locale,
      },
      options: Options(
        responseType: ResponseType.json,
        headers: const <String, dynamic>{
          'Accept': 'application/json',
        },
      ),
    );

    final Map<String, dynamic> responseJson = _normalizeJsonObject(
      response.data,
    );

    return _unwrapLayoutResponse(responseJson);
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