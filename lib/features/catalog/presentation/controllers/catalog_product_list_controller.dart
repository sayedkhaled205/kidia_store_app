import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_options.dart';
export 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_options.dart';
import 'dart:async';
import 'dart:convert';

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
    this.initialFilters = const CatalogProductFilters(),
    this.initialSort = CatalogSort.relevance,
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
  final CatalogProductFilters initialFilters;
  final CatalogSort initialSort;

  @override
  bool operator ==(Object other) {
    return other is CatalogProductListRequest &&
        other.title == title &&
        other.search == search &&
        other.categoryId == categoryId &&
        other.brandId == brandId &&
        other.collection == collection &&
        other.searchOnly == searchOnly &&
        other.pageSize == pageSize &&
        other.initialFilters == initialFilters &&
        other.initialSort == initialSort;
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
    initialFilters,
    initialSort,
  );
}

/// Versioned public catalog state. No cart, account, checkout or session data.
final class CatalogPageState {
  static String encode(CatalogProductListController controller) {
    final r = controller.request, s = controller.state, f = s.filters;
    List<List<String>> options(List<CatalogSizeOption> values) => [
      for (final value in values) [value.taxonomy, value.term, value.label],
    ];
    return base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'v': 1,
              'q': s.search,
              'c': controller.effectiveCategoryId,
              'b': r.brandId,
              'l': r.collection,
              't': r.title,
              's': s.sort.name,
              'f': {
                'sale': f.onSaleOnly,
                'min': f.minimumPriceMinor,
                'max': f.maximumPriceMinor,
                'brand': f.brandId,
                'label': f.brandLabel,
                'tags': [
                  for (final tag in f.tags) [tag.id, tag.label],
                ],
                'sizes': options(f.sizes),
                'colors': options(f.colors),
              },
            }),
          ),
        )
        .replaceAll('=', '');
  }

  static CatalogProductListRequest restore(
    String? encoded,
    CatalogProductListRequest fallback,
  ) {
    if (encoded == null || encoded.isEmpty || encoded.length > 1600) {
      return fallback;
    }
    try {
      final d = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      );
      if (d is! Map || d['v'] != 1 || d['f'] is! Map) return fallback;
      final f = d['f'] as Map;
      String text(Object? v) => v is String && v.length <= 200 ? v : '';
      int? id(Object? v) =>
          v is int && v > 0 && v < 9007199254740991 ? v : null;
      String amount(Object? v) =>
          RegExp(r'^\d{1,12}$').hasMatch(text(v)) ? text(v) : '';
      List<CatalogSizeOption> options(Object? v) => v is List && v.length <= 20
          ? [
              for (final row in v)
                if (row is List &&
                    row.length == 3 &&
                    text(row[0]).isNotEmpty &&
                    text(row[1]).isNotEmpty)
                  CatalogSizeOption(
                    taxonomy: text(row[0]),
                    term: text(row[1]),
                    label: text(row[2]),
                  ),
            ]
          : [];
      final tags = f['tags'];
      return CatalogProductListRequest(
        title: text(d['t']),
        search: text(d['q']),
        categoryId: id(d['c']),
        brandId: id(d['b']),
        collection: text(d['l']),
        pageSize: fallback.pageSize,
        searchOnly: fallback.searchOnly,
        initialSort:
            CatalogSort.values.where((s) => s.name == d['s']).firstOrNull ??
            CatalogSort.relevance,
        initialFilters: CatalogProductFilters(
          onSaleOnly: f['sale'] == true,
          minimumPriceMinor: amount(f['min']),
          maximumPriceMinor: amount(f['max']),
          brandId: id(f['brand']),
          brandLabel: text(f['label']),
          sizes: options(f['sizes']),
          colors: options(f['colors']),
          tags: tags is List && tags.length <= 20
              ? [
                  for (final row in tags)
                    if (row is List && row.length == 2 && id(row[0]) != null)
                      CatalogTagOption(id: id(row[0])!, label: text(row[1])),
                ]
              : [],
        ),
      );
    } on Object {
      return fallback;
    }
  }
}

