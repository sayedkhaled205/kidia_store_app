import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._remoteDataSource);

  final CatalogRemoteDataSource _remoteDataSource;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) {
    return _guard(
      () async => (await _remoteDataSource.fetchProducts(
        query,
      )).map((model) => model.toEntity()),
    );
  }

  @override
  Future<CatalogProduct> getProduct(int productId) {
    return _guard(
      () async => (await _remoteDataSource.fetchProduct(productId)).toEntity(),
    );
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) {
    return _guard(
      () async => List<CatalogVariation>.unmodifiable(
        (await _remoteDataSource.fetchVariations(
          productId,
        )).map((model) => model.toEntity()),
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
