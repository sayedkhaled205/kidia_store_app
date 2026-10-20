import 'package:dio/dio.dart';

/// Read requests may retry transient transport failures once. Mutations retry
/// only connection establishment timeouts, before any request was sent.
Future<T> retryConnectionOnce<T>(
  Future<T> Function() request, {
  bool readOnly = false,
}) async {
  try {
    return await request();
  } on DioException catch (error) {
    final retryable =
        error.type == DioExceptionType.connectionTimeout ||
        (readOnly &&
            const {
              DioExceptionType.connectionError,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            }.contains(error.type));
    if (!retryable || error.response != null) {
      rethrow;
    }
    return request();
  }
}
