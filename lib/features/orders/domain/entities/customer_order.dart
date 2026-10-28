class CustomerOrderItem {
  const CustomerOrderItem({
    required this.name,
    required this.quantity,
    this.imageUrl = '',
  });

  final String name;
  final int quantity;
  final String imageUrl;
}

enum CustomerOrderCancellationType { none, cancel, request }

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.statusName,
    required this.totalDisplay,
    required this.itemCount,
    required this.items,
    this.dateCreated,
    this.canCancel = false,
    this.cancellationType = CustomerOrderCancellationType.none,
    this.isPaid,
    this.needsPayment,
    this.paymentUri,
    this.paymentMethod = '',
    this.paymentMethodTitle = '',
    this.shippingMethod = '',
    this.paymentEndpointPath = '',
  });

  final int id;
  final String number;
  final String status;
  final String statusName;
  final String totalDisplay;
  final int itemCount;
  final List<CustomerOrderItem> items;
  final DateTime? dateCreated;
  final bool canCancel;
  final CustomerOrderCancellationType cancellationType;

  /// Null means the connector did not provide verified payment facts.
  final bool? isPaid;
  final bool? needsPayment;
  final Uri? paymentUri;
  final String paymentMethod;
  final String paymentMethodTitle;
  final String shippingMethod;
  final String paymentEndpointPath;

  bool get isCancellationRequest =>
      cancellationType == CustomerOrderCancellationType.request;
}

class CustomerOrderPage {
  const CustomerOrderPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  final List<CustomerOrder> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
}
