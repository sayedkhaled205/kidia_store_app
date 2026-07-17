import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:kidia_store_app/features/orders/domain/repositories/customer_orders_repository.dart';
import 'package:kidia_store_app/features/orders/presentation/controllers/customer_orders_controller.dart';

void main() {
  test('loads and appends unique customer orders', () async {
    final _FakeCustomerOrdersRepository repository =
        _FakeCustomerOrdersRepository();
    final CustomerOrdersController controller = CustomerOrdersController(
      repository,
      pageSize: 2,
    );

    await controller.loadInitial();
    expect(controller.state.items.map((CustomerOrder order) => order.id), <int>[
      2,
      1,
    ]);
    expect(controller.state.hasNextPage, isTrue);

    await controller.loadMore();
    expect(controller.state.items.map((CustomerOrder order) => order.id), <int>[
      2,
      1,
      3,
    ]);
    controller.dispose();
  });

  test('replaces a cancellable order with the server result', () async {
    final _CancellableOrdersRepository repository =
        _CancellableOrdersRepository();
    final CustomerOrdersController controller = CustomerOrdersController(
      repository,
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    final CustomerOrder order = controller.state.items.single;
    expect(order.canCancel, isTrue);

    expect(await controller.cancelOrder(order), isTrue);
    expect(repository.cancelledOrderId, 9);
    expect(controller.state.items.single.status, 'cancelled');
    expect(controller.state.items.single.canCancel, isFalse);
    expect(controller.state.cancellingOrderIds, isEmpty);
  });
}

class _FakeCustomerOrdersRepository implements CustomerOrdersRepository {
  @override
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  }) async {
    return CustomerOrderPage(
      items: page == 1
          ? const <CustomerOrder>[
              CustomerOrder(
                id: 2,
                number: '2',
                status: 'processing',
                statusName: 'Processing',
                totalDisplay: 'EGP 20',
                itemCount: 1,
                items: <CustomerOrderItem>[],
              ),
              CustomerOrder(
                id: 1,
                number: '1',
                status: 'completed',
                statusName: 'Completed',
                totalDisplay: 'EGP 10',
                itemCount: 1,
                items: <CustomerOrderItem>[],
              ),
            ]
          : const <CustomerOrder>[
              CustomerOrder(
                id: 1,
                number: '1',
                status: 'completed',
                statusName: 'Completed',
                totalDisplay: 'EGP 10',
                itemCount: 1,
                items: <CustomerOrderItem>[],
              ),
              CustomerOrder(
                id: 3,
                number: '3',
                status: 'pending',
                statusName: 'Pending',
                totalDisplay: 'EGP 30',
                itemCount: 1,
                items: <CustomerOrderItem>[],
              ),
            ],
      page: page,
      perPage: perPage,
      totalItems: 3,
      totalPages: 2,
    );
  }
}

class _CancellableOrdersRepository
    implements CustomerOrdersRepository, CustomerOrderCancellationRepository {
  int? cancelledOrderId;

  @override
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  }) async {
    return CustomerOrderPage(
      items: const <CustomerOrder>[
        CustomerOrder(
          id: 9,
          number: '9',
          status: 'processing',
          statusName: 'Processing',
          totalDisplay: 'EGP 90',
          itemCount: 1,
          items: <CustomerOrderItem>[],
          canCancel: true,
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
    cancelledOrderId = orderId;
    return const CustomerOrder(
      id: 9,
      number: '9',
      status: 'cancelled',
      statusName: 'Cancelled',
      totalDisplay: 'EGP 90',
      itemCount: 1,
      items: <CustomerOrderItem>[],
    );
  }
}
