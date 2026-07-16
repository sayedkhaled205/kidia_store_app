import 'dart:async';

import 'package:kidia_store_app/features/cart/data/models/cart_error_model.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:kidia_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

class StoreApiCheckoutRepository implements CheckoutRepository {
  StoreApiCheckoutRepository({
    required this.cartRepository,
    required this.transport,
    required this.cartTokenStore,
  });

  final CartRepository cartRepository;
  final CheckoutApiTransport transport;

  /// Must be the same token store used by the cart data source.
  final CartTokenStore cartTokenStore;

  Future<void> _submissionTail = Future<void>.value();
  String? _lastSuccessfulKey;
  CheckoutOrderResult? _lastSuccessfulResult;

  @override
  Future<CheckoutState> loadCheckout() async {
    try {
      return CheckoutState(cart: await cartRepository.getCart());
    } on CartRepositoryException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: _cartFailureKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          apiError: error.apiError,
          authoritativeCart: error.serverCart,
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: CheckoutFailureKind.unknown,
          message: 'Unable to load checkout.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CheckoutOrderResult> placeOrder(CheckoutSubmission submission) {
    final Completer<CheckoutOrderResult> completer =
        Completer<CheckoutOrderResult>();
    _submissionTail = _submissionTail.then<void>((_) async {
      try {
        final String key = submission.idempotencyKey.trim();
        if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(key)) {
          throw const CheckoutRepositoryException(
            kind: CheckoutFailureKind.invalidInput,
            message: 'A safe checkout idempotency key is required.',
          );
        }
        _validateSubmission(submission);
        if (_lastSuccessfulKey == key && _lastSuccessfulResult != null) {
          completer.complete(_lastSuccessfulResult);
          return;
        }

        String token = cartTokenStore.read()?.trim() ?? '';
        if (token.isEmpty) {
          await cartRepository.getCart();
          token = cartTokenStore.read()?.trim() ?? '';
        }
        if (token.isEmpty) {
          throw const CheckoutRepositoryException(
            kind: CheckoutFailureKind.configuration,
            message: 'The store did not issue a Cart-Token for checkout.',
          );
        }

        final CheckoutApiResponse response = await transport.placeOrder(
          cartToken: token,
          idempotencyKey: key,
          body: _submissionJson(submission),
        );
        final CheckoutOrderResult result = _parseOrderResult(response.data);
        _lastSuccessfulKey = key;
        _lastSuccessfulResult = result;
        completer.complete(result);
      } on CheckoutRepositoryException catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } on CheckoutApiTransportException catch (error, stackTrace) {
        completer.completeError(_transportFailure(error), stackTrace);
      } on CartRepositoryException catch (error, stackTrace) {
        completer.completeError(
          CheckoutRepositoryException(
            kind: _cartFailureKind(error.kind),
            message: error.message,
            statusCode: error.statusCode,
            apiError: error.apiError,
            authoritativeCart: error.serverCart,
            cause: error,
          ),
          stackTrace,
        );
      } on FormatException catch (error, stackTrace) {
        completer.completeError(
          CheckoutRepositoryException(
            kind: CheckoutFailureKind.invalidResponse,
            message: 'The store returned invalid checkout data.',
            cause: error,
          ),
          stackTrace,
        );
      } catch (error, stackTrace) {
        completer.completeError(
          CheckoutRepositoryException(
            kind: CheckoutFailureKind.unknown,
            message: 'Checkout failed unexpectedly.',
            cause: error,
          ),
          stackTrace,
        );
      }
    });
    return completer.future;
  }

  Map<String, dynamic> _submissionJson(CheckoutSubmission submission) {
    final String paymentMethod = submission.paymentMethodId.trim();
    return <String, dynamic>{
      'billing_address': _addressJson(submission.billingAddress),
      'shipping_address': _addressJson(submission.shippingAddress),
      'customer_note': submission.customerNote.trim(),
      if (paymentMethod.isNotEmpty) 'payment_method': paymentMethod,

      // Gateway-specific fields (card data, tokens, nonces) are deliberately
      // outside this generic checkout. A dedicated gateway adapter can provide
      // them later without ever persisting secrets in this repository.
      'payment_data': const <Map<String, String>>[],
    };
  }

  void _validateSubmission(CheckoutSubmission submission) {
    final CheckoutAddress billing = submission.billingAddress.trimmed();
    if (billing.firstName.isEmpty ||
        billing.lastName.isEmpty ||
        billing.address1.isEmpty ||
        billing.city.isEmpty ||
        !RegExp(r'^[A-Z]{2}$').hasMatch(billing.country) ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(billing.email) ||
        submission.customerNote.trim().length > 1000) {
      throw const CheckoutRepositoryException(
        kind: CheckoutFailureKind.invalidInput,
        message: 'Checkout contains invalid standard customer fields.',
      );
    }
  }

  Map<String, String> _addressJson(CheckoutAddress source) {
    final CheckoutAddress address = source.trimmed();
    return <String, String>{
      'first_name': address.firstName,
      'last_name': address.lastName,
      'company': address.company,
      'address_1': address.address1,
      'address_2': address.address2,
      'city': address.city,
      'state': address.state,
      'postcode': address.postcode,
      'country': address.country,
      'email': address.email,
      'phone': address.phone,
    };
  }

  CheckoutOrderResult _parseOrderResult(dynamic raw) {
    final Map<String, dynamic> json = CartJson.object(raw, 'checkout');
    final int orderId = CartJson.integer(json['order_id']);
    if (orderId <= 0) {
      throw const FormatException('Checkout must return a positive order id.');
    }
    final Map<String, dynamic> paymentResult = CartJson.optionalObject(
      json['payment_result'],
      'payment_result',
    );
    final Uri? redirectUri = _webUri(paymentResult['redirect_url']);
    return CheckoutOrderResult(
      orderId: orderId,
      status: CartJson.text(json['status'], fallback: 'pending').trim(),
      paymentStatus: CartJson.text(
        paymentResult['payment_status'],
        fallback: 'pending',
      ).trim(),
      redirectUri: redirectUri,
    );
  }

  CheckoutRepositoryException _transportFailure(
    CheckoutApiTransportException error,
  ) {
    final Map<String, dynamic>? json = _objectOrNull(error.data);
    CartErrorModel? apiError;
    if (json != null) {
      try {
        apiError = CartErrorModel.fromJson(json);
      } on FormatException {
        apiError = null;
      }
    }
    Cart? authoritativeCart;
    final Map<String, dynamic>? data = _objectOrNull(json?['data']);
    final Map<String, dynamic>? cart = _objectOrNull(data?['cart']);
    if (cart != null) {
      try {
        authoritativeCart = CartModel.fromJson(cart).toEntity();
      } on FormatException {
        authoritativeCart = null;
      }
    }
    final CheckoutFailureKind kind = error.statusCode == 409
        ? CheckoutFailureKind.conflict
        : _transportFailureKind(error.kind, error.statusCode);
    return CheckoutRepositoryException(
      kind: kind,
      message: apiError?.message.trim().isNotEmpty == true
          ? apiError!.message.trim()
          : error.message,
      statusCode: error.statusCode,
      apiError: apiError?.toEntity(),
      authoritativeCart: authoritativeCart,
      cause: error,
    );
  }

  Map<String, dynamic>? _objectOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    try {
      return CartJson.object(value, 'checkout_error');
    } on FormatException {
      return null;
    }
  }

  Uri? _webUri(dynamic value) {
    final Uri? uri = Uri.tryParse(value?.toString().trim() ?? '');
    final bool isLocalHttp =
        uri?.scheme == 'http' &&
        (uri?.host == 'localhost' || uri?.host == '127.0.0.1');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && !isLocalHttp)) {
      return null;
    }
    return uri;
  }

  CheckoutFailureKind _transportFailureKind(
    CheckoutTransportFailureKind kind,
    int? statusCode,
  ) {
    if (statusCode == 400 || statusCode == 422) {
      return CheckoutFailureKind.invalidInput;
    }
    if (statusCode == 401 || statusCode == 403) {
      return CheckoutFailureKind.unauthorized;
    }
    if (statusCode != null && statusCode >= 500) {
      return CheckoutFailureKind.server;
    }
    return switch (kind) {
      CheckoutTransportFailureKind.configuration =>
        CheckoutFailureKind.configuration,
      CheckoutTransportFailureKind.timeout => CheckoutFailureKind.timeout,
      CheckoutTransportFailureKind.connection => CheckoutFailureKind.connection,
      CheckoutTransportFailureKind.cancelled => CheckoutFailureKind.unknown,
      CheckoutTransportFailureKind.certificate =>
        CheckoutFailureKind.connection,
      CheckoutTransportFailureKind.rejected =>
        CheckoutFailureKind.invalidResponse,
      CheckoutTransportFailureKind.invalidResponse =>
        CheckoutFailureKind.invalidResponse,
      CheckoutTransportFailureKind.unknown => CheckoutFailureKind.unknown,
    };
  }

  CheckoutFailureKind _cartFailureKind(CartFailureKind kind) {
    return switch (kind) {
      CartFailureKind.invalidInput => CheckoutFailureKind.invalidInput,
      CartFailureKind.configuration => CheckoutFailureKind.configuration,
      CartFailureKind.timeout => CheckoutFailureKind.timeout,
      CartFailureKind.connection => CheckoutFailureKind.connection,
      CartFailureKind.cancelled => CheckoutFailureKind.unknown,
      CartFailureKind.certificate => CheckoutFailureKind.connection,
      CartFailureKind.unauthorized => CheckoutFailureKind.unauthorized,
      CartFailureKind.notFound => CheckoutFailureKind.invalidResponse,
      CartFailureKind.conflict => CheckoutFailureKind.conflict,
      CartFailureKind.server => CheckoutFailureKind.server,
      CartFailureKind.invalidResponse => CheckoutFailureKind.invalidResponse,
      CartFailureKind.unknown => CheckoutFailureKind.unknown,
    };
  }
}
