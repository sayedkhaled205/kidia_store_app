import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_change_source.dart';

class CatalogProductListRequest {
  const CatalogProductListRequest({
    this.title = '',
    this.search = '',
    this.categoryId,
    this.brandId,
    this.collection = '',
    this.searchOnly = false,
    this.pageSize = 20,
  });

  final String title;
  final String search;
  final int? categoryId;
  final int? brandId;
  final String collection;

  /// When true, an empty search is a deliberate idle state and no broad
  /// catalog request is sent until the customer submits a term.
  final bool searchOnly;
  final int pageSize;

  @override
  bool operator ==(Object other) {
    return other is CatalogProductListRequest &&
        other.title == title &&
        other.search == search &&
        other.categoryId == categoryId &&
        other.brandId == brandId &&
        other.collection == collection &&
        other.searchOnly == searchOnly &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode => Object.hash(
    title,
    search,
    categoryId,
    brandId,
    collection,
    searchOnly,
    pageSize,
  );
}

class CatalogProductFilters {
  const CatalogProductFilters({
    this.onSaleOnly = false,
    this.minimumPriceMinor = '',
    this.maximumPriceMinor = '',
    this.brandId,
    this.brandLabel = '',
    this.sizeTaxonomy = '',
    this.sizeTerm = '',
    this.sizeLabel = '',
    this.colorTaxonomy = '',
    this.colorTerm = '',
    this.colorLabel = '',
  });

  final bool onSaleOnly;
  final String minimumPriceMinor;
  final String maximumPriceMinor;
  final int? brandId;
  final String brandLabel;
  final String sizeTaxonomy;
  final String sizeTerm;
  final String sizeLabel;
  final String colorTaxonomy;
  final String colorTerm;
  final String colorLabel;

  bool get hasBrand => brandId != null && brandId! > 0;
  bool get hasColor => colorTaxonomy.isNotEmpty && colorTerm.isNotEmpty;
  bool get hasSize => sizeTaxonomy.isNotEmpty && sizeTerm.isNotEmpty;

  int get generalActiveCount {
    return (onSaleOnly ? 1 : 0) +
        (minimumPriceMinor.isNotEmpty ? 1 : 0) +
        (maximumPriceMinor.isNotEmpty ? 1 : 0) +
        (hasBrand ? 1 : 0);
  }

  int get activeCount {
    return generalActiveCount + (hasSize ? 1 : 0) + (hasColor ? 1 : 0);
  }

  bool get isEmpty => activeCount == 0;

  @override
  bool operator ==(Object other) {
    return other is CatalogProductFilters &&
        other.onSaleOnly == onSaleOnly &&
        other.minimumPriceMinor == minimumPriceMinor &&
        other.maximumPriceMinor == maximumPriceMinor &&
        other.brandId == brandId &&
        other.brandLabel == brandLabel &&
        other.sizeTaxonomy == sizeTaxonomy &&
        other.sizeTerm == sizeTerm &&
        other.sizeLabel == sizeLabel &&
        other.colorTaxonomy == colorTaxonomy &&
        other.colorTerm == colorTerm &&
        other.colorLabel == colorLabel;
  }

  @override
  int get hashCode => Object.hash(
    onSaleOnly,
    minimumPriceMinor,
    maximumPriceMinor,
    brandId,
    brandLabel,
    sizeTaxonomy,
    sizeTerm,
    sizeLabel,
    colorTaxonomy,
    colorTerm,
    colorLabel,
  );
}

class CatalogSizeOption {
  const CatalogSizeOption({
    required this.taxonomy,
    required this.term,
    required this.label,
  });

  final String taxonomy;
  final String term;
  final String label;

