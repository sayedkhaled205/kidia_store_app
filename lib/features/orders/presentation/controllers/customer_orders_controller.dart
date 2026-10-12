import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobishop_store_app/features/orders/domain/entities/customer_order.dart';
import 'package:mobishop_store_app/features/orders/domain/repositories/customer_orders_repository.dart';

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
  int _activeListReads = 0;
  bool _refreshRequested = false;
  bool _refreshingLoadedPages = false;
  Completer<void>? _refreshCompletion;

  CustomerOrdersState get state => _state;

  Future<void> loadInitial({bool refresh = false}) async {
    if (_disposed) return;
    _activeListReads++;
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
    } finally {
      _activeListReads--;
      _continueLoadedRefresh();
    }
  }

  Future<void> loadMore() async {
    if (_disposed ||
        _state.isInitialLoading ||
        _state.isRefreshing ||
        _state.isLoadingMore ||
        !_state.hasNextPage) {
      return;
    }
    _activeListReads++;
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
        _replace(_state.copyWith(isLoadingMore: false, loadMoreError: error));
      }
    } finally {
      _activeListReads--;
      _continueLoadedRefresh();
    }
  }

  /// Explicit, read-only refresh for a future external-change listener.
  ///
  /// Keeps the same controller/scroll owner and commits the loaded pages only
  /// after the whole batch succeeds. Calls while busy coalesce into one pending
  /// batch; this method does not subscribe to events or start polling.
  Future<void> refreshLoadedPages() {
    if (_disposed) return Future<void>.value();
    _refreshRequested = true;
    final Completer<void> completion = _refreshCompletion ??= Completer<void>();
    _continueLoadedRefresh();
    return completion.future;
  }

  void _continueLoadedRefresh() {
    if (_disposed || _refreshingLoadedPages) return;
    if (!_refreshRequested) {
      _refreshCompletion?.complete();
      _refreshCompletion = null;
      return;
    }
    if (_activeListReads > 0 || _state.cancellingOrderIds.isNotEmpty) return;
    _refreshRequested = false;
    _refreshingLoadedPages = true;
    unawaited(_refreshLoadedBatch());
  }

  Future<void> _refreshLoadedBatch() async {
    final int operation = ++_operation;
    final int loadedPages = _state.page > 0 ? _state.page : 1;
    _replace(_state.copyWith(isRefreshing: true));
    try {
      final CustomerOrderPage first = await _repository.getOrders(
        page: 1,
        perPage: pageSize,
      );
      if (!_isCurrent(operation)) return;
      int totalPages = first.totalPages;
      int totalItems = first.totalItems;
      final List<CustomerOrderPage> results = <CustomerOrderPage>[first];
      int pageLimit = loadedPages < totalPages ? loadedPages : totalPages;
      for (int page = 2; page <= pageLimit; page++) {
        final CustomerOrderPage result = await _repository.getOrders(
          page: page,
          perPage: pageSize,
        );
        if (!_isCurrent(operation)) return;
        results.add(result);
        totalItems = result.totalItems;
        if (result.totalPages < totalPages) {
          totalPages = result.totalPages;
          pageLimit = loadedPages < totalPages ? loadedPages : totalPages;
        }
      }
      if (!_isCurrent(operation)) return;
      final Map<int, CustomerOrder> unique = <int, CustomerOrder>{
        for (final CustomerOrderPage result in results)
          if (result.page <= totalPages)
            for (final CustomerOrder order in result.items) order.id: order,
      };
      _replace(
        _state.copyWith(
          items: List<CustomerOrder>.unmodifiable(unique.values),
          page: totalPages <= 0 ? 0 : pageLimit,
          totalItems: totalItems,
          totalPages: totalPages,
          isRefreshing: false,
          error: null,
          loadMoreError: null,
        ),
      );
    } catch (error) {
      if (_isCurrent(operation)) {
        _replace(
          _state.copyWith(isRefreshing: false, error: _state.error ?? error),
        );
      }
    } finally {
      _refreshingLoadedPages = false;
      // A manual load or cancellation can invalidate the old batch. Never
      // replace its result, nor clear a newer manual load's refresh indicator.
      if (!_disposed && _activeListReads == 0 && _state.isRefreshing) {
        _replace(_state.copyWith(isRefreshing: false));
      }
      _continueLoadedRefresh();
    }
  }

  bool isCancelling(int orderId) => _state.cancellingOrderIds.contains(orderId);

  final Map<int, CustomerOrder> _openedOrders = {};
  Future<CustomerOrder> loadOrder(int orderId) async {
    if (_repository is! CustomerOrderLookupRepository || _disposed) {
      throw const CustomerOrdersRepositoryException(kind: CustomerOrdersFailureKind.configuration, message: 'Order lookup is unavailable.');
    }
    final order = await (_repository as CustomerOrderLookupRepository).getOrder(orderId);
    if (_disposed) throw StateError('Order screen was disposed.');
    _openedOrders[orderId] = order;
    return order;
  }

  CustomerOrder? orderById(int orderId) {
    if (_openedOrders.containsKey(orderId)) return _openedOrders[orderId];
    for (final CustomerOrder order in _state.items) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  Future<bool> cancelOrder(CustomerOrder order) async {
    if (_disposed || !order.canCancel || isCancelling(order.id)) {
      return false;
    }
    if (_repository is! CustomerOrderCancellationRepository) {
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
    final CustomerOrderCancellationRepository repository =
        _repository as CustomerOrderCancellationRepository;

    // The cancellation response is authoritative. An older refresh must not
    // replace it, even if that refresh returns after cancellation succeeds.
    if (_refreshingLoadedPages) _operation++;

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
      if (_openedOrders.containsKey(updated.id)) _openedOrders[updated.id] = updated;
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
      _continueLoadedRefresh();
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
    _refreshRequested = false;
    _refreshCompletion?.complete();
    _refreshCompletion = null;
    super.dispose();
  }
}
