import 'package:dio/dio.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

abstract interface class ShopifyStorefrontReader {
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const <String, dynamic>{},
  });
}

abstract interface class ShopifyStorefrontCartTransport
    implements ShopifyStorefrontReader {
  Future<Map<String, dynamic>> cartMutation(
    String document, {
    Map<String, dynamic> variables = const <String, dynamic>{},
  });
}

/// Direct customer Storefront reads. No builder relay, shared Dio credentials,
/// automatic retries, private tokens, or redirects to another host.
class ShopifyStorefrontClient implements ShopifyStorefrontCartTransport {
  ShopifyStorefrontClient({
    required CommerceConnection connection,
    HttpClientAdapter? adapter,
  }) : _endpoint = connection.shopifyStorefrontEndpoint,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 10),
           sendTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 20),
           followRedirects: false,
           maxRedirects: 0,
           validateStatus: (int? status) => status != null,
           headers: <String, dynamic>{
             'Accept': 'application/json',
             'Content-Type': 'application/json',
             'Cache-Control': 'no-store',
             if (connection.shopifyPublicStorefrontToken.isNotEmpty)
               'X-Shopify-Storefront-Access-Token':
                   connection.shopifyPublicStorefrontToken,
           },
         ),
       ) {
    connection.requireCapability(CustomerCommerceCapability.catalog);
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Uri _endpoint;
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    // Reads cannot accidentally become mutations. Cart writes use their own
    // explicit method; Customer Account authentication is a separate protocol.
    if (!RegExp(r'^\s*(query\b|\{)').hasMatch(document) ||
        RegExp(r'\b(mutation|subscription)\b').hasMatch(document)) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
        message: 'This Storefront client only accepts catalog queries.',
      );
    }
    return _request(document, variables);
  }

  @override
  Future<Map<String, dynamic>> cartMutation(
    String document, {
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    if (!_isSingleCartMutation(document)) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.configuration,
        message: 'Only the supported customer cart operations are allowed.',
      );
    }
    // Never retry writes automatically. An interrupted response may follow a
    // successful mutation and must be reconciled by re-reading the known cart.
    return _request(document, variables);
  }

  Future<Map<String, dynamic>> _request(
    String document,
    Map<String, dynamic> variables,
  ) async {
    try {
      final Response<dynamic> response = await _dio.postUri<dynamic>(
        _endpoint,
        data: <String, dynamic>{'query': document, 'variables': variables},
      );
      final dynamic body = response.data;
      final int? status = response.statusCode;
      final dynamic errors = body is Map ? body['errors'] : null;
      final bool hasErrors = errors is List && errors.isNotEmpty;
      final bool channelLocked =
          hasErrors &&
          errors.any(
            (dynamic error) =>
                error is Map &&
                error['message'] == 'Online Store channel is locked.',
          );
      if (status != 200 || hasErrors) {
        throw StoreApiException(
          kind: channelLocked
              ? StoreApiFailureKind.configuration
              : status == 401 || status == 403
              ? StoreApiFailureKind.unauthorized
              : StoreApiFailureKind.server,
          statusCode: status,
          message: channelLocked
              ? 'Shopify Online Store channel is locked. No catalog data was '
                    'replaced with demo or empty results.'
              : 'Shopify rejected the Storefront request. No catalog data was '
                    'replaced with demo or empty results.',
        );
      }
      if (body is! Map || body['data'] is! Map) {
        throw const StoreApiException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'Shopify returned an invalid Storefront response.',
        );
      }
      return Map<String, dynamic>.from(body['data'] as Map);
    } on StoreApiException {
      rethrow;
    } on DioException catch (error) {
      // Do not retain/log DioException: it includes request headers and payload.
      throw StoreApiException(
        kind: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout => StoreApiFailureKind.timeout,
          DioExceptionType.badCertificate => StoreApiFailureKind.certificate,
          DioExceptionType.cancel => StoreApiFailureKind.cancelled,
          _ => StoreApiFailureKind.connection,
        },
        message: 'Could not reach the configured Shopify storefront.',
      );
    }
  }

  void close() => _dio.close(force: true);

  /// The gateway uses one unaliased cart root field and variables-only input.
  /// Validate that narrow grammar; do not accidentally allow a second root
  /// write such as cartSubmitForCompletion alongside a harmless cartCreate.
  static bool _isSingleCartMutation(String document) {
    if (!RegExp(r'^\s*mutation\b').hasMatch(document) ||
        document.contains(RegExp('["#]'))) {
      return false;
    }
    int braces = 0;
    int parentheses = 0;
    final List<String> rootFields = <String>[];
    for (final RegExpMatch match in RegExp(
      r'[A-Za-z_][A-Za-z0-9_]*|[{}()]',
    ).allMatches(document)) {
      final String token = match.group(0)!;
      if (token == '(') {
        parentheses++;
      } else if (token == ')') {
        if (--parentheses < 0) return false;
      } else if (token == '{' && parentheses == 0) {
        braces++;
      } else if (token == '}' && parentheses == 0) {
        if (--braces < 0) return false;
      } else if (braces == 1 && parentheses == 0) {
        rootFields.add(token);
      }
    }
    return braces == 0 &&
        parentheses == 0 &&
        rootFields.length == 1 &&
        const <String>{
          'cartCreate',
          'cartLinesAdd',
          'cartLinesUpdate',
          'cartLinesRemove',
          'cartDiscountCodesUpdate',
          'cartBuyerIdentityUpdate',
        }.contains(rootFields.single);
  }
}
