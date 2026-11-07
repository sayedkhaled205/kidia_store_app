import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_options.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_filter_data_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_money_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_product_model.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_variation_model.dart';
import 'package:mobishop_store_app/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';

void main() {
  test(
    'filter metadata caches coalesce per mode, expire and evict errors',
    () async {
      var now = DateTime(2026, 11, 6);
      final source = _FacetSource();
      final pending = Completer<CatalogFilterOptions>();
      source.handler = (_) => pending.future;
      final repository = CatalogRepositoryImpl(source, now: () => now);
      addTearDown(repository.dispose);
      final tags = repository.getFilterOptions(includeAttributes: false);
      final sameTags = repository.getFilterOptions(includeAttributes: false);
      final full = repository.getFilterOptions();
      expect(source.calls, [false, true]);
      pending.complete(const CatalogFilterOptions());
      await Future.wait([tags, sameTags, full]);
      await repository.getFilterOptions(includeAttributes: false);
      await repository.getFilterOptions();
      expect(source.calls.length, 2);
      now = now.add(const Duration(minutes: 6));
      source.handler = (_) async => throw StateError('offline');
      await expectLater(
        repository.getFilterOptions(includeAttributes: false),
        throwsStateError,
      );
      source.handler = (_) async => const CatalogFilterOptions();
      await repository.getFilterOptions(includeAttributes: false);
      expect(source.calls, [false, true, false, false]);
    },
  );
  test(
    'catalog invalidation discards even a late filter metadata response',
    () async {
      final changes = StreamController<int>.broadcast(sync: true);
      final pending = Completer<CatalogFilterOptions>();
      final source = _FacetSource()..handler = (_) => pending.future;
      final repository = CatalogRepositoryImpl(source, changes: changes.stream);
      addTearDown(changes.close);
      addTearDown(repository.dispose);
      final old = repository.getFilterOptions(includeAttributes: false);
      changes.add(1);
      pending.complete(const CatalogFilterOptions());
      await old;
      source.handler = (_) async => const CatalogFilterOptions();
      await repository.getFilterOptions(includeAttributes: false);
      expect(source.calls, [false, false]);
    },
  );
  test(
    'opening a recently listed product skips a duplicate read and expires after 20 seconds',
    () async {
      final source = _CountingSource();
      var now = DateTime(2026, 10, 17);
      final repository = CatalogRepositoryImpl(source, now: () => now);
      addTearDown(repository.dispose);
      final page = await repository.getProducts(CatalogProductQuery());
      expect(await repository.getProduct(10), same(page.items.single));
      expect(source.productCalls, 0);
      now = now.add(const Duration(seconds: 21));
      await repository.getProduct(10);
      expect(source.productCalls, 1);
    },
  );

  test('store changes invalidate cached product and variation data', () async {
    final changes = StreamController<int>.broadcast(sync: true);
    final source = _CountingSource();
    final repository = CatalogRepositoryImpl(source, changes: changes.stream);
    addTearDown(changes.close);
    addTearDown(repository.dispose);
    await repository.getProduct(10);
    await repository.getVariations(10);
    await repository.getProduct(10);
    await repository.getVariations(10);
    expect(source.productCalls, 1);
    expect(source.variationCalls, 1);
    changes.add(1);
    await repository.getProduct(10);
    await repository.getVariations(10);
    expect(source.productCalls, 2);
    expect(source.variationCalls, 2);
  });

  test(
    'concurrent reads share one request and an invalidated response cannot refill the cache',
    () async {
      final changes = StreamController<int>.broadcast(sync: true);
      final source = _CountingSource()
        ..pending = Completer<CatalogProductModel>();
      final repository = CatalogRepositoryImpl(source, changes: changes.stream);
      addTearDown(changes.close);
      addTearDown(repository.dispose);
      final first = repository.getProduct(10);
      final second = repository.getProduct(10);
      expect(source.productCalls, 1);
      changes.add(1);
      source.pending!.complete(_FakeCatalogRemoteDataSource._product);
      await Future.wait([first, second]);
      source.pending = null;
      await repository.getProduct(10);
      expect(source.productCalls, 2);
    },
  );

  test(
    'repository exposes domain products without leaking data models',
    () async {
      final CatalogRepositoryImpl repository = CatalogRepositoryImpl(
        _FakeCatalogRemoteDataSource(),
      );

      final page = await repository.getProducts(CatalogProductQuery());

      expect(page.items.single.id, 10);
      expect(page.items.single.name, 'Repository product');
      expect(page.items.single, isNot(isA<CatalogProductModel>()));
    },
  );

  test('repository preserves typed Store API failures', () async {
    final CatalogRepositoryImpl repository = CatalogRepositoryImpl(
      _FailingCatalogRemoteDataSource(),
    );

    await expectLater(
      repository.getProduct(10),
      throwsA(
        isA<CatalogRepositoryException>()
            .having(
              (CatalogRepositoryException error) => error.kind,
              'kind',
              StoreApiFailureKind.timeout,
            )
            .having(
              (CatalogRepositoryException error) => error.message,
              'message',
              'timed out',
            ),
      ),
    );
  });
}

