import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:kidia_store_app/features/orders/domain/repositories/customer_orders_repository.dart';

class CustomerOrdersState {
  const CustomerOrdersState({
    this.items = const <CustomerOrder>[],
    this.page = 0,
    this.totalItems = 0,
    this.totalPages = 0,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.cancellingOrderIds = const <int>{},
    this.error,
    this.loadMoreError,
    this.mutationError,
  });

  final List<CustomerOrder> items;
  final int page;
  final int totalItems;
  final int totalPages;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Set<int> cancellingOrderIds;
  final Object? error;
  final Object? loadMoreError;
  final Object? mutationError;

  bool get hasNextPage => page < totalPages;

  CustomerOrdersState copyWith({
    List<CustomerOrder>? items,
    int? page,
    int? totalItems,
    int? totalPages,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Set<int>? cancellingOrderIds,
    Object? error = _notProvided,
    Object? loadMoreError = _notProvided,
    Object? mutationError = _notProvided,
  }) {
    return CustomerOrdersState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      cancellingOrderIds: cancellingOrderIds ?? this.cancellingOrderIds,
      error: identical(error, _notProvided) ? this.error : error,
      loadMoreError: identical(loadMoreError, _notProvided)
          ? this.loadMoreError
          : loadMoreError,
      mutationError: identical(mutationError, _notProvided)
          ? this.mutationError
          : mutationError,
    );
  }
}

const Object _notProvided = Object();

class CustomerOrdersController extends ChangeNotifier {
  CustomerOrdersController(this._repository, {this.pageSize = 20});

  final CustomerOrdersRepository _repository;
  final int pageSize;
  CustomerOrdersState _state = const CustomerOrdersState();
  int _operation = 0;
  bool _disposed = false;

  CustomerOrdersState get state => _state;

  Future<void> loadInitial({bool refresh = false}) async {
    final int operation = ++_operation;
    _replace(
      _state.copyWith(
        isInitialLoading: !refresh || _state.items.isEmpty,
        isRefreshing: refresh && _state.items.isNotEmpty,
        isLoadingMore: false,
        error: null,
        loadMoreError: null,
      ),
    );
    try {
      final CustomerOrderPage result = await _repository.getOrders(
        page: 1,
        perPage: pageSize,
      );
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          items: List<CustomerOrder>.unmodifiable(result.items),
          page: result.page,
          totalItems: result.totalItems,
          totalPages: result.totalPages,
          isInitialLoading: false,
          isRefreshing: false,
          error: null,
        ),
      );
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          items: refresh ? _state.items : const <CustomerOrder>[],
          isInitialLoading: false,
          isRefreshing: false,
          error: error,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (_state.isInitialLoading ||
        _state.isRefreshing ||
        _state.isLoadingMore ||
        !_state.hasNextPage) {
      return;
    }
    final int operation = _operation;
    _replace(_state.copyWith(isLoadingMore: true, loadMoreError: null));
    try {
      final CustomerOrderPage result = await _repository.getOrders(
        page: _state.page + 1,
        perPage: pageSize,
      );
      if (!_isCurrent(operation)) {
        return;
      }
      final Map<int, CustomerOrder> unique = <int, CustomerOrder>{
        for (final CustomerOrder order in _state.items) order.id: order,
        for (final CustomerOrder order in result.items) order.id: order,
      };
      _replace(
        _state.copyWith(
          items: List<CustomerOrder>.unmodifiable(unique.values),
          page: result.page,
          totalItems: result.totalItems,
          totalPages: result.totalPages,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
    } catch (error) {
      if (_isCurrent(operation)) {
        _replace(
          _state.copyWith(isLoadingMore: false, loadMoreError: error),
        );
      }
    }
  }

  bool isCancelling(int orderId) => _state.cancellingOrderIds.contains(orderId);

  Future<bool> cancelOrder(CustomerOrder order) async {
    if (!order.canCancel || isCancelling(order.id)) {
      return false;
    }
    final CustomerOrdersRepository repository = _repository;
    if (repository is! CustomerOrderCancellationRepository) {
      _replace(
        _state.copyWith(
          mutationError: const CustomerOrdersRepositoryException(
            kind: CustomerOrdersFailureKind.configuration,
            message: 'Customer order cancellation is unavailable.',
          ),
        ),
      );
      return false;
    }

    _replace(
      _state.copyWith(
        cancellingOrderIds: Set<int>.unmodifiable(<int>{
          ..._state.cancellingOrderIds,
          order.id,
        }),
        mutationError: null,
      ),
    );
    try {
      final CustomerOrder updated = await repository.cancelOrder(order.id);
      _replace(
        _state.copyWith(
          items: List<CustomerOrder>.unmodifiable(<CustomerOrder>[
            for (final CustomerOrder item in _state.items)
              if (item.id == updated.id) updated else item,
          ]),
          mutationError: null,
        ),
      );
      return true;
    } catch (error) {
      _replace(_state.copyWith(mutationError: error));
      return false;
    } finally {
      _replace(
        _state.copyWith(
          cancellingOrderIds: Set<int>.unmodifiable(
            _state.cancellingOrderIds.where((int id) => id != order.id),
          ),
        ),
      );
    }
  }

  void clearMutationError() {
    if (_state.mutationError != null) {
      _replace(_state.copyWith(mutationError: null));
    }
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _replace(CustomerOrdersState value) {
    if (_disposed) {
      return;
    }
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    super.dispose();
  }
}
