import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_filter_data_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_money_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_product_model.dart';
import 'package:kidia_store_app/features/catalog/data/models/catalog_variation_model.dart';
import 'package:kidia_store_app/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';

void main() {
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
