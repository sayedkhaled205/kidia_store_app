import 'package:dio/dio.dart';

/// Retry only a connection establishment timeout, before a request was sent.
/// Send/receive failures can follow a committed mutation and must not replay.
Future<T> retryConnectionOnce<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    if (error.type != DioExceptionType.connectionTimeout ||
        error.response != null) {
      rethrow;
    }
    return request();
  }
}
