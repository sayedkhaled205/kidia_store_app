import 'dart:convert';

import 'package:dio/dio.dart';

class CmsPageLayoutRemoteDataSource {
  const CmsPageLayoutRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetch({
    required String page,
    required String locale,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/wp-json/woo-mobile/v1/page-layout/$page',
      queryParameters: <String, dynamic>{
        'locale': locale,
        '_kidia_refresh': DateTime.now().millisecondsSinceEpoch,
      },
      options: Options(
        responseType: ResponseType.json,
        headers: const <String, dynamic>{
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ),
    );
    final dynamic data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Page layout API returned invalid JSON.');
  }
}
