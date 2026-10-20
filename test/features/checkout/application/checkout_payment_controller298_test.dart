import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_payment_controller298.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';

CustomerOrder paymentOrder298({
  int id = 730,
  String status = 'pending',
  bool? paid = false,
  bool? needsPayment = true,
  String paymentMethod = '',
  String endpointPath = '/checkout/order-pay/730/',
  String? url =
      'https://store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_abc123',
}) => CustomerOrder(
  id: id,
  number: '$id',
  status: status,
  statusName: status,
  totalDisplay: 'EGP 100',
  itemCount: 1,
  items: const [],
  isPaid: paid,
  needsPayment: needsPayment,
  paymentUri: url == null ? null : Uri.parse(url),
  paymentMethod: paymentMethod,
  paymentEndpointPath: endpointPath,
);

void main() {
  final store = Uri.parse('https://store.example');
  test('same store order pay is the only allowed destination', () {
    expect(
      CheckoutPaymentPolicy298.destination(store, paymentOrder298()),
      isNotNull,
    );
    for (final url in [
      'https://evil.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a',
      'http://store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a',
      'https://name@store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a',
      'https://store.example:444/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a',
      'https://store.example/checkout/order-pay/731/?pay_for_order=true&key=wc_order_a',
      'https://store.example/checkout/order-received/730/?pay_for_order=true&key=wc_order_a',
      'https://store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a#foreign',
      'https://store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a&redirect_to=https://evil.example',
      'https://store.example/checkout/order-pay/730/?pay_for_order=true&key=wc_order_a&key=wc_order_b',
      'https://store.example/checkout/order-pay/730/?pay_for_order=false&key=wc_order_a',
      'https://store.example/checkout/order-pay/730/?pay_for_order=true&key=not_an_order_key',
      'javascript:alert(1)',
    ]) {
      expect(
        CheckoutPaymentPolicy298.destination(store, paymentOrder298(url: url)),
        isNull,
        reason: url,
      );
    }
    expect(
      CheckoutPaymentPolicy298.destination(
        Uri.parse('https://store.example/shop'),
        paymentOrder298(),
      ),
      isNull,
    );
    expect(
      CheckoutPaymentPolicy298.destination(store, paymentOrder298(paid: true)),
      isNull,
    );
    expect(
      CheckoutPaymentPolicy298.destination(
        store,
        paymentOrder298(needsPayment: null),
      ),
      isNull,
    );
  });

  test('configured localized endpoint works but cannot alter origin or order', () {
    for (final path in [
      '/checkout/pay-for-order/730/',
      '/إتمام-الطلب/دفع/730/',
      '/%d8%af%d9%81%d8%b9/730/',
    ]) {
      final order = paymentOrder298(
        endpointPath: path,
        url:
            'https://store.example$path?pay_for_order=true&key=wc_order_custom',
      );
      expect(
        CheckoutPaymentPolicy298.destination(store, order),
        isNotNull,
        reason: path,
      );
    }
    const installedPath = '/store/%D8%AF%D9%81%D8%B9/complete-order/101/';
    expect(
      CheckoutPaymentPolicy298.destination(
        Uri.parse('https://store.example/store/'),
        paymentOrder298(
          id: 101,
          endpointPath: installedPath,
          url:
              'https://store.example$installedPath?pay_for_order=true&key=wc_order_arabic',
        ),
      ),
      isNotNull,
    );
    for (final path in [
      '',
      '//evil.example/order-pay/730/',
      '/checkout/../order-pay/730/',
      '/checkout/%2e%2e/order-pay/730/',
      '/checkout/pay%2fother/730/',
      '/checkout/pay%5cother/730/',
      '/checkout/%252e%252e/pay/730/',
      '/checkout/pay/731/',
      '/checkout/pay/730/?redirect=x',
    ]) {
      final order = paymentOrder298(
        endpointPath: path,
        url:
            'https://store.example$path?pay_for_order=true&key=wc_order_custom',
      );
      expect(
        CheckoutPaymentPolicy298.destination(store, order),
        isNull,
        reason: path,
      );
    }
  });

  test(
    'opening is explicit, double taps launch once, return stays pending until server confirms',
    () async {
      var fresh = paymentOrder298();
      var reads = 0;
      final opened = <Uri>[];
      final gate = Completer<bool>();
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: store,
        sessionIsCurrent: () => true,
        readOrder: (id) async {
          reads++;
          expect(id, 730);
          return fresh;
        },
        launch: (uri) {
          opened.add(uri);
          return gate.future;
        },
      );
      await controller.refresh();
      expect(opened, isEmpty);
      expect(controller.state, CheckoutPaymentState298.pending);
      final opening = controller.openPayment();
      await Future<void>.delayed(Duration.zero);
      await controller.openPayment();
      expect(opened, hasLength(1));
      gate.complete(true);
      await opening;
      expect(controller.state, CheckoutPaymentState298.pending);
      await controller.returnedToApp();
      expect(controller.state, CheckoutPaymentState298.pending);
      fresh = paymentOrder298(
        status: 'processing',
        paid: true,
        needsPayment: false,
        url: null,
      );
      await controller.refresh();
      expect(controller.state, CheckoutPaymentState298.paid);
      await controller.openPayment();
      expect(opened, hasLength(1));
      expect(reads, 5);
      controller.dispose();
    },
  );

  test('COD remains received without a browser, not falsely paid', () async {
    var launches = 0;
    final controller = CheckoutPaymentController298(
      orderId: 730,
      storeUri: store,
      sessionIsCurrent: () => true,
      readOrder: (_) async => paymentOrder298(
        status: 'processing',
        // Woo is_paid() is status based; COD can still await collection.
        paid: true,
        needsPayment: false,
        paymentMethod: 'cod',
        url: null,
      ),
      launch: (_) async {
        launches++;
        return true;
      },
    );
    await controller.refresh();
    await controller.openPayment();
    expect(controller.state, CheckoutPaymentState298.received);
    expect(launches, 0);
    controller.dispose();
  });

  test(
    'resume during browser dispatch is reconciled after dispatch settles',
    () async {
      var reads = 0;
      final dispatch = Completer<bool>();
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: store,
        sessionIsCurrent: () => true,
        readOrder: (_) async {
          reads++;
          return paymentOrder298();
        },
        launch: (_) => dispatch.future,
      );
      final opening = controller.openPayment();
      await Future<void>.delayed(Duration.zero);
      await controller.returnedToApp();
      dispatch.complete(true);
      await opening;
      expect(reads, 2);
      expect(controller.state, CheckoutPaymentState298.pending);
      expect(controller.waitingForReturn, isFalse);
      controller.dispose();
    },
  );

  test('expired or switched identity during lookup never launches', () async {
    var current = true;
    var launches = 0;
    final lookup = Completer<CustomerOrder>();
    final controller = CheckoutPaymentController298(
      orderId: 730,
      storeUri: store,
      sessionIsCurrent: () => current,
      readOrder: (_) => lookup.future,
      launch: (_) async {
        launches++;
        return true;
      },
    );
    final opening = controller.openPayment();
    current = false;
    lookup.complete(paymentOrder298());
    await opening;
    expect(controller.state, CheckoutPaymentState298.unavailable);
    expect(controller.order, isNull);
    expect(launches, 0);
    controller.dispose();
  });

  test(
    'invalid order, missing facts and server errors stay actionable and unpaid',
    () async {
      for (final invalid in [
        paymentOrder298(id: 731),
        paymentOrder298(paid: null),
        paymentOrder298(paid: true, needsPayment: true),
      ]) {
        final controller = CheckoutPaymentController298(
          orderId: 730,
          storeUri: store,
          sessionIsCurrent: () => true,
          readOrder: (_) async => invalid,
          launch: (_) async => throw StateError('must not launch'),
        );
        await controller.refresh();
        expect(controller.state, CheckoutPaymentState298.unavailable);
        expect(controller.canPay, isFalse);
        controller.dispose();
      }
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: store,
        sessionIsCurrent: () => true,
        readOrder: (_) async => throw StateError('offline'),
        launch: (_) async => throw StateError('must not launch'),
      );
      await controller.refresh();
      expect(controller.state, CheckoutPaymentState298.unavailable);
      expect(controller.busy, isFalse);
      controller.dispose();
    },
  );

  test(
    'unsafe destination and failed browser opening do not complete payment',
    () async {
      var fresh = paymentOrder298(url: 'https://evil.example/pay');
      var launches = 0;
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: store,
        sessionIsCurrent: () => true,
        readOrder: (_) async => fresh,
        launch: (_) async {
          launches++;
          return false;
        },
      );
      await controller.refresh();
      expect(controller.canPay, isFalse);
      await controller.openPayment();
      expect(launches, 0);
      fresh = paymentOrder298();
      await controller.openPayment();
      expect(launches, 1);
      expect(controller.openFailed, isTrue);
      expect(controller.state, CheckoutPaymentState298.pending);
      expect(controller.waitingForReturn, isFalse);
      controller.dispose();
    },
  );

  test(
    'server cancellation closes the original order without a new request',
    () async {
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: store,
        sessionIsCurrent: () => true,
        readOrder: (_) async => paymentOrder298(
          status: 'cancelled',
          needsPayment: false,
          url: null,
        ),
        launch: (_) async => throw StateError('must not launch'),
      );
      await controller.refresh();
      expect(controller.state, CheckoutPaymentState298.closed);
      expect(controller.canPay, isFalse);
      controller.dispose();
    },
  );
}
