import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';

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
  });

  final bool onSaleOnly;
  final String minimumPriceMinor;
  final String maximumPriceMinor;
  final int? brandId;
  final String brandLabel;
  final String sizeTaxonomy;
  final String sizeTerm;
  final String sizeLabel;

  bool get hasBrand => brandId != null && brandId! > 0;
  bool get hasSize => sizeTaxonomy.isNotEmpty && sizeTerm.isNotEmpty;

  int get generalActiveCount {
    return (onSaleOnly ? 1 : 0) +
        (minimumPriceMinor.isNotEmpty ? 1 : 0) +
        (maximumPriceMinor.isNotEmpty ? 1 : 0) +
        (hasBrand ? 1 : 0);
  }

  int get activeCount {
    return generalActiveCount + (hasSize ? 1 : 0);
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
        other.sizeLabel == sizeLabel;
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
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.filterData,
    this.availableSizes = const <CatalogSizeOption>[],
  });

  final String search;
  final List<CatalogProduct> items;
  final CatalogSort sort;
  final CatalogProductFilters filters;
  final int page;
  final int totalItems;
  final int totalPages;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;
  final CatalogFilterData? filterData;
  final List<CatalogSizeOption> availableSizes;

  bool get hasNextPage => page < totalPages;

  CatalogProductListState copyWith({
    String? search,
    List<CatalogProduct>? items,
    CatalogSort? sort,
    CatalogProductFilters? filters,
    int? page,
    int? totalItems,
    int? totalPages,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _notProvided,
    Object? loadMoreError = _notProvided,
    Object? filterData = _notProvided,
    List<CatalogSizeOption>? availableSizes,
  }) {
    return CatalogProductListState(
      search: search ?? this.search,
      items: items ?? this.items,
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      page: page ?? this.page,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
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
    );
  }
}

const Object _notProvided = Object();

class CatalogProductListController extends ChangeNotifier {
  CatalogProductListController(this._repository, {required this.request})
    : _state = CatalogProductListState(search: request.search.trim());

  final CatalogRepository _repository;
  final CatalogProductListRequest request;
  CatalogProductListState _state;
  int _operation = 0;
  bool _disposed = false;

  CatalogProductListState get state => _state;

  bool get isAwaitingSearch {
    return request.searchOnly && _state.search.trim().isEmpty;
  }

  Future<void> loadInitial({bool refresh = false}) async {
    if (isAwaitingSearch) {
      _replace(
        _state.copyWith(
          items: const <CatalogProduct>[],
          page: 0,
          totalItems: 0,
          totalPages: 0,
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
          isInitialLoading: false,
          isRefreshing: false,
          error: null,
          loadMoreError: null,
          filterData: result.last,
          availableSizes: _mergeSizeOptions(
            _state.availableSizes,
            _discoverSizeOptions(page.items),
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
          isLoadingMore: false,
          loadMoreError: null,
          availableSizes: _mergeSizeOptions(
            _state.availableSizes,
            _discoverSizeOptions(page.items),
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
      perPage: request.pageSize,
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
      attributes: filters.hasSize
          ? <CatalogAttributeFilter>[
              CatalogAttributeFilter(
                taxonomy: filters.sizeTaxonomy,
                terms: <String>[filters.sizeTerm],
              ),
            ]
          : const <CatalogAttributeFilter>[],
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
    super.dispose();
  }
}
