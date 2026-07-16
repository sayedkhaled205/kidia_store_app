import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';

abstract interface class CheckoutRepository {
  Future<CheckoutState> loadCheckout();

  Future<Cart> updateCustomer({
    required CheckoutAddress billingAddress,
    required CheckoutAddress shippingAddress,
  });

  Future<CheckoutOrderResult> placeOrder(CheckoutSubmission submission);
}

enum CheckoutFailureKind {
  invalidInput,
  configuration,
  timeout,
  connection,
  unauthorized,
  conflict,
  server,
  invalidResponse,
  unknown,
}

class CheckoutRepositoryException implements Exception {
  const CheckoutRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.apiError,
    this.fieldErrors = const <String, String>{},
    this.authoritativeCart,
    this.cause,
  });

  final CheckoutFailureKind kind;
  final String message;
  final int? statusCode;
  final CartError? apiError;

  /// WooCommerce validation errors keyed by canonical checkout field names.
  ///
  /// Core address keys use the classic WooCommerce form (for example,
  /// `billing_first_name` and `shipping_postcode`) so presentation layers can
  /// map the same server response to either dynamic or built-in checkout UI.
  final Map<String, String> fieldErrors;

  /// WooCommerce can return the authoritative cart with a 409 response.
  final Cart? authoritativeCart;
  final Object? cause;

  bool get isConflict => kind == CheckoutFailureKind.conflict;

  @override
  String toString() => message;
}
