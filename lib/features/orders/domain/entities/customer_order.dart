class CustomerOrderItem {
  const CustomerOrderItem({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

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
