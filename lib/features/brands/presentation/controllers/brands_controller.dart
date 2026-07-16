import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';

class BrandsState {
  const BrandsState({
    this.items = const <StoreBrand>[],
    this.search = '',
    this.page = 0,
    this.totalItems = 0,
    this.totalPages = 0,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isUnsupported = false,
    this.error,
    this.loadMoreError,
  });

  final List<StoreBrand> items;
  final String search;
  final int page;
  final int totalItems;
  final int totalPages;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isUnsupported;
  final Object? error;
  final Object? loadMoreError;

  bool get hasNextPage => page < totalPages;

  BrandsState copyWith({
    List<StoreBrand>? items,
    String? search,
    int? page,
    int? totalItems,
    int? totalPages,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isUnsupported,
    Object? error = _notProvided,
    Object? loadMoreError = _notProvided,
  }) {
    return BrandsState(
      items: items ?? this.items,
      search: search ?? this.search,
      page: page ?? this.page,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isUnsupported: isUnsupported ?? this.isUnsupported,
      error: identical(error, _notProvided) ? this.error : error,
      loadMoreError: identical(loadMoreError, _notProvided)
          ? this.loadMoreError
          : loadMoreError,
    );
  }
}

const Object _notProvided = Object();

class BrandsController extends ChangeNotifier {
  BrandsController(this._repository, {this.pageSize = 30});

  final BrandsRepository _repository;
  final int pageSize;
  BrandsState _state = const BrandsState();
  int _operation = 0;
  bool _disposed = false;

  BrandsState get state => _state;

  Future<void> loadInitial({bool refresh = false}) async {
    final int operation = ++_operation;
    _replace(
      _state.copyWith(
        isInitialLoading: !refresh || _state.items.isEmpty,
        isRefreshing: refresh && _state.items.isNotEmpty,
        isLoadingMore: false,
        isUnsupported: false,
        error: null,
        loadMoreError: null,
      ),
    );

    try {
      final StoreBrandPage page = await _repository.getBrands(
        page: 1,
        perPage: pageSize,
        search: _state.search,
      );
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          items: List<StoreBrand>.unmodifiable(page.items),
          page: page.page,
          totalItems: page.totalItems,
          totalPages: page.totalPages,
          isInitialLoading: false,
          isRefreshing: false,
          error: null,
        ),
      );
    } on BrandsUnsupportedException {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          items: const <StoreBrand>[],
          page: 0,
          totalItems: 0,
          totalPages: 0,
          isInitialLoading: false,
          isRefreshing: false,
          isUnsupported: true,
          error: null,
        ),
      );
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          items: refresh ? _state.items : const <StoreBrand>[],
          isInitialLoading: false,
          isRefreshing: false,
          error: error,
        ),
      );
    }
  }

  Future<void> submitSearch(String value) async {
    final String search = value.trim();
    if (_state.search == search &&
        (_state.items.isNotEmpty || _state.isInitialLoading)) {
      return;
    }
    _operation++;
    _replace(_state.copyWith(search: search));
    await loadInitial();
  }

  Future<void> loadMore() async {
    if (_state.isInitialLoading ||
        _state.isRefreshing ||
        _state.isLoadingMore ||
        !_state.hasNextPage ||
        _state.isUnsupported) {
      return;
    }

    final int operation = _operation;
    _replace(_state.copyWith(isLoadingMore: true, loadMoreError: null));
    try {
      final StoreBrandPage page = await _repository.getBrands(
        page: _state.page + 1,
        perPage: pageSize,
        search: _state.search,
      );
      if (!_isCurrent(operation)) {
        return;
      }
      final Map<int, StoreBrand> unique = <int, StoreBrand>{
        for (final StoreBrand brand in _state.items) brand.id: brand,
        for (final StoreBrand brand in page.items) brand.id: brand,
      };
      _replace(
        _state.copyWith(
          items: List<StoreBrand>.unmodifiable(unique.values),
          page: page.page,
          totalItems: page.totalItems,
          totalPages: page.totalPages,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
    } on BrandsUnsupportedException {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          isLoadingMore: false,
          isUnsupported: true,
          loadMoreError: null,
        ),
      );
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(_state.copyWith(isLoadingMore: false, loadMoreError: error));
    }
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  void _replace(BrandsState value) {
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
