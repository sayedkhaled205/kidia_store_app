import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/orders/data/network/customer_orders_api_transport.dart';
import 'package:mobishop_store_app/features/orders/data/repositories/customer_orders_repository_impl.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';

void main() {
  test('optional images keep legacy orders readable and reject invalid URLs', () async {
    for (final value in [null, '', 'https://cdn.example/variation.png', 'http://store.example/parent.jpg', 'javascript:bad', 'https://secret@example.com/a', {}, '/relative.jpg']) {
      final repository=CustomerOrdersRepositoryImpl(_FakeOrdersTransport({
        'orders':[{'id':1,'number':'1','status':'completed','item_count':1,
          'items':[{'name':'Product','quantity':1,'image_url':value}]}],
        'page':1,'per_page':20,'total':1,'total_pages':1,
      }));
      final result=await repository.getOrders(page:1,perPage:20);
      expect(result.items.single.items.single.imageUrl,
        value=='https://cdn.example/variation.png'||value=='http://store.example/parent.jpg'?value:'');
    }
  });

  for (final type in <String>['cancel', 'request']) {
    test('preserves the server-authorized $type action', () async {
      final repository = CustomerOrdersRepositoryImpl(_FakeOrdersTransport({
        'orders': [{'id': 102, 'number': '102', 'status': 'processing',
          'status_name': 'Processing', 'total_display': 'EGP 10.00', 'can_cancel': true,
          'cancellation_type': type, 'item_count': 0, 'items': <dynamic>[]}],
        'page': 1, 'per_page': 20, 'total': 1, 'total_pages': 1,
      }));
      final page = await repository.getOrders(page: 1, perPage: 20);
      expect(page.items.single.canCancel, isTrue);
      expect(page.items.single.cancellationType, type == 'request'
          ? CustomerOrderCancellationType.request : CustomerOrderCancellationType.cancel);
    });
  }
  test(
    'does not invent cancellation permission from processing status',
    () async {
      final CustomerOrdersRepositoryImpl repository =
          CustomerOrdersRepositoryImpl(
            _FakeOrdersTransport(
              <String, dynamic>{
                'orders': <dynamic>[
                  <String, dynamic>{
                    'id': 101,
                    'number': '101',
                    'status': 'processing',
                    'status_name': 'قيد التنفيذ',
                    'date_created': '2026-07-16T20:30:00+03:00',
                    'total': '1320.00',
                    'total_display': 'EGP 1,320.00',
                    'currency_code': 'EGP',
                    'item_count': 3,
                    'can_cancel': false,
                    'items': <dynamic>[
                      <String, dynamic>{'name': 'كرسي أطفال', 'quantity': 1},
                      <String, dynamic>{'name': 'لعبة', 'quantity': 2},
                    ],
                  },
                ],
                'page': 1,
                'per_page': 20,
                'total': 1,
                'total_pages': 1,
              },
            ),
          );

      final CustomerOrderPage page = await repository.getOrders(
        page: 1,
        perPage: 20,
      );

      expect(page.totalItems, 1);
      expect(page.items.single.id, 101);
      expect(page.items.single.statusName, 'قيد التنفيذ');
      expect(page.items.single.totalDisplay, 'EGP 1,320.00');
      expect(page.items.single.items.last.quantity, 2);
      expect(page.items.single.canCancel, isFalse);
      expect(
        page.items.single.cancellationType,
        CustomerOrderCancellationType.none,
      );
    },
  );

  test('returns the authoritative cancelled order from WooCommerce', () async {
    final CustomerOrdersRepositoryImpl repository =
        CustomerOrdersRepositoryImpl(
          _FakeOrdersTransport(
            <String, dynamic>{
              'orders': <dynamic>[],
              'page': 1,
              'per_page': 20,
              'total': 0,
              'total_pages': 0,
            },
            cancelledData: <String, dynamic>{
              'order': <String, dynamic>{
                'id': 101,
                'number': '101',
                'status': 'cancelled',
                'status_name': 'Cancelled',
                'total_display': 'EGP 1,320.00',
                'item_count': 0,
                'items': <dynamic>[],
                'can_cancel': false,
              },
            },
          ),
        );

    final CustomerOrder order = await repository.cancelOrder(101);

    expect(order.status, 'cancelled');
    expect(order.canCancel, isFalse);
  });
}

class _FakeOrdersTransport
    implements CustomerOrdersApiTransport, CustomerOrderCancellationTransport {
  const _FakeOrdersTransport(this.data, {this.cancelledData});

  final dynamic data;
  final dynamic cancelledData;

  @override
  Future<CustomerOrdersApiResponse> fetchOrders({
    required int page,
    required int perPage,
  }) async {
    return CustomerOrdersApiResponse(data: data, statusCode: 200);
  }

  @override
  Future<CustomerOrdersApiResponse> cancelOrder(int orderId) async {
    return CustomerOrdersApiResponse(
      data: cancelledData,
      statusCode: 200,
    );
  }
}
