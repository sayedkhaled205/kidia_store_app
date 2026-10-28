import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:mobishop_store_app/features/orders/presentation/customer_orders_screen.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

void main() {
  testWidgets('order thumbnails use the item image with a stable fallback', (tester) async {
    for (final url in ['', 'https://store.example/item.jpg']) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: CustomerOrderItemImage(item:CustomerOrderItem(name:'Product',quantity:1,imageUrl:url)))));
      await tester.pumpAndSettle();
      expect(tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).imageUrl,url);
      expect(tester.getSize(find.byType(CustomerOrderItemImage)),const Size(56,56));
      expect(find.byIcon(Icons.checkroom_outlined),findsNothing);
      expect(tester.takeException(),isNull);
    }
  });

  testWidgets('notification opens exact order outside the loaded history page', (tester) async {
    final repository = _LookupOrdersRepository();
    await tester.pumpWidget(ProviderScope(overrides:[customerOrdersRepositoryProvider.overrideWithValue(repository),cartBadgeCountProvider.overrideWithValue(0)],child:const MaterialApp(locale:Locale('ar'),supportedLocales:[Locale('ar')],localizationsDelegates:GlobalMaterialLocalizations.delegates,home:CustomerOrdersScreen(initialOrderId:321))));
    await tester.pumpAndSettle();
    expect(repository.requestedId,321);
    expect(find.byKey(const Key('customer-order-details-321')),findsOneWidget);
    expect(find.text('طلب #321'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });

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

class _LookupOrdersRepository extends _EmptyOrdersRepository implements CustomerOrderLookupRepository {
  int? requestedId;
  @override Future<CustomerOrder> getOrder(int id) async {
    requestedId=id;
    return CustomerOrder(id:id,number:'$id',status:'completed',statusName:'Completed',totalDisplay:'EGP 10',itemCount:0,items:const []);
  }
}
