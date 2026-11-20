import 'dart:async';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_controller.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_safety_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/repositories/store_api_checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/data/storage/checkout_pending_attempt_store.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';
import '../support/checkout_test_data.dart';

class _Safety implements CheckoutSafetyTransport {
  bool fail = false;
  Completer<CheckoutApiResponse>? gate;
  int reads = 0;
  int recoveries = 0;
  @override
  Future<CheckoutApiResponse> loadCapabilities() async {
    reads++;
    if (gate != null) return gate!.future;
    if (fail) {
      throw const CheckoutApiTransportException(
        kind: CheckoutTransportFailureKind.connection,
        message: 'Synthetic offline capability read',
      );
    }
    return const CheckoutApiResponse(
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
  }

  @override
  Future<CheckoutApiResponse> recoverAttempt({
    required String idempotencyKey,
    String? cartToken,
  }) async {
    recoveries++;
    throw const CheckoutApiTransportException(
      kind: CheckoutTransportFailureKind.connection,
      message: 'Synthetic recovery unavailable',
    );
  }
}

class _Fixture {
  final tokens = MemoryCartTokenStore()..write('synthetic-cart');
  final pending = MemoryCheckoutPendingAttemptStore();
  final safety = _Safety();
  final transport = FakeCheckoutTransport();
  final cart = FakeCheckoutCartRepository(
    cart: checkoutCart(needsShipping: false),
  );
  bool healthyCartRead = true;
  bool sessionValid = true;
  late final repository = StoreApiCheckoutRepository(
    currentSessionIsValid: () => sessionValid,
    customerId: 27,
    requireServerSafety: true,
    cartRepository: cart,
    transport: transport,
    cartTokenStore: tokens,
    pendingAttemptStore: pending,
    safetyTransport: safety,
  );
  _Fixture() {
    cart.onGetCart = () async {
      if (!healthyCartRead) {
        throw const CartRepositoryException(
          kind: CartFailureKind.connection,
          message: 'Synthetic failed cart bootstrap',
        );
      }
      tokens.write('synthetic-cart');
      return cart.cart;
    };
    transport.onUpdateCustomer = () async =>
        CheckoutApiResponse(data: checkoutCartJson(needsShipping: false));
  }
  Future<CheckoutController> loaded() async {
    final controller = CheckoutController(repository: repository);
    await controller.load();
    await controller.refreshShipping();
    return controller;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'safety retry cannot accept a response from a changed account',
    () async {
      final f = _Fixture();
      final response = await f.safety.loadCapabilities();
      f.safety.gate = Completer<CheckoutApiResponse>();
      final operation = f.repository.refreshCheckoutSafety();
      final observed = expectLater(
        operation,
        throwsA(
          isA<CheckoutRepositoryException>().having(
            (e) => e.kind,
            'kind',
            CheckoutFailureKind.unauthorized,
          ),
        ),
      );
      f.sessionValid = false;
      f.safety.gate!.complete(response);
      await observed;
      expect(f.transport.calls, 0);
    },
  );
  test(
    'preexisting unknown marker cannot become confirmed not-dispatched',
    () async {
      final f = _Fixture();
      final controller = await f.loaded();
      addTearDown(controller.dispose);
      f.pending.value = const CheckoutPendingAttempt(
        idempotencyKey: 'earlier-attempt',
        createdAtMicros: 1,
      );
      await controller.submit();
      expect(controller.hasUnresolvedSubmission, true);
      expect(controller.canRefreshSafety, false);
      await controller.refreshSafety();
      await controller.submit();
      expect(f.transport.calls, 0);
      expect(f.pending.value?.idempotencyKey, 'earlier-attempt');
      expect(f.pending.value?.isUnresolved, true);
    },
  );
  test(
    'predispatch cart GET failure must not claim an unknown order',
    () async {
      final f = _Fixture();
      final controller = await f.loaded();
      addTearDown(controller.dispose);
      expect(controller.canSubmit, true);
      f.tokens.clear();
      f.healthyCartRead = false;
      await controller.submit();
      expect(
        f.transport.calls,
        0,
        reason: 'No order POST was ever dispatched.',
      );
      expect(
        f.pending.value,
        isNull,
        reason: 'No order dispatch marker was created.',
      );
      expect(
        controller.hasUnresolvedSubmission,
        false,
        reason: 'A failed GET before dispatch cannot create an unknown order.',
      );
      f.healthyCartRead = true;
      await controller.load();
      await controller.refreshShipping();
      expect(controller.canSubmit, true);
      expect(f.pending.value, isNull);
      expect(f.transport.calls, 0);
    },
  );
  test('actual uncertain POST retains marker and never resends', () async {
    final f = _Fixture();
    final controller = await f.loaded();
    addTearDown(controller.dispose);
    f.transport.error = const CheckoutApiTransportException(
      kind: CheckoutTransportFailureKind.connection,
      message: 'Synthetic lost POST acknowledgment',
    );
    await controller.submit();
    expect(f.transport.calls, 1);
    expect(f.pending.value?.isUnresolved, true);
    expect(controller.hasUnresolvedSubmission, true);
    await controller.submit();
    await controller.load();
    await controller.recoverPendingOrder();
    expect(f.transport.calls, 1);
    expect(f.safety.recoveries, 1);
    expect(controller.hasUnresolvedSubmission, true);
  });
  testWidgets(
    'capability GET failure can retry on the same screen without submitting',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = _Fixture();
      f.safety.fail = true;
      Widget app(Key key) => ProviderScope(
        child: MaterialApp(
          home: CheckoutScreen(key: key, repository: f.repository),
        ),
      );
      await tester.pumpWidget(app(const ValueKey('first')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('checkout-safety-unavailable')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-place-order')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('checkout-safety-retry')), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(f.safety.reads, 1);
      f.safety.fail = false;
      await tester.pump(const Duration(seconds: 2));
      expect(f.safety.reads, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-place-order')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('checkout-safety-retry')));
      await tester.pumpAndSettle();
      expect(f.safety.reads, 2);
      expect(
        find.byKey(const Key('checkout-safety-unavailable')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('checkout-place-order')))
            .onPressed,
        isNotNull,
      );
      expect(f.transport.calls, 0);
    },
  );
}