  String get key => '$taxonomy|$term';
}

class CatalogProductListState {
  const CatalogProductListState({
    required this.search,
    this.items = const <CatalogProduct>[],
    this.sort = CatalogSort.relevance,
    this.filters = const CatalogProductFilters(),
    this.page = 0,
    this.totalItems = 0,
    this.totalPages = 0,
    this.cursorPagination = false,
    this.cursorHasNextPage = false,
    this.cursorHasPreviousPage = false,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.filterData,
    this.availableSizes = const <CatalogSizeOption>[],
    this.availableColors = const <CatalogSizeOption>[],
  });

  final String search;
  final List<CatalogProduct> items;
  final CatalogSort sort;
  final CatalogProductFilters filters;
  final int page;
  final int? totalItems;
  final int? totalPages;
  final bool cursorPagination;
  final bool cursorHasNextPage;
  final bool cursorHasPreviousPage;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;
  final CatalogFilterData? filterData;
  final List<CatalogSizeOption> availableSizes;
  final List<CatalogSizeOption> availableColors;

  bool get hasKnownTotals => totalItems != null && totalPages != null;
  bool get hasNextPage =>
      cursorPagination ? cursorHasNextPage : page < (totalPages ?? 0);
  bool get hasPreviousPage =>
      cursorPagination ? cursorHasPreviousPage : page > 1;

  CatalogProductListState copyWith({
    String? search,
    List<CatalogProduct>? items,
    CatalogSort? sort,
    CatalogProductFilters? filters,
    int? page,
    Object? totalItems = _notProvided,
    Object? totalPages = _notProvided,
    bool? cursorPagination,
    bool? cursorHasNextPage,
    bool? cursorHasPreviousPage,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _notProvided,
    Object? loadMoreError = _notProvided,
    Object? filterData = _notProvided,
    List<CatalogSizeOption>? availableSizes,
    List<CatalogSizeOption>? availableColors,
  }) {
    return CatalogProductListState(
      search: search ?? this.search,
      items: items ?? this.items,
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      page: page ?? this.page,
      totalItems: identical(totalItems, _notProvided)
          ? this.totalItems
          : totalItems as int?,
      totalPages: identical(totalPages, _notProvided)
          ? this.totalPages
          : totalPages as int?,
      cursorPagination: cursorPagination ?? this.cursorPagination,
      cursorHasNextPage: cursorHasNextPage ?? this.cursorHasNextPage,
      cursorHasPreviousPage:
          cursorHasPreviousPage ?? this.cursorHasPreviousPage,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _notProvided) ? this.error : error,
      loadMoreError: identical(loadMoreError, _notProvided)
          ? this.loadMoreError
          : loadMoreError,
      filterData: identical(filterData, _notProvided)
          ? this.filterData
          : filterData as CatalogFilterData?,
      availableSizes: availableSizes ?? this.availableSizes,
      availableColors: availableColors ?? this.availableColors,
    );
  }
}

const Object _notProvided = Object();

class CatalogProductListController extends ChangeNotifier {
  CatalogProductListController(this._repository, {required this.request})
    : _state = CatalogProductListState(search: request.search.trim()) {
    if (_repository is CatalogChangeSource) {
      _catalogSubscription = (_repository as CatalogChangeSource).catalogChanges
          .listen((_) => unawaited(refreshSourceData()));
    }
  }

  final CatalogRepository _repository;
  final CatalogProductListRequest request;
  CatalogProductListState _state;
  int _operation = 0;
  bool _disposed = false;
  StreamSubscription<int>? _catalogSubscription;

  CatalogProductListState get state => _state;

  bool get isAwaitingSearch {
    return request.searchOnly && _state.search.trim().isEmpty;
  }

