import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';

abstract interface class CheckoutSafetyTransport {
  Future<CheckoutApiResponse> loadCapabilities();
  Future<CheckoutApiResponse> recoverAttempt({
    required String idempotencyKey,
    String? cartToken,
  });
}

/// Direct same-platform, customer-session-only reads. No Admin API credentials,
/// redirects, dynamic recovery destinations, or automatic checkout POST replay.
class StoreApiCheckoutSafetyTransport implements CheckoutSafetyTransport {
  StoreApiCheckoutSafetyTransport({
    required Uri storeUri,
    required this.authTokenReader,
    Dio? dio,
  }) : _storeUri = _normalize(storeUri),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
             ),
           );

  final Uri _storeUri;
  final CheckoutAuthTokenReader authTokenReader;
  final Dio _dio;

  @override
  Future<CheckoutApiResponse> loadCapabilities() =>
      _get('/mobishop/v1/native-checkout-capabilities');

  @override
  Future<CheckoutApiResponse> recoverAttempt({
    required String idempotencyKey,
    String? cartToken,
  }) {
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(idempotencyKey) ||
        idempotencyKey == '.' ||
        idempotencyKey == '..') {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'Recovery requires the exact safe checkout attempt key.',
      );
    }
    return _get(
      '/mobishop/v1/customer/checkout-attempts/$idempotencyKey',
      cartToken: cartToken,
      acceptKnownRejection: true,
    );
  }

  Future<CheckoutApiResponse> _get(
    String route, {
    String? cartToken,
    bool acceptKnownRejection = false,
  }) async {
    final String session = authTokenReader()?.trim() ?? '';
    if (!_safeHeader(session, 512)) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.rejected,
        statusCode: 401,
        message: 'Checkout recovery requires its current customer session.',
      );
    }
    final String cart = cartToken?.trim() ?? '';
    if (cart.isNotEmpty && !_safeHeader(cart, 4096)) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'Checkout recovery has an invalid cart token.',
      );
    }
    final Uri uri = _storeUri.replace(
      path: '${_storeUri.path == '/' ? '' : _storeUri.path}/wp-json$route',
      query: null,
      fragment: null,
    );
    try {
      final Response<dynamic> response = await _dio.getUri<dynamic>(
        uri,
        options: Options(
          responseType: ResponseType.json,
          followRedirects: false,
          validateStatus: (int? status) =>
              status != null &&
              ((status >= 200 && status < 300) ||
                  (acceptKnownRejection && status == 409)),
          headers: <String, String>{
            'Accept': 'application/json',
            'Cache-Control': 'no-store',
            'X-MobiShop-Session': session,
            if (cart.isNotEmpty) 'Cart-Token': cart,
          },
        ),
      );
      _assertSession(session);
      _assertExactUri(response.realUri, uri);
      return CheckoutApiResponse(
        data: _object(response.data),
        statusCode: response.statusCode,
      );
    } on CheckoutApiTransportException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      _assertSession(session);
      final Response<dynamic>? response = error.response;
      if (response != null) _assertExactUri(response.realUri, uri);
      final CheckoutTransportFailureKind kind = response != null
          ? CheckoutTransportFailureKind.rejected
          : switch (error.type) {
              DioExceptionType.connectionTimeout ||
              DioExceptionType.sendTimeout ||
              DioExceptionType.receiveTimeout ||
              DioExceptionType.transformTimeout =>
                CheckoutTransportFailureKind.timeout,
              DioExceptionType.connectionError ||
              DioExceptionType.badCertificate =>
                CheckoutTransportFailureKind.connection,
              _ => CheckoutTransportFailureKind.unknown,
            };
      Error.throwWithStackTrace(
        CheckoutApiTransportException(
          kind: kind,
          statusCode: response?.statusCode,
          message: 'The checkout safety read could not be verified.',
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.invalidResponse,
          message: 'The checkout safety response is invalid.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  void _assertSession(String expected) {
    if (authTokenReader()?.trim() != expected) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.rejected,
        statusCode: 401,
        message: 'The customer session changed during checkout recovery.',
      );
    }
  }

  void _assertExactUri(Uri actual, Uri expected) {
    if (actual.scheme.toLowerCase() != expected.scheme.toLowerCase() ||
        actual.host.toLowerCase() != expected.host.toLowerCase() ||
        actual.port != expected.port ||
        actual.path != expected.path ||
        actual.hasQuery ||
        actual.hasFragment ||
        actual.userInfo.isNotEmpty) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.invalidResponse,
        message: 'Checkout safety responded from an unexpected endpoint.',
      );
    }
  }

  static Map<dynamic, dynamic> _object(dynamic raw) {
    final dynamic value = raw is String ? jsonDecode(raw) : raw;
    if (value is! Map) {
      throw const FormatException('Checkout safety requires a JSON object.');
    }
    return value;
  }

  static bool _safeHeader(String value, int max) =>
      value.isNotEmpty &&
      value.length <= max &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

  static Uri _normalize(Uri uri) {
    AppConfig.requireWooCommerceCustomerTransport('checkout safety');
    final bool local =
        kDebugMode &&
        uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && !local) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.any((String part) => part == '.' || part == '..')) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.configuration,
        message: 'Checkout safety requires a configured HTTPS platform origin.',
      );
    }
    return uri.replace(
      host: uri.host.toLowerCase(),
      path:
          '/${uri.pathSegments.where((String part) => part.isNotEmpty).join('/')}',
    );
  }
}