class _CountingSource extends _FakeCatalogRemoteDataSource {
  int productCalls = 0;
  int variationCalls = 0;
  Completer<CatalogProductModel>? pending;
  @override
  Future<CatalogProductModel> fetchProduct(int productId) {
    productCalls++;
    return pending?.future ?? super.fetchProduct(productId);
  }

  @override
  Future<List<CatalogVariationModel>> fetchVariations(int productId) {
    variationCalls++;
    return super.fetchVariations(productId);
  }
}

class _FakeCatalogRemoteDataSource implements CatalogRemoteDataSource {
  static const CatalogProductModel _product = CatalogProductModel(
    id: 10,
    name: 'Repository product',
    slug: 'repository-product',
    type: 'simple',
    prices: CatalogMoneyModel(
      currencyCode: 'USD',
      currencyMinorUnit: 2,
      priceMinor: '2500',
    ),
  );

  @override
  Future<CatalogPage<CatalogCategoryModel>> fetchCategories(
    CatalogCategoryQuery query,
  ) async {
    return CatalogPage<CatalogCategoryModel>(
      items: const <CatalogCategoryModel>[],
      page: query.page,
      perPage: query.perPage,
      totalItems: 0,
      totalPages: 0,
    );
  }

  @override
  Future<CatalogFilterDataModel> fetchFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    return const CatalogFilterDataModel();
  }

  @override
  Future<CatalogProductModel> fetchProduct(int productId) async => _product;

  @override
  Future<List<CatalogVariationModel>> fetchVariations(int productId) async {
    return const <CatalogVariationModel>[];
  }

  @override
  Future<CatalogPage<CatalogProductModel>> fetchProducts(
    CatalogProductQuery query,
  ) async {
    return CatalogPage<CatalogProductModel>(
      items: const <CatalogProductModel>[_product],
      page: query.page,
      perPage: query.perPage,
      totalItems: 1,
      totalPages: 1,
    );
  }
}

class _FailingCatalogRemoteDataSource extends _FakeCatalogRemoteDataSource {
  @override
  Future<CatalogProductModel> fetchProduct(int productId) {
    throw const StoreApiException(
      kind: StoreApiFailureKind.timeout,
      message: 'timed out',
    );
  }
}

class _FacetSource extends _FakeCatalogRemoteDataSource
    implements CatalogFilterOptionsSource {
  final calls = <bool>[];
  Future<CatalogFilterOptions> Function(bool) handler = (_) async =>
      const CatalogFilterOptions();
  @override
  Future<CatalogFilterOptions> getFilterOptions({
    bool includeAttributes = true,
  }) {
    calls.add(includeAttributes);
    return handler(includeAttributes);
  }
}
