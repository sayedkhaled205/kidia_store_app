import 'package:dio/dio.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

/// Isolated, direct, read-only transport for the installed public Odoo mobile
/// catalog. No merchant license proof, admin API key, shared auth client, builder
/// relay, cookie jar, redirect, or private customer endpoint is accepted here.
class OdooCatalogClient implements StoreApiClient {
  OdooCatalogClient({
    required CommerceConnection connection,
    HttpClientAdapter? adapter,
  }) : _origin = connection.storeOrigin,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 10),
           sendTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 20),
           followRedirects: false,
           maxRedirects: 0,
           validateStatus: (int? status) => status != null,
           headers: const <String, dynamic>{
             'Accept': 'application/json',
             'Cache-Control': 'no-cache, no-store, must-revalidate',
             'Pragma': 'no-cache',
           },
         ),
       ) {
    if (connection.platform != CommercePlatform.odoo) {
      throw const FormatException('Odoo catalog needs an Odoo connection.');
    }
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Uri _origin;
  final Dio _dio;

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (!RegExp(
      r'^/api/mobile/v1/catalog/(categories|products|products/collection-data|products/[1-9][0-9]*(/variations)?)$',
    ).hasMatch(path)) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
        message: 'Only verified public Odoo catalog paths are allowed.',
      );
    }
    // Parameter encoding belongs to Uri/Dio, never concatenated user text.
    final Uri uri = _origin
        .resolve(path)
        .replace(
          queryParameters: queryParameters == null || queryParameters.isEmpty
              ? null
              : <String, dynamic>{
                  for (final MapEntry<String, dynamic> entry
                      in queryParameters.entries)
                    if (entry.value != null)
                      entry.key: entry.value is Iterable
                          ? (entry.value as Iterable)
                                .map((dynamic value) => value.toString())
                                .toList(growable: false)
                          : entry.value.toString(),
                },
        );
    try {
      final Response<dynamic> response = await _dio.getUri<dynamic>(uri);
      final int? status = response.statusCode;
      if (status != 200) {
        throw StoreApiException(
          kind: status == 401 || status == 403
              ? StoreApiFailureKind.unauthorized
              : status == 404
              ? StoreApiFailureKind.notFound
              : status != null && status >= 500
              ? StoreApiFailureKind.server
              : StoreApiFailureKind.invalidResponse,
          statusCode: status,
          message: 'Odoo rejected the public catalog request.',
        );
      }
      if (response.data is! Map && response.data is! List) {
        throw const StoreApiException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'Odoo returned an invalid public catalog response.',
        );
      }
      return StoreApiResponse(
        data: response.data,
        statusCode: status,
        headers: <String, List<String>>{
          for (final MapEntry<String, List<String>> header
              in response.headers.map.entries)
            header.key.toLowerCase(): List<String>.unmodifiable(header.value),
        },
      );
    } on StoreApiException {
      rethrow;
    } on DioException catch (error) {
      // Dio exceptions retain requests/headers; never expose them as causes.
      throw StoreApiException(
        kind: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.transformTimeout => StoreApiFailureKind.timeout,
          DioExceptionType.badCertificate => StoreApiFailureKind.certificate,
          DioExceptionType.cancel => StoreApiFailureKind.cancelled,
          _ => StoreApiFailureKind.connection,
        },
        message: 'Could not reach the configured Odoo public catalog.',
      );
    }
  }

  void close() => _dio.close(force: true);
}
