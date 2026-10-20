import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_safety_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/repositories/store_api_checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/data/storage/checkout_pending_attempt_store.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_safety.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import '../support/checkout_test_data.dart';

Map<String, dynamic> receipt298({
  bool locked = false,
  String status = 'pending',
  String payment = 'pending',
}) => {
  'protocol': 50,
  'state': 'order_created',
  'checkout_locked': locked,
  'automatic_replay': false,
  'payment_status': payment,
  'order': {
    'id': 730,
    'status': status,
    'total_price': '12500',
    'currency_code': 'USD',
    'currency_minor_unit': 2,
  },
};

void main() {
  test(
    'only verified explicit pending receipt can continue, a locked receipt stays unresolved',
    () {
      final receipt = CheckoutAttemptRecovery.parse(receipt298(), 200);
      expect(receipt.state, CheckoutRecoveryState.orderCreated);
      expect(receipt.orderResult!.paymentStatus, 'pending');
      expect(receipt.orderResult!.redirectUri, isNull);
      expect(
        CheckoutAttemptRecovery.parse(receipt298(locked: true), 200).isResolved,
        isFalse,
      );
      for (final data in [
        {...receipt298(), 'protocol': 49},
        {...receipt298(), 'automatic_replay': true},
        {...receipt298(), 'state': 'in_progress'},
        receipt298(status: 'processing'),
        receipt298(payment: 'failure'),
      ]) {
        expect(
          () => CheckoutAttemptRecovery.parse(data, 200),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'protected POST persists pending order and repeated taps/recovery never POST again',
    () async {
      final transport = FakeCheckoutTransport()
        ..response = CheckoutApiResponse(data: receipt298(), statusCode: 200);
      final pending = MemoryCheckoutPendingAttemptStore();
      final safety = _Safety();
      final repository = StoreApiCheckoutRepository(
        customerId: 27,
        requireServerSafety: true,
        cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
        transport: transport,
        cartTokenStore: MemoryCartTokenStore()..write('cart-27'),
        pendingAttemptStore: pending,
        safetyTransport: safety,
      );
      final submission = _submission();
      final result = await repository.placeOrder(submission);
      expect(result.orderId, 730);
      expect(result.status, 'pending');
      expect(result.paymentStatus, 'pending');
      expect(pending.value!.confirmedResult!.orderId, 730);
      expect((await repository.placeOrder(submission)).orderId, 730);
      final recovered = await repository.recoverPendingOrder();
      expect(recovered.orderResult!.paymentStatus, 'pending');
      expect(transport.calls, 1);
      expect(safety.recoveries, 1);
    },
  );

  test(
    'a bare gateway pending response remains ambiguous and cannot be replayed',
    () async {
      final transport = FakeCheckoutTransport()
        ..response = const CheckoutApiResponse(
          statusCode: 200,
          data: {
            'order_id': 730,
            'status': 'pending',
            'payment_result': {
              'payment_status': 'pending',
              'redirect_url': 'https://foreign.example/pay',
            },
            'extensions': {
              'mobishop_native_checkout50': {'protocol': 50, 'enforced': true},
            },
          },
        );
      final pending = MemoryCheckoutPendingAttemptStore();
      final repository = StoreApiCheckoutRepository(
        customerId: 27,
        requireServerSafety: true,
        cartRepository: FakeCheckoutCartRepository(cart: checkoutCart()),
        transport: transport,
        cartTokenStore: MemoryCartTokenStore()..write('cart-27'),
        pendingAttemptStore: pending,
        safetyTransport: _Safety(),
      );
      await expectLater(
        repository.placeOrder(_submission()),
        throwsA(isA<CheckoutRepositoryException>()),
      );
      expect(pending.value!.isUnresolved, isTrue);
      await expectLater(
        repository.placeOrder(_submission()),
        throwsA(isA<CheckoutRepositoryException>()),
      );
      expect(transport.calls, 1);
    },
  );
}

CheckoutSubmission _submission() {
  const address = CheckoutAddress(
    firstName: 'Test',
    lastName: 'Buyer',
    address1: '1 Test road',
    city: 'London',
    country: 'GB',
    email: 'test@example.com',
    phone: '12345',
  );
  return CheckoutSubmission(
    billingAddress: address,
    shippingAddress: address,
    customerNote: '',
    paymentMethodId: 'card',
    idempotencyKey: 'checkout-payment-298',
    confirmedTotal: CheckoutConfirmedTotal(
      totalPrice: '12500',
      currencyCode: 'USD',
      currencyMinorUnit: 2,
    ),
  );
}

class _Safety implements CheckoutSafetyTransport {
  int recoveries = 0;
  @override
  Future<CheckoutApiResponse> loadCapabilities() async =>
      const CheckoutApiResponse(
        statusCode: 200,
        data: {
          'protocol': 50,
          'enforced': true,
          'checkout_route': '/wc/store/v1/checkout',
          'recovery_route': '/mobishop/v1/customer/checkout-attempts/{key}',
          'guest_checkout': false,
          'automatic_replay': false,
          'qa_isolation': false,
        },
      );
  @override
  Future<CheckoutApiResponse> recoverAttempt({
    required String idempotencyKey,
    String? cartToken,
  }) async {
    expect(idempotencyKey, 'checkout-payment-298');
    recoveries++;
    return CheckoutApiResponse(data: receipt298(), statusCode: 200);
  }
}
