import 'dart:convert';
import 'package:dio/dio.dart';

/// Only an authenticated response from this merchant may invalidate its token.
class SessionRejectionInterceptor extends Interceptor {
  SessionRejectionInterceptor({
    required this.storeUri,
    required this.onRejected,
  });
  final Uri? storeUri;
  final Future<void> Function(String token) onRejected;

  Future<void> _inspect(Response<dynamic>? response) async {
    final store = storeUri;
    if (response == null ||
        response.statusCode != 401 ||
        store == null ||
        store.scheme != 'https' ||
        store.host.isEmpty) {
      return;
    }
    final request = response.requestOptions;
    if (request.uri.scheme != 'https' ||
        request.uri.host.isEmpty ||
        response.realUri.scheme != 'https' ||
        response.realUri.host.isEmpty ||
        request.uri.origin != store.origin ||
        response.realUri.origin != store.origin ||
        request.uri.userInfo.isNotEmpty ||
        response.realUri.userInfo.isNotEmpty) {
      return;
    }
    Object? data = response.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return;
      }
    }
    if (data is! Map ||
        !const {
          'mobishop_auth_unauthorized',
          'mobishop_native_checkout50_unauthorized',
        }.contains(data['code'])) {
      return;
    }
    final tokens = request.headers.entries.where(
      (entry) => entry.key.toLowerCase() == 'x-mobishop-session',
    );
    if (tokens.length != 1 || tokens.single.value is! String) return;
    final token = (tokens.single.value as String).trim();
    if (token.isEmpty) return;
    try {
      await onRejected(token);
    } catch (_) {
      // Keep the original rejection; a local storage failure is not a success.
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    await _inspect(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    await _inspect(err.response);
    handler.next(err);
  }
}