  /// Refresh source values without rebuilding the controller, losing filters,
  /// jumping to page one, or shrinking the already loaded infinite list.
  Future<void> refreshSourceData() async {
    if (_disposed || isAwaitingSearch) return;
    if (_state.items.isEmpty || _state.page < 1) {
      await loadInitial(refresh: true);
      return;
    }
    final int operation = ++_operation;
    final int originalPage = _state.page;
    final int rowCount = _state.items.length;
    final bool accumulatedPages = rowCount > request.pageSize;
    final bool cursorPagination = _state.cursorPagination;
    final int batchSize = cursorPagination
        ? request.pageSize
        : accumulatedPages
        ? 100
        : request.pageSize;
    // Cursor sessions are replayed from page1 after source invalidation, using
    // the real page size. An arbitrary page2/100-row request has no cursor.
    final int batchCount = cursorPagination
        ? originalPage
        : accumulatedPages
        ? (rowCount / batchSize).ceil()
        : 1;
    _replace(
      _state.copyWith(isRefreshing: true, isLoadingMore: false, error: null),
    );
    try {
      final List<CatalogProduct> updated = <CatalogProduct>[];
      CatalogPage<CatalogProduct>? latest;
      for (int batch = 0; batch < batchCount; batch++) {
        latest = await _repository.getProducts(
          _query(
            page: cursorPagination || accumulatedPages
                ? batch + 1
                : originalPage,
            includeFilters: true,
            perPage: batchSize,
          ),
        );
        if (!_isCurrent(operation)) return;
        if (cursorPagination && !accumulatedPages) updated.clear();
        updated.addAll(latest.items);
        if (!latest.hasNextPage) break;
      }
      if (latest == null || !_isCurrent(operation)) return;
      final CatalogFilterData? filterData = await _loadFilterData(
        _query(page: 1, includeFilters: false),
      );
      if (!_isCurrent(operation)) return;
      final int? totalItems = latest.totalItems;
      final int? totalPages = totalItems == null
          ? null
          : totalItems == 0
          ? 0
          : (totalItems / request.pageSize).ceil();
      _replace(
        _state.copyWith(
          items: List<CatalogProduct>.unmodifiable(
            accumulatedPages ? updated.take(rowCount) : updated,
          ),
          page: cursorPagination ? latest.page : originalPage,
          totalItems: latest.totalItems,
          totalPages: totalPages,
          cursorPagination: latest.cursorPagination,
          cursorHasNextPage: latest.cursorHasNextPage,
          cursorHasPreviousPage: latest.cursorHasPreviousPage,
          isInitialLoading: false,
          isRefreshing: false,
          loadMoreError: null,
          filterData: filterData,
          availableSizes: _discoverSizeOptions(updated),
          availableColors: _discoverColorOptions(updated),
        ),
      );
    } catch (error) {
      if (_isCurrent(operation)) {
        // A temporary source failure must not discard the visible list.
        _replace(_state.copyWith(isRefreshing: false, error: error));
      }
    }
  }

