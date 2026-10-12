import 'dart:async';

import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/data/odoo/odoo_catalog_gateway.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_change_source.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';

/// Only the verified public mobile catalog is exposed. Customer/cart/orders
/// must use a separate buyer-scoped contract, never the licensed merchantAPI.
class OdooCatalogRepository implements CatalogRepository, CatalogChangeSource {
  const OdooCatalogRepository({required this.gateway, this.changes});
  final OdooCatalogGateway gateway;
  final Stream<int>? changes;
  @override
  Stream<int> get catalogChanges => changes ?? const Stream<int>.empty();

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) =>
      _guard(() {
        _supportedProductQuery(query);
        return gateway.getProducts(
          page: query.page,
          perPage: query.perPage,
          search: query.search,
          categoryId: query.categoryIds.isEmpty
              ? null
              : query.categoryIds.single,
          newest: query.sort == CatalogSort.newest,
        );
      });

  @override
  Future<CatalogProduct> getProduct(int productId) =>
      _guard(() => gateway.getProduct(productId));

  @override
  Future<List<CatalogVariation>> getVariations(int productId) =>
      _guard(() => gateway.getVariations(productId));

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) => _guard(() {
    // Selector83 responses acknowledge the narrow parent/IDs/empty contract.
    // An older connector may still serve baseline name-ordered categories.
    if (query.search.isNotEmpty ||
        query.excludeIds.isNotEmpty ||
        (query.parentId != null && query.includeIds.isNotEmpty) ||
        (query.sort != CatalogCategorySort.menuOrder &&
            query.sort != CatalogCategorySort.name &&
            !(query.sort == CatalogCategorySort.include &&
                query.includeIds.isNotEmpty))) {
      throw _unsupported(
        'The Odoo public catalog does not support this category filter/sort.',
      );
    }
    return gateway.getCategories(
      page: query.page,
      perPage: query.perPage,
      parentId: query.parentId,
      hideEmpty: query.hideEmpty,
      includeIds: query.includeIds,
    );
  });

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) => _guard(() {
    _supportedProductQuery(query);
    if (query.search.isNotEmpty || query.categoryIds.isNotEmpty) {
      throw _unsupported('Odoo contextual filter metadata is not verified.');
    }
    if (attributeTaxonomies.isNotEmpty) {
      throw _unsupported('Odoo attribute filter metadata is not verified.');
    }
    return gateway.getFilterData();
  });

  static void _supportedProductQuery(CatalogProductQuery query) {
    if (query.search.runes.length > 80 ||
        (query.sort != CatalogSort.relevance &&
            query.sort != CatalogSort.name &&
            query.sort != CatalogSort.newest) ||
        query.includeIds.isNotEmpty ||
        query.excludeIds.isNotEmpty ||
        query.categoryIds.length > 1 ||
        query.tagIds.isNotEmpty ||
        query.brandIds.isNotEmpty ||
        query.parentIds.isNotEmpty ||
        query.stock.isNotEmpty ||
        query.attributes.isNotEmpty ||
        query.minimumPriceMinor.isNotEmpty ||
        query.maximumPriceMinor.isNotEmpty ||
        query.onSale != null ||
        query.featured != null ||
        query.productType != null) {
      throw _unsupported(
        'This Odoo catalog filter/sort is not verified in this build.',
      );
    }
  }

  static CatalogRepositoryException _unsupported(String message) =>
      CatalogRepositoryException(
        kind: StoreApiFailureKind.configuration,
        message: message,
      );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CatalogRepositoryException {
      rethrow;
    } on StoreApiException catch (error) {
      throw CatalogRepositoryException(
        kind: error.kind,
        message: error.message,
        statusCode: error.statusCode,
      );
    } on FormatException {
      throw const CatalogRepositoryException(
        kind: StoreApiFailureKind.invalidResponse,
        message: 'Odoo returned invalid catalog data.',
      );
    } on ArgumentError {
      throw _unsupported('Invalid Odoo catalog request.');
    } catch (_) {
      throw const CatalogRepositoryException(
        kind: StoreApiFailureKind.unknown,
        message: 'The Odoo catalog request failed.',
      );
    }
  }
}
