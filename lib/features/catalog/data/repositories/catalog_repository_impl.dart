import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_options.dart';
import 'dart:async';

import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_change_source.dart';

class CatalogRepositoryImpl
    implements
        CatalogRepository,
        CatalogChangeSource,
        CatalogFilterOptionsSource {
  CatalogRepositoryImpl(
    this._remoteDataSource, {
    Stream<int>? changes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _changes = changes?.asBroadcastStream() {
    _changeSubscription = _changes?.listen((_) => _clearProductReads());
  }

  final CatalogRemoteDataSource _remoteDataSource;
  final DateTime Function() _now;
  final Stream<int>? _changes;
  StreamSubscription<int>? _changeSubscription;
  int _revision = 0;
  Future<CatalogFilterOptions>? _filterOptions;
  DateTime? _filterOptionsExpire;
  @override
  Future<CatalogFilterOptions> getFilterOptions() async {
    final source = _remoteDataSource;
    if (source is! CatalogFilterOptionsSource) {
      return const CatalogFilterOptions();
    }
    if (_filterOptions != null &&
        _filterOptionsExpire != null &&
        _now().isBefore(_filterOptionsExpire!)) {
      return _filterOptions!;
    }
    final request = (source as CatalogFilterOptionsSource)
        .getFilterOptions()
        .timeout(const Duration(seconds: 15));
    _filterOptions = request;
    _filterOptionsExpire = _now().add(const Duration(minutes: 5));
    try {
      return await request;
    } catch (_) {
      if (identical(_filterOptions, request)) _filterOptions = null;
      rethrow;
    }
  }

  static const _productReadLifetime = Duration(seconds: 20);
  static const _maxProductReads = 96;
  final _products = <int, _RecentProductRead<CatalogProduct>>{};
  final _variations = <int, _RecentProductRead<List<CatalogVariation>>>{};
  final _productRequests = <int, Future<CatalogProduct>>{};
  final _variationRequests = <int, Future<List<CatalogVariation>>>{};

  @override
  Stream<int> get catalogChanges => _changes ?? const Stream<int>.empty();

  void _clearProductReads() {
    _revision++;
    _filterOptions = null;
    _filterOptionsExpire = null;
    _products.clear();
    _variations.clear();
    _productRequests.clear();
    _variationRequests.clear();
  }

  Future<void> dispose() async {
    _clearProductReads();
    await _changeSubscription?.cancel();
  }

  void _remember<T>(Map<int, _RecentProductRead<T>> cache, int id, T value) {
    cache.remove(id);
    cache[id] = _RecentProductRead(value, _now().add(_productReadLifetime));
    while (cache.length > _maxProductReads) {
      cache.remove(cache.keys.first);
    }
  }

  Future<T> _recentRead<T>(
    int id,
    Map<int, _RecentProductRead<T>> cache,
    Map<int, Future<T>> pending,
    Future<T> Function() load,
  ) async {
    final saved = cache[id];
    if (saved != null && _now().isBefore(saved.expiresAt)) return saved.value;
    final inFlight = pending[id];
    if (inFlight != null) return inFlight;
    final revision = _revision;
    final request = load();
    pending[id] = request;
    try {
      final value = await request;
      if (revision == _revision) _remember(cache, id, value);
      return value;
    } finally {
      if (identical(pending[id], request)) pending.remove(id);
    }
  }

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) {
    final revision = _revision;
    return _guard(() async {
      final page = (await _remoteDataSource.fetchProducts(
        query,
      )).map((model) => model.toEntity());
      // Store API lists contain the same public product fields as detail reads.
      // Reuse a just-rendered card instead of blocking quick-add on another GET.
      // Prices/stock expire quickly, store changes invalidate immediately, and
      // every cart mutation still uses WooCommerce's authoritative validation.
      if (revision == _revision) {
        for (final product in page.items) {
          _remember(_products, product.id, product);
        }
      }
      return page;
    });
  }

  @override
  Future<CatalogProduct> getProduct(int productId) {
    return _recentRead(
      productId,
      _products,
      _productRequests,
      () => _guard(
        () async =>
            (await _remoteDataSource.fetchProduct(productId)).toEntity(),
      ),
    );
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) {
    return _recentRead(
      productId,
      _variations,
      _variationRequests,
      () => _guard(
        () async => List<CatalogVariation>.unmodifiable(
          (await _remoteDataSource.fetchVariations(
            productId,
          )).map((model) => model.toEntity()),
        ),
      ),
    );
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) {
    return _guard(
      () async => (await _remoteDataSource.fetchCategories(
        query,
      )).map((model) => model.toEntity()),
    );
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) {
    return _guard(() async {
      final model = await _remoteDataSource.fetchFilterData(
        query,
        attributeTaxonomies: attributeTaxonomies,
      );
      return model.toEntity();
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CatalogRepositoryException {
      rethrow;
    } on StoreApiException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CatalogRepositoryException(
          kind: error.kind,
          message: error.message,
          statusCode: error.statusCode,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CatalogRepositoryException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'The store returned invalid catalog data.',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CatalogRepositoryException(
          kind: StoreApiFailureKind.unknown,
          message: 'The catalog request failed unexpectedly.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}

class _RecentProductRead<T> {
  const _RecentProductRead(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;
}
