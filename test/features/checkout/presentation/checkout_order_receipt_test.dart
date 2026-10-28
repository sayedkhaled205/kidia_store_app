import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/identity/customer_display_email.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_order_receipt.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:mobishop_store_app/features/orders/presentation/customer_orders_screen.dart';

void main() {
  test(
    'only a real email is displayed; authentication identifiers are unchanged',
    () {
      for (final email in [
        null,
        '',
        ' ',
        'guest-201000000000@no-email.invalid',
        'PHONE@NO-EMAIL.INVALID',
        'guest@invalid',
        'not an email',
      ]) {
        expect(customerDisplayEmail(email), isEmpty);
      }
      expect(
        customerDisplayEmail(' customer@gmail.com '),
        'customer@gmail.com',
      );
      expect(
        customerDisplayEmail('shopper@company.example'),
        'shopper@company.example',
      );
    },
  );
  for (final ar in [false, true]) {
    testWidgets(
      'receipt contains owned-order details and actions, narrow large text: $ar',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var shopping = 0;
        var details = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(ar ? 'ar' : 'en'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: CheckoutOrderReceipt(
                    orderId: 73,
                    title: ar ? 'تم استلام طلبك' : 'Order received',
                    onContinueShopping: () => shopping++,
                    onViewDetails: () => details++,
                    order: const CustomerOrder(
                      id: 73,
                      number: 'WEB-73',
                      status: 'processing',
                      statusName: 'Processing',
                      totalDisplay: 'EGP 510',
                      itemCount: 2,
                      paymentMethod: 'cod',
                      paymentMethodTitle: 'Cash on delivery',
                      shippingMethod: 'Standard delivery',
                      items: [
                        CustomerOrderItem(
                          name: 'Cotton kids set / طقم أطفال قطن',
                          quantity: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('WEB-73'), findsOneWidget);
        expect(find.text('EGP 510'), findsOneWidget);
        expect(find.text('Cash on delivery'), findsOneWidget);
        expect(find.text('Standard delivery'), findsOneWidget);
        expect(find.byType(CustomerOrderItemImage), findsOneWidget);
        expect(find.text('× 2'), findsOneWidget);
        expect(find.textContaining('Estimated'), findsNothing);
        final continueButton = find.byKey(
          const Key('receipt-continue-shopping'),
        );
        await tester.ensureVisible(continueButton);
        await tester.tap(continueButton);
        final detailButton = find.byKey(const Key('receipt-view-details'));
        await tester.ensureVisible(detailButton);
        await tester.tap(detailButton);
        expect(shopping, 1);
        expect(details, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'missing details stay retryable without inventing products or totals',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutOrderReceipt(
                orderId: 73,
                title: 'Order received',
                onRetry: () => retries++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('73'), findsOneWidget);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Order items'), findsNothing);
      await tester.tap(find.byKey(const Key('receipt-retry')));
      expect(retries, 1);
    },
  );
}
