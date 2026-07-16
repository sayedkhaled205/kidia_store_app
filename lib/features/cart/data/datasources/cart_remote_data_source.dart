import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_error_model.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_item.dart';

abstract interface class CartRemoteDataSource {
  Future<CartModel> fetchCart();

  Future<CartModel> addItem({
    required int productId,
    required int quantity,
    required List<CartItemVariation> variation,
  });

  Future<CartModel> updateItem({required String key, required int quantity});

  Future<CartModel> removeItem(String key);

  Future<CartModel> applyCoupon(String code);

  Future<CartModel> removeCoupon(String code);
}

class CartRemoteException implements Exception {
  const CartRemoteException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.apiError,
    this.serverCart,
    this.cause,
  });

  final CartFailureKind kind;
  final String message;
  final int? statusCode;
  final CartErrorModel? apiError;
  final CartModel? serverCart;
  final Object? cause;

  @override
  String toString() => message;
}

/// Official WooCommerce Store API cart data source.
///
/// The first tokenless GET is deliberately delegated to the shared
/// [StoreApiClient]. Once WooCommerce issues a Cart-Token, all cart requests use
/// [CartApiTransport] so the token can be attached to GET and POST requests.
class StoreApiCartRemoteDataSource implements CartRemoteDataSource {
  factory StoreApiCartRemoteDataSource({
    required StoreApiClient storeApiClient,
    required CartApiTransport transport,
    CartTokenStore? tokenStore,
  }) {
    return StoreApiCartRemoteDataSource._(
      storeApiClient,
      transport,
      tokenStore ?? MemoryCartTokenStore(),
    );
  }

  StoreApiCartRemoteDataSource._(
    this._storeApiClient,
    this._transport,
    this._tokenStore,
  );

  static const String _cartPath = '/wp-json/wc/store/v1/cart';

  final StoreApiClient _storeApiClient;
  final CartApiTransport _transport;
  final CartTokenStore _tokenStore;

  @override
  Future<CartModel> fetchCart() async {
    final String? token = _validToken;
    try {
      final StoreApiResponse response = token == null
          ? await _storeApiClient.get(_cartPath)
          : await _transport.request(
              CartApiMethod.get,
              _cartPath,
              headers: <String, String>{'Cart-Token': token},
            );
      return _parseSuccess(response);
    } on CartApiTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(_parseTransportFailure(error), stackTrace);
    }
  }

  @override
  Future<CartModel> addItem({
    required int productId,
    required int quantity,
    required List<CartItemVariation> variation,
  }) {
    return _mutate('$_cartPath/add-item', <String, dynamic>{
      'id': productId,
      'quantity': quantity,
      if (variation.isNotEmpty)
        'variation': variation
            .map((CartItemVariation value) => value.toStoreApiJson())
            .toList(growable: false),
    });
  }

  @override
  Future<CartModel> updateItem({required String key, required int quantity}) {
    return _mutate('$_cartPath/update-item', <String, dynamic>{
      'key': key,
      'quantity': quantity,
    });
  }

  @override
  Future<CartModel> removeItem(String key) {
    return _mutate('$_cartPath/remove-item', <String, dynamic>{'key': key});
  }

  @override
  Future<CartModel> applyCoupon(String code) {
    return _mutate('$_cartPath/apply-coupon', <String, dynamic>{'code': code});
  }

  @override
  Future<CartModel> removeCoupon(String code) {
    return _mutate('$_cartPath/remove-coupon', <String, dynamic>{'code': code});
  }

  String? get _validToken {
    final String value = _tokenStore.read()?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<CartModel> _mutate(String path, Map<String, dynamic> body) async {
    String? token = _validToken;
    if (token == null) {
      await fetchCart();
      token = _validToken;
    }
    if (token == null) {
      throw const CartRemoteException(
        kind: CartFailureKind.configuration,
        message: 'The store did not issue a Cart-Token for this cart session.',
      );
    }

    try {
      final StoreApiResponse response = await _transport.request(
        CartApiMethod.post,
        path,
        body: body,
        headers: <String, String>{'Cart-Token': token},
      );
      return _parseSuccess(response);
    } on CartApiTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(_parseTransportFailure(error), stackTrace);
    }
  }

  CartModel _parseSuccess(StoreApiResponse response) {
    _captureToken(response.header('cart-token'));
    return CartModel.fromJson(CartJson.object(response.data, 'cart'));
  }

  CartRemoteException _parseTransportFailure(CartApiTransportException error) {
    _captureToken(error.header('cart-token'));
    final Map<String, dynamic>? json = _optionalJsonObject(error.data);
    CartErrorModel? apiError;
    CartModel? serverCart;
    if (json != null) {
      if (json['code'] != null || json['message'] != null) {
        apiError = CartErrorModel.fromJson(json);
      }
      final Map<String, dynamic>? data = _optionalJsonObject(json['data']);
      final Map<String, dynamic>? cart = _optionalJsonObject(data?['cart']);
      if (cart != null) {
        try {
          serverCart = CartModel.fromJson(cart);
        } on FormatException {
          serverCart = null;
        }
      }
    }

    return CartRemoteException(
      kind: _failureKind(error.statusCode),
      message: apiError?.message.isNotEmpty == true
          ? apiError!.message
          : error.message,
      statusCode: error.statusCode,
      apiError: apiError,
      serverCart: serverCart,
      cause: error,
    );
  }

  Map<String, dynamic>? _optionalJsonObject(dynamic value) {
    if (value == null) {
      return null;
    }
    try {
      return CartJson.object(value, 'error');
    } on FormatException {
      return null;
    }
  }

  void _captureToken(String? token) {
    final String value = token?.trim() ?? '';
    if (value.isNotEmpty) {
      _tokenStore.write(value);
    }
  }

  CartFailureKind _failureKind(int? statusCode) {
    if (statusCode == 400 || statusCode == 422) {
      return CartFailureKind.invalidInput;
    }
    if (statusCode == 401 || statusCode == 403) {
      return CartFailureKind.unauthorized;
    }
    if (statusCode == 404) {
      return CartFailureKind.notFound;
    }
    if (statusCode == 409) {
      return CartFailureKind.conflict;
    }
    if (statusCode != null && statusCode >= 500) {
      return CartFailureKind.server;
    }
    return CartFailureKind.invalidResponse;
  }
}

CartFailureKind cartFailureKindFromStoreApi(StoreApiFailureKind kind) {
  return switch (kind) {
    StoreApiFailureKind.configuration => CartFailureKind.configuration,
    StoreApiFailureKind.timeout => CartFailureKind.timeout,
    StoreApiFailureKind.connection => CartFailureKind.connection,
    StoreApiFailureKind.cancelled => CartFailureKind.cancelled,
    StoreApiFailureKind.certificate => CartFailureKind.certificate,
    StoreApiFailureKind.unauthorized => CartFailureKind.unauthorized,
    StoreApiFailureKind.notFound => CartFailureKind.notFound,
    StoreApiFailureKind.server => CartFailureKind.server,
    StoreApiFailureKind.invalidResponse => CartFailureKind.invalidResponse,
    StoreApiFailureKind.unknown => CartFailureKind.unknown,
  };
}
