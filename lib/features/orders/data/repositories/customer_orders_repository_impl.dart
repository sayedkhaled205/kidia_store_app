import 'package:kidia_store_app/features/orders/data/network/customer_orders_api_transport.dart';
import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:kidia_store_app/features/orders/domain/repositories/customer_orders_repository.dart';

class CustomerOrdersRepositoryImpl
    implements CustomerOrdersRepository, CustomerOrderCancellationRepository {
  const CustomerOrdersRepositoryImpl(this._transport);

  final CustomerOrdersApiTransport _transport;

  @override
  Future<CustomerOrderPage> getOrders({
    required int page,
    required int perPage,
  }) async {
    try {
      final CustomerOrdersApiResponse response = await _transport.fetchOrders(
        page: page,
        perPage: perPage,
      );
      return _parsePage(response.data);
    } on CustomerOrdersTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerOrdersRepositoryException(
          kind: _repositoryKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerOrdersRepositoryException(
          kind: CustomerOrdersFailureKind.invalidResponse,
          message: 'The store returned invalid customer order data.',
          cause: error,
        ),
        stackTrace,
      );
    } on CustomerOrdersRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerOrdersRepositoryException(
          kind: CustomerOrdersFailureKind.unknown,
          message: 'Loading customer orders failed unexpectedly.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CustomerOrder> cancelOrder(int orderId) async {
    final CustomerOrdersApiTransport transport = _transport;
    if (transport is! CustomerOrderCancellationTransport) {
      throw const CustomerOrdersRepositoryException(
        kind: CustomerOrdersFailureKind.configuration,
        message: 'Customer order cancellation is unavailable.',
      );
    }
    try {
      final CustomerOrdersApiResponse response = await transport.cancelOrder(
        orderId,
      );
      final Map<String, dynamic> json = _object(
        response.data,
        'cancel order response',
      );
      return _parseOrder(json['order']);
    } on CustomerOrdersTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerOrdersRepositoryException(
          kind: _repositoryKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerOrdersRepositoryException(
          kind: CustomerOrdersFailureKind.invalidResponse,
          message: 'The store returned invalid customer order data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  CustomerOrderPage _parsePage(dynamic value) {
    final Map<String, dynamic> json = _object(value, 'orders page');
    final List<dynamic> rawOrders = _list(json['orders'], 'orders');
    final List<CustomerOrder> orders = rawOrders
        .map<CustomerOrder>(_parseOrder)
        .toList(growable: false);
    final int safePage = _nonNegativeInt(json['page'], 'page');
    final int safePerPage = _nonNegativeInt(json['per_page'], 'per_page');
    final int totalItems = _nonNegativeInt(json['total'], 'total');
    final int totalPages = _nonNegativeInt(
      json['total_pages'],
      'total_pages',
    );

    return CustomerOrderPage(
      items: List<CustomerOrder>.unmodifiable(orders),
      page: safePage < 1 ? 1 : safePage,
      perPage: safePerPage < 1 ? 20 : safePerPage,
      totalItems: totalItems,
      totalPages: totalPages,
    );
  }

  CustomerOrder _parseOrder(dynamic value) {
    final Map<String, dynamic> json = _object(value, 'order');
    final int id = _positiveInt(json['id'], 'order.id');
    final String number = _requiredText(json['number'], 'order.number');
    final String status = _requiredText(json['status'], 'order.status');
    final String statusName = _text(json['status_name']).trim();
    final String totalDisplay = _text(json['total_display']).trim();
    final String dateSource = _text(json['date_created']).trim();
    final DateTime? dateCreated = dateSource.isEmpty
        ? null
        : DateTime.tryParse(dateSource);
    if (dateSource.isNotEmpty && dateCreated == null) {
      throw const FormatException('order.date_created must be an ISO date.');
    }

    final List<CustomerOrderItem> items = _list(
      json['items'],
      'order.items',
    ).map<CustomerOrderItem>(_parseItem).toList(growable: false);
    final int itemCount = _nonNegativeInt(json['item_count'], 'item_count');
    final String fallbackTotal = <String>[
      _text(json['currency_code']).trim(),
      _text(json['total']).trim(),
    ].where((String part) => part.isNotEmpty).join(' ');

    return CustomerOrder(
      id: id,
      number: number,
      status: status,
      statusName: statusName.isEmpty ? status : statusName,
      totalDisplay: totalDisplay.isEmpty ? fallbackTotal : totalDisplay,
      itemCount: itemCount,
      items: List<CustomerOrderItem>.unmodifiable(items),
      dateCreated: dateCreated,
      canCancel: _boolean(json['can_cancel']),
    );
  }

  CustomerOrderItem _parseItem(dynamic value) {
    final Map<String, dynamic> json = _object(value, 'order item');
    return CustomerOrderItem(
      name: _requiredText(json['name'], 'order item.name'),
      quantity: _positiveInt(json['quantity'], 'order item.quantity'),
    );
  }

  Map<String, dynamic> _object(dynamic value, String field) {
    if (value is! Map) {
      throw FormatException('$field must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  List<dynamic> _list(dynamic value, String field) {
    if (value is! List) {
      throw FormatException('$field must be an array.');
    }
    return List<dynamic>.from(value);
  }

  String _text(dynamic value) => value?.toString() ?? '';

  String _requiredText(dynamic value, String field) {
    final String result = _text(value).trim();
    if (result.isEmpty) {
      throw FormatException('$field must not be empty.');
    }
    return result;
  }

  int _positiveInt(dynamic value, String field) {
    final int parsed = _int(value, field);
    if (parsed < 1) {
      throw FormatException('$field must be positive.');
    }
    return parsed;
  }

  int _nonNegativeInt(dynamic value, String field) {
    final int parsed = _int(value, field);
    if (parsed < 0) {
      throw FormatException('$field must not be negative.');
    }
    return parsed;
  }

  int _int(dynamic value, String field) {
    final int? parsed = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('$field must be an integer.');
    }
    return parsed;
  }

  bool _boolean(dynamic value) {
    if (value is bool) {
      return value;
    }
    return const <String>{'1', 'true', 'yes', 'on'}.contains(
      _text(value).trim().toLowerCase(),
    );
  }

  CustomerOrdersFailureKind _repositoryKind(
    CustomerOrdersTransportFailureKind kind,
  ) {
    return switch (kind) {
      CustomerOrdersTransportFailureKind.configuration =>
        CustomerOrdersFailureKind.configuration,
      CustomerOrdersTransportFailureKind.unauthorized =>
        CustomerOrdersFailureKind.unauthorized,
      CustomerOrdersTransportFailureKind.timeout =>
        CustomerOrdersFailureKind.timeout,
      CustomerOrdersTransportFailureKind.connection =>
        CustomerOrdersFailureKind.connection,
      CustomerOrdersTransportFailureKind.certificate =>
        CustomerOrdersFailureKind.certificate,
      CustomerOrdersTransportFailureKind.server =>
        CustomerOrdersFailureKind.server,
      CustomerOrdersTransportFailureKind.invalidResponse =>
        CustomerOrdersFailureKind.invalidResponse,
      CustomerOrdersTransportFailureKind.unknown =>
        CustomerOrdersFailureKind.unknown,
    };
  }
}
