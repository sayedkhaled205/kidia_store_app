import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';

abstract interface class CustomerOrdersRepository {
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  });
}

abstract interface class CustomerOrderCancellationRepository {
  Future<CustomerOrder> cancelOrder(int orderId);
}

enum CustomerOrdersFailureKind {
  configuration,
  unauthorized,
  timeout,
  connection,
  certificate,
  server,
  invalidResponse,
  unknown,
}

class CustomerOrdersRepositoryException implements Exception {
  const CustomerOrdersRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final CustomerOrdersFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
