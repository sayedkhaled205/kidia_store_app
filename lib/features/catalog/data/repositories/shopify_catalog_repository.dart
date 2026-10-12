import 'dart:async';
import 'dart:convert';

import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/data/shopify/shopify_catalog_gateway.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_data.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_change_source.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';

/// Adapts the Native catalog contract to real Shopify Storefront connections.
/// Page numbers identify visited cursor pages, never a fabricated total/count.
/// This class does not provide customer auth, checkout or any Admin operation.
class ShopifyCatalogRepository
    implements CatalogRepository, CatalogChangeSource {
  ShopifyCatalogRepository({required this.gateway, Stream<int>? changes}) {
    _subscription = changes?.listen((int revision) {
      if (_disposed) return;
      _products.clear();
      _collections.clear();
      _generation++;
      _changes.add(revision);
    });
  }

  static const int _maximumSessions = 16;
  static const int _maximumPages = 200;
  static const int _maximumVariantPages = 40; // 2,000 variants, no truncation.
  final ShopifyCatalogGateway gateway;
  final Map<String, _CursorSession> _products = <String, _CursorSession>{};
  final Map<String, _CursorSession> _collections = <String, _CursorSession>{};
  final StreamController<int> _changes = StreamController<int>.broadcast(
    sync: true,
  );
  StreamSubscription<int>? _subscription;
  bool _disposed = false;
  int _generation = 0;

  @override
  Stream<int> get catalogChanges => _changes.stream;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(CatalogProductQuery query) {
    return _guard(() async {
      _validateProducts(query);
      final Map<String, dynamic> normalized = query.toStoreApiQuery()
        ..remove('page');
      final String key = jsonEncode(normalized);
      final _CursorSession session = _session(_products, key, query.page);
      final int operation = ++session.operation;
      final String? after = session.after[query.page];
      final ShopifyCursorPage<ShopifyProductRecord> page = await gateway
          .getProducts(
            first: query.perPage,
            after: after,
            search: query.search,
            sort:
                query.categoryIds.isNotEmpty &&
                    query.sort == CatalogSort.relevance
                ? ShopifyCatalogSort.relevance
                : _productSort(query.sort, hasSearch: query.search.isNotEmpty),
            collectionId: query.categoryIds.isEmpty
                ? null
                : query.categoryIds.single,
          );
      _validateCurrent(_products, key, session, operation);
      _acceptPage(session, query.page, after, page);
      return CatalogPage<CatalogProduct>(
        items: List<CatalogProduct>.unmodifiable(
          page.items.map((ShopifyProductRecord record) => record.product),
        ),
        page: query.page,
        perPage: query.perPage,
        totalItems: null,
        totalPages: null,
        cursorPagination: true,
        cursorHasNextPage: page.hasNextPage,
        // An earlier visited page can be fetched again using its known cursor.
        // Forward Shopify connections may not report hasPreviousPage reliably.
        cursorHasPreviousPage:
            query.page > 1 && session.after.containsKey(query.page - 1),
        nextCursor: page.hasNextPage ? page.endCursor : null,
        previousCursor: query.page > 1 ? session.after[query.page - 1] : null,
      );
    });
  }

  @override
  Future<CatalogProduct> getProduct(int productId) {
    return _guard(() async {
      if (productId <= 0) throw _unsupported('Invalid Shopify product ID.');
      final int generation = _generation;
      final ShopifyProductRecord record = await gateway.getProduct(productId);
      _validateGeneration(generation);
      if (record.product.id != productId) {
        throw const FormatException('Shopify returned a different product.');
      }
      if (!record.product.hasVariations) return record.product;
      // The shared detail controller may ignore a later variation fetch error.
      // Complete this selection list before exposing a successful detail page.
      final List<CatalogVariation> variations = await _completeVariants(
        productId,
        generation,
        firstRecord: record,
      );
      final CatalogProduct product = record.product;
      return CatalogProduct(
        id: product.id,
        name: product.name,
        slug: product.slug,
        type: product.type,
        prices: product.prices,
        parentId: product.parentId,
        variationLabel: product.variationLabel,
        permalink: product.permalink,
        sku: product.sku,
        summary: product.summary,
        description: product.description,
        isFeatured: product.isFeatured,
        isOnSale: product.isOnSale,
        isPurchasable: product.isPurchasable,
        isInStock: product.isInStock,
        stockStatus: product.stockStatus,
        averageRating: product.averageRating,
        reviewCount: product.reviewCount,
        images: product.images,
        categories: product.categories,
        brands: product.brands,
        attributes: product.attributes,
        variations: variations,
      );
    });
  }

  @override
  Future<List<CatalogVariation>> getVariations(int productId) {
    return _guard(() async {
      if (productId <= 0) throw _unsupported('Invalid Shopify product ID.');
      return _completeVariants(productId, _generation);
    });
  }

  Future<List<CatalogVariation>> _completeVariants(
    int productId,
    int generation, {
    ShopifyProductRecord? firstRecord,
  }) async {
    final List<CatalogVariation> result = <CatalogVariation>[];
    final Set<String> cursors = <String>{};
    final Set<int> ids = <int>{};
    String? after;
    for (int index = 0; index < _maximumVariantPages; index++) {
      final ShopifyProductRecord record = index == 0 && firstRecord != null
          ? firstRecord
          : await gateway.getProduct(
              productId,
              variantFirst: 50,
              variantAfter: after,
            );
      _validateGeneration(generation);
      if (record.product.id != productId || record.variants == null) {
        throw const FormatException('Shopify variants are missing.');
      }
      final ShopifyCursorPage<CatalogVariation> page = record.variants!;
      for (final CatalogVariation variation in page.items) {
        if (!ids.add(variation.id)) {
          throw const FormatException('Shopify repeated a variant.');
        }
        result.add(variation);
      }
      if (!page.hasNextPage) {
        if (result.isEmpty) {
          throw const FormatException('Shopify variants are empty.');
        }
        return List<CatalogVariation>.unmodifiable(result);
      }
      final String cursor = _nextCursor(page.endCursor);
      if (page.items.isEmpty || !cursors.add(cursor)) {
        throw const FormatException('Shopify variant cursor did not advance.');
      }
      after = cursor;
    }
    throw _unsupported(
      'This product has too many variant pages to load safely. '
      'No partial variant list was returned.',
    );
  }

  @override
  Future<CatalogPage<CatalogCategory>> getCategories(
    CatalogCategoryQuery query,
  ) {
    return _guard(() async {
      _validateCollections(query);
      if (query.includeIds.isNotEmpty) {
        final generation = _generation;
        final items = await Future.wait(
          query.includeIds.map(gateway.getCollection),
        );
        _validateGeneration(generation);
        return CatalogPage<CatalogCategory>(
          items: items,
          page: 1,
          perPage: query.perPage,
          totalItems: items.length,
          totalPages: 1,
        );
      }
      final Map<String, dynamic> normalized = query.toStoreApiQuery()
        ..remove('page');
      final String key = jsonEncode(normalized);
      final _CursorSession session = _session(_collections, key, query.page);
      final int operation = ++session.operation;
      final String? after = session.after[query.page];
      final ShopifyCursorPage<CatalogCategory> page = await gateway
          .getCollections(first: query.perPage, after: after);
      _validateCurrent(_collections, key, session, operation);
      _acceptPage(session, query.page, after, page);
      return CatalogPage<CatalogCategory>(
        items: page.items,
        page: query.page,
        perPage: query.perPage,
        totalItems: null,
        totalPages: null,
        cursorPagination: true,
        cursorHasNextPage: page.hasNextPage,
        cursorHasPreviousPage:
            query.page > 1 && session.after.containsKey(query.page - 1),
        nextCursor: page.hasNextPage ? page.endCursor : null,
        previousCursor: query.page > 1 ? session.after[query.page - 1] : null,
      );
    });
  }

  @override
  Future<CatalogFilterData> getFilterData(
    CatalogProductQuery query, {
    Iterable<String> attributeTaxonomies = const <String>[],
  }) async {
    throw _unsupported(
      'Shopify aggregate filters are not provided by this Storefront gateway. '
      'No WooCommerce filter endpoint or invented counts were used.',
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _products.clear();
    _collections.clear();
    await _subscription?.cancel();
    await _changes.close();
  }

  _CursorSession _session(
    Map<String, _CursorSession> sessions,
    String key,
    int page,
  ) {
    _validateGeneration(_generation);
    if (page > _maximumPages) {
      throw _unsupported(
        'The requested Shopify cursor page exceeds the limit.',
      );
    }
    if (page == 1) {
      sessions.remove(key);
      sessions[key] = _CursorSession(_generation);
      if (sessions.length > _maximumSessions) {
        sessions.remove(sessions.keys.first);
      }
    }
    final _CursorSession? session = sessions[key];
    if (session == null || !session.after.containsKey(page)) {
      throw _unsupported(
        'This Shopify page has no known cursor. Start at the first page '
        'and navigate using Next or Previous.',
      );
    }
    return session;
  }

  void _validateCurrent(
    Map<String, _CursorSession> sessions,
    String key,
    _CursorSession session,
    int operation,
  ) {
    _validateGeneration(session.generation);
    if (!identical(sessions[key], session) || operation != session.operation) {
      throw _cancelled();
    }
  }

  void _validateGeneration(int generation) {
    if (_disposed || generation != _generation) throw _cancelled();
  }

  static void _acceptPage<T>(
    _CursorSession session,
    int pageNumber,
    String? after,
    ShopifyCursorPage<T> page,
  ) {
    // Refetching a previously visited page invalidates its later cursor chain.
    session.after.removeWhere((int number, _) => number > pageNumber);
    if (!page.hasNextPage) return;
    final String next = _nextCursor(page.endCursor);
    if (page.items.isEmpty ||
        next == after ||
        session.after.values.contains(next)) {
      throw const FormatException('Shopify catalog cursor did not advance.');
    }
    session.after[pageNumber + 1] = next;
  }

  static String _nextCursor(String? value) {
    if (value == null || value.isEmpty || value.length > 4096) {
      throw const FormatException('Invalid Shopify next cursor.');
    }
    return value;
  }

  static void _validateProducts(CatalogProductQuery query) {
    if (query.perPage > 20) {
      throw _unsupported('Shopify product page size must be at most 20.');
    }
    if (query.categoryIds.length > 1 ||
        (query.categoryIds.isNotEmpty && query.search.isNotEmpty) ||
        query.tagIds.isNotEmpty ||
        query.brandIds.isNotEmpty ||
        query.parentIds.isNotEmpty ||
        query.includeIds.isNotEmpty ||
        query.excludeIds.isNotEmpty ||
        query.stock.isNotEmpty ||
        query.attributes.isNotEmpty ||
        query.minimumPriceMinor.isNotEmpty ||
        query.maximumPriceMinor.isNotEmpty ||
        query.onSale != null ||
        query.featured != null ||
        query.productType != null) {
      throw _unsupported(
        'The requested Shopify product filter is not implemented. '
        'An unfiltered catalog was not substituted.',
      );
    }
  }

  static ShopifyCatalogSort _productSort(
    CatalogSort value, {
    required bool hasSearch,
  }) {
    return switch (value) {
      CatalogSort.newest => ShopifyCatalogSort.newest,
      CatalogSort.relevance =>
        hasSearch ? ShopifyCatalogSort.relevance : ShopifyCatalogSort.newest,
      CatalogSort.priceLowToHigh => ShopifyCatalogSort.priceLowToHigh,
      CatalogSort.priceHighToLow => ShopifyCatalogSort.priceHighToLow,
      CatalogSort.name => ShopifyCatalogSort.name,
      CatalogSort.includeOrder ||
      CatalogSort.popularity ||
      CatalogSort.rating => throw _unsupported(
        'The requested Shopify product sort is unsupported.',
      ),
    };
  }

  static void _validateCollections(CatalogCategoryQuery query) {
    if (query.perPage > 100 ||
        (query.parentId != null && query.parentId != 0) ||
        query.hideEmpty ||
        query.search.isNotEmpty ||
        (query.includeIds.isNotEmpty &&
            (query.page != 1 ||
                query.perPage != query.includeIds.length ||
                query.parentId != null ||
                query.sort != CatalogCategorySort.include)) ||
        query.excludeIds.isNotEmpty ||
        (query.sort != CatalogCategorySort.name &&
            query.sort != CatalogCategorySort.menuOrder &&
            !(query.sort == CatalogCategorySort.include &&
                query.includeIds.isNotEmpty))) {
      throw _unsupported(
        'The requested Shopify collection filter or hierarchy is unsupported. '
        'Collections are flat; empty counts and hierarchy are not invented.',
      );
    }
  }

  static CatalogRepositoryException _unsupported(String message) =>
      CatalogRepositoryException(
        kind: StoreApiFailureKind.configuration,
        message: message,
      );

  static CatalogRepositoryException _cancelled() =>
      const CatalogRepositoryException(
        kind: StoreApiFailureKind.cancelled,
        message: 'The Shopify catalog request is no longer current.',
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      _validateGeneration(_generation);
      return await action();
    } on CatalogRepositoryException {
      rethrow;
    } on StoreApiException catch (error, trace) {
      // The direct transport has already removed response bodies/credentials.
      Error.throwWithStackTrace(
        CatalogRepositoryException(
          kind: error.kind,
          statusCode: error.statusCode,
          message: error.message,
        ),
        trace,
      );
    } on FormatException catch (_, trace) {
      Error.throwWithStackTrace(
        const CatalogRepositoryException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'Shopify returned invalid catalog data.',
        ),
        trace,
      );
    } on StateError catch (_, trace) {
      Error.throwWithStackTrace(
        const CatalogRepositoryException(
          kind: StoreApiFailureKind.notFound,
          message: 'This product is not published to the Shopify storefront.',
        ),
        trace,
      );
    } catch (_, trace) {
      Error.throwWithStackTrace(
        const CatalogRepositoryException(
          kind: StoreApiFailureKind.unknown,
          message: 'The Shopify catalog request could not be completed.',
        ),
        trace,
      );
    }
  }
}

class _CursorSession {
  _CursorSession(this.generation);
  final int generation;
  int operation = 0;
  final Map<int, String?> after = <int, String?>{1: null};
}
