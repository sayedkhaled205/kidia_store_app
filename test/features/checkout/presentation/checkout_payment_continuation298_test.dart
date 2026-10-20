import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_payment_controller298.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_payment_continuation298.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';
import 'package:mobishop_store_app/features/checkout/presentation/providers/checkout_payment_provider298.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:mobishop_store_app/features/orders/presentation/customer_orders_screen.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';
import '../support/checkout_test_data.dart';
import '../application/checkout_payment_controller298_test.dart'
    show paymentOrder298;

void main() {
  testWidgets(
    'an existing pending order can resume payment from order history',
    (tester) async {
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: Uri.parse('https://store.example'),
        sessionIsCurrent: () => true,
        readOrder: (_) async => paymentOrder298(),
        launch: (_) async => true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerOrdersRepositoryProvider.overrideWithValue(
              _OrdersForPayment(),
            ),
            cartBadgeCountProvider.overrideWithValue(0),
            checkoutPaymentController298Provider.overrideWith(
              (ref, id) => controller,
            ),
          ],
          child: const MaterialApp(
            home: CustomerOrdersScreen(initialOrderId: 730),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('customer-order-payment-730'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-payment-pending')), findsOneWidget);
      expect(
        find.byKey(const Key('checkout-continue-payment')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'created checkout reaches payment actions without repeating its order POST',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var launches = 0;
      final repository = FakeCheckoutRepository(
        onSubmit: (_) async => CheckoutOrderResult(
          orderId: 730,
          status: 'pending',
          paymentStatus: 'success',
          // An arbitrary response redirect is ignored, never opened.
          redirectUri: Uri.parse('https://untrusted.example/pay'),
        ),
      );
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: Uri.parse('https://store.example'),
        sessionIsCurrent: () => true,
        readOrder: (_) async => paymentOrder298(),
        launch: (uri) async {
          expect(uri.host, 'store.example');
          launches++;
          return true;
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_NoSession.new),
            mobileAnalyticsProvider.overrideWithValue(_NoAnalytics()),
            checkoutPaymentController298Provider.overrideWith(
              (ref, id) => controller,
            ),
          ],
          child: MaterialApp(home: CheckoutScreen(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout-place-order')));
      await tester.pumpAndSettle();
      expect(repository.submitCalls, 1);
      expect(launches, 0);
      expect(find.byKey(const Key('checkout-payment-pending')), findsOneWidget);
      expect(find.byKey(const Key('checkout-success')), findsNothing);
      await tester.tap(find.byKey(const Key('checkout-continue-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout-check-payment')));
      await tester.pumpAndSettle();
      expect(repository.submitCalls, 1);
      expect(launches, 1);
      expect(find.byKey(const Key('checkout-payment-pending')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final ar in [false, true]) {
    testWidgets(
      'explicit continuation and pending return are usable ${ar ? 'Arabic' : 'English'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var order = paymentOrder298();
        var launches = 0;
        var reviews = 0;
        final controller = CheckoutPaymentController298(
          orderId: 730,
          storeUri: Uri.parse('https://store.example'),
          sessionIsCurrent: () => true,
          readOrder: (_) async => order,
          launch: (_) async {
            launches++;
            return true;
          },
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checkoutPaymentController298Provider.overrideWith(
                (ref, id) => controller,
              ),
            ],
            child: MaterialApp(
              locale: Locale(ar ? 'ar' : 'en'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(
                body: CheckoutPaymentContinuation298(
                  orderId: 730,
                  onReviewOrders: () => reviews++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(launches, 0);
        expect(
          find.byKey(const Key('checkout-payment-pending')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('checkout-continue-payment')));
        await tester.pumpAndSettle();
        expect(launches, 1);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('checkout-payment-pending')),
          findsOneWidget,
        );
        order = paymentOrder298(
          status: 'processing',
          paid: true,
          needsPayment: false,
          url: null,
        );
        await tester.tap(find.byKey(const Key('checkout-check-payment')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('checkout-payment-paid')), findsOneWidget);
        expect(
          find.byKey(const Key('checkout-continue-payment')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const Key('checkout-payment-review-orders')),
        );
        expect(reviews, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'a missing payment contract offers retry and orders without claiming success',
    (tester) async {
      final controller = CheckoutPaymentController298(
        orderId: 730,
        storeUri: Uri.parse('https://store.example'),
        sessionIsCurrent: () => true,
        readOrder: (_) async => paymentOrder298(paid: null, needsPayment: null),
        launch: (_) async => throw StateError('must not launch'),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkoutPaymentController298Provider.overrideWith(
              (ref, id) => controller,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CheckoutPaymentContinuation298(
                orderId: 730,
                onReviewOrders: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('checkout-payment-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkout-check-payment')), findsOneWidget);
      expect(
        find.byKey(const Key('checkout-payment-review-orders')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkout-continue-payment')), findsNothing);
      expect(find.byKey(const Key('checkout-success')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _NoSession extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _NoAnalytics extends MobileAnalytics {
  @override
  void trackInBackground(
    String event, {
    int objectId = 0,
    String label = '',
    num value = 0,
    String currency = '',
    int orderId = 0,
    Map<String, Object?> properties = const {},
    String authToken = '',
  }) {}
}

class _OrdersForPayment
    implements CustomerOrdersRepository, CustomerOrderLookupRepository {
  @override
  Future<CustomerOrder> getOrder(int orderId) async => paymentOrder298();
  @override
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  }) async => CustomerOrderPage(
    items: [paymentOrder298()],
    page: 1,
    perPage: 20,
    totalItems: 1,
    totalPages: 1,
  );
}
