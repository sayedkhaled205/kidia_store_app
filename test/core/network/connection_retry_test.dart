import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/connection_retry.dart';

void main() {
  for (final phase in DioExceptionType.values) {
    test('read transport recovery is bounded at $phase', () async {
      var attempts = 0;
      final error = DioException(
        requestOptions: RequestOptions(path: '/public-read'),
        type: phase,
      );
      await expectLater(
        retryConnectionOnce(() async {
          attempts++;
          throw error;
        }, readOnly: true),
        throwsA(same(error)),
      );
      expect(
        attempts,
        const {
              DioExceptionType.connectionTimeout,
              DioExceptionType.connectionError,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            }.contains(phase)
            ? 2
            : 1,
      );
    });
  }

  test('a received HTTP rejection is never retried', () async {
    var attempts = 0;
    final options = RequestOptions(path: '/public-read');
    final error = DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      response: Response(requestOptions: options, statusCode: 403),
    );
    await expectLater(
      retryConnectionOnce(() async {
        attempts++;
        throw error;
      }, readOnly: true),
      throwsA(same(error)),
    );
    expect(attempts, 1);
  });
}