class CatalogProductFilters {
  const CatalogProductFilters({
    this.onSaleOnly = false,
    this.minimumPriceMinor = '',
    this.maximumPriceMinor = '',
    this.brandId,
    this.brandLabel = '',
    List<CatalogTagOption> tags = const [],
    String sizeTaxonomy = '',
    String sizeTerm = '',
    String sizeLabel = '',
    String colorTaxonomy = '',
    String colorTerm = '',
    String colorLabel = '',
    List<CatalogSizeOption>? sizes,
    List<CatalogSizeOption>? colors,
    // Public selection arguments remain compatible with legacy single-value filters.
    // ignore: prefer_initializing_formals
  }) : _tags = tags,
       // ignore: prefer_initializing_formals
       _sizes = sizes,
       // ignore: prefer_initializing_formals
       _colors = colors,
       _legacySize = (taxonomy: sizeTaxonomy, term: sizeTerm, label: sizeLabel),
       _legacyColor = (
         taxonomy: colorTaxonomy,
         term: colorTerm,
         label: colorLabel,
       );

  final List<CatalogTagOption> _tags;
  List<CatalogTagOption> get tags {
    final entries = {
      for (final tag in _tags)
        if (tag.id > 0) tag.id: tag,
    }.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(entries);
  }

  final bool onSaleOnly;
  final String minimumPriceMinor;
  final String maximumPriceMinor;
  final int? brandId;
  final String brandLabel;
  final List<CatalogSizeOption>? _sizes;
  final List<CatalogSizeOption>? _colors;
  final ({String taxonomy, String term, String label}) _legacySize;
  final ({String taxonomy, String term, String label}) _legacyColor;

  List<CatalogSizeOption> get sizes => _options(_sizes, _legacySize);
  List<CatalogSizeOption> get colors => _options(_colors, _legacyColor);
  String get sizeTaxonomy => sizes.firstOrNull?.taxonomy ?? '';
  String get sizeTerm => sizes.firstOrNull?.term ?? '';
  String get sizeLabel => sizes.firstOrNull?.label ?? '';
  String get colorTaxonomy => colors.firstOrNull?.taxonomy ?? '';
  String get colorTerm => colors.firstOrNull?.term ?? '';
  String get colorLabel => colors.firstOrNull?.label ?? '';

  static List<CatalogSizeOption> _options(
    List<CatalogSizeOption>? values,
    ({String taxonomy, String term, String label}) legacy,
  ) {
    final entries =
        values ??
        [
          if (legacy.taxonomy.isNotEmpty && legacy.term.isNotEmpty)
            CatalogSizeOption(
              taxonomy: legacy.taxonomy,
              term: legacy.term,
              label: legacy.label,
            ),
        ];
    final unique = <String, CatalogSizeOption>{
      for (final option in entries)
        if (option.taxonomy.isNotEmpty && option.term.isNotEmpty)
          option.key: option,
    }.values.toList()..sort((a, b) => a.key.compareTo(b.key));
    return List.unmodifiable(unique);
  }

  bool get hasBrand => brandId != null && brandId! > 0;
  bool get hasColor => colors.isNotEmpty;
  bool get hasSize => sizes.isNotEmpty;
  int get generalActiveCount =>
      (onSaleOnly ? 1 : 0) +
      (minimumPriceMinor.isNotEmpty ? 1 : 0) +
      (maximumPriceMinor.isNotEmpty ? 1 : 0) +
      (hasBrand ? 1 : 0) +
      tags.length;
  int get activeCount => generalActiveCount + sizes.length + colors.length;
  bool get isEmpty => activeCount == 0;

  CatalogProductFilters withOptions({
    List<CatalogSizeOption>? sizes,
    List<CatalogSizeOption>? colors,
  }) => CatalogProductFilters(
    onSaleOnly: onSaleOnly,
    minimumPriceMinor: minimumPriceMinor,
    maximumPriceMinor: maximumPriceMinor,
    brandId: brandId,
    brandLabel: brandLabel,
    tags: tags,
    sizes: List.unmodifiable(sizes ?? this.sizes),
    colors: List.unmodifiable(colors ?? this.colors),
  );

