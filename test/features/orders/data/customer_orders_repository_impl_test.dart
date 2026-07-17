import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/orders/data/network/customer_orders_api_transport.dart';
import 'package:kidia_store_app/features/orders/data/repositories/customer_orders_repository_impl.dart';
import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';

void main() {
  test('parses WooCommerce order history without losing order data', () async {
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
  });
}

class _FakeOrdersTransport implements CustomerOrdersApiTransport {
  const _FakeOrdersTransport(this.data);

  final dynamic data;

  @override
  Future<CustomerOrdersApiResponse> fetchOrders({
    required int page,
    required int perPage,
  }) async {
    return CustomerOrdersApiResponse(data: data, statusCode: 200);
  }
}