  Future<void> loadInitial({bool refresh = false}) async {
    if (isAwaitingSearch) {
      _replace(
        _state.copyWith(
          items: const <CatalogProduct>[],
          page: 0,
          totalItems: 0,
          totalPages: 0,
          cursorPagination: false,
          cursorHasNextPage: false,
          cursorHasPreviousPage: false,
          isInitialLoading: false,
          isRefreshing: false,
          error: null,
          loadMoreError: null,
          filterData: null,
        ),
      );
      return;
    }

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

    final CatalogProductQuery query = _query(page: 1, includeFilters: true);
    final CatalogProductQuery filterQuery = _query(
      page: 1,
      includeFilters: false,
    );

    try {
      final List<Object?> result = await Future.wait<Object?>(<Future<Object?>>[
        _repository.getProducts(query),
        _loadFilterData(filterQuery),
      ]);
      if (!_isCurrent(operation)) {
        return;
      }

      final CatalogPage<CatalogProduct> page =
          result[0] as CatalogPage<CatalogProduct>;
      _replace(
        _state.copyWith(
          items: List<CatalogProduct>.unmodifiable(page.items),
          page: page.page,
          totalItems: page.totalItems,
          totalPages: page.totalPages,
          cursorPagination: page.cursorPagination,
          cursorHasNextPage: page.cursorHasNextPage,
          cursorHasPreviousPage: page.cursorHasPreviousPage,
          isInitialLoading: false,
          isRefreshing: false,
          error: null,
          loadMoreError: null,
          filterData: result.last,
          availableSizes: _mergeSizeOptions(
            _state.availableSizes,
            _discoverSizeOptions(page.items),
          ),
          availableColors: _mergeSizeOptions(
            _state.availableColors,
            _discoverColorOptions(page.items),
          ),
        ),
      );
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(
        _state.copyWith(
          items: refresh ? _state.items : const <CatalogProduct>[],
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
      final CatalogPage<CatalogProduct> page = await _repository.getProducts(
        _query(page: _state.page + 1, includeFilters: true),
      );
      if (!_isCurrent(operation)) {
        return;
      }

      final Map<int, CatalogProduct> unique = <int, CatalogProduct>{
        for (final CatalogProduct product in _state.items) product.id: product,
        for (final CatalogProduct product in page.items) product.id: product,
      };
      _replace(
        _state.copyWith(
          items: List<CatalogProduct>.unmodifiable(unique.values),
          page: page.page,
          totalItems: page.totalItems,
          totalPages: page.totalPages,
          cursorPagination: page.cursorPagination,
          cursorHasNextPage: page.cursorHasNextPage,
          cursorHasPreviousPage: page.cursorHasPreviousPage,
          isLoadingMore: false,
          loadMoreError: null,
          availableSizes: _mergeSizeOptions(
            _state.availableSizes,
            _discoverSizeOptions(page.items),
          ),
          availableColors: _mergeSizeOptions(
            _state.availableColors,
            _discoverColorOptions(page.items),
          ),
        ),
      );
    } catch (error) {
      if (!_isCurrent(operation)) {
        return;
      }
      _replace(_state.copyWith(isLoadingMore: false, loadMoreError: error));
    }
  }

  Future<void> loadPage(int pageNumber) async {
    if (isAwaitingSearch ||
        pageNumber < 1 ||
        (!_state.cursorPagination && pageNumber > (_state.totalPages ?? 0)) ||
        (_state.cursorPagination &&
            ((pageNumber == _state.page + 1 && !_state.hasNextPage) ||
                (pageNumber == _state.page - 1 && !_state.hasPreviousPage) ||
                (pageNumber - _state.page).abs() > 1)) ||
        pageNumber == _state.page ||
        _state.isInitialLoading ||
        _state.isRefreshing ||
        _state.isLoadingMore) {
      return;
    }

    final int operation = ++_operation;
    _replace(
      _state.copyWith(isInitialLoading: true, error: null, loadMoreError: null),
    );
    try {
      final CatalogPage<CatalogProduct> page = await _repository.getProducts(
        _query(page: pageNumber, includeFilters: true),
      );
      if (!_isCurrent(operation)) return;
      _replace(
        _state.copyWith(
          items: List<CatalogProduct>.unmodifiable(page.items),
          page: page.page,
          totalItems: page.totalItems,
          totalPages: page.totalPages,
          cursorPagination: page.cursorPagination,
          cursorHasNextPage: page.cursorHasNextPage,
          cursorHasPreviousPage: page.cursorHasPreviousPage,
          isInitialLoading: false,
          error: null,
          availableSizes: _mergeSizeOptions(
            _state.availableSizes,
            _discoverSizeOptions(page.items),
          ),
          availableColors: _mergeSizeOptions(
            _state.availableColors,
            _discoverColorOptions(page.items),
          ),
        ),
      );
    } catch (error) {
      if (!_isCurrent(operation)) return;
      _replace(_state.copyWith(isInitialLoading: false, error: error));
    }
  }

  Future<void> changeSort(CatalogSort sort) async {
    if (_state.sort == sort) {
      return;
    }
    _operation++;
    _replace(_state.copyWith(sort: sort));
    await loadInitial();
  }

  Future<void> applyFilters(CatalogProductFilters filters) async {
    if (_state.filters == filters) {
      return;
    }
    _operation++;
    _replace(_state.copyWith(filters: filters));
    await loadInitial();
  }

  Future<void> applySize(CatalogSizeOption? size) {
    final CatalogProductFilters current = _state.filters;
    return applyFilters(
      CatalogProductFilters(
        onSaleOnly: current.onSaleOnly,
        minimumPriceMinor: current.minimumPriceMinor,
        maximumPriceMinor: current.maximumPriceMinor,
        brandId: current.brandId,
        brandLabel: current.brandLabel,
        sizeTaxonomy: size?.taxonomy ?? '',
        sizeTerm: size?.term ?? '',
        sizeLabel: size?.label ?? '',
        colorTaxonomy: current.colorTaxonomy,
        colorTerm: current.colorTerm,
        colorLabel: current.colorLabel,
      ),
    );
  }

  Future<void> applyColor(CatalogSizeOption? color) {
    final CatalogProductFilters current = _state.filters;
    return applyFilters(
      CatalogProductFilters(
        onSaleOnly: current.onSaleOnly,
        minimumPriceMinor: current.minimumPriceMinor,
        maximumPriceMinor: current.maximumPriceMinor,
        brandId: current.brandId,
        brandLabel: current.brandLabel,
        sizeTaxonomy: current.sizeTaxonomy,
        sizeTerm: current.sizeTerm,
        sizeLabel: current.sizeLabel,
        colorTaxonomy: color?.taxonomy ?? '',
        colorTerm: color?.term ?? '',
        colorLabel: color?.label ?? '',
      ),
    );
  }

  Future<void> submitSearch(String value) async {
    final String search = value.trim();
    if (_state.search == search &&
        (_state.items.isNotEmpty || _state.isInitialLoading)) {
      return;
    }
    _operation++;
    _replace(
      _state.copyWith(
        search: search,
        items: search.isEmpty && request.searchOnly
            ? const <CatalogProduct>[]
            : _state.items,
      ),
    );
    await loadInitial();
  }

  Future<CatalogFilterData?> _loadFilterData(CatalogProductQuery query) async {
    try {
      return await _repository.getFilterData(query);
    } catch (_) {
      // Product browsing remains available on stores/extensions that do not
      // expose the optional collection-data endpoint.
      return null;
    }
  }

  CatalogProductQuery _query({
    required int page,
    required bool includeFilters,
    int? perPage,
  }) {
    final String collection = request.collection.trim().toLowerCase();
    final bool collectionIsSale = <String>{
      'sale',
      'on-sale',
      'on_sale',
    }.contains(collection);
    final bool collectionIsFeatured = collection == 'featured';
    final bool collectionIsNewest = <String>{
      'new',
      'newest',
      'latest',
    }.contains(collection);
    final CatalogProductFilters filters = includeFilters
        ? _state.filters
        : const CatalogProductFilters();

    return CatalogProductQuery(
      page: page,
      perPage: perPage ?? request.pageSize,
      search: _state.search,
      sort: collectionIsNewest ? CatalogSort.newest : _state.sort,
      categoryIds: request.categoryId != null
          ? <int>[request.categoryId!]
          : const <int>[],
      brandIds: request.brandId != null
          ? <int>[request.brandId!]
          : filters.hasBrand
          ? <int>[filters.brandId!]
          : const <int>[],
      minimumPriceMinor: filters.minimumPriceMinor,
      maximumPriceMinor: filters.maximumPriceMinor,
      attributes: <CatalogAttributeFilter>[
        if (filters.hasSize)
          CatalogAttributeFilter(
            taxonomy: filters.sizeTaxonomy,
            terms: <String>[filters.sizeTerm],
          ),
        if (filters.hasColor)
          CatalogAttributeFilter(
            taxonomy: filters.colorTaxonomy,
            terms: <String>[filters.colorTerm],
          ),
      ],
      onSale: filters.onSaleOnly || collectionIsSale ? true : null,
      featured: collectionIsFeatured ? true : null,
    );
  }

  static List<CatalogSizeOption> _discoverSizeOptions(
    Iterable<CatalogProduct> products,
  ) {
    final Map<String, CatalogSizeOption> options =
        <String, CatalogSizeOption>{};
    for (final CatalogProduct product in products) {
      for (final CatalogProductAttribute attribute in product.attributes) {
        if (!_isSizeAttribute(attribute)) {
          continue;
        }
        for (final CatalogAttributeTerm term in attribute.terms) {
          final String taxonomy = attribute.taxonomy.trim();
          final String slug = term.slug.trim();
          final String label = term.name.trim();
          if (taxonomy.isEmpty || slug.isEmpty) {
            continue;
          }
          final CatalogSizeOption option = CatalogSizeOption(
            taxonomy: taxonomy,
            term: slug,
            label: label.isEmpty ? slug : label,
          );
          options[option.key] = option;
        }
      }
    }
    final List<CatalogSizeOption> result = options.values.toList()
      ..sort(
        (CatalogSizeOption first, CatalogSizeOption second) =>
            first.label.toLowerCase().compareTo(second.label.toLowerCase()),
      );
    return List<CatalogSizeOption>.unmodifiable(result);
  }

  static List<CatalogSizeOption> _discoverColorOptions(
    Iterable<CatalogProduct> products,
  ) {
    final Map<String, CatalogSizeOption> options =
        <String, CatalogSizeOption>{};
    for (final CatalogProduct product in products) {
      for (final CatalogProductAttribute attribute in product.attributes) {
        if (!_isColorAttribute(attribute)) {
          continue;
        }
        for (final CatalogAttributeTerm term in attribute.terms) {
          final String taxonomy = attribute.taxonomy.trim();
          final String slug = term.slug.trim();
          final String label = term.name.trim();
          if (taxonomy.isEmpty || slug.isEmpty) {
            continue;
          }
          final CatalogSizeOption option = CatalogSizeOption(
            taxonomy: taxonomy,
            term: slug,
            label: label.isEmpty ? slug : label,
          );
          options[option.key] = option;
        }
      }
    }
    final List<CatalogSizeOption> result = options.values.toList()
      ..sort(
        (CatalogSizeOption first, CatalogSizeOption second) =>
            first.label.toLowerCase().compareTo(second.label.toLowerCase()),
      );
    return List<CatalogSizeOption>.unmodifiable(result);
  }

  static bool _isColorAttribute(CatalogProductAttribute attribute) {
    final String value = '${attribute.taxonomy} ${attribute.name}'
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    return RegExp(
      r'(^|\s)(color|colors|colour|colours|لون|اللون|ألوان|الوان|الألوان|الالوان)(\s|$)',
    ).hasMatch(value);
  }

  static bool _isSizeAttribute(CatalogProductAttribute attribute) {
    final String value = '${attribute.taxonomy} ${attribute.name}'
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    return RegExp(
      r'(^|\s)(size|sizes|pa size|مقاس|المقاس|مقاسات|المقاسات|حجم|الحجم|أحجام|الاحجام)(\s|$)',
    ).hasMatch(value);
  }

  static List<CatalogSizeOption> _mergeSizeOptions(
    Iterable<CatalogSizeOption> current,
    Iterable<CatalogSizeOption> discovered,
  ) {
    final Map<String, CatalogSizeOption> options = <String, CatalogSizeOption>{
      for (final CatalogSizeOption option in current) option.key: option,
      for (final CatalogSizeOption option in discovered) option.key: option,
    };
    final List<CatalogSizeOption> result = options.values.toList()
      ..sort(
        (CatalogSizeOption first, CatalogSizeOption second) =>
            first.label.toLowerCase().compareTo(second.label.toLowerCase()),
      );
    return List<CatalogSizeOption>.unmodifiable(result);
  }

  bool _isCurrent(int operation) {
    return !_disposed && operation == _operation;
  }

  void _replace(CatalogProductListState value) {
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
    _catalogSubscription?.cancel();
    super.dispose();
  }
}
