import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';

/// The amount the buyer actually confirmed, never a floating-point estimate.
class CheckoutConfirmedTotal {
  CheckoutConfirmedTotal({
    required String totalPrice,
    required this.currencyCode,
    required this.currencyMinorUnit,
  }) : totalPrice = _minor(totalPrice) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode) ||
        currencyMinorUnit < 0 ||
        currencyMinorUnit > 8) {
      throw const FormatException('Invalid confirmed checkout currency.');
    }
  }

  factory CheckoutConfirmedTotal.fromCartTotals(CartTotals totals) {
    if (totals.totalEstimated) {
      throw const FormatException(
        'An estimated total cannot confirm an order.',
      );
    }
    return CheckoutConfirmedTotal(
      totalPrice: totals.priceMinor,
      currencyCode: totals.currency.code,
      currencyMinorUnit: totals.currency.minorUnit,
    );
  }

  final String totalPrice;
  final String currencyCode;
  final int currencyMinorUnit;

  Map<String, Object> toJson() => <String, Object>{
    'total_price': totalPrice,
    'currency_code': currencyCode,
    'currency_minor_unit': currencyMinorUnit,
  };

  static String _minor(String value) {
    if (!RegExp(r'^[0-9]{1,40}$').hasMatch(value)) {
      throw const FormatException('Invalid confirmed checkout amount.');
    }
    return value.replaceFirst(RegExp(r'^0+(?=[0-9])'), '');
  }
}

/// A fixed protocol, not permission to use an arbitrary server-supplied URL.
class CheckoutSafetyCapability {
  const CheckoutSafetyCapability({required this.enforced});
  static const int protocol = 50;
  static const String namespace = 'mobishop_native_checkout50';
  static const String checkoutRoute = '/wc/store/v1/checkout';
  static const String recoveryRoute =
      '/mobishop/v1/customer/checkout-attempts/{key}';
  final bool enforced;

  factory CheckoutSafetyCapability.fromJson(dynamic raw) {
    if (raw is! Map ||
        raw['protocol'] != protocol ||
        raw['protocol'] is! int ||
        raw['enforced'] is! bool ||
        raw['checkout_route'] != checkoutRoute ||
        raw['recovery_route'] != recoveryRoute ||
        raw['guest_checkout'] != false ||
        raw['automatic_replay'] != false ||
        raw['qa_isolation'] is! bool) {
      throw const FormatException('Unsupported checkout safety contract.');
    }
    return CheckoutSafetyCapability(enforced: raw['enforced'] as bool);
  }
}

enum CheckoutRecoveryState {
  unresolved,
  rejectedBeforeDispatch,
  rejectedBeforePayment,
  orderCreated,
}

/// This is the outcome of one exact authenticated attempt, never order-history
/// matching, a new basket, or an invitation to replay a POST automatically.
class CheckoutAttemptRecovery {
  const CheckoutAttemptRecovery.unresolved()
    : state = CheckoutRecoveryState.unresolved,
      orderResult = null;
  const CheckoutAttemptRecovery.rejected()
    : state = CheckoutRecoveryState.rejectedBeforePayment,
      orderResult = null;
  const CheckoutAttemptRecovery.rejectedBeforeDispatch()
    : state = CheckoutRecoveryState.rejectedBeforeDispatch,
      orderResult = null;
  const CheckoutAttemptRecovery.created(CheckoutOrderResult result)
    : state = CheckoutRecoveryState.orderCreated,
      orderResult = result;

  final CheckoutRecoveryState state;
  final CheckoutOrderResult? orderResult;
  bool get isResolved => state != CheckoutRecoveryState.unresolved;

  static bool isProvenPreDispatchRejection(
    dynamic raw,
    int? statusCode, {
    required String expectedAttemptKey,
    required int? expectedCustomerId,
  }) =>
      statusCode == 409 &&
      raw is Map &&
      raw['protocol'] is int &&
      raw['protocol'] == 50 &&
      raw['code'] == 'mobishop_native_checkout50_rejected_before_dispatch' &&
      raw['state'] == 'rejected_before_dispatch' &&
      raw['checkout_dispatched'] == false &&
      raw['automatic_replay'] == false &&
      raw['attempt_key'] is String &&
      raw['attempt_key'] == expectedAttemptKey &&
      expectedCustomerId != null &&
      expectedCustomerId > 0 &&
      raw['customer_id'] is int &&
      raw['customer_id'] == expectedCustomerId;

  static CheckoutAttemptRecovery parse(
    dynamic raw,
    int? statusCode, {
    String? expectedAttemptKey,
    int? expectedCustomerId,
  }) {
    if (raw is! Map ||
        raw['protocol'] != 50 ||
        raw['protocol'] is! int ||
        raw['automatic_replay'] != false) {
      throw const FormatException('Unverified checkout attempt recovery.');
    }
    if (expectedAttemptKey != null &&
        isProvenPreDispatchRejection(
          raw,
          statusCode,
          expectedAttemptKey: expectedAttemptKey,
          expectedCustomerId: expectedCustomerId,
        )) {
      return const CheckoutAttemptRecovery.rejectedBeforeDispatch();
    }
    if (statusCode == 409 &&
        raw['state'] == 'rejected_before_payment' &&
        raw['code'] == 'mobishop_native_checkout50_rejected_before_payment') {
      return const CheckoutAttemptRecovery.rejected();
    }
    if (statusCode == 202 &&
        (raw['state'] == 'unknown' || raw['state'] == 'in_progress')) {
      return const CheckoutAttemptRecovery.unresolved();
    }
    if (statusCode != 200 ||
        raw['state'] != 'order_created' ||
        raw['checkout_locked'] is! bool) {
      throw const FormatException('Unverified checkout attempt recovery.');
    }
    final dynamic order = raw['order'];
    final dynamic status = order is Map ? order['status'] : null;
    if (order is! Map ||
        order['id'] is! int ||
        (order['id'] as int) <= 0 ||
        status is! String ||
        !RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(status) ||
        order['total_price'] is! String ||
        order['currency_code'] is! String ||
        order['currency_minor_unit'] is! int ||
        (raw['payment_status'] != 'success' &&
            raw['payment_status'] != 'unknown')) {
      throw const FormatException('Unverified recovered checkout receipt.');
    }
    CheckoutConfirmedTotal(
      totalPrice: order['total_price'] as String,
      currencyCode: order['currency_code'] as String,
      currencyMinorUnit: order['currency_minor_unit'] as int,
    );
    // A created order can be real while a crashed dispatch still owns the
    // basket. Do not persist a resolved receipt or clear the blocker then.
    if (raw['checkout_locked'] == true) {
      return const CheckoutAttemptRecovery.unresolved();
    }
    return CheckoutAttemptRecovery.created(
      CheckoutOrderResult(
        orderId: order['id'] as int,
        status: status,
        paymentStatus: raw['payment_status'] as String,
      ),
    );
  }
}
