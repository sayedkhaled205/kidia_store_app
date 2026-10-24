import 'dart:async';
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
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';
import 'package:mobishop_store_app/features/checkout/presentation/providers/checkout_inline_payment95.dart';
import 'package:mobishop_store_app/features/checkout/presentation/providers/checkout_payment_provider298.dart';
import '../support/checkout_test_data.dart';
import '../application/checkout_payment_controller298_test.dart'
    show paymentOrder298;

void main() {
  for (final ar in [false, true]) {
    testWidgets(
      'inline fields precede submission and missing card creates no order ($ar)',
      (tester) async {
        final repo = repository();
        await mount(tester, repo, arabic: ar);
        await tester.tap(
          find.byKey(const Key('checkout-payment-kashier_card')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('inline-card-number')), findsOneWidget);
        expect(find.byKey(const Key('inline-card-expiry')), findsOneWidget);
        expect(find.byKey(const Key('inline-card-cvv')), findsOneWidget);
        expect(find.byKey(const Key('inline-card-name')), findsOneWidget);
        expect(repo.submitCalls, 0);
        await tester.tap(find.byKey(const Key('checkout-place-order')));
        await tester.pumpAndSettle();
        expect(repo.submitCalls, 0);
        expect(find.byKey(const Key('checkout-success')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'one button preserves card fields while preparing, pays once, confirms only after server',
    (tester) async {
      final pendingOrder = Completer<CheckoutOrderResult>();
      final paid = Completer<bool>();
      final analytics = _Analytics();
      final repo = repository()..onSubmit = (_) => pendingOrder.future;
      var paymentCalls = 0;
      bool? cardStillValid;
      Object? received;
      await mount(
        tester,
        repo,
        analytics: analytics,
        pay:
            ({
              required orderId,
              required card,
              required amount,
              required currency,
              required arabic,
            }) {
              paymentCalls++;
              received = (orderId, amount, currency);
              cardStillValid = card.validate();
              return paid.future;
            },
      );
      await fillCard(tester);
      final place = find.byKey(const Key('checkout-place-order'));
      final onPressed = tester.widget<FilledButton>(place).onPressed!;
      onPressed();
      onPressed();
      await tester.pump();
      expect(repo.submitCalls, 1);
      expect(paymentCalls, 0);
      expect(
        find.byKey(const Key('checkout-completing-payment')),
        findsOneWidget,
      );
      pendingOrder.complete(pendingResult);
      await tester.pump();
      await tester.pump();
      expect(paymentCalls, 1);
      expect(received, (730, '125.00', 'USD'));
      expect(
        cardStillValid,
        true,
        reason: 'SDK form must survive submitting -> order response',
      );
      expect(find.byKey(const Key('checkout-continue-payment')), findsNothing);
      expect(find.byKey(const Key('checkout-success')), findsNothing);
      expect(analytics.events, isNot(contains('purchase')));
      expect(
        repo.submissions.single.customFields.values,
        isNot(contains('4111111111111111')),
      );
      paid.complete(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-success')), findsOneWidget);
      expect(repo.submitCalls, 1);
      expect(paymentCalls, 1);
      expect(analytics.events.where((v) => v == 'purchase'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching to COD removes card details and preserves offline order flow',
    (tester) async {
      final repo = repository()..onSubmit = (_) async => checkoutOrderResult;
      var paymentCalls = 0;
      await mount(
        tester,
        repo,
        pay:
            ({
              required orderId,
              required card,
              required amount,
              required currency,
              required arabic,
            }) async {
              paymentCalls++;
              return true;
            },
      );
      await fillCard(tester);
      await tester.tap(find.byKey(const Key('checkout-payment-cod')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inline-card-number')), findsNothing);
      await tester.tap(find.byKey(const Key('checkout-payment-kashier_card')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('inline-card-number')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('checkout-payment-cod')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout-place-order')));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(repo.submissions.single.paymentMethodId, 'cod');
      expect(paymentCalls, 0);
      expect(find.byKey(const Key('checkout-success')), findsOneWidget);
    },
  );

  testWidgets(
    'cancelled or unsettled card retains exact order without success or automatic retry',
    (tester) async {
      final repo = repository();
      final analytics = _Analytics();
      final recovery = CheckoutPaymentController298(
        orderId: 730,
        storeUri: Uri.parse('https://store.example'),
        sessionIsCurrent: () => true,
        readOrder: (_) async => paymentOrder298(),
        launch: (_) async => throw StateError('Must not automatically retry'),
      );
      addTearDown(recovery.dispose);
      var paymentCalls = 0;
      await mount(
        tester,
        repo,
        analytics: analytics,
        recovery: recovery,
        pay:
            ({
              required orderId,
              required card,
              required amount,
              required currency,
              required arabic,
            }) async {
              paymentCalls++;
              return false;
            },
      );
      await fillCard(tester);
      await tester.tap(find.byKey(const Key('checkout-place-order')));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(paymentCalls, 1);
      expect(find.byKey(const Key('checkout-payment-pending')), findsOneWidget);
      expect(find.byKey(const Key('checkout-success')), findsNothing);
      expect(analytics.events, isNot(contains('purchase')));
      await tester.pumpWidget(const SizedBox());
    },
  );
}

const pendingResult = CheckoutOrderResult(
  orderId: 730,
  status: 'pending',
  paymentStatus: 'pending',
);
FakeCheckoutRepository repository() => FakeCheckoutRepository(
  state: CheckoutState(
    cart: checkoutCart(paymentMethods: ['cod', 'kashier_card']),
    nativePaymentAdapters: const {'kashier_card': 'kashier'},
  ),
  onSubmit: (_) async => pendingResult,
);

Future<void> fillCard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('checkout-payment-kashier_card')));
  await tester.pumpAndSettle();
  // Public dummy card values; all payment traffic in these tests is mocked.
  for (final entry in {
    'number': '4111111111111111',
    'expiry': '12/39',
    'cvv': '123',
    'name': 'Test Customer',
  }.entries) {
    await tester.enterText(
      find.byKey(Key('inline-card-${entry.key}')),
      entry.value,
    );
  }
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  FakeCheckoutRepository repo, {
  bool arabic = false,
  CheckoutInlinePayment95? pay,
  CheckoutPaymentController298? recovery,
  MobileAnalytics? analytics,
}) async {
  tester.view.physicalSize = const Size(700, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_NoSession.new),
        mobileAnalyticsProvider.overrideWithValue(analytics ?? _Analytics()),
        checkoutInlinePayment95Provider.overrideWithValue(
          pay ??
              ({
                required orderId,
                required card,
                required amount,
                required currency,
                required arabic,
              }) async => throw StateError('Unexpected payment'),
        ),
        if (recovery != null)
          checkoutPaymentController298Provider.overrideWith(
            (ref, id) => recovery,
          ),
      ],
      child: MaterialApp(
        locale: Locale(arabic ? 'ar' : 'en'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: CheckoutScreen(repository: repo),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoSession extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _Analytics extends MobileAnalytics {
  final events = <String>[];
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
  }) => events.add(event);
}
