import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/saved_checkout_address92.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_presentation.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';

import '../support/checkout_test_data.dart';

void main() {
  testWidgets('double confirmation during address sync reports one order once', (tester) async {
    _useTallSurface(tester);
    final sync = Completer<void>();
    var reports = 0;
    final repo = FakeCheckoutRepository(onUpdateCustomer: (_, _) async {
      await sync.future;
      return checkoutCart();
    });
    await tester.pumpWidget(_testApp(CheckoutScreen(repository: repo, onOrderSuccess: (_) => reports++)));
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(find.byKey(const Key('checkout-place-order'))).onPressed!;
    confirm();
    confirm();
    await tester.pump();
    sync.complete();
    await tester.pumpAndSettle();
    expect(repo.submitCalls, 1);
    expect(reports, 1);
  });
  testWidgets('choose either saved address or start a new address', (tester) async {
    _useTallSurface(tester);
    final repo = FakeCheckoutRepository(state: CheckoutState(cart: checkoutCart(), savedAddresses: [
      const SavedCheckoutAddress92(id:'home',label:'Home',values:{'first_name':'Ada','last_name':'Test','phone':'5550100','country':'US','state':'CA','city':'First city','address_1':'First street','address_2':'Suite 4'}),
      const SavedCheckoutAddress92(id:'work',label:'Work',values:{'first_name':'Ada','last_name':'Test','phone':'5550101','country':'US','state':'CA','city':'Second city','address_1':'Second street'}),
    ]));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4EA999),
      ).copyWith(primary: const Color(0xFF4EA999), surface: Colors.white)),
      home: CheckoutScreen(repository: repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout-address-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-billing-address1')), findsNothing);
    expect(find.byKey(const Key('checkout-address-selected-home')), findsOneWidget);
    // Read rendered colors, including inherited text styles. Brand-colored
    // button text on a brand-colored address card was difficult to read.
    for (final id in ['home', 'work']) {
      final card = find.byKey(Key('checkout-address-$id'));
      final material = tester.widget<Material>(find.descendant(
        of: card, matching: find.byType(Material),
      ).first);
      final label = find.descendant(of: card, matching: find.byType(Text)).first;
      final foreground = DefaultTextStyle.of(tester.element(label)).style.color!;
      final background = material.color!;
      expect(background.computeLuminance(), greaterThan(0.85));
      expect(foreground.computeLuminance(), lessThan(0.04));
      expect((background.computeLuminance() + 0.05) /
          (foreground.computeLuminance() + 0.05), greaterThanOrEqualTo(7));
    }
    expect(find.byKey(const Key('checkout-customer-note')), findsOneWidget);
    expect(find.byKey(const Key('checkout-different-shipping-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout-edit-address')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField,'First street'), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout-address-work')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-billing-address1')), findsNothing);
    expect(find.byKey(const Key('checkout-address-selected-home')), findsNothing);
    expect(find.byKey(const Key('checkout-address-selected-work')), findsOneWidget);
    expect(find.widgetWithText(TextFormField,'First street'), findsNothing);
    await tester.tap(find.byKey(const Key('checkout-new-address')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField,'Second street'), findsNothing);
    expect(find.byKey(const Key('checkout-billing-address1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic checkout headings follow app locale, including saved addresses', (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: CheckoutScreen(repository: FakeCheckoutRepository(state: CheckoutState(
        cart: checkoutCart(), savedAddresses: const [SavedCheckoutAddress92(
          id: 'incomplete', label: 'Test', values: {'address_1': 'Test street'},
        )],
      ))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('إتمام الطلب'), findsOneWidget);
    expect(find.text('عناوينك المحفوظة'), findsOneWidget);
    expect(find.text('عنوان جديد'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
    expect(find.text('Billing address'), findsNothing);
    await tester.tap(find.byKey(const Key('checkout-address-incomplete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-billing-address1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('complete saved address submits without repeated billing fields', (tester) async {
    _useTallSurface(tester);
    final repo = FakeCheckoutRepository(state: CheckoutState(cart: checkoutCart(), savedAddresses: const [
      SavedCheckoutAddress92(id: 'one', label: 'One', values: {
        'first_name':'Ada','last_name':'Test','phone':'5550100', 'country':'US',
        'state':'CA','city':'Test city','address_1':'Test street',
      }),
    ]));
    await tester.pumpWidget(_testApp(CheckoutScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout-address-one')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkout-billing-firstName')), findsNothing);
    await tester.tap(find.byKey(const Key('checkout-place-order')));
    await tester.pumpAndSettle();
    expect(repo.submissions, hasLength(1));
    expect(repo.submissions.single.billingAddress.address1, 'Test street');
    expect(repo.submissions.single.shippingAddress.address1, 'Test street');
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders standard address, payment, and summary data', (
    WidgetTester tester,
  ) async {
    _useTallSurface(tester);
    await tester.pumpWidget(
      _testApp(CheckoutScreen(repository: FakeCheckoutRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('checkout-billing-firstName')), findsOneWidget);
    expect(find.byKey(const Key('checkout-billing-email')), findsNothing);
    expect(find.byKey(const Key('checkout-billing-phone')), findsOneWidget);
    expect(find.byKey(const Key('checkout-billing-postcode')), findsNothing);
    expect(find.text('Phone *'), findsOneWidget);
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
                CheckoutFieldDefinition(
                  key: 'billing_postcode',
                  group: CheckoutFieldGroup.billing,
                  type: CheckoutFieldType.hidden,
                  label: 'Postcode',
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
    expect(
      find.byKey(const Key('checkout-dynamic-billing_postcode')),
      findsNothing,
    );
    expect(find.text('Postcode'), findsNothing);
  });

  testWidgets(
    'hides Egypt country and renders governorate as a WooCommerce dropdown',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _testApp(
          CheckoutScreen(
            repository: FakeCheckoutRepository(
              state: CheckoutState(
                cart: checkoutCart(),
                fieldDefinitions: <CheckoutFieldDefinition>[
                  CheckoutFieldDefinition(
                    key: 'billing_country',
                    group: CheckoutFieldGroup.billing,
                    type: CheckoutFieldType.hidden,
                    label: 'الدولة / المنطقة',
                    defaultValue: 'EG',
                  ),
                  CheckoutFieldDefinition(
                    key: 'billing_state',
                    group: CheckoutFieldGroup.billing,
                    type: CheckoutFieldType.select,
                    label: 'المحافظة',
                    required: true,
                    options: const <String, String>{
                      'EGC': 'القاهرة',
                      'EGGZ': 'الجيزة',
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('checkout-dynamic-billing_country')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('checkout-dynamic-billing_state')),
        findsOneWidget,
      );
      expect(find.text('المحافظة *'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checkout-dynamic-billing_state')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الجيزة').last);
      await tester.pumpAndSettle();
      expect(find.text('الجيزة'), findsOneWidget);
    },
  );

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
    expect(find.byKey(const Key('checkout-shipping-postcode')), findsNothing);
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

  for (final CheckoutDesign design in CheckoutDesign.values) {
    testWidgets('renders the ${design.apiValue} checkout design', (
      WidgetTester tester,
    ) async {
      _useTallSurface(tester);
      await tester.pumpWidget(
        _testApp(
          CheckoutScreen(
            repository: FakeCheckoutRepository(),
            design: design,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('checkout-design-${design.apiValue}')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkout-place-order')), findsOneWidget);
    });
  }

  testWidgets('mobile checkout keeps scrolling on a short viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _testApp(CheckoutScreen(repository: FakeCheckoutRepository())),
    );
    await tester.pumpAndSettle();

    final Finder scrollFinder = find.byKey(const Key('checkout-form-scroll'));
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: scrollFinder,
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(scrollFinder, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
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
