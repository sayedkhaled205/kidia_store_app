import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';

abstract interface class CatalogRepository {
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query);

  Future<CatalogProduct> getProduct(int productId);

  Future<List<CatalogVariation>> getVariations(int productId);

  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  );

  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  });
}

class CatalogRepositoryException implements Exception {
  const CatalogRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final StoreApiFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
