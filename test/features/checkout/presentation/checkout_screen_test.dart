import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/presentation/checkout_screen.dart';

import '../support/checkout_test_data.dart';

void main() {
  testWidgets('renders standard address, payment, and summary data', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(CheckoutScreen(repository: FakeCheckoutRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-billing-firstName')), findsOneWidget);
    expect(find.byKey(const Key('checkout-billing-email')), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Cash on delivery'), findsOneWidget);
    expect(find.text(r'$125.00'), findsOneWidget);
    expect(
      find.byKey(const Key('checkout-gateway-disclaimer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('checkout-place-order')), findsOneWidget);
  });

  testWidgets('renders checkout fields supplied by the WordPress plugin', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(
        CheckoutScreen(
          repository: FakeCheckoutRepository(
            state: CheckoutState(
              cart: checkoutCart(),
              fieldDefinitions: <CheckoutFieldDefinition>[
                CheckoutFieldDefinition(
                  key: 'billing_vat_number',
                  group: CheckoutFieldGroup.billing,
                  type: CheckoutFieldType.text,
                  label: 'VAT number',
                  required: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('checkout-dynamic-billing_vat_number')),
      findsOneWidget,
    );
    expect(find.text('VAT number *'), findsOneWidget);
  });

  testWidgets('validates payment selection using Store API method ids', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(
        CheckoutScreen(
          repository: FakeCheckoutRepository(
            state: CheckoutState(
              cart: checkoutCart(paymentMethods: <String>['cod', 'bacs']),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkout-place-order')));
    await tester.pump();
    expect(find.byKey(const Key('checkout-payment-error')), findsOneWidget);
    expect(find.text('Choose a payment method.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('checkout-payment-bacs')));
    await tester.pump();
    expect(find.byKey(const Key('checkout-payment-error')), findsNothing);
  });

  testWidgets('shows a separate shipping form only when requested', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(CheckoutScreen(repository: FakeCheckoutRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-shipping-firstName')), findsNothing);
    await tester.tap(
      find.byKey(const Key('checkout-different-shipping-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('checkout-shipping-firstName')),
      findsOneWidget,
    );
  });

  testWidgets('places one order and reports success to the host app', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    CheckoutOrderResult? reported;
    final FakeCheckoutRepository repository = FakeCheckoutRepository();
    await tester.pumpWidget(
      _testApp(
        CheckoutScreen(
          repository: repository,
          onOrderSuccess: (CheckoutOrderResult result) => reported = result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkout-place-order')));
    await tester.pumpAndSettle();

    expect(repository.submitCalls, 1);
    expect(reported?.orderId, 730);
    expect(find.byKey(const Key('checkout-success')), findsOneWidget);
    expect(find.text('Order number: 730'), findsOneWidget);
  });

  testWidgets('shows a retryable load failure', (WidgetTester tester) async {
    final FakeCheckoutRepository repository = FakeCheckoutRepository(
      onLoad: () async => throw StateError('offline'),
    );
    await tester.pumpWidget(_testApp(CheckoutScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-load-error')), findsOneWidget);
    repository.onLoad = null;
    await tester.tap(find.byKey(const Key('checkout-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-billing-firstName')), findsOneWidget);
  });

  testWidgets('keeps the wide checkout layout usable in RTL', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: CheckoutScreen(repository: FakeCheckoutRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext formContext = tester.element(
      find.byKey(const Key('checkout-form-scroll')).first,
    );
    expect(Directionality.of(formContext), TextDirection.rtl);
    expect(find.byKey(const Key('checkout-place-order')), findsOneWidget);
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(theme: ThemeData(useMaterial3: true), home: home);
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
