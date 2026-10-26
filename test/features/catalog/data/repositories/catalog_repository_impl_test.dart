import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
  test('detail reads never reuse a listed or completed stock snapshot', () async {
    final source = _CountingSource();
    final repository = CatalogRepositoryImpl(source);
    addTearDown(repository.dispose);
    await repository.getProducts(CatalogProductQuery());
    await repository.getProduct(10);
    await repository.getProduct(10);
    await repository.getVariations(10);
    await repository.getVariations(10);
    expect(source.productCalls, 2);
    expect(source.variationCalls, 2);
  });

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
    expect(source.productCalls, 2);
    expect(source.variationCalls, 2);
    changes.add(1);
    await repository.getProduct(10);
    await repository.getVariations(10);
    expect(source.productCalls, 3);
    expect(source.variationCalls, 3);
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
