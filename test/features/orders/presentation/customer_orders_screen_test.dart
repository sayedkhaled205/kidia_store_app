import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:kidia_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:kidia_store_app/features/orders/presentation/customer_orders_screen.dart';
import 'package:kidia_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

void main() {
  testWidgets('shows the signed-in customer previous orders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerOrdersRepositoryProvider.overrideWithValue(
            const _ScreenOrdersRepository(),
          ),
          cartBadgeCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: CustomerOrdersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طلباتي'), findsOneWidget);
    expect(find.text('طلب #101'), findsOneWidget);
    expect(find.text('قيد التنفيذ'), findsOneWidget);
    expect(find.text('كرسي أطفال'), findsOneWidget);
    expect(find.text('EGP 1,320.00'), findsOneWidget);
    expect(find.byKey(const Key('cancel-customer-order-101')), findsNothing);
    expect(find.text('طلب إلغاء'), findsNothing);
    expect(find.textContaining('الخطوة التالية'), findsNothing);

    await tester.tap(find.byKey(const Key('open-customer-order-101')));
    await tester.pumpAndSettle();

    expect(find.text('تفاصيل الطلب'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-order-details-101')),
      findsOneWidget,
    );
    expect(find.text('منتجات الطلب'), findsOneWidget);
    expect(
      find.byKey(const Key('details-cancel-customer-order-101')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('details-cancel-customer-order-101')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-order')));
    await tester.pumpAndSettle();

    expect(find.text('طلب إلغاء'), findsWidgets);
    expect(
      find.byKey(const Key('details-cancel-customer-order-101')),
      findsNothing,
    );
    expect(
      find.text('تم إرسال طلب الإلغاء للمراجعة.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('order-cancellation-requested-notice')),
      findsOneWidget,
    );
  });

  testWidgets('shows a clean empty state when the customer has no orders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerOrdersRepositoryProvider.overrideWithValue(
            const _EmptyOrdersRepository(),
          ),
          cartBadgeCountProvider.overrideWithValue(0),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: CustomerOrdersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا توجد طلبات حتى الآن'), findsOneWidget);
    expect(find.text('تعذر تحميل طلباتك'), findsNothing);
  });
}

class _ScreenOrdersRepository
    implements CustomerOrdersRepository, CustomerOrderCancellationRepository {
  const _ScreenOrdersRepository();

  @override
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  }) async {
    return CustomerOrderPage(
      items: <CustomerOrder>[
        CustomerOrder(
          id: 101,
          number: '101',
          status: 'processing',
          statusName: 'قيد التنفيذ',
          totalDisplay: 'EGP 1,320.00',
          itemCount: 1,
          items: const <CustomerOrderItem>[
            CustomerOrderItem(name: 'كرسي أطفال', quantity: 1),
          ],
          dateCreated: DateTime.parse('2026-07-16T20:30:00+03:00'),
          canCancel: true,
          cancellationType: CustomerOrderCancellationType.request,
        ),
      ],
      page: 1,
      perPage: perPage,
      totalItems: 1,
      totalPages: 1,
    );
  }

  @override
  Future<CustomerOrder> cancelOrder(int orderId) async {
    return const CustomerOrder(
      id: 101,
      number: '101',
      status: 'cancel-request',
      statusName: 'Cancellation requested',
      totalDisplay: 'EGP 1,320.00',
      itemCount: 1,
      items: <CustomerOrderItem>[
        CustomerOrderItem(name: 'كرسي أطفال', quantity: 1),
      ],
    );
  }
}

class _EmptyOrdersRepository implements CustomerOrdersRepository {
  const _EmptyOrdersRepository();

  @override
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  }) async {
    return CustomerOrderPage(
      items: const <CustomerOrder>[],
      page: 1,
      perPage: perPage,
      totalItems: 0,
      totalPages: 0,
    );
  }
}