  @override
  bool operator ==(Object other) =>
      other is CatalogProductFilters &&
      other.onSaleOnly == onSaleOnly &&
      other.minimumPriceMinor == minimumPriceMinor &&
      other.maximumPriceMinor == maximumPriceMinor &&
      other.brandId == brandId &&
      other.brandLabel == brandLabel &&
      listEquals(other.tags, tags) &&
      listEquals(other.sizes, sizes) &&
      listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hash(
    onSaleOnly,
    minimumPriceMinor,
    maximumPriceMinor,
    brandId,
    brandLabel,
    Object.hashAll(tags),
    Object.hashAll(sizes),
    Object.hashAll(colors),
  );
}

class CatalogProductListState {
  const CatalogProductListState({
    required this.search,
    this.items = const <CatalogProduct>[],
    this.sort = CatalogSort.relevance,
    this.filters = const CatalogProductFilters(),
    this.selectedChildCategoryId,
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
  final int? selectedChildCategoryId;
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
    Object? selectedChildCategoryId = _notProvided,
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
      selectedChildCategoryId: identical(selectedChildCategoryId, _notProvided)
          ? this.selectedChildCategoryId
          : selectedChildCategoryId as int?,
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
    : _state = CatalogProductListState(
        search: request.search.trim(),
        filters: request.initialFilters,
        sort: request.initialSort,
      ) {
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
  int? get effectiveCategoryId =>
      _state.selectedChildCategoryId ?? request.categoryId;

  /// Filter within the current category page, keeping its rail and filters.
  Future<void> selectChildCategory(int? categoryId) async {
    if (_disposed || (categoryId != null && categoryId <= 0)) return;
    final selected = categoryId == request.categoryId ? null : categoryId;
    if (_state.selectedChildCategoryId == selected) return;
    ++_operation;
    _replace(
      _state.copyWith(
        selectedChildCategoryId: selected,
        items: const [],
        page: 0,
        totalItems: 0,
        totalPages: 0,
        cursorPagination: false,
        cursorHasNextPage: false,
        cursorHasPreviousPage: false,
        isInitialLoading: true,
        isRefreshing: false,
        isLoadingMore: false,
        error: null,
        loadMoreError: null,
        filterData: null,
        availableSizes: const [],
        availableColors: const [],
      ),
    );
    await loadInitial();
  }

  Future<CatalogFilterOptions> loadFilterOptions() {
    final source = _repository;
    return source is CatalogFilterOptionsSource
        ? (source as CatalogFilterOptionsSource).getFilterOptions()
        : Future.value(const CatalogFilterOptions());
  }

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

  Future<void> applySize(CatalogSizeOption? size) => applySizes([?size]);
  Future<void> applyColor(CatalogSizeOption? color) => applyColors([?color]);
  Future<void> applySizes(List<CatalogSizeOption> sizes) =>
      applyFilters(_state.filters.withOptions(sizes: sizes));
  Future<void> applyColors(List<CatalogSizeOption> colors) =>
      applyFilters(_state.filters.withOptions(colors: colors));

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
      categoryIds: effectiveCategoryId != null
          ? <int>[effectiveCategoryId!]
          : const <int>[],
      brandIds: request.brandId != null
          ? <int>[request.brandId!]
          : filters.hasBrand
          ? <int>[filters.brandId!]
          : const <int>[],
      tagIds: filters.tags.map((tag) => tag.id),
      minimumPriceMinor: filters.minimumPriceMinor,
      maximumPriceMinor: filters.maximumPriceMinor,
      attributes: _attributeFilters([...filters.sizes, ...filters.colors]),
      onSale: filters.onSaleOnly || collectionIsSale ? true : null,
      featured: collectionIsFeatured ? true : null,
    );
  }

  static List<CatalogAttributeFilter> _attributeFilters(
    List<CatalogSizeOption> options,
  ) {
    final groups = <String, Set<String>>{};
    for (final option in options) {
      groups.putIfAbsent(option.taxonomy, () => <String>{}).add(option.term);
    }
    return [
      for (final group in groups.entries)
        CatalogAttributeFilter(taxonomy: group.key, terms: group.value),
    ];
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
