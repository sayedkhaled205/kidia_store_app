import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';

abstract interface class CheckoutRepository {
  Future<CheckoutState> loadCheckout();

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
    this.authoritativeCart,
    this.cause,
  });

  final CheckoutFailureKind kind;
  final String message;
  final int? statusCode;
  final CartError? apiError;

  /// WooCommerce can return the authoritative cart with a 409 response.
  final Cart? authoritativeCart;
  final Object? cause;

  bool get isConflict => kind == CheckoutFailureKind.conflict;

  @override
  String toString() => message;
}
