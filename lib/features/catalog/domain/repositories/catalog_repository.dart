import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';

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

/// Optional capability for repositories that keep a recently read product's
/// images around after it would otherwise be considered expired, so a
/// product page can show the known photo while a fresh read is in flight.
/// Implementing this is never required by [CatalogRepository]; fakes and
/// other commerce backends are unaffected unless they opt in.
abstract interface class CatalogProductImagePreviewSource {
  /// Returns the images last seen for [productId], or an empty list when
  /// none are cached (including an invalid, non-positive id).
  List<CatalogImage> cachedProductImages(int productId);
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
